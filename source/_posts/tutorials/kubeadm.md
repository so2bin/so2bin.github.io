---
layout: pages
title: kubeadm初始化k8s
date: 2024-01-24 11:26:41
tags: ["k8s"]
---
## init
### 节点环境准备
* 关闭swap
```bash
# 查看
sudo swapon --show
# 关闭
sudo swapoff -a
```
* 配置其它：
```bash
# sudo vim /etc/sysctl.d/k8s.conf
# 添加： 
net.ipv4.ip_forward = 1

# 导出配置
containerd config default > /etc/containerd/config.toml
# 修改配置
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
  ...
  [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
    SystemdCgroup = true

# 执行命令
sudo modprobe br_netfilter
sudo systemctl restart containerd
```
* 按正常流程安装完docker, containerd组件

<!--more-->

### 默认安装
* kubeadm初始化
```bash
# 以containerd作为运行时
NODENAME=$(hostname -s) \
&& KUBERNETES_VERSION="v1.25.6" \
&& MASTER_IP=$(ip addr show enp3s0f0 | grep "inet\b" | awk '{print $2}' | cut -d/ -f1)
sudo kubeadm init --image-repository=registry.aliyuncs.com/google_containers  \
 --pod-network-cidr="192.168.0.0/16" \
 --service-cidr="10.96.0.0/12"  \
 --kubernetes-version $KUBERNETES_VERSION  \
 --apiserver-advertise-address $MASTER_IP  \
 --node-name $NODENAME \
 --cri-socket unix:///run/containerd/containerd.sock \
 --control-plane-endpoint=atms-01.vm

kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/tigera-operator.yaml \
    -f https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/custom-resources.yaml

kubectl  taint node atms-02 node-role.kubernetes.io/control-plane:NoSchedule-
```

### 修改CIDR
* 在一些k8s安装要求下，可能需要修改pod CIDR或service CIDR，可通过如下方式安装：
> 当前修改service CIDR没生效，所以只演示修改pod CIDR

* kubeadm初始化 
```bash
# 以containerd作为运行时
NODENAME=$(hostname -s) \
&& KUBERNETES_VERSION="v1.25.6" \
&& MASTER_IP=$(ip addr show enp0s31f6 | grep "inet\b" | awk '{print $2}' | cut -d/ -f1)
sudo kubeadm init --image-repository=registry.aliyuncs.com/google_containers  \
 --pod-network-cidr="192.169.0.0/16" \
 --service-cidr="10.96.0.0/12"  \
 --kubernetes-version $KUBERNETES_VERSION  \
 --apiserver-advertise-address $MASTER_IP  \
 --node-name $NODENAME \
 --cri-socket unix:///run/containerd/containerd.sock \
 --control-plane-endpoint=atms-02.vm

kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/tigera-operator.yaml 

kubectl  taint node atms-02 node-role.kubernetes.io/control-plane:NoSchedule-
```

* 修改calico：
```yaml
# wget https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/custom-resources.yaml
# 修改内容如下：
# 自定义calico custom-resource.yaml配置自定义CIDR
# This section includes base Calico installation configuration.
# For more information, see: https://projectcalico.docs.tigera.io/master/reference/installation/api#operator.tigera.io/v1.Installation
apiVersion: operator.tigera.io/v1
kind: Installation
metadata:
  name: default
spec:
  # Configures Calico networking.
  calicoNetwork:
    # Note: The ipPools section cannot be modified post-install.
    ipPools:
    - blockSize: 26
      cidr: 192.169.0.0/16
      encapsulation: VXLANCrossSubnet
      natOutgoing: Enabled
      nodeSelector: all()
  #serviceCIDRs:
  #- 10.97.0.0/12

---

# This section configures the Calico API server.
# For more information, see: https://projectcalico.docs.tigera.io/master/reference/installation/api#operator.tigera.io/v1.APIServer
apiVersion: operator.tigera.io/v1
kind: APIServer 
metadata: 
  name: default 
spec: {}
```

## reset
* 通过如下命令重置k8s节点，如在执行`kubeadm init`或`kubeadm join`后可通过下面命令重置节点：
```bash
sudo kubeadm reset
```


