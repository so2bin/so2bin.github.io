---
title: Envoy
date: 2024-01-06 16:52:44
tags:
---
## 概念
### 分布式服务治理
* 服务治理：对服务不断增长的复杂度的管理与管理
* 服务拓扑变化，网络，安全
* API网关，服务发现，服务容错，部署，调用，追踪

<!-- more -->

### Service Mesh
* Linkerd, Envoy, Istio
* 起源于："What's a service mesh? And do I need one?"
* 指专注于服务之间通信的基础设施，负责在现代云原生应用的复杂网络拓扑中可靠的传递请求；
* 除了基本网络通信的基础功能外，还需要包括分布式应用程序之间通信应该具备的功能，如熔断，限流，trace, metrics, 服务发现，负载均衡；
<img src="sm-base.png" width="80%">
* 即微服务业务程序独立于网络通信proxy组件运行，proxy提供服务间的通信，以及熔断、限流、trace, metrcis, 服务发现，安全，LB，超时，mirror，认证和授权等功能，这就是Service Mesh；
* 数据平面 + 控制平面
* 数据平面：䚣及系统中的每个数据包或请求，完成网络相关功能；
* 控制平面：为网络中的数据平台提供策略和配置，其不接触系统中的数据包或请求；
* 开启Service Mesh后的服务通信逻辑：
 * 微服务间不直接通信，则proxy代理
 * Service Mesh内置流量治理相关高级功能；
 * Service Mesh与编程语言无关；
 * 服务间的局部故障可由Mesh自动处理；
 * 数据平面 + 控制平面；
 * 容器编排平台中，proxy以容器sidecar模式运行；
* 常见实现方案：
 * 数据平面：Linkerd, Nignx, Envoy等
 * 控制平面：Istio, Nelson等

### Envoy
* 数据平台的实现
* 2016年Lyft公司创建并开源
* Istio 2017年开发

#### 概念
* Envoy is an L7 proxy and communication bus designed for large modern service oriented architectures.

#### 高级特性
* 进程外架构
* 基于C++11代码实现，高并发
* 高性能：单进程非阻塞
* L3/L4 filter架构
* HTTP L7 filter架构
* HTTP/2支持
* HTTP L7路由
* GRPC支持
* 服务发现，动态配置（xDS）
* 健康检测
* 高级负载均衡
* 可观测性

* 显著特性：高性能、可扩展性、动态配置性

## Envoy原理与使用
### 组件
* Listeners: 面向请求输出的一端
* Cluster: 面向上游后端
* Filter Chains: 中间的过滤链，如Router
<img src="envoy-top.png" width="80%">

#### cluster
* cluster可以静态配置，也可以通过Cluster Discovery Server（CDS）动态发现
* cluster后端服务为Endpoint，后端服务也有对应的动态发现服务Endpoint Discovery server(EDS)

### xDS
* Cluster: cluster是Envoy连接到的一组逻辑上相似的endpoint集合，通过 CDS提供集群配置；
* 位置Locality: 上游endpoint运行的区域拓扑，包括地域，区域，子区域等；
* 地域Region：locality所属的地理位置
* 区域Zone：AWS中的可用区AZ
* 子区域：Envoy实例或端点运行的区域内的位置，用于支持区域内的多个负载均衡目标
* xDS: 一系列管理API的统称，如CDS, EDS, RDS等


### Envoy线程模型
* 单进程，多线程架构，主线程Main负责管理，Worker线程负责执行监听，过滤，转发等代理服务的核心功能；
* Main线程：启动、关闭，xDS API的调用处理，动态配置，健康检测，集群管理等，所有事件均以异步非阻塞模式完成
* Worker线程：默认根据当前CPU核数创建同等数量的工作线程，也可通过`--concurrency`来指定线程数；每个线程都会启动一个非阻塞事件循环，为每个连接初始休一个过滤器栈并处理此连接的整个生命周期的所有事件；每个线程都会监听所有用户配置的socket，对于某次连接请求，是由系统kernel负责将请求派发给一个工作线程处理；
* 文件刷新线程：专用的独立写文件线程
<img src="envoy-threads.png" width="70%" title="envoy线程模型">

