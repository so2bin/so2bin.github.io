---
title: k8s client-go
date: 2024-02-19 22:01:07
tags: [k8s, client-go]
---
## client
* k8s client-go提供4个client：`RESTClient`, `ClientSet`, `DynamicClient`, `DiscoveryClient`

### RESTClient
* 作为另外三类client的基类，提供与k8s apiserver的底层API请求构造与请求；

### ClientSet
* 用于方便访问k8s内置api group资源的client，如deployment, pod等；

### DynamicClient
* 通过指定资源组，资源版本即可操作k8s中的任务资源，包括CRD和内置资源；
* DynamicClient使用嵌套的`map[string]interface{}`结构来存储k8s apiserver的返回资源结构，通过反射机制，在运行时进行数据绑定；

### DiscoveryClient
* 与前面三种client不同，该client不是用于管理k8s资源对象的，该client是用于查询k8s支持的GVR资源类型的，与`kubectl api-versions`和`kubectl api-resources`返回的资源内容相关；

<!-- more -->

## Informer
### Reflector and List-Watch
* 资料：https://xiaorui.cc/archives/7361

* List: 通过k8s apiserver Restful API获取全量数据列表，并同步到本地缓存中，该操作基于HTTP短连接实现；
* Watch负责监听资源变化，并调用相应事件处理函数进行处理，如更新本地缓存，使本地缓存与ETCD保持一致，该操作基于HTTP长连接实现；
* Reflector是client-go中用于监听指定资源的组件，当资源发生变化时，会以事件的形式存储到本地队列，然后触发后续的相应处理函数；
* Reflector核心逻辑有三部分：
    * List: 全量同步指定资源；
    * Watch: 监听资源的变更；
    * 定时同步：定时更触发同步机制，定时更新缓存数据，可配置定时同步的周期；
* 当Watch断开时，Reflector会重新走List-Watch流程；

* 第一次执行List操作时，由于`resourceVersion`为空，拉取的是全是数据；
* 当list-wathc出现异常重试时，List会根据本地存储的最新的`resourceVersion`拉取其之后的所有新数据；

### DeltaFIFO
* 增量的本地阶段，记录了资源的变化过程；
* FIFO即为先入先出的本地队列；
* Delta为资源的变化事件，存储的数据结构`Deltas`有两个属性：`Type`, `Object`，分别表示事件类型（增删改），资源类型；
* FIFO负责接收来自Reflector的事件，将按顺序存储，多个相同事件只会被处理一次；

### Indexer
* 本身是一个本地存储，并扩展了一定的索引能力；
* Reflector通过DeltaFIFO的操作后，数据会被存储到Indexer中；
* Indexer中的数据与ETCD完全一致；

**几个重要概念**

* `IndexFunc`: 索引函数，用于计算一个资源对象的索引值列表，可以根据需要自定义，如通过label, annotation来生成索引列表；
* `Index`：存储数据，如要查找某个ns下的pod，就要让pod按ns空间进行索引，对应的Index类型即为`map[ns]pods`；
* `Indexers`：存储索引器，key为索引器名称，value为索引器实现函数（IndexFunc），如`map[ns]XXXIndexFunc`
> 即存储索引的存储器
* `Indices`：存储缓存器，key为索引器名称，value为缓存的数据（Index），如`map[ns]map[ns]sets.pod`
> 即存储缓存数据的存储器

```go
index := cache.NewIndexer(
    cache.MetaNamespaceKeyFunc,  // 资源key生成函数
    cache.Indexers{  // 索引存储器名 => 索引生成函数
        "namespace": XXXNsIndexFunc, 
        "nodeName": XXNodeNameIndexFunc,
    })
pod1 := &v1.Pod{...}
pod2 := &v1.Pod{...}
pod3 := &v1.Pod{...}

_ = index.Add(pod1)
_ = index.Add(pod2)
_ = index.Add(pod3)

// 查询
pods, err := index.ByIndex("namespace", "xxx")
pods, err = index.ByIndex("nodeName", "xxx")
```

## SharedInformer
* 通过`SharedInformer`为多个Controller提供缓存资源对象的informer共享，避免重复缓存；
* `SharedInformer`一般是使用`SharedInformerFactory`来管理控制器需要的资源对象的informer，使用map结构来存储资源对象的informer；

## SharedIndexInformer
* 继承了`SharedInformer`，并扩展了添加和获取Indexers的能力；

## SharedInformerFactory
* `SharedInformerFactory`为所有已知GVR提供共享的informer；
* 其有一个`Start`方法，用于启动所有Reflector的Informer；
* 其`WaitForCacheSync`函数会不断调用factory持有的informer的`HasSynced`方案直接全部返回true，表示所有informer关注的资源对象已经全部缓存到了本地；
* `InformerFor`方法，是用于返回`SharedInformerFactory`中指定资源类型所对应的informer，如果不存在则会先创建；
* k8s client-go已经提供了内置的常用informer，如`PodInforer`, `ServiceInformer`等；

```go
sharedInformerFactory := informers.NewSharedInformerFactory(clientSet, 0)
podInformer := sharedInformerFactory.Core().V1().Pods()
// 生成一个indexer便于查询数据
indexer := podInformer.Lister()

// 启动informer
sharedInformerFactory.Start(nil)
sharedInformerFactory.WaitForCacheSync(nil)

// 查询pod
pods, err := indexer.List(labels.Everything())
```


