---
layout: pages
title: istio多集群
date: 2024-05-20 14:55:03
tags: [istio, 多集群网格]
---

## 线上多集群流量分发异常故障排查
### 问题背景

我们平台在线上建了以3个k8s集群组成的istio多集群服务风格，有A, E, F三个集群。
在这几天，有一个服务出现了流量在集群间分布不是按DR配置的权重比例，如下图所示，我们看到应用所有的流量都到了F区，但副本的分布是`A:F=69:31`，这明显是错的：
<img src="traffic-distri-wrong.png" width="60%" alt="traffic-distri-wrong">


### 分析

* 首先我们进入到`istio-ingress`网关的pod内，通过如下命令查看`/clusters`的配置，过滤出该服务的cluster权重比例配置，看是否正常：
```bash
# 进入到istio-ingress的pod里面执行
curl -s http://localhost:15000/clusters | grep qingqiu-72b-triton-prod-v1 | grep weight

# 得到结果如下
outbound|80||image-auditing-test-v1.ai-ppt-beautify-test.svc.cluster.local::<F>:15443::weight::10
outbound|80||image-auditing-test-v1.ai-ppt-beautify-test.svc.cluster.local::<A>:15443::weight::20
```

* 其实从这里就已经可以看出问题了，因为`weight`就是代表这个`cluster`的pod数，而该服务我们配置的副本总数为50，在集群间的pod数分布为：`A:F=36:14`。
* 再次，我们继续分析了`/endpoints`的配置，通过如下命令：
```bash
# 通过istioctl工具查看
istioctl proxy-config endpoint  istio-ingress-57b9dcccbc-g6l7w.istio-ingress  | grep ai-ppt-beautify-test | grep image-auditing
```
我们在A集群中得到了如下图的结果（这里的是`atms-glb-`开头，是由于内部的应用插件所致，原理是与`image-auditing-test-v1`一样的）：
<img src="enpoints-wrong.png" width="100%" alt="enpoints-wrong">

可以看到，我们的endpoints只有F集群的端点，无A区的本地pod列表，由此可见，目前的配置是出了问题的。

### 原因分析

* 因团队的同事发现，集群中的最近新增的node没有打印拓扑label，且刚好没有流量的pod是在这些node上的，但早上我们为这几个node打上标签上，流量分布问题仍然没有修复：
```bash
kubectl get nodes -o custom-columns="NAME:{.metadata.name},REGION:{.metadata.labels.topology\.kubernetes\.io/region},ZONE:{.metadata.labels.topology\.kubernetes\.io/zone},kas/infer:{.metadata.labels.kas/infer}"
```
![node-topo](node-topo.png)

* 后又到下午，又发现上述`image-auditing`的`/cluster`, `endpoints`的配置又正常了，流量分布也正常，观察发现，此时唯一的变化就是服务的pod数从50变成了30；
* 基于这些观察，我们判断，问题的本质仍然是由于之前的pod没有打上拓扑label，但重新打label并不会触发istio `/clusters`, `/endpoints`配置的重新下发，而pod数的变化或重启，则会触发配置的下发，由此才造就了上述问题，因此这是istio配置下发的bug；

### 验证

* 基于该猜测，我们找了另一个有同样问题的服务，其pod分布在三个集群，且其E集群只有一个pod，而该pod是没有流量的，我手动重启了该pod后，流量分布就正常了：
下图为重启pod前的流量分布：
<img src="before-restart-distri.png" width="50%" alt="before-restart-distri">

下图为重启pod后的流量分布：
<img src="after-restart-distri.png" width="50%" alt="after-restart-distri">