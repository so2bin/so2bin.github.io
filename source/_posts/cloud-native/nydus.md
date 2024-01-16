---
title: Nydus
date: 2024-01-13 14:40:04
tags: ["Nydus", "Cloud Native"]
---
## 资料
* [官方技术博客介绍](https://developer.aliyun.com/article/979419)
* [容器技术之容器镜像篇](https://mp.weixin.qq.com/s?spm=a2c6h.12873639.article-detail.7.71813892qT8cYh&__biz=MzUxNjE3MTcwMg==&mid=2247485160&idx=1&sn=289581225c168e86c5ed3e6819f2a719&chksm=f9aa3431ceddbd277ae447934fbe3fa7bf773158976c5f2b95dcf516ab87e1a32871692683dd&scene=21#wechat_redirect)
* [Dragonfly 发布 Nydus 容器镜像加速服务](https://mp.weixin.qq.com/s?spm=a2c6h.12873639.article-detail.8.71813892qT8cYh&__biz=MzUxNjE3MTcwMg==&mid=2247484853&idx=1&sn=4ef7232be5e32a479987f073e3c6bd20&chksm=f9aa376cceddbe7ab678e11a1b6baa89a338a7d6dd7fd2de7734fb50a4bc3963d850fdb5f991&scene=21#wechat_redirect)

## 特点
* 镜像lazy加载，按需下载镜像blob数据，容器启动速度更快；
* blobs级别的镜像数据去重，节省空间；
* 提供用户态文件系统Fuse，兼容OCI分发标准，和artifacts标准（lazy加载就是基于该fuse实现）；
* 支持镜像存储backend，镜像数据可以放registry或对象存储上；
* 与Dragonfly P2P系统集成；

## 架构
* 主要包括一种新的镜像格式和一个负责解析容器镜像的FUSE用户态文件系统进程；
<img src="arch.png" width="70%" height="70%"  style="margin: 0 auto;"/>
* nydus可以配置一个本地缓存（local cache）用来缓存镜像数据，避免每次都从远端数据源拉取数据；

### nydus Rafs vs OCIv1镜像格式
* 如下图所示，Rafs镜像格式是分了两块：元数据(bootstrap)、镜像数据块(blobs)；
* OCI下的镜像层文件tar.gz变成了只存储文件数据块，文件以chunk为粒度进行切割和去重；
![Rafs vs OCI](rafs-vs-oci.png)

### Rafs用户态FUSE缺陷和解决
* 用户太的FUSE会存在大量的系统开销，当容器中存在大量文件时，会产生大量的fuse请求，生成内核态和用户态之间的频繁切换，造成性能瓶颈；
* nydus为了解决该问题，在开发Rafs v6镜像格式，该功能依托于EROFS文件系统，用于实现真正的内核态的容器镜像格式；
* 该Rafs v6的按需加载技术，将由EROFS over Fscache技术完成，阿里为此改造了linux fscache文件的缓存内核模块，以于合并到linux 5.19内核版本主线；
> fscache是linux系统中成熟的文件缓存方案，广泛用于网络文件系统，如NFS, Ceph等，阿里对该模块进行了增强，使用支持本地文件系统（如erofs）的按需加载特性，因此该方案中，fscache接管了本地缓存管理的工作（即前面的local cache）；
* 改造后的视图变为： 
![nydus-on-erofs](nydus-on-erofs.png)
* 下图为pod使用fscache与nydus交互的过程：
![fscache+nydus](fscache-nydus.png)
* 官方使用教程：https://github.com/dragonflyoss/nydus/blob/master/docs/nydus-fscache.md

### Rafs镜像格式
> Rafs: Registry Acceleration File System

#### Merkle Tree
> [镜像元数据核心算法：merkle tree](https://developer.aliyun.com/article/842854)
* nydus实现了一种新的镜像格式（docker原生的OCI镜像格式可以参考我之前的文章"OCI镜像规范"），该格式是将镜像文件拆分成元数据和数据blobs两层，其中的元数据就是一颗以文件/目录为树节点的Merkle Tree；
* 该数据结构的特点有：
    * MT树可以是二叉树也可以为多叉树，这里nydus是后者；
    * MT树叶子节点的value是数据集合的单元数据或单元数据的HASH；
    * MT树的非叶子节点的value是根据所有子节点的值计算出来的HASH值；
* 该数据结构的优势有：
    * 对比两颗MT的root节点能直接对比出该树的数据是否一样，如这里的nydus可以通过root的HASH值直接判断出下载的镜像是否与原始镜像一样；
    * 如数据不一样，能够快速分辨出哪一个子节点不同，递归后即可快速找出异常的叶子节点，因此可以仅重新下载该叶子节点的数据即可；
    * blobs的HASH列表可以看成一颗调度为2的MT树；
    * 检索数据块的时间复杂度为`Log(N)`
* 该数据结构被广泛应用于P2P网络中，用于确保从其它节点接受的数据没有损坏或被人为替换；
<img src="MT.png" width="70%" height="50%"  style="margin: 0 auto;"/>

#### nydus镜像元数据
* 如下图所示，nydus的元数据是以文件/目录为节点组件的MT树，所有叶子节点为文件，value由文件内容的HASH决定，非叶子节点为目录，HASH由目录下的子节点HASH确定：
<img src="metadata.png" width="80%"  style="margin: 0 auto;"/>

#### nydus blobs镜像数据
* 镜像数据是被分成固定大小的blobs数据块，大小为4MB；
* blobs可以用于多镜像共享；
* 传统OCI镜像是以gzip从仓库拉到本地并进行解压的，解压前会有数据校验，但解压后并不会再进行校验，这里可能就存在漏洞，而nydus的数据不需要解压到本地，且对每一次数据访问均会进行校验，因此提供了blobs级的安全校验；

