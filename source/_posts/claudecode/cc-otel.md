---
title: Claude Code OpenTelemetry 可观测性体系深度分析
date: 2026-04-07
categories: claudecode
tags:
  - Claude Code
  - OpenTelemetry
  - 源码分析
  - 可观测性
---

# Claude Code OpenTelemetry 可观测性体系深度分析

## 1. 设计哲学总览

Claude Code 作为一个 AI Agent 级别的工具，其 OpenTelemetry（OTel）可观测性体系的设计哲学可以概括为：

**"分层递进、按需激活、多管齐下、隐私优先"**

1. **分层递进（Layered Telemetry）**：可观测性被分为三个独立层次——Metrics（指标）、Logs/Events（事件）、Traces（链路追踪），各自独立配置、独立导出，互不干扰。
2. **按需激活（Opt-in Activation）**：不同级别的可观测性通过不同环境变量和 Feature Gate 控制，从"默认开启的基础指标"到"需要显式启用的详细链路追踪"，形成阶梯式激活策略。
3. **多管齐下（Multi-Backend）**：同一份采集数据可以同时导出到多个后端（OTLP、BigQuery、Prometheus、Perfetto、内部 1P 分析系统），每个后端有专门的 Exporter 实现。
4. **隐私优先（Privacy-First）**：默认对用户 Prompt 做脱敏处理（`<REDACTED>`），仅在用户显式 opt-in 时才记录原文；不同用户身份（`ant` vs 外部）看到的追踪细节不同。

---

## 2. 架构总览

```
┌─────────────────────────────────────────────────────────────────┐
│                        Claude Code Agent                         │
│                                                                  │
│  ┌─────────────┐   ┌─────────────┐   ┌─────────────────────┐   │
│  │ Interaction  │──▶│ LLM Request │──▶│ Tool Execution      │   │
│  │ Span         │   │ Span        │   │ Span                │   │
│  │ (root)       │   │ (child)     │   │ ├─ blocked_on_user  │   │
│  │              │   │             │   │ ├─ execution         │   │
│  │              │   │             │   │ └─ hook              │   │
│  └─────────────┘   └─────────────┘   └─────────────────────┘   │
│         │                  │                    │                 │
│  ┌──────▼──────────────────▼────────────────────▼──────────┐    │
│  │              Telemetry Attributes Layer                   │    │
│  │    (user.id, session.id, organization.id, ...)           │    │
│  └──────┬──────────────────┬────────────────────┬──────────┘    │
│         │                  │                    │                 │
│  ┌──────▼──────┐   ┌──────▼──────┐   ┌────────▼────────┐       │
│  │   Metrics   │   │ Logs/Events │   │    Traces        │       │
│  │ (Counters)  │   │ (OTel Logs) │   │ (Spans)          │       │
│  └──────┬──────┘   └──────┬──────┘   └────────┬────────┘       │
└─────────┼──────────────────┼───────────────────┼────────────────┘
          │                  │                   │
    ┌─────▼─────┐    ┌──────▼──────┐    ┌───────▼───────┐
    │Exporters: │    │Exporters:   │    │Exporters:     │
    │• OTLP     │    │• OTLP       │    │• OTLP         │
    │• BigQuery │    │• Console    │    │• Console      │
    │• Prometheus│    │• 1P Logger  │    │• Perfetto     │
    │• Console  │    │             │    │               │
    └───────────┘    └─────────────┘    └───────────────┘
```

---

## 3. 核心文件清单

| 文件路径 | 职责 |
|---------|------|
| `src/utils/telemetry/instrumentation.ts` | **中枢初始化器**：OTel SDK 的 Resource、Provider、Exporter 装配，启动/关闭生命周期 |
| `src/utils/telemetry/sessionTracing.ts` | **链路追踪引擎**：Span 创建/结束、父子关系、AsyncLocalStorage 上下文传播 |
| `src/utils/telemetry/betaSessionTracing.ts` | **Beta 详细追踪**：System Prompt/Tool Schema 去重日志、增量 new_context 计算 |
| `src/utils/telemetry/events.ts` | **事件发射器**：`logOTelEvent()` 通过 OTel Logs API 发射结构化事件 |
| `src/utils/telemetry/bigqueryExporter.ts` | **自定义 Metrics Exporter**：将 OTel 指标序列化为 BigQuery 格式并通过 HTTP POST 上报 |
| `src/utils/telemetry/perfettoTracing.ts` | **Perfetto 追踪**：Chrome Trace Event 格式，输出可在 ui.perfetto.dev 可视化的 JSON |
| `src/utils/telemetry/logger.ts` | **OTel 诊断日志桥**：将 OTel 内部诊断信息桥接到应用调试日志 |
| `src/utils/telemetryAttributes.ts` | **公共属性工厂**：构建所有遥测信号的通用维度（user.id、session.id 等） |
| `src/bootstrap/state.ts` | **全局状态**：持有 MeterProvider、LoggerProvider、TracerProvider 以及各 Counter 实例 |
| `src/services/analytics/firstPartyEventLogger.ts` | **第一方事件系统**：独立于客户 OTLP 的内部分析事件管道 |
| `src/services/analytics/firstPartyEventLoggingExporter.ts` | **第一方事件 Exporter**：带 backoff 重试、磁盘持久化的自定义 LogRecordExporter |
| `src/entrypoints/init.ts` | **启动入口**：延迟加载 OTel 模块、创建 Meter 和 Counter 实例 |

