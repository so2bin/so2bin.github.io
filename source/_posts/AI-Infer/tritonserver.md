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
> TRTLLM triton backend inflight batching使用：https://github.com/triton-inference-server/tensorrtllm_backend/blob/main/inflight_batcher_llm/README.md


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

### GptManager流程设计
* BatchManger被设计为与推理服务交互，如tritonserver这种带有模型执行线程池的结构；
* 模型线程在一个loop iteration开始时会调用`GetInferenceRequestsCallback`接口用于读取新的请求；
* 在loop iteration结束时调用`SendResponseCallback`发送响应数据，在流式模式下，允许一次响应单个token；
* `PollStopSignalCallback`, `ReturnBatchManagerStatsCallback`也是在loop iteration结束时调用；
* scheduler policy用于batch manager确定需要调度多少个请求来执行，在设置为`kMAX_UTILIZATION`时，其会深度最大化调度更多的请求，但这也会存在KVCache不足导致请求被pause，当然这些pased请求会被自动恢复重试，用户看到的是请求延迟会增加；


### Multi-GPU execution
* 当用TP/PP在多GPU上推理时，会在每个GPU上跑一个GptManger进程实例(rank)，可通过`CUDA_VISIBLE_DEVICES`环境变量来控制GPU的可见范围；
* 在每个generation loop中，需要确保所有的ranks都看到同样的inputs，在TRTLLM triton backend中，是通过在`GetInferenceRequestsCallback`中调用MPI broadcast函数来确保所有的MPI rank看到同样的请求数据；

### demo
#### 资料
> https://github.com/triton-inference-server/tensorrtllm_backend/blob/main/inflight_batcher_llm/README.md
> https://github.com/NVIDIA/TensorRT-LLM/blob/main/examples/llama/README.md#llama

#### CUDA计算架构
* 查看各GPU型号的计算架构：https://developer.nvidia.com/cuda-gpus#compute
* Compute Capability说明：https://docs.nvidia.com/cuda/cuda-c-programming-guide/index.html#compute-capability
* 不同技术架构支持的特性：https://docs.nvidia.com/cuda/cuda-c-programming-guide/index.html#compute-capabilities

#### 手动编译trtllm wheel
> https://github.com/NVIDIA/TensorRT-LLM/blob/release/0.5.0/docs/source/installation.md#build-tensorrt-llm-in-one-step

1. 默认安装的有时候会有代码的冲突，需要手动安装
```bash
# 切换到对应的tag，同步submodule
git checkout v0.10.0 
git submodule update --init --recursive
git lfs install
git lfs pull

# 89对应RTX 4090
python3 ./scripts/build_wheel.py --trt_root /usr/local/tensorrt --cuda_architectures "89;89-real" -j 8 --clean  
# --build_dir cpp/build
```
2. 安装
```bash
pip install ./build/tensorrt_llm*.whl
# 验证
trtllm-build --help
```


#### 步骤
1. 下载HF模型
```bash
pip install -U huggingface_hub hf_transfer
export HF_ENDPOINT=https://hf-mirror.com
huggingface-cli download --resume-download gpt2 --local-dir gpt2
```
2. 转换权重
> https://github.com/NVIDIA/TensorRT-LLM/blob/main/examples/llama/README.md#llama
```bash
# 切换到v0.10.0 tag，不能直接用main，因为main分布下的脚本可能与pip安装的不同
git checkout v0.10.0 
# 如果切换tag后submodule如3rdparty/cutlass出现commitid变更（如因网络问题导致同步错误等），可进入该submodule项目后手动切换到对应的commitid上：
# cd 3rdparty/cutlass && git checkout 7d49e6c7e2f8896c47f586706e67e1fb215529dc
# 转换到FP16 1GPU
python TensorRT-LLM/examples/llama/convert_checkpoint.py --model_dir /mnt/models/source/ --output_dir /data/trtllm/output/trtllm-chpt-fp16 --dtype float16
```

4. 编译trt engin:
```bash
# 默认：max_batch_size=1, max_input_len=1024, max_output_len=1024, max_num_tokens=1024, use_paged_context_fmha=1024
#      paged_kv_cache=true, gemm_plugin=false
trtllm-build --checkpoint_dir  /data/trtllm/output/trtllm-chpt-fp16/ --output_dir  /data/trtllm/output/trtllm_engine_fp16 
```

3. 编译模型
```bash
# --workers 编译engine的线程数，可不与TP一致
# 多卡并行时，要求：world_size == tp_size * pp_size
trtllm-build --model_config $model_cfg --strongly_typed --output_dir $engine_dir --max_batch_size 2048 --max_input_len 2048 --max_output_len 4096 --workers $tp_size --max_num_tokens 2048 --use_paged_context_fmha enable --multiple_profiles enable
```
官方示例给出的Llama-3-8B配置文件：
> https://nvidia.github.io/TensorRT-LLM/performance/perf-overview.html#network-configuration-files
```json
{
    "architecture": "LlamaForCausalLM",
    "num_hidden_layers": 32,
    "num_attention_heads": 32,
    "num_key_value_heads": 8,
    "hidden_size": 4096,
    "vocab_size": 128256,
    "max_position_embeddings": 8192,
    "hidden_act": "silu",
    "norm_epsilon": 1e-05,
    "dtype": "float16",
    "position_embedding_type": "rope_gpt_neox",
    "intermediate_size": 28672,
    "rotary_base": 500000.0,
    "rope_theta": 500000.0,
    "rotary_scaling": null,
    "mapping": {
        "world_size": 1,
        "tp_size": 1,
        "pp_size": 1
    },
    "quantization": {
        "quant_algo": "FP8",  // FP8仅在H100或更新的机器上支持，4090可以设置为null
        "kv_cache_quant_algo": "FP8" // FP8仅在H100或更新的机器上支持，4090可以设置为null
    },
    "kv_dtype": "float16"
}
```

4. summarize
```bash
# --check_accuracy 
python examples/summarize.py --engine_dir /data/trtllm/output/trtllm_engine_fp16/ --batch_size 1 --test_trt_llm --hf_model_dir /mnt/models/source/ --data_type fp16 
```

4. 测试Dataset准备
```bash
benchmarks/cpp/prepare_dataset.py --output=$dataset_file --tokenizer=$model_name token-norm-dist --num-requests=2000 --input-mean=$isl --output-mean=$osl --input-stdev=0 --output-stdev=0
```

5. 运行Benchmark
* 该命令将会运行`gptManagerBenchmark`二进制，会报告出吞吐和其它指标数据：
```bash
mpirun -n $tp_size --allow-run-as-root --oversubscribe cpp/build/benchmarks/gptManagerBenchmark --engine_dir $engine_dir --type IFB --dataset $dataset_file --scheduler_policy max_utilization --kv_cache_free_gpu_mem_fraction 0.9 --output_csv $results_csv --request_rate -1.0 --enable_chunked_context --streaming --warm_up 0
```

### benchmark
> https://github.com/NVIDIA/TensorRT-LLM/tree/main/benchmarks/cpp

#### 编译benchmark工具
* 默认在编译TRTLLM时，不会编译benchmarks工具，需要在编译命令中带上如下参数：
```bash
python3 ./scripts/build_wheel.py --trt_root /usr/local/tensorrt --cuda_architectures "89;89-real" -j 12 \
    --clean  --benchmarks --use_ccache --fast_build 
```



## TRTLLM调优
> https://nvidia.github.io/TensorRT-LLM/performance/perf-best-practices.html


## mpirun

