---
title: dragonfly
date: 2024-01-13 14:39:59
tags:
---
## 资料
* [Toward Next Generation Container Image](https://drive.google.com/file/d/1LRfLUkNxShxxWU7SKjc_50U0N9ZnGIdV/view?pli=1)

> 这项目名字取的好，按阿里武侠的风格，应该翻译为技能：飞龙在天

## 价值
* 提供集群内的P2P文件分发能力，可以用于加速文件分发和镜像分发，源支持OSS, S3等云存储类型，也支持OCI镜像仓库；
* 组件间通信协议为GRPC；
* 可以与nydus结合，作为containerd与nydus的中间层，为集群提供nydus镜像格式的文件加速分发和加速镜像启动，如下图所示：

![(df-nydus-arch](df-nydus-arch.png)

## 架构
* 如下图所示，为其架构图：
![df arch](df-arch.png)
* dragonfly包含的核心三部分：Manager, Schduler, Seed Peer以及Peer组成的P2P下载网络，Dfdaemon可以作为Seed Peer和Peer；
* Manager：维护P2P集群的关联关系，动态配置，用户态以及权限管理；
* Scheduler：为下载节点选择最优下载父节点，异常情况控制Dfaaemon回源；
* Seed Peer：Dfdaemon开启Seed Peer模式可以作为P2P集群中回源节点，即整个下载的根节点，与后端存储/镜像仓库交互；
* Peer：通过Dfdaemon部署，基于C/S架构，提供dfget命令行下载工具和dfget daemon运行守护进程，提供任务下载能力；
![df-flow](df-flow.png)

## 加速对象存储
* https://d7y.io/zh/docs/concepts/terminology/dfstore


## Dfdaemon
代码入口：
1. `Makefile` docker-build-dfdaemon
2. `build/images/dfdaemon/Dockerfile`
3. 
```Dockerfile
RUN make build-dfget && make install-dfget

RUN if [ "$(uname -m)" = "ppc64le" ]; then \
    wget -qO/bin/grpc_health_probe https://github.com/grpc-ecosystem/grpc-health-probe/releases/download/${GRPC_HEALTH_PROBE_VERSION}/grpc_health_probe-linux-ppc64le; \
    elif [ "$(uname -m)" = "aarch64" ]; then \
    wget -qO/bin/grpc_health_probe https://github.com/grpc-ecosystem/grpc-health-probe/releases/download/${GRPC_HEALTH_PROBE_VERSION}/grpc_health_probe-linux-arm64; \
    else \
    wget -qO/bin/grpc_health_probe https://github.com/grpc-ecosystem/grpc-health-probe/releases/download/${GRPC_HEALTH_PROBE_VERSION}/grpc_health_probe-linux-amd64; \
    fi && \
    chmod +x /bin/grpc_health_probe
COPY --from=builder /opt/dragonfly/bin/dfget /opt/dragonfly/bin/dfget
COPY --from=health /bin/grpc_health_probe /bin/grpc_health_probe

EXPOSE 65001
ENTRYPOINT ["/opt/dragonfly/bin/dfget", "daemon"]
```
4. `cmd/dfget/cmd/daemon.go`
5. `client/daemon/daemon.go`的`cd.ProxyManager.IsEnabled()`
