---
title: Tritonserver 源码阅读
date: 2024-09-13
categories: AI-Infer
tags:
  - tritonserver
  - AI推理
---

## tritonserver
* 推理接口入口:`server/src/http_server.cc` `HTTPAPIServer::HandleInfer`函数https://github.com/triton-inference-server/server/blob/363bcdcd03cddcd00979c7fd3315557328221c6d/src/http_server.cc#L3578;
