---
layout: pages
title: k8s device-plugin
date: 2024-03-02 00:10:11
tags: [k8s, device-plugin]
---
## k8s device-plugin机制
### docker运行GPU容器
* nvidia的GPU容器镜像原理是：NVIDIA驱动相对更稳定，因此容器中使用容器封装的CUDA/SDK库，共用宿主机的NVIDIA驱动；
* docker运行GPU容器时，需要将NVIDIA驱动映射到容器内：
```bash
# 以下的命令与nvidia-docker同样的作用原理
docker run --it --volume=navidia_driver_xxx.xx:/usr/local/nvidia:ro \
    --device=/dev/nvidiactl \
    --device=/dev/nvidia-uvm \
    --device=/dev/nvidia-uvm-tools \
    --device=/dev/nvidia0 \
    nvidia/cuda nvidia-smi
```

### k8s 运行GPU容器
1. 安装NVIDIA驱动；
2. 安装NVIDIA Dcoker：`nvidia-docker2`
3. 部署NVIDIA Device Plugin：`device-nvidia-plugin`

### k8s GPU资源插件原理
利用了两种技术：
1. Extended Resources，允许用用户自定义资源扩展，如这里的扩展：`nvidia.com/gpu: 2`, 也可用于如RDMA, AMD GPU, FPGA等；
2. Device Plugin Framework，允许第三方设备提供商以插件外置的方式对设置的调度和全生命周期管理；

<!-- more -->

#### Extended Resources
* 属于node级别的资源，是可以与Device Plugin独立的；
* 可以直接通过一个k8s REST API完成node扩展资源的上报：
```bash
curl --header "Content-Type: application/json-patch+json" \
    --request PATCH \
    --data '[{"op": "add", "path": "/status/capacity/nvidia.com/gpu", "value": "1"}]' \
    https://localhost:6443/api/v1/nodes/<target node>/staus
```
对应的node资源表现：
```yaml
# kubectl get node xxx -o yaml
status:
  allocatable:
    cpu: "128"
    ephemeral-storage: "6804750049483"
    hugepages-1Gi: "0"
    hugepages-2Mi: "0"
    memory: 527904364Ki
    pods: "110"
    tencent.com/vcuda-core: "800"
    tencent.com/vcuda-memory: "767"
  capacity:
    cpu: "128"
    ephemeral-storage: 7383626368Ki
    hugepages-1Gi: "0"
    hugepages-2Mi: "0"
    memory: 528006764Ki
    pods: "110"
    tencent.com/vcuda-core: "800"
    tencent.com/vcuda-memory: "767"
```

* 如果是用的Device Plugin机制实现，则需要手动上报，插件会在设备上报的过程中自动完成；

#### Device Plugin机制
##### 资料
* https://kubernetes.io/docs/concepts/extend-kubernetes/compute-storage-net/device-plugins/

##### Device Plugin实现
1. Initialization: 完成设备相关的初始化工作，设备进入Ready状态；
2. plugin启动一个GRPC service，将通过本地unix socket完成端口监听，实现如下接口：
```go
service DevicePlugin {
      // GetDevicePluginOptions returns options to be communicated with Device Manager.
      rpc GetDevicePluginOptions(Empty) returns (DevicePluginOptions) {}

      // ListAndWatch returns a stream of List of Devices
      // Whenever a Device state change or a Device disappears, ListAndWatch
      // returns the new list
      rpc ListAndWatch(Empty) returns (stream ListAndWatchResponse) {}

      // Allocate is called during container creation so that the Device
      // Plugin can run device specific operations and instruct Kubelet
      // of the steps to make the Device available in the container
      rpc Allocate(AllocateRequest) returns (AllocateResponse) {}

      // GetPreferredAllocation returns a preferred set of devices to allocate
      // from a list of available ones. The resulting preferred allocation is not
      // guaranteed to be the allocation ultimately performed by the
      // devicemanager. It is only designed to help the devicemanager make a more
      // informed allocation decision when possible.
      rpc GetPreferredAllocation(PreferredAllocationRequest) returns (PreferredAllocationResponse) {}

      // PreStartContainer is called, if indicated by Device Plugin during registration phase,
      // before each container start. Device plugin can run device specific operations
      // such as resetting the device before making devices available to the container.
      rpc PreStartContainer(PreStartContainerRequest) returns (PreStartContainerResponse) {}
}
```
> 其中`GetDevicePluginOptions`与`PreStartContainer`的实现是可选的，也就是说如果不需要，实现为空函数即可

3. 向kubelet发起注册，带上unix socket位置信息；
4. 注册成功后，plugin会监控设备的状态，将主动向kubelet上报变化或健康状态(`ListAndWatch`)，同时还需要处理`Allocate`请求，在处理分配请求的过程，可能需要执行一些设备相关的初始化操作，并需要将一些必要的信息响应回去，以达到让kubelet对容器运行时参数进行一些修改，如配置容器的Annotations, environments, device nodes, mounts等；
5. plugin还需要能处理kubelet重启的情况，并进行重新注册；

**当plugin检测到设备异常时**

* plugin会向kubelet上报状态
* 如果异常Device处于空闲未分配状态，则kubelet会将其从可分配名额中剔除
* 而如果异常Device处于占用状态，kubelet不会做任何处理，因为直接删除pod是不合理的危险操作

**kubelet向APIServer上报数据**

* kubelet只会向APIServer上报GPU的数量，不会上报其它信息，如GPU ID列表；
* 这些GPU ID列表只会保存在kubelet Device Plugin Manager中；
* 该机制就会导致，调度器，只能看到GPU的数量配置，看不到具体的GPU列表，因此无法实现一些复杂场景的调度；

#### Pod申请资源调度过程
1. k8s scechuler根据资源类型和数量，选择合适的node绑定到pod上，该node的资源数量减少；
2. kubelet Device Plugin Manager会向Plugin发起`Allocate`请求，Plugin会响应相关的参数，如env，mount等，这些参数将会在容器创建过程中对容器进行修改；
3. kubelet创建容器，并配置上`Allocate`响应的参数；

#### Device Plugin集成Topology Manager
* Togology Manager是kubelet的一个组件，允许对资源调度进行拓扑对齐管理；
* 为了实现该功能同，Device Plugin API扩展了`TopologyInfo`结构：
```go
message TopologyInfo {
    repeated NUMANode nodes = 1;
}

message NUMANode {
    int64 ID = 1;
}
```
* 需要进入拓扑管理的Device Plugin在进入Device注册时，可以带上一个`TopologyInfo`信息，里面包括Device ID和健康状态，利用这些信息即可由Togology Manager来提供资源分配的拓扑决策；

#### 当前缺陷
1. 设备调度发生在kubelet层面，缺乏全局视角
2. 资源上报信息有限（仅数量），导致精细度不足，如无法解决异构场景的调度
3. 调度策略简单，并且无法配置，无法应用复杂场景


#### 社区异构资源调度方案
* Nvidia GPU Device Plugin: https://github.com/NVIDIA/k8s-device-plugin.git
* GPU Share Device Plugin:
    * https://github.com/AliyunContainerService/gpushare-scheduler-extender.git
    * https://github.com/AliyunContainerService/gpushare-device-plugin.git
* RDMA Device Plugin: https://github.com/Mellanox/k8s-rdma-shared-dev-plugin.git
* FPGA Device Plugin: https://github.com/Xilinx/FPGA_as_a_Service/tree/master/k8s-device-plugin



