---
layout: pages
title: Go Knowledge
date: 2024-02-29 20:56:05
tags: ["Go"]
---

## Go init
### 资料
* https://cloud.tencent.com/developer/article/2138066

### 说明
* Go的总体初始化过程如下图所示：
<img src="go-init-order.png" width="75%" style="margin: 0 auto;"/>

* 同模块中，优先级：const常量 > var变量 > `init()`
* 同模块中，前后`init()`的优先级，为从上到下顺序执行
* 同包中，不同模块的`init()`优先级：按文件名排序依次执行不同模块的`init()`

* import导入包`init()`顺序：被导入包的`init()`先执行

<!-- more -->
