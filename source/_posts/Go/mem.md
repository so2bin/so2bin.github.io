---
title: Go 内存模型
date: 2024-01-28 17:00:47
tags: ["Go", "内存模型"]
---
## 架构
### 分层架构
* Go的页单元大小 ：8KB，linux操作系统：4KB；
* 如下图所示，分了三层来管理
    * mcache: 每个P一个，为每个mspan额外缓存了一个，无锁；
    * mcentral: 分了67个span，从8B-32B，细粒度锁；
    * mheap: 全局唯一；
<img src="go-mem-arch.png" width="60%" height="60%"  style="margin: 0 auto;" alt="go-mem-arch"/>
<!-- more -->
<img src="go-mem-arch2.png" width="60%" height="60%"  style="margin: 0 auto;" alt="go-mem-arch2"/>


### 三类对象
* tiny 微对象，<=8B，通过P的专属tinyAllocator分配，依次从：mcache tiny -> mcache span -> mcentral -> mheap -> VM分配；
* small 小对象，<=32KB， 依次从：mcache span -> mcentral -> mheap -> VM分配；
* large 大对象，>32KB，依次从：mcentral -> mheap -> VM分配；