### Envoy配置方式
* 支持非常灵活的配置方式，且各内部组件的配置均可支持静态与动态配置；
* 在云原生生态中，istio采用的是全动态配置，即EDS, CDS, LDS, SDS等均通过xDS实现动态配置

#### 概念
##### Bootstrap启动配置
* node: 节点标识，代表envoy实例
* static_resources: 静态配置
* dynamic_resources: 动态配置，基于xDS API获取配置信息，如listener, cluster等
> 启动全动态配置后，极少数场景需要重启Envoy进程，支持热重启
* admin: 管理接口
* tracing: 分布式追踪
* layed_runtime: 一些关键特性，通过K/V数据保存，支持多层 覆盖配置
* hds_config: health check配置
* overload_manager: 过载管理器
* stats_sinks: 统计信息接收器

#### Listeners
* One Envoy configuration supports any number of listeners with a single process.
* Each listener is independently configured with some number of network(L3/L4) filters.
> TCP，不支持UDP

##### Network(L3/4) filters
* 存在三种类型的network filters，处理L4层上的TCP报文
 * Read filters  处理入栈报文
 * Write filters  处理出栈报文
 * Read/Write filters  同时处理出入栈报文
* Envoy内置了很多过滤器：
 * 代理类：TCP Proxy, HTTP connection manager, Mysql Proxy, Redis Proxy等
 * 其它：Rate Limit, Upstream Cluster from SNI等

##### HTTP connection manager
* 该filter本身是L3/L4 filter，能够将原始数据转换为HTTP级别消息和事件，拿到L7的数据，如headers，body等
* 其处理了所有HTTP连接和请求共有的功能，如访问日志，trace，header/body操作，路由管理，统计信息等；
* 在该管理器中，还支持使用L7层HTTP过滤器：Router，Rate limit, Health check, Gzip, Fault Injection等；
![HTTP Filters](http-filters.png)

#### clusters CDS and EDS
* Envoy可配置任意数量的upstream clusters，并使用Cluster Manager进行管理
* cluster可由用户静态配置也可由CDS API动态获取
* cluster中的Endpoints同样可由静态配置或EDS、DNS来动态发现：
 * Static
 * Strict DNS: 严格DNS,既将DNS的解析的每个IP视为cluster endpoint
 * Logical DNS: 逻辑DNS,仅使用在需要启动新连接时返回的第一个IP作为一个endpoint，这适用于大规模web服务集群，因该类服务的DNS IP可能会智能变化
 * Original destination
 * EDS: 一种基于GRPC或REST-JSON API的xDS API服务发现方式
 * Custom cluster: 自定义集群发现机制


### 启动
```bash
envoy -c /etc/envoy/envoy.yaml
```
 
### admin接口
* Envoy内置了一个管理服务，支持修改、查询操作，可能会暴露私有数据，如统计数据，集群名，证书等，因此有必要做好其权限控制机制（envoy本身没对admin接口有权限机制）；
* 可以限制其监听address到127.0.0.1（istio中统一为该地址）以保证安全；
* `/help` 返回admin支持的所有接口
* `/listeners` 列出所有listener
* `/clusters` 列出所有clusters以及状态
* `/ready`
* `/config_dump` 返回整个envoy生效的配置信息
* `/healthcheck/fail` POST，强制设计HTTP健康状态为失败
* `/logging`
* `/quitquitquit` exit server
* `/stats` envoy格式的指标数据
* `/stats/prometheus` prometheus格式的指标数据 

#### /clusters相关参数
![/clusters](clusters.png)
* `region::` 位置，一般指机房
* `zone::` 机房中的区域
* `sub_zone::` 区域中的子区域，如节点
* `priority::` 影响优先级流量的调度
* `cx_total` total connections
* `cx_active` total active connections
* `rq_total` total requests
* `rq_timoue` total timeout requests
* `rq_success` total request with non-5xx responses
* `rq_error` total 5xx responses
