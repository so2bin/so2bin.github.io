---
layout: pages
title: nano banana 技术风格
date: 2026-01-05 13:02:05
tags: [AI, gemini]
---
# 风格
## "Retro Engineering Schematic" (复古工程蓝图/原理图风格)

* 特点：融合了“达芬奇手稿”、“老式专利图纸”和“现代UI图标”

### 🎨 风格定义 (Style Definition)
这种风格的核心要素包含：
1. 背景 (Background):
    * 材质: 米黄色纸张 (Yellowish Paper)、羊皮纸 (Vintage Parchment)、做旧纸张 (Aged Paper)。
    * 纹理: 轻微的纸张纹理，偶尔带有网格线或测量标记 (Grid/Measurement Lines)，增加工程感。
2. 线条 (Line Work):
    * 墨线 (Ink Lines): 清晰、精细的黑色轮廓线，像针管笔手绘。
    * 风格: 干净利落 (Clean)，非素描草图，具有专业制图的严谨性。
3. 色彩 (Color Palette):
    * 主色调: 暖色调背景 + 黑色线条。
    * 点缀色 (Accents): 使用 低饱和度淡彩 (Light Pastels) 或 复古墨水色（如青色 Teal、砖红色 Brick Red、琥珀色 Amber）来区分功能块。避免使用高饱和度的霓虹色。
4. 内容元素 (Elements):
    * 微缩图示 (Micro-Schematics): 每个模块内部包含具体的微型图标（文档、树状图、网络、放大镜），而非抽象的空框。
    * 布局: 结构化布局（层级堆叠或线性流程），强调逻辑关系。

### 📝 通用提示词模板 (Universal Prompt Template)
您可以将下方的 [您的主题] 和 [具体内容] 替换为您需要生成的任何技术内容。
#### 英文模板 (推荐)
> Create an image illustrating [YOUR TECHNICAL TOPIC].
>
> Style: Retro Engineering Schematic on Yellowish Paper.
>
> * Visual Aesthetic: Vintage technical drawing style, clean black ink lines on warm aged paper background. Professional, detailed, and precise.
> * Colors: Black outlines with soft pastel color accents (Teal, Brick Red, Amber) to highlight key elements. NO neon or dark mode colors.
> * Structure: [DESCRIBE LAYOUT, e.g., A vertical stack of 5 layers / A horizontal flowchart].
> * Details: Inside each block/node, draw detailed schematic icons representing its function (e.g., [LIST ICONS, e.g., databases, servers, code blocks]). Avoid heavy industrial machinery; use modern UI/software metaphors instead.
>
> Specific Content:
> 1. [Part 1 Name]: [Description of icon/action]. Label: "[Label Name]".
> 2. [Part 2 Name]: [Description of icon/action]. Label: "[Label Name]".
> 3. [Part 3 Name]: [Description of icon/action]. Label: "[Label Name]".
> ...
>
> Key: High-quality technical illustration, schematic clarity, vintage aesthetic.

**中文应用示例 (以"微服务架构"为例)**

如果您想生成一张 微服务架构图，您可以这样填写模板：

> Create an image illustrating a Microservices Architecture.
>
> Style: Retro Engineering Schematic on Yellowish Paper.
>
> * Visual Aesthetic: Vintage technical drawing style, clean black ink lines on warm aged paper background.
> * Colors: Black outlines with soft pastel color accents (Teal for services, Red for databases).
> * Structure: A central hub connected to multiple independent service blocks.
> * Details: Inside each block, draw schematic icons like Servers, APIs, and Databases.
>
> Specific Content:
> 1. Gateway: An icon of a door or switch. Label: "API Gateway".
> 2. Service A: An icon of a user profile. Label: "User Service".
> 3. Service B: An icon of a shopping cart. Label: "Order Service".
> 4. Database: Cylinder icons connected to services. Label: "DB Clusters".
>
> Key: High-quality technical illustration, schematic clarity, vintage aesthetic.

### 💡 关键修饰词 (Magic Keywords)
如果您想微调风格，可以尝试添加或强调以下词汇：
* 更复古: "Leonardo da Vinci sketch style" (达芬奇手稿风), "Patent illustration" (专利图纸风).
* 更现代/整洁: "Minimalist schematic" (极简原理图), "Infographic style" (信息图风格).
* 强调细节: "Intricate details" (错综复杂的细节), "Micro-icons" (微图标).
希望这个模板能帮助您在未来的技术文档中保持这种高质量的视觉风格！

### 案例
#### context-fixer
````
## Image: Context-Fixer Agent 架构 (Context-Fixer Agent Architecture)
**Goal**: 架构级 + 中等粒度细节 + 贴图丰富（Agent/Analyzer/Fixer 明确能力贴图），并且**连线语义严格正确**（用硬约束锁死，避免 AI 乱画）。模块底色采用你参考图那种**贴合圆角矩形边界的渐变渐隐**（不是圆形光晕）。

