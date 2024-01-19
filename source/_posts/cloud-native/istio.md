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

