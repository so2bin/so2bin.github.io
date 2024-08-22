---
title: CUDA Learn
date: 2024-03-03 11:02:05
tags: [GPU, CUDA]
---
## 01 向量加
* nvcc compiler识别kernel call:
```c++
add<<<N, 1>>>();  // N block parallel， 1 thread each block
```
* 组织：`grid`, `block`, `thread`:
 * `block`代表一组worker，可以完成一块任务；

* `__global__`关键字，会向compiler提示这是一个kernel函数，需要在GPU上运行：
```c++
__global__ void add(int *a, int *b, int *c) {
    c[blockIdx.x] = a[blockIdx.x] + b[blockIdx.x]
}
```

* block的下一级为thread，如下所示为thread parallel：
```c++
addVec<<<1, N>>>();  // 1 block, N thread parallel each block

__global__ void add(int *a, int *b, int *c) {
    c[threadIdx.x] = a[threadIdx.x] + b[threadIdx.x]
}
```

* 支持任意长度:
```c++
__global__ void add(int *a, int *b, int *c, int n) {
    int index = threadIdx.x + blockIdx.x * blockDim.x
    // 一般来说，计算的数据长度不一定刚好就是blockDim.x(块的线程数量)的整数倍，
    // 所以这里的index可能超时实际的长度，需要加上如下的if判断
    if (index < n) {  // thread check
        c[index] = a[index] + b[index]
    }
}
``` 
此时在调用该kernel时，需要对分配的block向上取整数，以让其有足够多的block, thread来完成计算：
```c++
add<<<(N+M-1) / M, M>>>(d_a, d_b, d_c, N);
```