---

## 4. 初始化流程（Initialization Pipeline）

### 4.1 启动时序

```
应用启动
  │
  ├─ init.ts: init()
  │    ├─ applySafeConfigEnvironmentVariables()
  │    ├─ [延迟 import] instrumentation.ts
  │    │    └─ initializeTelemetry()
  │    │         ├─ bootstrapTelemetry()          ← 1. 环境变量映射
  │    │         ├─ diag.setLogger(...)            ← 2. OTel 诊断日志
  │    │         ├─ initializePerfettoTracing()    ← 3. Perfetto（独立于 OTel）
  │    │         ├─ Resource 构建                  ← 4. service.name/version/os/host
  │    │         ├─ MeterProvider + Readers        ← 5. Metrics 管道
  │    │         ├─ LoggerProvider + Exporters     ← 6. Logs 管道（if telemetry enabled）
  │    │         ├─ TracerProvider + Processors    ← 7. Traces 管道（if enhanced）
  │    │         └─ registerCleanup(shutdown)      ← 8. 优雅关闭注册
  │    │
  │    ├─ setMeter(meter)                         ← 9. 创建业务 Counter
  │    └─ initialize1PEventLogging()              ← 10. 第一方事件系统
  │
  └─ 主循环开始
```

### 4.2 延迟加载策略

这是一个极其重要的设计决策——OTel 模块总体积约 1.2MB+，为了不拖慢启动速度：

```typescript
// init.ts 中通过动态 import 延迟加载
// initializeTelemetry is loaded lazily via import() in setMeterState()
// to defer ~400KB of OpenTelemetry + protobuf modules
```

更进一步，gRPC Exporter（~700KB @grpc/grpc-js）在 `instrumentation.ts` 内部按协议类型**按需动态导入**：

```typescript
// instrumentation.ts — 只在协议为 grpc 时才加载
case 'grpc': {
  const { OTLPMetricExporter } = await import(
    '@opentelemetry/exporter-metrics-otlp-grpc'
  )
  exporters.push(new OTLPMetricExporter())
  break
}
```

**设计意图**：一个进程最多只使用一种协议变体，但静态导入会一次加载全部 6 个 Exporter 模块。通过 switch-case + dynamic import，将实际加载量降到最小。

### 4.3 Resource 构建

Resource 是 OTel 中标识遥测信号来源的元数据结构。Claude Code 构建了一个多层合并的 Resource：

```typescript
const baseResource = resourceFromAttributes({
  [ATTR_SERVICE_NAME]: 'claude-code',
  [ATTR_SERVICE_VERSION]: MACRO.VERSION,  // 编译时注入的版本号
})

// 按优先级合并
const resource = baseResource
  .merge(osResource)        // os.type, os.description
  .merge(hostArchResource)  // host.arch
  .merge(envResource)       // OTEL_RESOURCE_ATTRIBUTES 环境变量
```

### 4.4 环境变量体系

Claude Code 定义了一套完整的环境变量体系来控制遥测行为：

