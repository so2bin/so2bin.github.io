---
layout: pages
title: pod
date: 2024-02-22 11:59:09
tags: [k8s]
---
## pod内容器共享空间
**资料**
* https://www.cnblogs.com/rexcheny/p/11017146.html
* https://linchpiner.github.io/k8s-multi-container-pods.html

**问题**

k8s的pod内可以同时容纳多个容器，那这些容器之间有哪些资源（命名空间）是可以共享的？

**答案**

![pod share](pod-isolation.png)

* 容器的隔离技术是通过cgroup和namespace隔离实现，linux支持namespace有：
    * UTS名称空间，保存内核版本，主机名，域名
    * NET空间，通过逻辑网络栈实现网络空间的隔离
    * 进程PID空间，通过fork时指定的一个参数控制，不同空间间的PID是隔离了，看不到彼此的PID，子空间看不到父空间的内容，但父空间可以管理子空间，如发送信息
    * IPC空间，即进程间通信的隔离，不同容器之间无法通过如信号量，队列，共享内存（System V IPC和POSIX消息队列），来实现进程间通信
    * USER空间，实现用户，组相关功能的隔离
    * MNT空间，即磁盘挂载点和文件系统的隔离能力，同一主机上的不同进程访问相同的路径能看到相同的内容，是因为他们共享本机的磁盘和文件系统
    * 文件系统：不同容器都有自己的一个snapshotter目录，文件系统是隔离的

* pod内的不同容器之间的共享稍有不同：
    * UTS名称空间，是共享的
    * USER空间，共享的
    * NET空间，是共享的，因此不同容器启相同端口会冲突
    * PID空间，默认是关闭的，可以通过`shareProcessNamespace: true`打开
    * IPC空间，是共享的
    ![pod-c-share-IPC](pod-c-share-IPC.png)
    * MNT空间，隔离的，但可以通过挂载同一个pod volume来共享挂载的内容，实现不同容器间的共享挂载，但不同容器之间的文件系统是隔离的
    ![pod-c-share-volume](pod-c-share-volume.png)


