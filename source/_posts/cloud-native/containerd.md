---
title: containerd
date: 2024-01-16 22:53:39
tags: ["Cloud Native", "Containerd"]
---
## 资料
* https://github.com/containerd/containerd/blob/main/docs/historical/design/architecture.md
* https://blog.frognew.com/2021/05/relearning-container-08.html
* https://blog.frognew.com/2021/06/relearning-container-09.html
 

## 概念
### Bundles
* 简单来说，`bundles`在文件系统上就是一个目录，该目录下包括容器运行时如runC启动容器需要的：配置、元数据、rootfs；
* 这个目录是由文件系统驱动程序将镜像的多层文件通过联合挂载的方式以目录的形式呈现给容器运行时的；


## 架构

* Containerd架构上设计被拆成了多个组件，这些组件被组织到了subsystems子系统中；
* 这个构架的主要目标是协调`bundles`的创建和执行；

![Arch](Arch.png)

### subsystems
* 用户通过GRPC API与子系统交互，当前containerd提供两个子系统服务：
    * Bundle: Bundle服务为用户提供从磁盘镜像提供bundle和打包bundle为磁盘镜像的能力；
    * Runtime: Runtime服务提供执行bundle的能力，包括创建运行时容器；
* 一般来说，每个子系统都包括一个或多个关联的controller组件来实现该子系统的能力；

### Modules
除了子系统，Containerd有多个跨子系统边界的组件：
* Executor: 实现容器运行时
* Supervisor: 监控容器状态
* Metadata：存储metadata的图数据库，在contailerd目录中有一个meta.db，是一boltdb文件；
* Content: 具体的blobs文件存储，sha256索引；
* Snapshot: 管理容器镜像的文件系统snapshots，这里的snapshot可以理解为镜像文件目录的联合，如overlay2的联合目录形成容器的rootfs；
* Events: 
* Metrics: 

### Client-side组件
* 一些在客户端实现的组件能力，如镜像的分发接口实现；

### Data Flow
* Bundle是containerd的核心，如下流程是bundle的创建过程：
![Bundle Creation](bundle-creation.png)

在整个流程中，需要和三个组件进行交互：Distribution, Bundle, Runtime。其中：
* Distribution的作用显然是用于从仓库拉取镜像到content store下，如我本地的`/var/lib/containerd/io.containerd.content.v1.content`，同时镜像的name和root manifest pointers会被注册到metadata store中，对应我本地的目录`/var/lib/containerd/io.containerd.metadata.v1.bolt`；
* Bundle会解压镜像，并组装成一个容器运行所需的bundle，镜像的数据从前面的content目录中读取，镜像的layers会被联合mount到snapshot中，对应到我本地的目录：`/var/lib/containerd/io.containerd.snapshotter.v1.overlayfs`；
* 当容器运行所需的rootfs snapshot准备好了，bundle controller会基于镜像的manifest和config内容生成`runC`容器运行标准所需的配置文件；
* 所有这些bundle随后会一起传给Runtime子系统执行，用于创建一个容器；