| 环境变量 | 作用 | 默认值 |
|---------|------|-------|
| `CLAUDE_CODE_ENABLE_TELEMETRY` | 总开关：启用第三方 OTLP 遥测导出 | `false` |
| `OTEL_METRICS_EXPORTER` | Metrics Exporter 类型（`console`, `otlp`, `prometheus`） | `none` |
| `OTEL_LOGS_EXPORTER` | Logs Exporter 类型（`console`, `otlp`） | `none` |
| `OTEL_TRACES_EXPORTER` | Traces Exporter 类型（`console`, `otlp`） | `none` |
| `OTEL_EXPORTER_OTLP_PROTOCOL` | OTLP 协议（`grpc`, `http/json`, `http/protobuf`） | — |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | OTLP 收集器地址 | — |
| `OTEL_EXPORTER_OTLP_HEADERS` | OTLP 请求头 | — |
| `OTEL_LOG_USER_PROMPTS` | 允许在追踪中记录用户 prompt 原文 | `false` |
| `OTEL_LOG_TOOL_CONTENT` | 允许记录工具输入/输出内容 | `false` |
| `ENABLE_BETA_TRACING_DETAILED` | 启用 Beta 详细追踪 | `false` |
| `BETA_TRACING_ENDPOINT` | Beta 追踪上报地址 | — |
| `CLAUDE_CODE_ENHANCED_TELEMETRY_BETA` | 增强遥测（Feature Gate） | 由 GrowthBook 控制 |
| `CLAUDE_CODE_PERFETTO_TRACE` | Perfetto 本地追踪 | `false` |
| `CLAUDE_CODE_OTEL_SHUTDOWN_TIMEOUT_MS` | 关闭超时 | `2000` |
| `OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE` | 指标时间粒度 | `delta` |

**Ant（内部用户）特殊路径**：`ANT_OTEL_*` 前缀的变量在构建时注入，运行时由 `bootstrapTelemetry()` 映射为标准 `OTEL_*`。

---

## 5. 三大信号深度解析

### 5.1 Metrics（指标）

#### 5.1.1 业务指标定义

Claude Code 定义了 8 个核心业务 Counter，全部注册在 `com.anthropic.claude_code` 命名空间下：

| 指标名 | 描述 | 单位 |
|-------|------|-----|
| `claude_code.session.count` | CLI 会话启动次数 | — |
| `claude_code.lines_of_code.count` | 代码行修改数（含 type=added/removed 维度） | — |
| `claude_code.pull_request.count` | 创建的 PR 数量 | — |
| `claude_code.commit.count` | 创建的 commit 数量 | — |
| `claude_code.cost.usage` | 会话 API 调用成本 | USD |
| `claude_code.token.usage` | Token 消耗量 | tokens |
| `claude_code.code_edit_tool.decision` | 代码编辑工具的决策分布 | — |
| `claude_code.active_time.total` | 活跃时间 | seconds |

#### 5.1.2 Counter 的封装设计

Counter 被封装为 `AttributedCounter` 类型，它在 OTel Counter 之上附加公共维度属性：

```typescript
export type AttributedCounter = {
  add(value: number, additionalAttributes?: Attributes): void
}

// init.ts 中的创建逻辑
function createCounter(name: string, options: MetricOptions): AttributedCounter {
  const counter = meter?.createCounter(name, options)
  return {
    add(value: number, additionalAttributes?: Attributes) {
      const baseAttributes = getTelemetryAttributes()
      counter?.add(value, { ...baseAttributes, ...additionalAttributes })
    }
  }
}
```

**设计亮点**：每次 `add()` 调用时，自动注入 `user.id`、`session.id`、`organization.id` 等公共维度，业务代码无需关心属性传递。

#### 5.1.3 基数控制（Cardinality Control）

指标维度的基数（cardinality）是 OTel Metrics 的核心挑战。Claude Code 通过环境变量控制哪些高基数维度被包含：

```typescript
const METRICS_CARDINALITY_DEFAULTS = {
  OTEL_METRICS_INCLUDE_SESSION_ID: true,   // 默认包含
  OTEL_METRICS_INCLUDE_VERSION: false,     // 默认不包含（版本过多）
  OTEL_METRICS_INCLUDE_ACCOUNT_UUID: true, // 默认包含
}
```

对于事件来说，`prompt.id` 和 `workspace.host_paths` 只附加到 **Events** 上，而不附加到 **Metrics** 上，因为它们会造成无界基数。

#### 5.1.4 时间粒度：Delta vs Cumulative

```typescript
// 默认设置为 delta —— 这是一个慎重的决定
if (!process.env.OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE) {
  process.env.OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE = 'delta'
}
```

BigQuery Exporter 中甚至有一条注释：

```typescript
selectAggregationTemporality(): AggregationTemporality {
  // DO NOT CHANGE THIS TO CUMULATIVE
  // It would mess up the aggregation of metrics
  // for CC Productivity metrics dashboard
  return AggregationTemporality.DELTA
}
```

Delta 模式在 CLI 工具场景下更合理——每个进程短暂存活，报告的是"增量变化"而非"累积总量"。

#### 5.1.5 多 Exporter 并行

