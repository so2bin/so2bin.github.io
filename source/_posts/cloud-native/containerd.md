---
title: containerd
date: 2024-01-16 22:53:39
tags: ["Cloud Native", "Containerd"]
---
## 资料
* https://github.com/containerd/containerd/blob/main/docs/historical/design/architecture.md
* https://blog.frognew.com/2021/05/relearning-container-08.html
* https://blog.frognew.com/2021/06/relearning-container-09.html
* https://blog.mobyproject.org/where-are-containerds-graph-drivers-145fc9b7255

* 高层架构
![Top Arch](top-arch.png) 

## 概念
### 联合挂载
* 由overlay filesystem提供的能力，支持将多个文件系统层叠加在一起，且只显示最顶层的文件和目录，OverlayFS是其实现，docker当前默认存储驱动为overlay2，就是基于该文件系统；
* 在contaierd中这个联合挂载的roofs视图是由snapshotter准备的snapshots；

<!-- more -->

### filesystem
* 在容器生态中，有两种类型的文件系统：overlays filesystem, snapshoting filesystem；
* AUFS, OverlayFS是overlays filesystem，通过联合挂载将多层目录合并提供给容器，提供file级差异，通常工作于常用文件系统如EXT4, XFS；
* Divcemapper, btrfs, ZFS是snapshoting filesystem，提供block级差异，只能工作在为它们格式化的卷上；

### Bundles
* 简单来说，`bundles`在文件系统上就是一个目录，该目录下包括容器运行时如runC启动容器需要的：配置、元数据、rootfs；
* 这个目录是由文件系统驱动程序将镜像的多层文件通过联合挂载的方式以目录的形式呈现给容器运行时的；


## 架构

* Containerd架构上设计被拆成了多个组件，这些组件被组织到了subsystems子系统中；
* 这个构架的主要目标是协调`bundles`的创建和执行；

<img src="Arch.png" width="70%" style="margin: 0 auto;">

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

## Containerd plugins
### 资料
* https://github.com/containerd/containerd/blob/main/docs/PLUGINS.md

### 介绍
* 如前面的Containerd架构图所示，Containerd有很多组件和服务，其中的一些是以插件化的形式提供的，Containerd提供了一对应的插件接口，只要实现这些接口即可自定义扩展这些功能插件；
* 这些扩展接口包括：runtime, snapshotter, content store；
* content store service接口： 
https://pkg.go.dev/github.com/containerd/containerd/v2/api/services/content/v1#ContentServer
* snapshotter service接口： 
https://pkg.go.dev/github.com/containerd/containerd/v2/api/services/snapshots/v1#SnapshotsServer
* diff service接口： 
https://pkg.go.dev/github.com/containerd/containerd/v2/api/services/diff/v1#DiffServer
* 配置plugins扩展可以通过两种方式：1. 二进制；2. 配置plugin grpc proxy；

### Proxy Plugins
* 这里就是配置plugin的GRPC proxy的方式来扩展插件能力；
* containerd plugin GRPC服务监听的是本地的unix socket，配置时需要配置对应的plugin的：name, type, address；
* type类型必须为：`snapshot`, `content`, `diff`；

1. 编辑containerd配置文件：`/etc/containerd/config.toml`
2. 增加`[proxy_plugins]`段，并在段内添加`[proxy_plugins.<plugin-name>]`
3. 配置如下：
```toml
version = 2

[proxy_plugins]
  [proxy_plugins.<plugin-name>]
    type = "snapshot"
    address = "/var/run/<plugin-name>.sock"
```

* Every plugin can have its own section using the pattern `[plugins."<plugin type>.<plugin id>"]`，如：
```toml
version = 2

[plugins]
  [plugins."io.containerd.monitor.v1.cgroups"]
    no_prometheus = false
```

* containerd默认的配置查看：`containerd config default`
* 合并自定义配置后的containerd配置：`containerd config dump`
* 查看当前containerd有的所有plugins列表：`ctr plugins ls`

## snapshotter
### 资料
* [What is a containerd snapshotter?](https://dev.to/napicella/what-is-a-containerd-snapshotters-3eo2)
* https://github.com/containerd/containerd/tree/main/docs/snapshotters

### 概念与介绍
* snapshotter是类似替换了docker的graph driver的作用；
* snapshotter的接口设计是围绕overlay filesystem和snapshoting filesystem中IO更复杂的snapshoting filesystem设计的，因此在支持overlay的接口上没什么压力；
* 如上面的plugins所描述，containerd的snapshotter是以插件化的形式内置，用户可以通过实现snapshotter的GRPC接口实现自定义方案，这就是nydus实现lazy load懒加载技术的基础；
* 复用snapshotter plugin机制，官方提供了一种`Remote Snapshotter`的方案，用于实现类似远程挂载的技术，基于该原理可以实现镜像懒加载实现，类似Slacker的能力；
* 官方提供了一种原生的snapshotter实现：`native`，开插件在合并镜像layer时是直接copy文件，所以磁盘复用率不高，可参考文档：[What is a containerd snapshotter?](https://dev.to/napicella/what-is-a-containerd-snapshotters-3eo2)的使用示例，但明显这是最简单的不依赖其它文件系统的实现，在开发测试阶段很实用：
![native snapshotter](native.png)

### Remote Snapshotter and Stargz Snapshotter
> https://github.com/containerd/stargz-snapshotter?tab=readme-ov-file
> [Startup Containers in Lightning Speed with Lazy Image Distribution on Containerd](https://medium.com/nttlabs/startup-containers-in-lightning-speed-with-lazy-image-distribution-on-containerd-243d94522361)

#### 原理
* 谷歌提出了[`Stargz Snapshotter`](https://github.com/containerd/stargz-snapshotter?tab=readme-ov-file)就是`Remote Snapshotter`的一种实现，该方案实现了lazy pulling；
![stargz-lazypull](stargz-lazypull.png)
* 该技术是基于CRFS设计的stargz镜像格式，该格式相对于tar/tar.gz格式，最大的不同就是能实现压缩文件的索引，也就是可以直接取到tar.gz压缩文件内的子文件，且取出的子文件也是tar.gz格式，这样基于OCI镜像分发规范的range request特性即可实现lazy pull；
* stargz镜像格式完全兼容tar.gz，因此可以直接用于仅支持OCI镜像格式的容器环境；
![stargz-format](stargz-format.png)

> 如我的另一篇介绍`nydus`的文章说到的，stagz镜像格式是以文件为粒度的lazy pull，共享粒度相对于nydus的block来说更粗；

* AWS也实现了一种lazy pull snapshotter方案，声称不需要进行镜像格式的转换，而是生成了一份独立的index artifact(SOCI index)：https://github.com/awslabs/soci-snapshotter
