---
title: istio
date: 2024-01-07 07:25:24
tags:
---
## 资料
* [xDS与配置推送]https://blog.fatedier.com/2022/06/01/istio-control-plane-config-push-optimization/#xds-%E6%A6%82%E5%BF%B5%E8%AF%B4%E6%98%8E

## 背景
* 云原生拓荒者-Netflix: 性能Performance，扩容Scalability，可用性Availability
* 提升可用性（反脆弱性），可通过 弹性处理局部故障：
 * 快速失败(fail fast)与故障转移(failover)：超时并重新请求，将流量调度到其它副本
 * 优雅降级：所有副本都出现故障时，熔断上游服务，当前应用以降级形式继续提供服务
 * 金丝雀发布：变更是导致脆弱性的重要原因，任何形式的上线新版本都应该基于灰度部署
* 将服务治理下沉到基础设施中：service mesh

<!-- more -->

## Service Mesh技术标准
* UDPA(Universal Data Plane API) 统一数据平台API, Envoy就是该标准的实现
* SMI(Service Mesh Interface) 控制平面规范，如docker, LINKERD
<img src="image-8.png" width="70%" title="SMI vs UDPA">

## Istio发展历程
* 2017年5月随Linkerd1.0后，5月发布了Istio 0.1版本
* 2018年Envoy稳定版发布，同时期，7月Istio 1.0发布，
* 2019年，Istio 1.1发布，该版本为完全分布式实现，但存在严重的性能问题
* 2020年，Istio发布1.5版本，控制平台重新回归单体架构，解决性能问题

## 特性
### 部署模式
* sidecar
* host级别，即每个主机共享一个

## 多集群部署
### 资料
* https://mp.weixin.qq.com/s/tPxw48np5bAaTeumUET1fA

## 异常检测（Outlier Detection）与故障隔离（Outlier Ejection）
### 资源 
* https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/upstream/outlier

### 原理
* 概念：异常检测（Outlier detection）与隔离（Outlier Ejection）是用于动态判断一个上游cluster host是否出现了异常，并决策是否将其从健康负载均衡池中剔除的技术；
* 异常情况可以分为多种维度：连续失败（consecutive failures），实时成功率，实时延迟等；
* 异常检测是一种被动健康检测，当然envoy也是支持主动健康检测机制，这两者可以同时配置生效；
* Outlier detection是一种cluster configuration，因此需要filters来将异常事件过滤出来，以提供出errors, timeouts, resets等，当前支持该功能的filters有：`http router`, `tcp proxy`, `redis proxy`, `thrift proxy`；

### 异常分类
* 异常错误分为两类：externally originated errors, locally originated errors
    1. externally error: 是指由upstream server针对请求响应的error，如HTTP响应500状态码，或redis返回了一个无法解析的payload；
    2. locally originated error: 由envoy产生的事件，如连接upstream host是出现了中断，超时（TCP reset, timeout），或无法建立TCP连接等；

* 异常检测出的error，是由filter类型决定的：
    1. http router filter: 如可以检测出timeouts, tcp reset，同时因其能解析HTTP协议，因此可以产生HTTP协议的error，如TCP连接建立成功，但上游服务响应失败的情况，如500；
    2. tcp proxy filter: 因不理解HTTP协议，所以只能提供locally originated error；

* 默认情况下，`outlier_detection.split_external_local_origin_errors`是`false`，此时externally与locally error不作区分，统一统计并用于`outlier_detection.consecutive_5xx`, ` outlier_detection.consecutive_gateway_failure`, `outlier_detection.success_rate_stdev_factor`的计算，如访问HTTP服务时2次建立连接失败，第三次成功，但上游响应500，则会统计出locally error次数为3；

> 对于TCP流量，`outlier_detection.consecutive_5xx`是正确的配置，并透明对应到TCP连接失败的配置；

* 如果`outlier_detection.split_external_local_origin_errors=true`，则externally, locally error会独立计数；

### 故障隔离算法
* 当一个upstream host触发故障隔离时，其隔离时间是在`outlier_detection.base_ejection_time`的基础上，与连接ejection的次数相乘的，即`total_ejection_time=outlier_detection.base_ejection_time * ejection_times`，当然允许配置一个最大隔离时间`outlier_detection.max_ejection_time`（istio貌似还不支持https://istio.io/latest/docs/reference/config/networking/destination-rule/#OutlierDetection）；
* 通过`outlier_detection.interval`周期性检测，当该host恢复健康时，这个ejection time multiplier会递减，也就是说它不是一次性减少到`outlier_detection.base_ejection_time`这个隔离耗时的；


### Detection types
#### Consecutive 5xx
* 配置项：`outlier_detection.consecutive_5xx`

* `outlier_detection.split_external_local_origin_errors: false`：会统计上全部的的exteranlly, locally error计数，即包括HTTP级的5XX和TCP级的连接error；
* `outlier_detection.split_external_local_origin_errors: true`：此时仅统计externally error，不统计locally error，如对于HTTP服务，仅5XX类型的error会被统计进来，对于redis proxy，仅无法解析的异常响应会被统计进来；


#### Consecutive Gateway Failure
* 配置项：`outlier_detection.consecutive_gateway_failure value`

* `outlier_detection.split_external_local_origin_errors: false`：该配置项目仅统计`outlier_detection.consecutive_5xx`的一个子集：`502`, `503`, `504`，还有TCP级的故障，如timeout, tcp reset等；
* `outlier_detection.split_external_local_origin_errors: true`：其仅统计`outlier_detection.consecutive_5xx`的一个子集：`502`, `503`, `504`，并且仅用于http router；


#### Consecutive Local Origin Failure
* 配置项：`outlier_detection.consecutive_local_origin_failure`

* `outlier_detection.split_external_local_origin_errors: false`：此时该配置项无效
* `outlier_detection.split_external_local_origin_errors: true`：仅考虑locally originated error，如TCP timeout, reset等，可同时用于http router, tcp proxy, redis proxy；