Metrics 支持同时启用多个 Exporter，通过 `PeriodicExportingMetricReader` 包装：

- **OTLP Exporter**：标准 OTel 协议导出（支持 gRPC/HTTP JSON/HTTP Protobuf）
- **BigQuery Exporter**：自定义 `PushMetricExporter`，POST 到 `api.anthropic.com/api/claude_code/metrics`
- **Prometheus Exporter**：暴露 pull 端点
- **Console Exporter**：调试用

BigQuery Exporter 有更长的导出间隔（5 分钟 vs 默认 60 秒），用以降低后端负载。

### 5.2 Logs/Events（结构化事件）

#### 5.2.1 双轨事件系统

Claude Code 有两套独立的事件日志系统，各有不同用途：

**第一轨：第三方 OTLP 事件（`events.ts`）**

通过 OTel Logs API 的 `Logger.emit()` 发射，导出到客户配置的 OTLP 后端：

```typescript
export async function logOTelEvent(
  eventName: string,
  metadata: { [key: string]: string | undefined } = {},
): Promise<void> {
  const eventLogger = getEventLogger()
  // ...
  eventLogger.emit({
    body: `claude_code.${eventName}`,
    attributes: {
      ...getTelemetryAttributes(),
      'event.name': eventName,
      'event.timestamp': new Date().toISOString(),
      'event.sequence': eventSequence++,   // 单调递增序列号
    },
  })
}
```

典型事件包括：`user_prompt`、`system_prompt`、`tool`（tool schema 首次出现时）等。

**第二轨：第一方内部分析事件（`firstPartyEventLogger.ts`）**

完全独立于客户遥测管道，使用自己的 `LoggerProvider`：

```typescript
// IMPORTANT: We must get the logger from our local provider, not logs.getLogger()
// because logs.getLogger() returns a logger from the global provider, which is
// separate and used for customer telemetry.
firstPartyEventLogger = firstPartyEventLoggerProvider.getLogger(
  'com.anthropic.claude_code.events',
  MACRO.VERSION,
)
```

事件通过自定义 `FirstPartyEventLoggingExporter` 以 protobuf 格式 POST 到 `/api/event_logging/batch`。

**设计哲学**：将内部分析数据与客户可见的遥测数据严格隔离——内部事件永远不会泄露到客户的 OTLP 端点，反之亦然。

#### 5.2.2 事件采样策略

第一方事件支持通过 GrowthBook 远程配置的采样率控制：

```typescript
export type EventSamplingConfig = {
  [eventName: string]: {
    sample_rate: number  // 0-1
  }
}
```

未配置的事件 100% 记录，`sample_rate=0` 则完全丢弃。

#### 5.2.3 事件持久化与重试

`FirstPartyEventLoggingExporter` 实现了完善的故障恢复机制：

1. **追加式写入**：失败事件以 JSONL 格式追加到 `~/.claude/telemetry/1p_failed_events.<sessionId>.<batchUUID>.json`
2. **二次方退避重试**：`delay = baseDelay × attempts²`，最大 30 秒
3. **跨进程恢复**：启动时扫描同 session 的历史失败文件，在后台重试
4. **短路优化**：一个批次失败后，跳过后续所有批次，避免向不健康的端点白费请求
5. **最大尝试次数**：默认 8 次后丢弃

### 5.3 Traces（分布式链路追踪）

这是 Claude Code OTel 实现中**最精华**的部分，它完整地追踪了 Agent 执行链路。

#### 5.3.1 Span 层次结构

```
claude_code.interaction (root span)
  │
  ├─ claude_code.llm_request (model=claude-sonnet-4-20250514)
  │     attributes: input_tokens, output_tokens, cache_read_tokens,
  │                 ttft_ms, duration_ms, success, ...
  │
  ├─ claude_code.tool (tool_name=Write)
  │     ├─ claude_code.tool.blocked_on_user  ← 等待用户授权
  │     ├─ claude_code.tool.execution        ← 实际执行
  │     └─ claude_code.hook                  ← PreToolUse/PostToolUse 钩子
  │     attributes: tool_name, duration_ms, new_context, ...
  │
  ├─ claude_code.llm_request (第二轮 LLM 调用)
  │
  └─ claude_code.tool (tool_name=BashTool)
        ...
```

每个 Span 类型对应一个 `SpanType`：

```typescript
type SpanType =
  | 'interaction'         // 用户交互回合（root）
  | 'llm_request'         // LLM API 请求
  | 'tool'                // 工具执行（完整生命周期）
  | 'tool.blocked_on_user'// 等待用户批准
  | 'tool.execution'      // 工具实际执行
  | 'hook'                // Hook 执行
```

