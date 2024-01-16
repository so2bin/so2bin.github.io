---
title: Lazy Docker Containers
date: 2024-01-16 14:55:45
tags: ["lazy container", "docker"]
---
# 论文粗读：Slacker: Fast Distribution with Lazy Docker Containers
## 阅读目标
* 了解docker容器启动过程的数据特性，以及slacker的设计思路，不对该存储驱动做过细了解。

## 介绍
* 开发了名为`HelloBench`的工具来分析57个不同的容器应用，分析容器启动过程的IO数据特性和镜像可压缩性，得出结论：在容器的启动过程中，镜像的拉取占76%的时间，但仅读了6.4%的数据。
* 基于这些发现，作者设计开发了一种新的docker存储驱动：Slacker，可以用于加速容器的启动速度。
* Slacker采用中心化存储思路，所有的docker workers和registries都共享这些数据。
* Container的启动主要慢在文件系统的瓶颈，相对而言，network, compute, memory资源更快且简单，容器应用需要一个完整的初始化文件系统，包括应用binary，完整的linux系统和依赖包；
* 在谷歌的研究论文中，容器应用启动延时变化秀大，中间值一般为25s，且package installation占了80%，其中的一个瓶颈为并发写磁盘的过程；
* 提供快启动的好处：
    * 应用能快速扩容以应对突发事件（flash-crowd events）；
    * 集群调度器能以最少的代价频繁执行rebalance nodes；
    * 应用更新或bug修复能快速发布；
    * 开发者可以交互式构建和测试分发应用；
<!--more-->
* 作者分了两步来尝试解决这个问题：
    1. 开发了开源工具`HelloBench`来分析容器启动过程的IO特性和镜像特征，该工具得到如下结论：
        * 容器启动阶段，copying package data耗时占了76%；
        * 这些copy的数据中，仅6.4%的数据是容器启动阶段真实需要的；
        * 相比于gzip压缩，简单的跨镜像块去重能达到更好的压缩比；
    2. 基于这些研究，作者设计开发了Slacker docker存储驱动，该驱动提供了如laziy pull image而不是拉取整个镜像内容，能显著减少网络IO；
* 基于这些技术，Slacker能提供72倍的镜像pull加速，提供5倍的容器部署周期加速，20倍的应用部署周期加速；

## Docker Backgroud
### Version Control for Containers
* cgroups通过6个namepsace来提供多种资源的虚拟化隔离：文件系统挂载点、IPC队列、网络、主机名、进程ID和用户ID；
* docker image是多layer的只读文件集合，layer的拉取在网络上是通过gzip tar文件来传输，在本地的存储格式是由对应的docker存储驱动决定；

### Docker Storage Driver Interface
> 当前docker默认采用overlay2存储驱动，部分源码可参考我前面的`OCI镜像规范`文档。
* docker容器有两种访问文件系统的方式：1. 通过挂载本机路径到容器中；2. 容器需要访问镜像层的数据，如应用binary, libraries；
* docker是通过存储驱动提供mount point来给容器提供镜像层文件的视图，容器将这些作为其rootfs；
* docker存储驱动需要至少实现如下图的接口：
![docker driver api](docker-driver-api.png)
* 其中的Diff和ApplyDiff分别用于生成新的镜像层tar文件和将层的tar文件联合到容器文件系统中，如下图所示：
![diff](diff.png)
* 联合挂载点提供了底层文件系统的多层目录的聚合视图；

> 论文中提到的AUFS现在已不是docker的默认存储驱动，现在为overlay2，所以这些内容跳过


## Slacker
### 架构
* 其构架的核心思路是将镜像/容器数据统一存储到一个集中式存储器NFS上，这样容器启动时，仅需要读取的数据才会通过网络拉取，避免了同步整个镜像文件的情况，显著减少网络IO：
![slacker-arch](slacker-arch.png)

> 看到这，需要理解的东西基本差不多了，其它一些技术有点过时或不适用于生产，所以不再继续细读。

