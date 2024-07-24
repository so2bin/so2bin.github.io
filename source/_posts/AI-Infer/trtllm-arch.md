---
layout: pages
title: TRTLLM架构
date: 2024-03-03 11:02:05
tags: [GPU, Tritonserver, TRT-LLM]
---
## 资料
* https://nvidia.github.io/TensorRT-LLM/architecture/overview.html

## 架构
### 介绍
* 本质上是python包了C++，C++基于TensorRT引擎实现了GPT等模型结构；
* 除模型本身的搭建外，TRTLLM还提供了C++ GPTRuntime，该模块提供了高效的GPT类模型的TRT运行时，如包含了beam-search, top-k采样, kvcache, page-attention等；
* 还提供了一个tritonserver backend用于LLM在线推理；

### 模型Definition
* TRTLLM通过pyding11暴露的[TensorRT Python级API](https://docs.nvidia.com/deeplearning/tensorrt/api/python_api/coreConcepts.html)来搭建模型；
* `tensorrt_llm.Builder`类包含了`tensorrt.Builder`对象，通过`tensorrt_llm.Builder.create_network`函数创建一个`tensorrt.INetworkDefinition`模型对象；
* 在TRTLLM中，可以基于`tensorrt_llm.functional`模块提供的基础算子库来构建模型网络结构，如下demo所示：
```python
# In tensorrt_llm.functional:
def activation(input: Tensor, act_type: trt.ActivationType) -> Tensor:
    layer = default_trtnet().add_activation(input.trt_tensor, act_type)   # default_trtnet() -> INetworkDefinition
    return _create_tensor(layer.get_output(0), layer)

relu    = partial(activation, act_type=trt.ActivationType.RELU)
sigmoid = partial(activation, act_type=trt.ActivationType.SIGMOID)
```

#### Adding a Model
* TRT-LLM提供了多种基础算子/层可用于搭建模型：
1. low-level functions, like: `concat`, `add`, `sum`
2. Basic layers, such as: `Linear`, `LayerNorm`
3. High-level layers, such as: `MLP`, `Attentions`


### 模型Compilation
* 一旦模型结构`tensorrt.INetworkDefinition`定义完成，即可通过`tensorrt.Builder.build_engine`来将模型转换成TRT格式；
* Tensorrt编译器会遍历整个模型结构，提供了算子融合（通过模式匹配`pattern-matching`自动识别），图融合的能力(compiles the graph of operations into a single [CUDA Graph](https://developer.nvidia.com/blog/cuda-graphs/) that can be launched all at one time)，以提升性能；
* 对于复杂的算子，如FlashAttention，无法通过TRT自动完成优化，这里就需要复用`plugins`能力；
* 光有TRT Engine文件还不够，因为LLM的推理不只是简单的forward pass，因此TRTLLM还提供了一个高度优化的C++ Runtime来专用于TRT LLM的推理过程，用以管理如KVCache等能力；

### Plugins
* 算子融合能做的是有限的，很多功能/算子无法自动识别，仅用算子融合能达到的优化很有限，如`Flash-Atteention`优化MH，因此TRT提供了`plugin`机制用于用户定制功能；
* plugins是一些用户定义的插入到模型图中的nodes，TRT-LLM中的plugins可以在`cpp/tensorrt_llm/plugins`目录中找到；
* TRT plugin的编程规范：https://docs.nvidia.com/deeplearning/tensorrt/developer-guide/index.html#extending

### Runtime
* TRT-LLM提供了Python, C++版本的运行时；
* 对于GPT类的LLM，TRT-LLM Runtime负载模型的加载，input sequence的处理，generation loop的逻辑；

### Multi-GPU与Multi-Node 
* TensorRT是为单GPU设计，但TRT-LLM通过plugins封装了NCCL库的通信primitives，以及通过plugins优化了多GPU All-Reduce primitive，因此TRT-LLM具备了多GPU推理的能力（`TP`, `PP`）；
* 这个通信插件源码位于：`cpp/tensorrt_llm/plugins/ncclPlugin`；
* 在Python API中暴露如下：
```py
# In tensorrt_llm/functional.py:

# Collectives.
def allreduce(tensor: Tensor, group: List[int]) -> Tensor
def allgather(tensor: Tensor, group: List[int], gather_dim: int = 0) -> Tensor

# Point-to-point communication primitives.
def send(tensor: Tensor, tgt: int) -> Tensor
def recv(tensor: Tensor, src: int) -> Tensor
```
* `TP`负载较均衡，但有较大的通信带宽压力；
* `PP`能减少通信带宽需求，但会导致和GPU负载不均衡的问题；

### TensorRT-LLM Checkpoint
* 随着TRT-LLM的版本/功能变得越稳定，现在TRT-LLM开发团队开始提出unifying the API and workflow of TensorRT-LLM；
* 三段workflow:
```text
NeMo -------------
                  |
HuggingFace ------
                  |   convert                             build                    load
Modelopt ---------  ----------> TensorRT-LLM Checkpoint --------> TensorRT Engine ------> TensorRT-LLM ModelRunner
                  |
JAX --------------
                  |
DeepSpeed --------
```
* TRT-LLM checkpoint的格式如下：
1. `config.json`文件：包含模型超参；
2. 1个或多个rank权重文件，每个文件都是一个权重tensor map，不同的文件根据ranks会被加载到不同的GPU上；

* 权重文件的tensor命名类似pytorch的格式，如`transformer.layers.0.input_layernorm.weight`, kvcache优化参数：`transformer.layers.0.attention.kv_cache_scaling_factor`等；

### TensorRT-LLM Build Workflow
* 两步编译：
1. 通过训练框架导出的模型checkpoints定义出TRT-LLM模型；
2. 编译TRT-LLM模型为TRT-LLM engine；

* 为了泛化/统一TRT-LLM模型优化的过程，TRT-LLM提出一些模型定义的标准或引入格式；
* 当前的TRT-LLM checkpoint格式定义，适用于所有的decoder-only架构的模式；
* `trtllm-build`命令工具已经标准化，但当前的`convert_checkpoint.py`脚本仍然还是以源码的形式提供在`examples`目录中，这样做的原因是：
1. 当前的TRT-LLM模型演进速度很快，所以模型调度相关的`convert_checkpoint.py`脚本很容易过时；
2. TRT-LLM当前正在推理一套新的high-level API来实现模型转换、engine编译、推理过程，因这些高级API需要调用weight convert代码，因此未来`convert_checkpoint.py`将会提取出一套全新的高级通用API来为这些功能服务；
* 这些高级模型API可以参考`0.9`版本下的`tensorrt_llm/models/llama`，其演示了一系列新的模型importing, converting weights API；

#### Conversion APIs
* 为了将模型特定的转换过程附带到模型自己的模块上，TRT-LLM提出了一个通用的模型转换接口类，其它模型都会间接继承该类：
* 该接口会返回转换后的checkpoint内存对象，需要再根据需要进行持久化到磁盘；
* 未来该类还会继续扩展对`jax`, `nemo`, `keras`格式的支持；
```py
class TopModelMixin:
    @classmethod
    def from_hugging_face(cls,
                          hf_model_dir: str,
                          dtype: Optional[str] = 'float16',
                          mapping: Optional[Mapping] = None,
                          **kwargs):
        '''
        Create LLM object and load weights from hugging face
        Parameters:
            hf_model_dir: the hugging face model directory
            dtype: str, the default weights data type when loading from the hugging face model
            mapping: Mapping, specify the multi-gpu parallel strategy, when it's None, single GPU is used
        '''
        raise NotImplementedError("Subclass shall override this")
```

#### Quantization APIs
* TRT-LLM的量化能力依赖于NVIDIA的Modelopt工具，如：`FP8`, `W4A16_AWQ`, `W4A8_AWQ`，同时TRT-LLM自己也提供了部分量化实现，如`Smooth Quant`, `INT8 KV cache`, `INT4/INT8` weight only；
* 在TRT-LLM 0.8版本中，对于`Modelopt`支持的量化算法，example目录下的模型都有一个标准化的`quantize.py`脚本提供TRT-LLM量化模型的导出，而对于`Modelopt`不支持的量化算法，用户需要使用模型特定的`convert_checkpoint.py`脚本来导致TRT-LLM checkpoint；
* 当前TRT-LLM提供了统一的模型量化接口，所有的模型结构均会继承该类：
* 默认的`quantize()`接口实现仅提供了`Modelopt`支持的量化算法；
```py
class PretrainedModel:
    @classmethod
    def quantize(
        cls,
        hf_model_dir,
        output_dir,
        quant_config: QuantConfig,
        mapping: Optional[Mapping] = None): #some args are omitted here
        # Internally quantize the given hugging face models using Modelopt
        # and save the checkpoint to output_dir
```


#### Build APIs
* `tensorrt_llm.build` API实现TRT-LLM模型的TRT编译，流程为：creating a builder, creating a network object, tracing the model to the network, buildind TRT engines；
* 这个其实就是编译TRT的过程；
```py
llama = ... # create LLaMAForCausalLM object
build_config = BuildConfig(max_batch_size=1)
engine = tensorrt_llm.build(llama, build_config)
engine.save(engine_dir)
```
* TRT-LLM也提供了一个通用的从磁盘读checkpoint文件的接口，后结合`tensorrt_llm.build`接口即可完成编译过程：
```py
## TensorRT-LLM code
class PretrainedModel:
    @classmethod
    def from_checkpoint(cls,
                    ckpt_dir: str,
                    rank: int = 0,
                    config: PretrainedConfig = None):
        # Internally load the model weights from a given checkpoint directory
```

## Advanced
### MH, MQA, GQA
> https://nvidia.github.io/TensorRT-LLM/advanced/gpt-attention.html#multi-head-multi-query-and-group-query-attention
> https://arxiv.org/abs/1706.03762
> https://arxiv.org/abs/1911.02150
> https://arxiv.org/abs/2307.09288

* 这些结构的实现位于`tensorrt_llm.functional.gpt_attention`模块

> 当前的实现中，支持两种输入模式：**padded**, **packed**(non-padded)，由于**packed**模式有更高效的内存使用，并且往往计算速度更快，所以未来**padded**模式可能不再支持；

#### padded vs packed
* TRTLLM中，GPT注意力的QKV输入支持两种输入模式：`padded`, `packed`，这个模式由全局参数`remove_input_padding`决定；
* `remove_input_padding=false` 此时，输入长度短于`max_sequence_lenght`的序列将会被padding到最大长度，这会导致内存的浪费以及无效的计算过程；
* `remove_input_padding=true`  此时，不同长度的输入序列不需要进行padding，TRT-LLM会将这些输入序列packed在一起，但用户端需要提供一个1D tensor来记录不同序列的数据长度；

#### Context and Gneratoin Phases
##### Context Phase
* `context_fmha_type=disabled`时，GPT MHA的中间计算结果需要存储到内存中，用于后续的`softmax`操作，效率很底；
* `context_fmha_type=enabled`，MHA/MQA会融合成一个单独的kernel：
    * short context: 将使用`vanilla`实现MHA/MQA；
    * larger context: kernel将使用Flash Attention算法实现，参考：[1](https://arxiv.org/abs/2205.14135), [2](https://arxiv.org/abs/2307.08691)；
* 当前的实现还会引入额外的kernel来执行一些操作，如前处理，KVCache的获取等；

##### FP8 Context FMHA
* `use_fp8_context_fmha = enable` 开启Context FHMA FP8量化；
* 支持同时开启`use_fp8_context_fmha`与`use_paged_context_fmha=enable` paged context FMHA；

##### Generation Phase
* generation phase是由一个单独的kernal实现：`masked multi-head attention`：That kernel is able to apply pre-processing on the Q, K, and V elements on-the-fly: adds the QKV bias, applies RoPE, and performs dequantization and quantization. 
* `masked MHA kernel`有一个特殊的版本：在GPU占用率较低时，能够将work分发到多个CUDA thread block上，该特性通过参数`multi_block_mode`开启；（适用于小batch, 小heade的模型场景，这个小的定义是相对于GPU而言，有一个经验公式：`batch_size * num_heads < GPU multi-processors`）


##### in-flight Batching
* 开启该特性后，context phase中的序列可以与generation phase中的一起处理，开启该功能时，input tensor必须使用`packed`模式；
* 当前的实现中，context phase的序列必须位于generation phase序列的前面；

##### Chunked Context
* 在原先的处理中，通常我们会一次性处理完所有的context tokens，而当前特性是先将context token拆分成多份(chunks)，这样context tokens就可以与generation tokens组batch，提升整个系统的吞吐；
* 开始该能力后，对于input sequence长度的限制也就不存在，TRT-LLM支持更长的上下文；
* 要开启该能力，同时需要开启`use_paged_context_fmha`特性；
* context chunk的size需要是kv-cache block size的整数倍；

#### KV Cache
* 在generation phase中，一个通用的优化是在MHA kernel中cache过去计算过的K,V值，即KVCache；
* TRT-LLM中每一层transformer layer都有一个KV Cache，当前有两种KVCache实现：`contiguous`, `paged`；

##### Contiguous KVCache
* Contiguous KVCache就是一个大Tensor，shape: `[max_batch_size * max_beam_width, 2, num_heads, max_seqlen, hidden_dim_per_head]`
* 对于那些请求序列短于`max_seqlen`的请求来说，这种cache实现明显有大量的显存浪费；

##### Paged KVCache
* 将KVCache分块保存，多个请求共享；
* 实现于`tensorrt_llm.runtime.KVCacheManager`，manager会追踪序列，按需完成block的分配与回收；

##### INT8/FP8 KVCache
* TRT-LLM支持INT8, FP8 KVCache量化：`kv_cache_quant_mode=QuantMode.INT8_KV_CACHE`, `kv_cache_quant_mode=QuantMode.FP8_KV_CACHE`；
* 当开启了INT8/FP8 KVCache量化，input必须量化成8bit，scaling factor存放于`kv_cache_scaling_factor` 1D tensor，目前仅支持per-tensor级的量化；
* 在generation阶段，这些量化的cache值会被MHA/MQA在线DQ；

##### Sliding Window Attention, Cyclic KVCache
* TRT-LLM同时支持一种`Cyclic KVCache`的特性，该特性下，KVCache会被当作一个环形buffer，该buffer中仅保存近N个token，N由参数：`max_attention_window_size`决定，缓存丢弃采用LRU策略；
* 在Context阶段，如何输入序列长度超出了`max_attention_window_size`，则`Sliding Window Attention`机制会激活，该模式下的效果与`sliding_window_size`一样；
* 该特性会减少在处理超长序列时的KVCache内存使用；


##### StreamingLLM
* 通过`streamingllm`参数控制开启；
* 该功能使用window attention来为长上下文提供稳定高效的推理，该模式下，仅`max_attention_window_size`个token会被缓存到KVCache中， 且前`sink_token_length`个token一定会被缓存；

#### Input QKV tensor
* input QKV tensor是在完成与hidden state projection之后 ，将QKV以最后一维拼接起来的tensor，之后会对该tensor执行INT8/FP8量化；
* 在`padded`模式下，该tensor的shape为：`[batch_beam_sizem, max_seqlen, 3*hidden_dim]`，这里的`batch_beam_sizem`：
    * 在context phase: `batch_beam_sizem=batch size(sequence number)`
    * 在generation phase: `batch_beam_sizem=batch size * beam_width`
* 在`packed`模式下，该tensor的shape为：`[num_tokens, 3*hidden_dim]`，这里的`num_tokens`就是总token数；（因为这里没有pading过程，所以就是总token数）
    * context phase: `num_tokens`即所有序列的总请求长度
    * generation phase: `num_tokens`即各序列长度*`beam_width`之和

`packed`模式下`num_tokens`计算的伪代码如下：
```py
num_tokens = 0

# Add the length of each sequence in context phase.
for seq in context_phase:
    num_tokens += seq.length

# Add the width of the beam for each sequence in generation phase.
# 这里是因为每次只生成一个token，一个token有beam_width个输出 
for seq in generation_phase:
    num_tokens += seq.beam_width
```

## TRTLLM GPTRuntime
> https://github.com/NVIDIA/TensorRT-LLM/blob/v0.8.0/docs/source/gpt_runtime.md
> https://github.com/NVIDIA/TensorRT-LLM/blob/v0.11.0/docs/source/advanced/gpt-runtime.md

* declared in `cpp/include/tensorrt_llm/runtime`
* implemented in `cpp/tensorrt_llm/runtime`
* 目前支持如GPT，BLOOM，LLAMA等自回归模型，未来会增加对encoder-decoder如T5的支持；


## 内存架构
* TRT-LLM模型推理阶段，内存主要由三部分组成：`weights tensors`, `internal activation tensors`, `I/O tensors`；
* 对于 `I/O tensors`主要的内存占用来自KVCache；

### Weights Size
* Weights size是由模型的大小，权重精度，并行策略决定的，在build阶段已经可以确定；
* 并行策略，如TP=8，则每个rank只保存了1/8的权重；

### Activation Size
* 在TRT build阶段，TRT会pre-computes需要的activation tensor内存大小，进行提前分配，以避免运行时OOM，减少shape切换时的耗时；
* 一个profile的内存使用是由其max-tensor-shape决定的；
* 除此之外，还有一些内部的activation size，如模型结构，算子融合，算子调度等；
* 在TRT engine编译完成后，Activation Size就被确定下来，可通过日志或`trt.ICudaEngine.device_memory_size`获取；
* 对于一个指定了精度与并行策略的模型，Activation Size还可以通过`max_batch_size`, `max_num_tokens`, `max_input_length`, `max_beam_width`, `padding removal`, `context FMHA`来进行调整；
* `context FMHA`可以显著减少GPT Attention plugin的显存占用（未开启时，显存占用是序列长度的二次方关系）；
* TP并行：每个rank只拥有一部分权重，因此计算时只计算一部分tensor，对应的activation尺寸也是一部分；
* PP并行：每个rank拥有docoder一部分层，每个层都需要完整的tensor，因此其activation尺寸与运行整个模型是一样的；（所以TP在内存效率上会更高，但需要更高的带宽）


### I/O tensors
#### 非KVCache显存
* 在进行KVCache分配前，TRT-LLM C++ Runtime会提前分配一用于存储I/O tensor、decoupled dynamic decoder的内存，这些与`max_batch_size` and `max_seq_len`有关；（其实就是输入输出的显存buffer）


#### KVCache显存
##### not paged kvcache
* 不开启 paged kvcache时，C++ Runtime为每个layer都分配一个固定的cache，shape为：`[batch size, 2, heads,  max seq length, hidden dimension per head]`

##### paged kvcache
* 开启paged kvcache时，TRT-LLM runtime会在初始化时，pre-allocates kvcache with configured number of blocks，并在运行时使用；
* `Executor`对象创建时，由`KVCacheConfig`参数控制KVCache的分配，其中有两个可选参数：`maxTokens`, `freeGpuMemoryFraction`，默认分配90%的剩余GPU显存；
* 在IFB调度时，会自动调度足够多的请求，在保证KVCache有足够空间的前提下；

## modelopt (原ammo)
> * `modelopt`是由`nvidia-ammo`改名过来的；
> * https://github.com/NVIDIA/TensorRT-Model-Optimizer

### LLM PTQ
> https://github.com/NVIDIA/TensorRT-Model-Optimizer/blob/main/llm_ptq/README.md

* modelopt PTQ量化API：
```py
import modelopt.torch.quantization as mtq

model = AutoModelForCausalLM.from_pretrained("...")

# Select the quantization config, for example, INT8 Smooth Quant
config = mtq.INT8_SMOOTHQUANT_CFG


# Prepare the calibration set and define a forward loop
def forward_loop(model):
    for data in calib_set:
        model(data)


# PTQ with in-place replacement to quantized modules
model = mtq.quantize(model, config, forward_loop)
```

* 导出量化后的模型
```py
from modelopt.torch.export import export_tensorrt_llm_checkpoint

with torch.inference_mode():
    export_tensorrt_llm_checkpoint(
        model,  # The quantized model.
        decoder_type,  # The type of the model, e.g gptj, llama or gptnext.
        dtype,  # The exported weights data type.
        export_dir,  # The directory where the exported files will be stored.
        inference_tensor_parallel,  # The number of GPUs used in the inference time tensor parallel.
        inference_pipeline_parallel,  # The number of GPUs used in the inference time pipeline parallel.
        use_nfs_workspace,  # If exporting in a multi-node setup, please specify a shared directory like NFS for cross-node communication.
    )
```

## FP8
### qformat=fp8
* PTQ量化：利用的是modelopt工具完成量化（参考上面`LLM PTQ`一节）
```bash
python TensorRT-LLM/examples/quantization/quantize.py --model_dir /mnt/models/source/  --output_dir /data/trtllm/output/trtllm-chpt-fp8  --dtype bfloat16  --qformat fp8  --calib_size 256
```
* build
```bash
trtllm-build --checkpoint_dir /data/trtllm/output/trtllm-chpt-fp8/ --output_dir  /data/trtllm/output/trtllm_engine_fp8 --gemm_plugin bfloat16 --use_custom_all_reduce disable  --max_batch_size 16
```
* benchmark
```bash
TensorRT-LLM/cpp/build/benchmarks/gptManagerBenchmark --engine_dir /data/trtllm/output/trtllm_engine_fp8/ IFB --dataset ./output/torken-norm-dist.json  --streaming --warm_up 1
```

### kvcache=fp8
* PTQ量化：
```bash
python TensorRT-LLM/examples/quantization/quantize.py --model_dir /mnt/models/source/  --output_dir /data/trtllm/output/trtllm-chpt-fp8  --dtype float16  --qformat fp8  --kv_cache_dtype fp8
```
* build
```bash
trtllm-build --checkpoint_dir /data/trtllm/output/trtllm-chpt-fp8/ --output_dir  /data/trtllm/output/trtllm_engine_fp8 --gemm_plugin float16 --use_custom_all_reduce disable  --max_batch_size 16
```
* benchmark
```bash
TensorRT-LLM/cpp/build/benchmarks/gptManagerBenchmark --engine_dir /data/trtllm/output/trtllm_engine_fp8/ IFB --dataset ./output/torken-norm-dist.json  --streaming --warm_up 1
```

