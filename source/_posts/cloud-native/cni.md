---
layout: pages
title: cni
date: 2024-02-18 22:15:43
tags: ["k8s", "CNI"]
---

## 容器网络
### docker网络模式
* 默认创建如下三种：bridge, host, none
```bash
hbb@hbb:~$ docker network ls
NETWORK ID     NAME      DRIVER    SCOPE
3c92bea4cc95   bridge    bridge    local
3d964312d0b5   host      host      local
07d5e640e74f   none      null      local
```
* 默认容器均采用bridge网桥模式，所有容器均会创建一对虚拟网络接口，容器内一个eth0，容器外一个vethXXX，vethXXX属于docker0，通过docker0实现对外网的访问；
* `host`模式即与主机共享网络空间，不使用私有的容器网络空间；
* `none`模式即容器内没有eth0网口，因此无法与容器外通信；

### network namespace, veth pair, bridge
* 下图所示为相关概念：
![network namespace vs veth pair vs bridge](basic-concepts.png)

#### `bridge`
* docker0 bridge即纯软件实现的虚拟交换机，可实现与物理交换机同样的功能，如二层交换，ARP寻找MAC地址；

#### `network namespace`
* 即将一个物理的网络协议栈进行逻辑隔离，形成网络空间，不同的拷贝协议栈有自己独立的网络接口，ip，route tables, iptables等，而进程可以设置使用不同的network namespace，多个进程也可以属于同一个ns，一个pod有一个独立的ns，pod内的容器属于同一个ns；


### 容器网络通信模型
* pod内容器属于同一个网络空间，所以可直接相互访问；
* 同机不同容器之间，通过虚拟以太网veth network互联，docker安装后，会默认创建一个docker0作为虚拟以太网的bridge网桥，在容器创建时会在容器内外创建一对虚拟网络接口，容器内为eth0，容器外即主机上会对应创建一个vethXXX名的接口名，如下图所示：
    * 该图为docker容器内eth0，与docker0属于同一网段： 
![veth in C](vethInC.png)
    * 该图为上面容器在主机上对应的veth网口，其master为docker0：
![veth on host](vethOnHost.png)
* 在主机上通过`docker inspect network bridge`命令可查看docker列出的当前docker默认bridge网桥docker0下的容器网络信息：
![docker bridge](docker-bridge.png)

<!-- more -->
* 因此，同主机上的容器之间是通过网桥来实现互联，其为2层网络通信；
* k8s跨节点的网络通信，需要对应的CNI插件来创建和维护，其原理是通过IP包路由来实现；
* 因为k8s的容器编排会导致pod频繁变化，对应的IP也会频繁变化，因此实现更新对应的网络信息是需要对应的CNI插件来实现，不同插件实现的跨节点的网络通信方式不一样，如通过TUN隧道等；
![k8s network](k8s-network.png)

### pod网络创建过程
* kubelet -> CRI plugin -> pod net ns, pause sandox -> CNI plugin
* 如下图所示：
![pod network](pod-network.png)

### vxlan网络与flannel CNI
* 如图所示，为vxlan原理：
![vxlan](vxlan.png)

* flannel CNI插件会为每个node分配一个子网IP段，上面的pod会从该网段范围取一个IP；
* 默认，flannel跨节点通信是通过`vxlan`实现，即通过隧道技术`L2 Oery UDP`；

### calico CNI


## 集群网络
* 通过service来维护pod IP的抽象，管理与负载均衡；
* 通过环境变量或DNS来实现服务发现；