#### 5.3.2 上下文传播机制：AsyncLocalStorage

传统 OTel 在 Node.js 中使用 `AsyncResource` 或全局 Context API 传播 trace context。Claude Code 做了一个**非典型但实用**的选择——使用 `AsyncLocalStorage` 管理 Span 上下文：

```typescript
const interactionContext = new AsyncLocalStorage<SpanContext | undefined>()
const toolContext = new AsyncLocalStorage<SpanContext | undefined>()
```

**为什么？**

1. Agent 的 LLM 请求和工具执行有**严格的嵌套层次**：`interaction → llm_request/tool`
2. LLM 请求可能**并行执行**（warmup 请求、分类器、主线程），ALS 提供自然的作用域隔离
3. 比 OTel 标准 Context API 更轻量，不需要通过 `context.with()` 传播

父子关系通过手动设置 OTel Context 实现：

```typescript
const ctx = parentSpanCtx
  ? trace.setSpan(otelContext.active(), parentSpanCtx.span)
  : otelContext.active()
const span = tracer.startSpan('claude_code.llm_request', { attributes }, ctx)
```

#### 5.3.3 Span 生命周期管理

**创建与跟踪**：

```typescript
const activeSpans = new Map<string, WeakRef<SpanContext>>()
const strongSpans = new Map<string, SpanContext>()
```

两个 Map 的分工：
- `activeSpans`：所有活跃 Span 的**弱引用**——当 Span 被 ALS 释放且无其他引用时，GC 可回收
- `strongSpans`：不在 ALS 中存储的 Span（LLM request、blocked-on-user、tool execution、hook）需要**强引用**防止被 GC

**自动清理**：

```typescript
const SPAN_TTL_MS = 30 * 60 * 1000 // 30 分钟

function ensureCleanupInterval(): void {
  const interval = setInterval(() => {
    for (const [spanId, weakRef] of activeSpans) {
      const ctx = weakRef.deref()
      if (ctx === undefined) {
        activeSpans.delete(spanId)   // WeakRef 已失效，GC 已回收
      } else if (ctx.startTime < cutoff) {
        ctx.span.end()               // 超时兜底：结束并移除
        activeSpans.delete(spanId)
      }
    }
  }, 60_000)
  interval.unref()  // 不阻止进程退出
}
```

**设计亮点**：
- `unref()` 确保定时器不会阻止 Node.js 自然退出
- WeakRef + 定时清理 = 零内存泄漏风险
- 30 分钟 TTL 作为异常场景的兜底（如未捕获异常导致 Span 未关闭）

#### 5.3.4 Span 属性丰富度

以 LLM Request Span 为例，结束时记录的元数据：

```typescript
endLLMRequestSpan(llmSpan, {
  inputTokens,           // 输入 Token 数
  outputTokens,          // 输出 Token 数
  cacheReadTokens,       // 缓存命中 Token
  cacheCreationTokens,   // 缓存创建 Token
  success,               // 是否成功
  statusCode,            // HTTP 状态码
  error,                 // 错误信息
  attempt,               // 重试次数
  modelOutput,           // 模型输出文本（Beta）
  thinkingOutput,        // 思考链输出（仅 Ant）
  hasToolCall,           // 是否包含工具调用
  ttftMs,                // Time To First Token
  requestSetupMs,        // 请求建立耗时
  attemptStartTimes,     // 各次重试的开始时间戳
})
```

#### 5.3.5 Beta 详细追踪的增量上下文机制

Beta 追踪（`betaSessionTracing.ts`）引入了一个精妙的设计——**基于 Hash 的增量上下文追踪**。

**问题**：Agent 的每轮 LLM 请求都携带完整的对话历史，如果每次都记录完整历史，追踪数据量会爆炸式增长。

**解决方案**：

```typescript
// 跟踪每个 Agent（querySource）最后上报的消息 Hash
const lastReportedMessageHash = new Map<string, string>()

// 每次 LLM 请求时，只发送自上次上报后的新消息
const lastHash = lastReportedMessageHash.get(querySource)
let startIndex = 0
if (lastHash) {
  for (let i = 0; i < messagesForAPI.length; i++) {
    if (hashMessage(messagesForAPI[i]) === lastHash) {
      startIndex = i + 1  // 从上次报告的下一条开始
      break
    }
  }
}
const newMessages = messagesForAPI.slice(startIndex)
```

同样的思路也应用于 **System Prompt 去重**：

