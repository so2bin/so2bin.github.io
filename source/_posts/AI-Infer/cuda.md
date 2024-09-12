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


### share-memory
* 功能：提升性能、实现inter-thread数据通信；
* SMEM bank confilict ??


## 05 atomic, reductions, warp shuffle


## managed/unified memory
* 一种GPU/CPU内存直接关联，并按需分布、数据自动同步的能力，通过类似page fault的技术实现：
![managerd memory](./managed-memory.png)

* GPU memory oversubscription, pages are be migrated to GPU on demand:
```c++
void foo() {
    // GPU has 16GB memory
    char *data;
    // size_t size = 64ULL*1024*1024*1024;
    cudaMallocManaged(&data, size);
}
```
* 支持系统级原子操作，支持CPU/GPU/多GPU;
* 统一内存并不是为了性能优化，主要是为了简化程序开发，甚至该技术的引入因大量的page-fault需要系统介入反而会引入性能下降；
* explicit prefetching: `cudaMemPrefetchAsync(ptr, len, dstDevice, stream)`，可以将其类比于`cudaMemcpy(Async)`，该能力的引入就可以批量移动数据，避免大量page-fault；  

* UM相关资料：![UM learn](./um-learn.png)