---

### Visual Style（固化为参考图的模块风格）
- **Canvas**: 16:9 横向
- **Background**: 米黄色羊皮纸纹理 + 左侧淡灰工程网格（细、淡）
- **Cards**: 圆角矩形卡片，**细深灰描边**（不强调粗黑），轻微投影
- **Colored Software Stickers（必须）**: 全部为**带色**粉彩填充软件贴图（蓝/青/绿/橙/紫）+ 黑色细描边；贴图清晰、简约、UI 感
- **Module Background = Edge Feather Gradient（关键）**:
  - 每个模块卡片有**非常淡**的粉彩底色
  - 底色必须是**贴合圆角矩形形状的渐变渐隐**：中心更淡，靠近卡片边界略微更显色，然后沿边界**柔和羽化渐隐**（soft feather fade aligned to rounded rectangle）
  - **不要圆形/放射状光晕**；渐变必须与卡片边界一致、不突兀
- **Arrows**: 深灰细线箭头；旁路用细虚线；总闭环箭头蓝灰稍粗但克制
- **Do NOT**: 机械贴图、AST、长代码、密集小字
- 模块中的文字除小标题外不要加粗
---

### Layout（尺寸优化：Toolchain 更大；Observation/Target Code 更小）
使用 2×3 网格，但**Toolchain 占比更大**（宽与高都更大），Observation 与 Target Code 更小：
- Top row: `Agent` | `Toolchain` | `Context-Analyzer`
- Bottom row: `Observation` | `Target Code` | `Context-Fixer`

> Toolchain 视觉上像你参考图那样“内容多的大面板”；Observation/Target Code 像“信息摘要小卡片”。

---

## Components（贴图与内容要求）
### 1) Agent（左上）
- **Title**: `Agent`
- **Subtitle**: `LangGraph + ReAct (CRE)`
- **Stickers（至少 3 个）**:
  1. 彩色Agent（LLM/思考）
  2. 小型 StateGraph 节点图（抽象节点即可，不画全细节箭头）
  3. Read-Only / Write 
- **Tiny tags（最多 2 个）**: `Policy`, `Planning`

### 2) Toolchain（中上，大面板，风格固化为参考图）
- **Title**: `Toolchain`
- **Subtitle**: `Tools Capabilities & Layering`
- **Panel style 必须像参考图**：
  - 顶部标题居中，内部两列或左右分区：左侧 Read-Only，右侧 Write
  - 每行工具左侧有小彩色行图标（简约）
  - 底部有一行居中文案：`Agent uses these tools`
- **Read-Only Tools**:
  - `check_compilation`
  - `analyze_breaks`
  - `scan_async_risks`
  - `identify_function`
  - `get_callees_metainfo`
  - 注：`Read-Only -> return to Agent`
- **Write Tools**:
  - `run_context_fixer`
  - `fix_implicit_interface`
  - `fix_struct_methods`
  - `cleanup_local_root`
  - `fix_compile_errors`
  - `fix_test_context`
  - `fix_high_risk_async`
  - 注：`Write -> trigger Compilation`

### 3) Context-Analyzer（右上，风格固化为参考图）
- **Title**: `Context-Analyzer`
- **必须包含 3 个并列软件贴图（像参考图那样排列并标注）**:
  1. `SSA`：3 个小 SSA 方块/指令块堆叠
  2. `CFG`：菱形分支流程图（两条路径）
  3. `CallGraph`：彩色节点网络小图
- **Artifacts（只属于 Analyzer）**: 在 Analyzer 下方或右下角叠放“文档页”贴图并标注：
  - `agent_analysis.json`
  - `agent_breaks.json`
  - `agent_async.json`
  - `interface-impls.json`

### 4) Observation（左下，小卡片，只有 metrics）
- **Title**: `Observation`
- **Sticker**: 小仪表/计数器 UI
- **Metrics（两行即可）**:
  - `compile_ok`, `compile_errors`
  - `break_count`, `async_risks`
- **禁止**：这里不出现 Artifacts 文档贴图

### 5) Context-Fixer（右下，贴图参考你给的树状图）
- **Title**: `Context-Fixer`
- **Stickers（至少 2 个主贴图 + 1 个小贴图）**:
  1. **Reverse Propagation**：
     - 倒置树/小图网络贴图中最下一个root为红色 `Break` 节点
     - **箭头方向必须是从 Break 节点向上游/向叶子节点走**（反向回溯）
     - 视觉像你参考图：简约节点 + 连线 + 明确方向箭头
  2. **Interface Sync**：
     - 顶部 `Interface` 盒子，向下连接 2~3 个 `Impl` 盒子（树状分叉）
  3. 小贴图：`local-fix-root`（`context.TODO()` → `ctx` 的短替换箭头）
- **Tiny tags（最多 3 个）**: `Reverse Propagation`, `Interface Sync`, `local-fix-root`