```typescript
const seenHashes = new Set<string>()

if (!seenHashes.has(promptHash)) {
  seenHashes.add(promptHash)
  // 只在首次出现时记录完整 System Prompt
  void logOTelEvent('system_prompt', { ... })
}
```

**隐私可见性控制矩阵**：

| 内容 | External 用户 | Ant 内部用户 |
|-----|:---:|:---:|
| System Prompt | ✅ | ✅ |
| Model Output | ✅ | ✅ |
| Thinking Output | ❌ | ✅ |
| Tools | ✅ | ✅ |
| new_context | ✅ | ✅ |

#### 5.3.6 内容截断与 Honeycomb 兼容

所有大型文本属性都进行了截断处理，以适配 Honeycomb（追踪后端）的 64KB 属性限制：

```typescript
const MAX_CONTENT_SIZE = 60 * 1024 // 60KB（Honeycomb limit 64KB，留安全余量）

export function truncateContent(content: string, maxSize = MAX_CONTENT_SIZE) {
  if (content.length <= maxSize) return { content, truncated: false }
  return {
    content: content.slice(0, maxSize) + '\n\n[TRUNCATED - Content exceeds 60KB limit]',
    truncated: true,
  }
}
```

截断时会附加元数据：`xxx_truncated: true`, `xxx_original_length: N`。

---

## 6. Perfetto 追踪系统（独立于 OTel）

除了标准 OTel 追踪外，Claude Code 还实现了一套完全独立的 **Perfetto 追踪系统**（仅限内部用户）。

### 6.1 设计目的

Perfetto 提供的是**本地可视化的全量追踪**，而 OTel Traces 是**上报到远端的采样追踪**。它们是互补关系：

- **OTel Traces**：生产环境监控、问题排查、SLO 计量
- **Perfetto**：本地开发调试、性能 profiling、Agent 层次可视化

### 6.2 Chrome Trace Event 格式

Perfetto 输出标准的 Chrome Trace Event JSON，支持在 `ui.perfetto.dev` 或 `chrome://tracing` 中可视化：

```typescript
type TraceEvent = {
  name: string
  cat: string           // 分类：api, tool, interaction, user_input
  ph: TraceEventPhase   // B(begin), E(end), X(complete), i(instant), C(counter)
  ts: number            // 微秒级时间戳（相对于 trace 开始）
  pid: number           // 进程 ID（主进程=1，子 Agent=递增 ID）
  tid: number           // 线程 ID（Agent 名称的 hash）
  dur?: number
  args?: Record<string, unknown>
}
```

### 6.3 多 Agent 可视化

Perfetto 追踪的一大亮点是**多 Agent 层次结构可视化**：

```typescript
// 每个 Agent 映射为独立的 "进程"（pid）
function getProcessIdForAgent(agentId: string): number {
  processIdCounter++
  agentIdToProcessId.set(agentId, processIdCounter)
  return processIdCounter
}

// Agent 名称映射为 "线程"（tid）
threadId: stringToNumericHash(agentName)
```

在 Perfetto UI 中，每个子 Agent 显示为独立的进程轨道，其中的 API 调用、工具执行以瀑布图的形式排列，并且可以看到：

- **Request Setup** 子 Span（客户端初始化、重试等）
- **First Token** 子 Span（含 TTFT、ITPS）
- **Sampling** 子 Span（含采样速度 OTPS）
- **Retry Attempt** 子 Span（每次重试的起止时间）

### 6.4 API Call 的精细化子 Span

Perfetto 中的 API Call span 被分解为多个子阶段：

```
┌──────── API Call (B/E) ────────────────────────────┐
│ ┌── Request Setup ──┐                              │
│ │  ┌─ Attempt 1 ─┐  │                              │
│ │  └─────────────┘  │                              │
│ │  ┌─ Attempt 2 ─┐  │                              │
│ │  └─────────────┘  │                              │
│ └────────────────────┘                              │
│                       ┌── First Token ──┐           │
│                       │ ttft, itps,     │           │
│                       │ cache_hit_rate  │           │
│                       └─────────────────┘           │
│                                          ┌─ Sampling ─┐
│                                          │ otps,       │
│                                          │ output_toks │
│                                          └─────────────┘
└─────────────────────────────────────────────────────┘
```

### 6.5 内存管理

长时间运行的 cron 会话可能产生大量事件，Perfetto 追踪有严格的内存控制：

```typescript
const MAX_EVENTS = 100_000  // ~30MB

function evictOldestEvents(): void {
  if (events.length < MAX_EVENTS) return
  const dropped = events.splice(0, MAX_EVENTS / 2)  // 淘汰最老的一半
  events.unshift({
    name: 'trace_truncated',    // 插入标记事件
    cat: '__metadata',
    // ...
  })
}
```

