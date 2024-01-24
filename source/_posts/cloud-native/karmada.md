---
title: Karmada
date: 2024-01-18 20:07:37
tags: ["Cloud Native", "Karmada", "k8s"]
---
## 资料
* [Kubernetes 多集群管理：Kubefed](https://mp.weixin.qq.com/s?__biz=MzIzNTU1MjIxMQ==&amp;mid=2247483886&amp;idx=1&amp;sn=d397c17088a6a5c2516d7a77acb961e6&amp;chksm=e8e42d52df93a44416c4f250c581158e15d44ba17bc11f5abcd310d59bf9c9fe5fef5aa0e4b8&amp;scene=21#wechat_redirect)
* [vivo Karmada实践](https://www.cnblogs.com/vivotech/p/17684105.html)

## 背景
* karmada是由华为开源的云原生多集群容器编排平台，在kubernetes Federation v1, v2（`kubefed`）的基础上发展而来，吸取了其经验和教训，`kubefed`项目目前已经被放弃；
* 其特点是在保存原有k8s资源定义API不变的情况下，通过添加与多云应用资源编排相关的一套新的API和控制面板组件，为用户提供多云/多集群容器部署，实现扩展、高可用等目标；


## 部署
### 注意
* 跨集群的pod网络通信可以接入如`Submariner`这种开源方案
* In order to prevent routing conflicts, Pod and Service CIDRs of clusters need non-overlapping
* 要开启multi-cluster service，需要安装`ServiceExport`和`ServiceImport`



