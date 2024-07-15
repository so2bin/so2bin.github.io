---
layout: pages
title: Tritonserver
date: 2024-03-03 11:02:05
tags: [GPU, Tritonserver]
---

## 调研文档

【金山文档 | WPS云文档】 Tritonserver_TensorRT-LLM调研 https://365.kdocs.cn/l/cqu1Q0RUtYog

## in-flight batching
> `in-flight batching`在业内也被称为`continuous batching`, `iteration-level batching`

### TRTLLM Batch Manager
#### 资料
* https://nvidia.github.io/TensorRT-LLM/advanced/batch-manager.html#the-batch-manager-in-tensorrt-llm

#### 介绍
* TRTLLM中的`in-flight batching`功能是闭源的，其通过TRT-LLM的`Batch Manager`组件实现，但该组件暴露了一些`hooks`以允许用户注册自定义的函数，包括new requests read，completed requests response；
* 该特性支持在每个token生成loop步骤中加入新到达的请求，并结束掉处理完的请求，因此能显著提升GPU利用率，消除推理气泡；
![inflight-batch](inflight-batch-1.png)

#### Batch Manager API
* Batch Manager暴露了几个接口用于与其交互，其中有两个是必须要实现的，还有几个可选的callback函数，这些被定义在`callbacks.h`中：
https://github.com/NVIDIA/TensorRT-LLM/blob/main/cpp/include/tensorrt_llm/batch_manager/callbacks.h
```c++
namespace tensorrt_llm::batch_manager
{

class InferenceRequest;
class NamedTensor;

using GetInferenceRequestsCallback = std::function<std::list<std::shared_ptr<InferenceRequest>>(int32_t)>;
using SendResponseCallback = std::function<void(uint64_t, std::list<NamedTensor> const&, bool, std::string const&)>;
using PollStopSignalCallback = std::function<std::unordered_set<uint64_t>()>;
// json of stats as a string
using ReturnBatchManagerStatsCallback = std::function<void(std::string const&)>;

} // namespace tensorrt_llm::batch_manager
```
* 这些API会在token生成loop中被调用；

* 构造API：
> https://github.com/NVIDIA/TensorRT-LLM/blob/main/cpp/tensorrt_llm/pybind/batch_manager/gptManager.h
```c++

GptManager::GptManager(std::filesystem::path const& trtEnginePath, tb::TrtGptModelType modelType,
    GetInferenceRequestsCallback const& getInferenceRequestsCb, SendResponseCallback const& sendResponseCb,
    tb::PollStopSignalCallback const& pollStopSignalCb,
    tb::ReturnBatchManagerStatsCallback const& returnBatchManagerStatsCb,
    tb::TrtGptModelOptionalParams const& optionalParams, std::optional<uint64_t> terminateReqId)
{
    mManager = std::make_unique<tb::GptManager>(trtEnginePath, modelType, callbackAdapter(getInferenceRequestsCb),
        callbackAdapter(sendResponseCb), pollStopSignalCb, returnBatchManagerStatsCb, optionalParams, terminateReqId);
}
```

##### Get And Send Callbacks
* 这两个函数是必须要实现的，用于获取请求，返回响应数据；

###### SendResponseCallback
* `SendResponseCallback`函数指标，是用于向Batch Manager 传递最新的请求的函数，其需要返回一个request list: `std::list<std::shared_ptr<InferenceRequest>`；
* 对于每个`InferenceRequests`，必须提供input tensor和`uint64_t`的request UID标识`requestID`，同时input tensor将通过map的形式提供，格式：`std::map<std::string, Tensor>`；

###### SendResponseCallback
* 向调用端（tritonserver）发送响应，通过`requestID`来确定请求对象，带上list of output tensors `std::list<NamedTensor>`；
* boolean参数用于识别响应结束的标识；
* 非空error string则表示有异常信息；
* 对于已经处理过的`requestID`，batch manager会拒绝处理该请求，在`SendResponseCallback`调用后，该`requestID`将会被标记为final=true，此时该`requestID`可以被其它请求使用；

###### PollStopSignalCallback 
* 用于中断请求的处理，即对应`tritonserver`的取消操作；

##### Statistics
* `ReturnBatchManagerStatsCallback`函数用于batch manager暴露出json格式的统计信息；
* batch manager提供了多种统计信息，包括：
    * 请求相关的：`Active Request Count`, `Max Request Count`
    * paged KV Cache相关的：`Max/Free/Used KV cache blocks`, `Tokens per KV cache block`, `Scheduled Requests`
    * in-flight batching相关的(per iteration)：`Scheduled Requests`(总请求数), `Context Requests`(context阶段请求数), `Generation Requests`(generation阶段请求数)，`Total COntext Tokens`(所有当前context阶段请求的token数)

### GptManager上配置的BatchManager相关参数
#### 必要参数
* `trtEnginePath` TRTLLM模型文件路径
* `modelType` batching类型：
    * `V1` 传统的batching机制：batched请求阻塞等待所有请求结束后返回，batched request全部padding到maximum input/output sequence length；
    * `InflightBatching`: newly arrived request动态加入到当前正在执行的batching中，且请求在达到条件时可立刻结束，不需要任何padding；
    * `InflightFusedBatching`: `InflightBatching`的改进版本，利用了额外的操作融合机会，会优于`InflightBatching`的效果；
* `maxBeamWidth`
* `capacitySchedulerPolicy`在每个inflightbatching generation loop iteration中，选择可用请求（subset of requests）的策略：
    * `MAX_UTILIZATION` 尽可能打包更多底层TRT引擎能支持的请求数量，虽然该方案能最大化提供GPU利用率，但可能会导致一些请求在KV cache容量不足时被paused并restarted；
    * `GUARANTEED_NO_EVICT` 相对保守的KV cache使用方案，保证请求一旦开始就不会向上面的方案一样出现驱逐，即请求一定能正常处理掉；

> 我们平台上运行的应用中就出现过在配置`MAX_UTILIZATION`时的请求耗时被异常延长，GPU利用率持续跑满的情况：
![abnomal-duration](abnomal-duration.png)
![abnormal-gpu](abnormal-gpu.png)

#### 可选参数`TrtGptModelOptionalParams`
* `kvCacheConfig`
    * `maxTokens` 默认未指定，指KV Cache会持有的最大token数，该tokens是针对所有请求的，因此其也决定了KVCache占用的显存上限，如配置了该值，则最终的KV Cache上限将取当前参数与`freeGpuMemoryFraction`中计算出的最小值；
    * `maxAttentionWindow` 默认未指定，达到类似sliding windows attention or StreamingLLM的效果，即控制注意力计算的token数，默认时将与所有previous token计算注意力，即为MHA, MQA的效果；
    * `freeGpuMemoryFraction` KVCache的显存使用比例上限，该值是在完成模型加载/权重加载后的剩余显存的比例值，最终的KVCache取值将取`freeGpuMemoryFraction`与`maxTokens`计算出的最小值；
    * `enableBlockReuse`，默认`false`，允许跨请求复用之前计算出的KVCache blocks，可以优化内存使用与计算；
* `enableChunkedContext`，默认为`false`，是否开启context chunking，控制是否允许context chunking，该功能可以将大上下文拆分出很多小chunks，以更小的粒度来调度，以实现context与generation阶段的batching操作，提升系统吞吐；
* `peftCacheManagerConfig` LoRA相关的参数，暂时不考虑；

## mpirun