过期 Span 也有 30 分钟 TTL 自动清理。

---

## 7. BigQuery 自定义 Metrics Exporter

### 7.1 设计动机

除了标准 OTLP 导出外，Claude Code 为 API 客户和企业用户实现了直连 BigQuery 的指标导出器。这是因为 Anthropic 需要在自己的数据仓库中分析产品使用指标。

### 7.2 导出条件

```typescript
function isBigQueryMetricsEnabled() {
  // 1. API 客户（排除 Claude.ai 订阅者和 Bedrock/Vertex）
  // 2. Claude for Enterprise (C4E) 用户
  // 3. Claude for Teams 用户
  return is1PApiCustomer() || isC4EOrTeamUser
}
```

### 7.3 数据格式

BigQuery Exporter 将 OTel 标准 `ResourceMetrics` 转换为精简的 JSON 格式：

```json
{
  "resource_attributes": {
    "service.name": "claude-code",
    "service.version": "1.0.33",
    "os.type": "linux",
    "host.arch": "x64",
    "aggregation.temporality": "delta",
    "user.customer_type": "api",
    "user.subscription_type": "enterprise"
  },
  "metrics": [
    {
      "name": "claude_code.token.usage",
      "description": "Number of tokens used",
      "unit": "tokens",
      "data_points": [
        {
          "attributes": { "user.id": "...", "session.id": "..." },
          "value": 4532,
          "timestamp": "2025-01-15T10:30:00.000Z"
        }
      ]
    }
  ]
}
```

### 7.4 组织级 Opt-out

BigQuery 导出尊重组织级别的 Metrics Opt-out 设置：

```typescript
const metricsStatus = await checkMetricsEnabled()
if (!metricsStatus.enabled) {
  resultCallback({ code: ExportResultCode.SUCCESS })  // 静默跳过
  return
}
```

---

## 8. 代理与 mTLS 支持

OTLP Exporter 支持企业级网络配置：

```typescript
function getOTLPExporterConfig() {
  const proxyUrl = getProxyUrl()
  const mtlsConfig = getMTLSConfig()
  const caCerts = getCACertificates()

  // 1. 如果不需要代理，直接配置 mTLS/CA
  config.httpAgentOptions = { ...mtlsConfig, ca: caCerts }

  // 2. 如果需要代理，创建 HttpsProxyAgent
  const proxyAgent = new HttpsProxyAgent(proxyUrl, {
    cert: mtlsConfig.cert,
    key: mtlsConfig.key,
    ca: caCerts,
  })

  // 3. 支持动态 Headers（通过 otelHeadersHelper 外部命令刷新）
  config.headers = async () => {
    const dynamicHeaders = getOtelHeadersFromHelper()
    return { ...staticHeaders, ...dynamicHeaders }
  }
}
```

---

## 9. 优雅关闭（Graceful Shutdown）

Agent 进程退出时的遥测数据保全是关键挑战。Claude Code 采用了多层保障：

### 9.1 关闭流程

```typescript
const shutdownTelemetry = async () => {
  const timeoutMs = parseInt(
    process.env.CLAUDE_CODE_OTEL_SHUTDOWN_TIMEOUT_MS || '2000',
  )
  try {
    endInteractionSpan()  // 1. 结束活跃的交互 Span

    // 2. 并行 flush + shutdown，带超时竞赛
    const chains = [meterProvider.shutdown()]
    if (loggerProvider) {
      chains.push(loggerProvider.forceFlush().then(() => loggerProvider.shutdown()))
    }
    if (tracerProvider) {
      chains.push(tracerProvider.forceFlush().then(() => tracerProvider.shutdown()))
    }

    await Promise.race([
      Promise.all(chains),
      telemetryTimeout(timeoutMs, 'OpenTelemetry shutdown timeout'),
    ])
  } catch { /* 静默 */ }
}
registerCleanup(shutdownTelemetry)
```

### 9.2 关键设计决策

1. **先 flush 后 shutdown**：`forceFlush()` 确保缓冲区数据发出，然后 `shutdown()` 释放资源
2. **各 Provider 独立链式**：Logger 的 flush 不阻塞 Tracer 的 shutdown（无瀑布效应）
3. **超时竞赛**：慢速的 OTLP 端点不会阻塞进程退出
4. **unref 定时器**：超时用的 Timer 不阻止进程自然退出

### 9.3 数据安全 flush

