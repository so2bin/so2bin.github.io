---
title: Go select
date: 2024-05-06 16:19:29
---
## 源码解析
> https://draveness.me/golang/docs/part2-foundation/ch05-keyword/golang-select/

* C语言提供的select是监听多个文件描述符，Go的select是类似的作用，可以让Goroutine同时监听多个channel的读写操作，在channel状态改变前，会一直阻塞当前的Goroutine；

## 核心流程
### 编译期优化
编译器会根据select不同的case数量进行优化：
1. 如果空的select，则会转换为`runtime.block`直接挂起当前Goroutine；
2. 如果只有一个case，则会转换为一个if+channel操作语句；
3. 如果有两个case, 且其中一个是default，则会将其中的case转换为非阻塞的底层发送`runtime.selectnbsend`/接收`runtime.selectnbrecv`函数实现；
4. 其它情况下，会通过`runtime.selectgo`来获取可执行的case索引，通过多个if语句来执行对应case中的代码：
```go
chosen, revcOK := selectgo(selv, order, 3)
if chosen == 0 {
    ...
    break
}
if chosen == 1 {
    ...
    break
}
if chosen == 2 {
    ...
    break
}
```
<!-- more -->
### selectgo
1. 随机生成一个遍历的轮询顺序`pollOrder`，并根据channel的地址生成`lockOrder`，其中的`pollOrder`是实现case之间的随机性， 避免出现case饥饿现象；
> 在计算这两个order的过程，源码中写死了数组的上限，这也就限制了select中case的数量为`1<<16`个：
```go
func selectgo(cas0 *scase, order0 *uint16, ncases int) (int, bool) {
	cas1 := (*[1 << 16]scase)(unsafe.Pointer(cas0))
	order1 := (*[1 << 17]uint16)(unsafe.Pointer(order0))
    ...
}
```
2. 根据pollOrder遍历所有的case，查看是否有可执行的channel：
    * 如果存在，则直接获取case索引，并返回
    * 如果不存在，则创建`runtime.sudog`结构体，并将当前Goroutine加入到所有相关的channel的收发队列中，并`runtime.gopark`挂起当前的Goroutine；
    * 这些`sudog`结构是以链表的形式组织起来的；
![sudog-list](sudog-list.png)
3. 当有channel唤醒当前Goroutine时，会再次按`lockOrder`遍历所有case，找到待处理的`runtime.sudog`对应的索引；
4. 其它没匹配到的channel中的sudog，会从channel队列中清理掉；
```go
func selectgo(cas0 *scase, order0 *uint16, ncases int) (int, bool) {
	...
	sg = (*sudog)(gp.param)
	gp.param = nil

	casi = -1
	cas = nil
	sglist = gp.waiting  // header node of link
	for _, casei := range lockorder {
		k = &scases[casei]
		if sg == sglist {
			casi = int(casei)
			cas = k
		} else {
			c = k.c
			if int(casei) < nsends {
				c.sendq.dequeueSudoG(sglist)
			} else {
				c.recvq.dequeueSudoG(sglist)
			}
		}
		sgnext = sglist.waitlink
		sglist.waitlink = nil
		releaseSudog(sglist)
		sglist = sgnext
	}

	c = cas.c
	goto retc
	...
}
```