### 6) Target Code（中下，小卡片）
- **Title**: `Target Code`
- **Stickers**: 彩色文件夹/文件树 + 小代码页
- **Tiny file tree snippet（3~5 行）**:
  - `main.go`
  - `pkg/`
  - `internal/`
  - `test/`

---

## ✅ Connections（硬约束 + 唯一连线清单）
### HARD CONSTRAINTS（必须严格遵守）
1) **Toolchain has NO outgoing arrows** to any module（Toolchain 不指向任何组件）。  
2) **Agent has NO direct arrow to Target Code**。  
3) **No line between Observation and Context-Fixer**。  
4) 工具名标签（run_context_fixer / analyze_breaks / scan_async_risks / check_compilation）只允许出现在**从 Agent 发出的箭头**上；绝不出现在从 Toolchain 发出的箭头上（因为 Toolchain 不允许有出箭头）。

### ONLY draw these arrows（只允许这些箭头，且不得额外添加）
- `Agent → Context-Analyzer`（solid）label: `analyze_breaks / scan_async_risks`
- `Agent → Context-Fixer`（solid）label: `run_context_fixer`
- `Context-Analyzer → Observation`（solid）label: `Metrics`
- `Target Code → Observation`（solid）label: `Compile Metrics`
- `Context-Fixer → Target Code`（solid）label: `Apply Patches`
- `Observation → Agent`（two separate arrows）labels:
  - `Compile Status`
  - `Analysis Status`
- One thick blue-gray loop arrow around everything label:
  - `Observe → Decide → Apply → Verify`

> `Toolchain` 与 `Agent` 关系用**非箭头**表达：Toolchain 面板底部文字 `Agent uses these tools`（不画 Toolchain→Agent 或 Agent→Toolchain 也可以；若一定要表达，可用括号/brace，无箭头）。

---

## Prompt Description for Nano Banana（可直接复制）
> Create a **16:9** infographic with yellowish parchment paper + faint left grid. Use rounded cards with **thin dark-gray outlines** and subtle shadow. Use **colored minimal software stickers** (pastel filled icons, not line art).  
> Each module card must have a **very light pastel background** with an **edge-feathered gradient that matches the rounded-rectangle boundary**: slightly more color near the card edges, smoothly fading (soft feather) without any circular/radial halo shapes.
>
> Title at top center: **“Context-Fixer Agent 架构 (Context-Fixer Agent Architecture)”**.
>
> Layout: **2×3 grid** with sizing:
> - Toolchain card is **larger** (both wider and taller).
> - Observation and Target Code cards are **smaller**.
> Top row: Agent | Toolchain | Context-Analyzer
> Bottom row: Observation  | Target Code | Context-Fixer
>
> HARD CONSTRAINTS (must follow exactly):
> 1) Toolchain has **NO outgoing arrows** to any module.
> 2) Agent has **NO direct arrow to Target Code**.
> 3) **No line between Observation and Context-Fixer**.
> 4) Tool-call labels appear ONLY on arrows starting from Agent.
>
> Draw ONLY these arrows:
> - Agent -> Context-Analyzer (solid) label “analyze_breaks / scan_async_risks”
> - Agent -> Context-Fixer (solid) label “run_context_fixer”
> - Context-Analyzer -> Observation (solid) label “Metrics”
> - Target Code -> Observation (solid) label “Compile Metrics”
> - Context-Fixer -> Target Code (solid) label “Apply Patches”
> - Observation -> Agent (two separate return arrows) labels “Compile Status” and “Analysis Status”
> - One thick blue-gray loop arrow around everything label “Observe → Decide → Apply → Verify”
>
> Agent card: include colored stickers (chat bubble, small StateGraph nodes diagram, read-only/write router) and tiny tags Policy/Planning.
>
> Toolchain card: match the provided Toolchain style: big clean tools list panel, two sections Read-Only and Write, colored row icons, notes “Read-Only -> return to Agent (no rebuild)” and “Write -> trigger Compilation”, and a bottom caption “Agent uses these tools”. No arrows from Toolchain.
>
> Context-Analyzer card: match the provided Analyzer style: three labeled stickers in a row “SSA”, “CFG”, “CallGraph”, plus an Artifacts document stack labeled agent_analysis.json, agent_breaks.json, agent_async.json, interface-impls.json.
>
> Observation card: metrics table only (compile_ok, compile_errors, break_count, async_risks). No artifacts.
>
> Context-Fixer card: use tree-style stickers like the reference:  
> - Reverse Propagation tree with a red “Break” node and arrows **moving upward from Break to upstream/root** (reverse search).  
> - Interface Sync tree: “Interface” on top branching to multiple “Impl” boxes.  
> - Small local-fix-root sticker: “context.TODO() -> ctx”.
>
> Target Code card: colored file-tree + code-page stickers and a tiny 3–5 line file list.
>
> Keep text minimal, spacing generous, no mechanical icons, no AST trees.

````