```typescript
// 登出或切换组织前，必须 flush 以防数据泄露
export async function flushTelemetry(): Promise<void> {
  // ...forceFlush all providers...
  // 即使 flush 失败也不阻塞登出
}
```

---

## 10. 工具调用（Tool Execution）的完整追踪生命周期

以一次工具调用为例，展示追踪在源码中的完整流转：

```
processTextPrompt.ts:
  startInteractionSpan(userPrompt)     ──▶ interaction span 开始
    │
claude.ts:
  llmSpan = startLLMRequestSpan(model, newContext, messages)
    │                                  ──▶ llm_request span 开始（挂在 interaction 下）
    ▼
logging.ts:
  endLLMRequestSpan(llmSpan, metadata) ──▶ llm_request span 结束（附带 token/延迟指标）
    │
toolExecution.ts:
  startToolSpan(tool.name, attrs)      ──▶ tool span 开始（挂在 interaction 下）
  startToolBlockedOnUserSpan()         ──▶ blocked_on_user 子 span 开始
    │
    │  ... 等待用户授权 ...
    │
  endToolBlockedOnUserSpan(decision)   ──▶ blocked_on_user 子 span 结束
  startToolExecutionSpan()             ──▶ execution 子 span 开始
    │
    │  ... 工具实际执行 ...
    │
  endToolExecutionSpan({ success })    ──▶ execution 子 span 结束
  endToolSpan(toolResult)              ──▶ tool span 结束（附带 new_context）
    │
REPL.tsx:
  endInteractionSpan()                 ──▶ interaction span 结束
```

---

## 11. 与其他 Agent 框架的对比

| 特性 | Claude Code | LangSmith/LangChain | OpenAI SDK |
|------|:---------:|:---------:|:---------:|
| OTel 原生支持 | ✅ 全面使用 OTel SDK | ❌ 自定义协议 | 部分（自定义 trace） |
| 标准 OTLP 导出 | ✅ 三大信号全支持 | ❌ 专有后端 | ❌ |
| 自定义 Exporter | ✅ BigQuery + 1P | ✅ LangSmith | ❌ |
| 本地可视化 | ✅ Perfetto | ❌ | ❌ |
| Span 层次设计 | interaction→llm/tool→sub | chain→llm/tool | run→step |
| 隐私脱敏 | ✅ 多级 opt-in | 部分 | ❌ |
| 增量上下文追踪 | ✅ Hash-based delta | ❌ 全量 | ❌ |
| 企业级网络支持 | ✅ mTLS/Proxy/CA | ❌ | ❌ |

---

## 12. 设计启示总结

### 12.1 Agent 可观测性的关键挑战

1. **长对话的上下文追踪**：Agent 的对话历史持续增长，全量记录不现实。Claude Code 通过 Hash-based 增量追踪解决。
2. **并行请求的归因**：Agent 可能同时发起多个 LLM 请求（warmup、分类器、主线程）。Claude Code 通过显式传递 Span 引用而非依赖"最近的 Span"来解决。
3. **工具执行的多阶段追踪**：工具调用不是原子操作——它包括权限检查、用户等待、实际执行、Hook 运行。每个阶段都是独立的子 Span。
4. **CLI 工具的生命周期**：进程随时可能退出，必须有超时竞赛和多层 flush 保障。
5. **隐私与可观测性的平衡**：默认脱敏 + 按需 opt-in + 按身份差异化展示。

### 12.2 架构决策精华

1. **延迟加载一切**：OTel 模块只在需要时加载，gRPC 模块按协议动态导入。
2. **WeakRef + TTL = 零泄漏**：Span 管理既不阻止 GC，又有超时兜底。
3. **ALS 替代标准 Context**：在 Agent 的嵌套执行模型中更自然。
4. **双轨事件系统**：内部分析与客户遥测严格隔离。
5. **Delta 时间粒度**：CLI 短生命周期进程的最佳选择。
6. **console exporter 的 stdout 安全**：在 stream-json 模式下自动剥离 console exporter，因为 stdout 是 SDK 消息通道。

### 12.3 值得借鉴的模式

- **属性工厂模式**：`getTelemetryAttributes()` 集中管理所有公共维度
- **封装 Counter**：`AttributedCounter` 自动注入基础属性
- **超时竞赛**：`Promise.race([work, timeout])` 用于所有 I/O 操作
- **环境变量分层**：`ANT_OTEL_* → OTEL_*` 的构建时/运行时映射
- **Feature Gate 控制**：GrowthBook 远程配置 + 环境变量覆盖 + 构建时死代码消除
