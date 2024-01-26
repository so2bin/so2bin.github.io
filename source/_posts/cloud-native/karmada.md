---
title: Karmada
date: 2024-01-18 20:07:37
tags: ["Cloud Native", "Karmada", "k8s"]
---
## 资料
* [kubefed v2](https://cloud.tencent.com/developer/article/1804669)
* [Kubernetes 多集群管理：Kubefed](https://mp.weixin.qq.com/s?__biz=MzIzNTU1MjIxMQ==&amp;mid=2247483886&amp;idx=1&amp;sn=d397c17088a6a5c2516d7a77acb961e6&amp;chksm=e8e42d52df93a44416c4f250c581158e15d44ba17bc11f5abcd310d59bf9c9fe5fef5aa0e4b8&amp;scene=21#wechat_redirect)
* [vivo Karmada实践](https://www.cnblogs.com/vivotech/p/17684105.html)

## 背景
* karmada是由华为开源的云原生多集群容器编排平台，在kubernetes Federation v1, v2（`kubefed`）的基础上发展而来，吸取了其经验和教训，`kubefed`项目目前已经被放弃；
* 其特点是在保存原有k8s资源定义API不变的情况下，通过添加与多云应用资源编排相关的一套新的API和控制面板组件，为用户提供多云/多集群容器部署，实现扩展、高可用等目标；
* 如下图所示为`kubefed` v2接入vs时需要定义的CRD，因此接入`kubefed`是需要对原始k8s资源进行改造，对用户不友好：
```yaml
apiVersion: types.kubefed.io/v1beta1
kind: FederatedVirtualService
metadata:
  name: service-route
  namespace: default
spec:
  placement:
    clusters:
    - name: cluster1
    - name: cluster2
    - name: cluster3
  template:
    metadata:
      name: service-route
    spec:
      gateways:
      - service-gateway
      hosts:
      - '*'
      http:
      - match:
        - uri:
            prefix: /
        route:
        - destination:
            host: service-a-1
            port:
              number: 3000
```

<!--more-->

## 部署
### 注意
* 跨集群的pod网络通信可以接入如`Submariner`这种开源方案
* In order to prevent routing conflicts, Pod and Service CIDRs of clusters need non-overlapping
* 要开启multi-cluster service，需要安装`ServiceExport`和`ServiceImport`


## 架构
### 架构
* 核心组件有：`karmada apiserver`, `karmada controller manager`, `karmada scheduler`；
* `karmada apiserver`是在k8s apiserver的基础上开发的，所以功能与k8s apiserver类似；
* `karmada scheduler`是集群调度器，即完成在资源下发阶段，为资源选择合适集群的目标；
* `karmada controller manager`如下图所示，集成了4个controller：
    * `Cluster Controller` 将k8s集群连接到karmada，为每个集群都创建了一个[Cluster资源对象](https://github.com/karmada-io/api/blob/81a2cd59ba32a54fd45b02253e9d2d82e1be12cf/cluster/v1alpha1/types.go#L43)，来管理集群的生命周期；
    * `Policy Controller` 监视`PropagationPolicy`对象，当该CRD创建时，controller会选择与`resourceSelector`匹配的一组资源，为每个单独的联邦资源对象创建`ResourceBinding`对象；
    * `Binding Controller` 监视`ResourceBinding`对象，为每个带有单个资源manifest的集群创建一个[`Work`对象](https://github.com/karmada-io/api/blob/81a2cd59ba32a54fd45b02253e9d2d82e1be12cf/work/v1alpha1/work_types.go#L43)；
    * `Executioin Controller` 监视`Work`对象，当资源创建时，controller会把资源下发到成员集群中；

![Arch](arch.png)

### 资源下发四个阶段
* karmada下的资源配置下发会经历4个阶段：`Resource Template` -> `Propagation Policy` -> `Resource Binding` -> `Override Policy`；
* `Resource Template`阶段：是定义资源模板，其可直接套用原生k8s的配置，无需进行改造；
* `Propagation Policy`阶段：为通过PropagationPolicy API来定义多集群的调度要求，[CRD定义源码在这](https://github.com/karmada-io/api/blob/81a2cd59ba32a54fd45b02253e9d2d82e1be12cf/policy/v1alpha1/propagation_types.go#L49)；
    * 支持1:N的策略映射机制，无需为每个联邦应用都标明调度约束；
    * 使用默认策略的情况下，用户可以直接与k8s API交互；
* `Resource Binding`阶段：此时应用会为每个联邦应用创建一个ResourceBinding资源，用于关联其PropagationPolicy资源，该[CRD定义源码在这](https://github.com/karmada-io/api/blob/81a2cd59ba32a54fd45b02253e9d2d82e1be12cf/work/v1alpha2/binding_types.go#L58)
* `Override Policy`阶段：为每个ResourceBinding资源执行集群级别的差异化配置改写，其[CRD定义源码在这](https://github.com/karmada-io/api/blob/81a2cd59ba32a54fd45b02253e9d2d82e1be12cf/policy/v1alpha1/override_types.go#L49)

![Karmada资源下发](resource-apply.png)


## 组件特性
### PropagationPolicy

### 重调度：`karmada-descheduler` and `karmada-scheduler-estimator`
#### `karmada-descheduler`
* 可根据成员集群内实例状态变化，主动触发重调度；



#### `karmada-scheduler-estimator`
* 为调度器提供更精确的成员集群运行实例的期望状态；


## Karmada Install
### 环境准备
1. 安装k8s；
2. 如k8s主机是配置的域名，因karmada-controller需要通过该域名如`atms-00.vm`访问目标集群，所以需要在karmada机器的coredns上配置如下IP映射：
```conf
#  kubectl edit cm -n kube-system coredns  -o yaml
        hosts {
          10.13.149.88 atms-01.vm
          10.13.148.34 atms-02.vm

          fallthrough
        }
```

### install
1. 安装cli：
```bash
curl -s https://raw.githubusercontent.com/karmada-io/karmada/master/hack/install-cli.sh | sudo INSTALL_CLI_VERSION=1.8.1 bash
curl -s https://raw.githubusercontent.com/karmada-io/karmada/master/hack/install-cli.sh | sudo INSTALL_CLI_VERSION=1.8.1 bash -s kubectl-karmada
```

2. 初始化karmada
```bash
sudo kubectl karmada init --kubeconfig ~/.kube/config

#mkdir -p $HOME/.kube
sudo cp -i /etc/karmada/karmada-apiserver.config $HOME/.kube/karmada-apiserver.config
# sudo cp -i /etc/karmada/karmada-apiserver.config $HOME/.kube/karmada-apiserver.config
sudo chown $(id -u):$(id -g) $HOME/.kube/karmada-apiserver.config
```

3. Karmada有两个context: `karmada-apiserver`和`karmada-host`，可通过`kubectl config view`查看所有集群：

**`karmada-apiserver`**

* 切换Context：`kubectl config use-context karmada-apiserver --kubeconfig ~/.kube/karmada-apiserver.config`
* 该Context是与Karmada控制面板交互时使用的主要`kubeconfig`；

**`karmada-host`**

* 切换Context：`kubectl config use-context karmada-host --kubeconfig ~/.kube/karmada-apiserver.config`
* 该Context仅用于调试Karmada对`hostcluster`的安装；

4. join集群
```bash
# 先更改当前member集群的名
kubectl config rename-context kubernetes-admin@kubernetes atms-01

# register
kubectl karmada --kubeconfig ~/.kube/karmada-apiserver.config  join atms-01 --cluster-kubeconfig=$HOME/.kube/config

# check
kubectl get clusters --kubeconfig ~/.kube/karmada-apiserver.config
```
5. OK

### uninstall
* 命令如下：
```bash
kubectl --kubeconfig /etc/karmada/karmada-apiserver.config get clusters
sudo rm -rf /var/lib/karmada-etcd
```


