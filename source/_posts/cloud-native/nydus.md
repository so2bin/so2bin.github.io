---
title: Nydus
date: 2024-01-13 14:40:04
tags: ["Nydus", "Cloud Native"]
---
## 资料
* https://developer.aliyun.com/article/979419
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

### 镜像格式


