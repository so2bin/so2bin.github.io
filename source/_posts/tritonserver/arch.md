---
layout: pages
title: Tritonserver架构
date: 2024-05-18 11:23:34
tags: ["tritonserver", "架构"]
---
## 模型调度类型
### Stateless模型
* 常见的如CV领域的模型
* 调度模式：默认的均衡调度，dynamic batch调度

### Stateful模型
* 常见如NLP，语音模型
* 调度模式：
    * Sequence batch
        * Direct：不打batch，顺序不乱
        * Oldest：可以做batch，顺序可能打乱
* `sequence batcher`内部通过`correlation ID`来将语音的序列请求发送到合适的模型实例中

### Ensemble模型
* 模型pipeline
* 每个模型有自己的调度器


## model analyzer
* 模型分析工具，可提供多模型的部署优化报告 
* 通过`throughput`, `latency`, GPU内存等指标来决定如何优化模型配置
* 提供了两种benchmark分析工具：
    1. Performance Analysis: 测量吞吐，延迟指标
    2. Memory Analysis：内存分析

## backend
### custom backend
#### example
* 官方demo：https://github.com/NVIDIA/DeepLearningExamples

## model repositry
### model版本目录
* TRT: model.plan
* ONNX: model.oxx
* TorchScripts: model.pt
* Tensorflow: model.grahpdef or model.savedmodel/
* Python: model.py
* Openvino: model.xml and model.bin
* Custom: model.so


## model configuration
* dynamic input时，设置`max_batch_size`不为0，则在`input`上不能指定batch维度，如下示例：
> `max_batch_size`表示输入的维度最大维度，此时input中可以指定动态维度-1
```config
max_batch_size: 8
input [
    {
        name: "input"
        data_type: TYPE_FP32
        format: FORMAT_NCHW
        dims: [3, 512, 512]
    }
    {
        name: "input_dy"
        data_type: TYPE_FP32
        format: FORMAT_NCHW
        dims: [3, -1, -1]
    }
]
```
* `max_batch_size: 0`，此时batch维度必须写到input/output里面，此时input batch维度不可变，即不能为-1：
```config
max_batch_size: 0
input [
    {
        name: "input"
        data_type: TYPE_FP32
        format: FORMAT_NCHW
        dims: [2, 3, 512, 512]
    }
]
```

* `backend` or `platform` 均能配置`backend`信息，因此在某些模型下，可以仅配置`platform`或`backend`中一个，但为了保险起见，真实使用应该推荐一定要配置`backend`；
* 对于`backend: tensorflow`的情况，必须指定说明`platform: tensorflow_graphdef / tensorflow_savedmodel`；

    * TRT： `backend: tensorrt` or `platform: tensorrt_plan`
    * ONNX: `backend: onnxruntie` or `platform: onnxruntie_onnx`
    * Tensorflow: `backend: tensorflow`可选，`platform: tensorflow_graphdef / tensorflow_savedmodel`必须；
    * Pytorch: `backend: pytorch` or `platform: pytorch_libtorch`；
    * Openvino: `backend: openvino`必须；
    * Python: `backend: python` 必须；
    * Custom: `backend: <backend_name>` 必须；



