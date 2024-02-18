---
title: Go GMP and Scheduler
date: 2024-01-28 19:58:17
tags: ["Go", "GMP", "Scheduler"]
---
## 资料
* https://medium.com/@sanilkhurana7/understanding-the-go-scheduler-and-looking-at   1-how-it-works-e431a6daacf
* https://segmentfault.com/a/1190000041860912/en

## 结构

## 原理
* G：协程，P：processor，M：系统线程，M绑定一个P才能执行G；
* P的数据是控制着Go的并发能力，由环境变量`GOMAXPROCESS`控制数量，线程数一般不配置，但也有一个底层的函数可设置（`SetMaxThreads`），M默认上限是10000；
* P的存在是为了实现G的调度和M/G之间M:N的关系；
* P有一个local queue，无锁，当P的local queue无G时，会从Global queue取，此时需要用锁，而如果Global queue也无G时，会走work stealing，尝试从其它P的local queue上找G运行；
* G的抢占调度是基于时间片，即如果G长时间连续运行超过10ms，则会通过系统信号SIGURG强制调度该协程；
* 当G发生阻塞，如系统调用IO操作时，会创建一个新的线程或利用一个空闲的线程来绑定当前P，以继续执行P上的G，而旧线程进入阻塞睡眠状态；
* P的local queue放的G的数量上限为256；
* 当因IO阻塞进入idle状态的线程，在G系统调用结束时，因此时M上没有P了，而G的执行一定需要P，所以会尝试先去获取一个idle的P来执行，如找到了，则会将该G放到该P的local queue中，如果没有，则M会进入idle线程队列，G会放到Global queue中；

<!--more-->


