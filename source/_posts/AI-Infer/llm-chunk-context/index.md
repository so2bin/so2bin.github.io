---
title: LLM Chunk Context
date: 2024-07-25 14:26:10
tags: [LLM, Chunk Context]
---
## 资料
* [Chunk Context原理解析](https://mp.weixin.qq.com/s?__biz=Mzg2NjcwNjcxNQ==&mid=2247485844&idx=1&sn=ae2c577b0001251fedc015fd06a3cfc0&chksm=ce47fde0f93074f64cff5bf434db47d4a7b930802e68a6ee789920c36d8ce5be426a87701d91&mpshare=1&srcid=0725pEyOGCQaoyt7AagPzZGW&sharer_shareinfo=c24d2c11280a2af52d437727e0374c43&sharer_shareinfo_first=c24d2c11280a2af52d437727e0374c43&from=singlemessage&scene=1&subscene=10000&sessionid=1721888012&clicktime=1721888185&enterid=1721888185&ascene=1&fasttmpl_type=0&fasttmpl_fullversion=7309591-zh_CN-zip&fasttmpl_flag=0&realreporttime=1721888185511&devicetype=android-31&version=28003254&nettype=ctnet&abtest_cookie=AAACAA%3D%3D&lang=zh_CN&exportkey=n_ChQIAhIQFxCOwd0iFEebdNa2u8otuxL2AQIE97dBBAEAAAAAAHNDLdPsWrMAAAAOpnltbLcz9gKNyK89dVj05MLGAgIPF7Tf%2FbQFUe5vrWedB1JBGWODtJrnjdD9Ao3hGvObwNjZGqvL29WnoWic6elKTGm%2BML3Yo2qzjBq6j4jsgH5E7nyOauDsr6KiUWh5%2BMqTP%2Fotrc2BtRxjhriuM3PMek%2B%2BBn48p3GJcg4DJv58CJpTUrklDj6fewezxepbW6w21CNtCKdkriMVfzfQ9Ftr39uNVaJ552NP6uRtMYjItOWMh2yICtGxYrC%2F%2BkoogrKIR3%2BfPE6FqDNdH8PD2ybBxqQqJfRhTW%2FWf7LFKg%3D%3D&pass_ticket=gFDlqWxJbgaJkT5AIEHB5o6K3JVXNxbue48yx1F7%2FzEfy4FgC3IhhU%2BkeFq4Y%2BdP&wx_header=3)
* 算力与显存的数量分析：https://blog.csdn.net/taoqick/article/details/132009733


### prefill vs decode
1. prefill是长序列并行计算，decode是token by token
2. prefill过程直接计算QKV，不需要读KVCache，decode过程需要读KVCache拼接后再计算
3. 各请求的context长度不同，prefill计算量不同
4. 对于deocde，不同请求的iteration次数不同，计算attention时的mask矩阵也不同；



