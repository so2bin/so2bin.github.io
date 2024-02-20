---
layout: pages
title: probe
date: 2024-02-20 09:49:46
tags: [k8s]
---

## Readiness, Liveness, StartupProbe
### 执行原理
* 均支持三种检测探针：TCP, HTTP, Exec Shell
* 探针的执行均由kubelet组件执行；

#### Exec探针执行
* 由kubelet组件调用CRI接口的ExecSync接口，在对应的容器内执对应的cmd命令，获取其返回值；
```go
func (pb *prober) runProbe(p *v1.Probe, pod *v1.Pod, status v1.PodStatus, container v1.Container, containerID kubecontainer.ContainerID) (probe.Result, string, error) {
    ...     
    command := kubecontainer.ExpandContainerCommandOnlyStatic(p.Exec.Command, container.Env)
    return pb.exec.Probe(pb.newExecInContainer(container, containerID, command, timeout))
    ...
}
        
func (pb *prober) newExecInContainer(container v1.Container, containerID kubecontainer.ContainerID, cmd []string, timeout time.Duration) exec.Cmd {
	return execInContainer{func() ([]byte, error) {
		return pb.runner.RunInContainer(containerID, cmd, timeout)
	}}
}
        

func (m *kubeGenericRuntimeManager) RunInContainer(id kubecontainer.ContainerID, cmd []string, timeout time.Duration) ([]byte, error) {
	stdout, stderr, err := m.runtimeService.ExecSync(id.ID, cmd, 0)
	return append(stdout, stderr...), err
}

func (pr execProber) Probe(e exec.Cmd) (probe.Result, string, error) {
	data, err := e.CombinedOutput()
	glog.V(4).Infof("Exec probe response: %q", string(data))
	if err != nil {
		exit, ok := err.(exec.ExitError)
		if ok {
			if exit.ExitStatus() == 0 {
				return probe.Success, string(data), nil
			} else {
				return probe.Failure, string(data), nil
			}
		}
		return probe.Unknown, "", err
	}
	return probe.Success, string(data), nil
}
```

#### HTTP探针执行
* 由kubelet请求容器指定的URL，根据response status来判断，status属于`[200-400)`即判断成功：
```go
func DoHTTPProbe(url *url.URL, headers http.Header, client HTTPGetInterface) (probe.Result, string, error) {
	req, err := http.NewRequest("GET", url.String(), nil)
	......
    if res.StatusCode >= http.StatusOK && res.StatusCode < http.StatusBadRequest {
		glog.V(4).Infof("Probe succeeded for %s, Response: %v", url.String(), *res)
		return probe.Success, body, nil
	}
	......
```

#### TCP探针执行
* 由kubelet执行`Dail`操作判断端口是否可连接：
```go
func DoTCPProbe(addr string, timeout time.Duration) (probe.Result, string, error) {
	conn, err := net.DialTimeout("tcp", addr, timeout)
	if err != nil {
		// Convert errors to failures to handle timeouts.
		return probe.Failure, err.Error(), nil
	}
	err = conn.Close()
	if err != nil {
		glog.Errorf("Unexpected error closing TCP probe socket: %v (%#v)", err, err)
	}
	return probe.Success, "", nil
}
```

### StartupProbe作用
![startupProbe](startupProbe.png)
* 对于一些服务场景，服务启动时间较长，以往的做法是调大`LivenessProbe`的`initialDelaySeconds`和`failureThreshold`值，但如果超过这个时间范围还没启动，服务会进入重启，并进入循环卡死的过程；
* 因此，`StartupProbe`就是用于解决这种场景下的问题，在`StartupProbe`成功之前，是不是为执行`LivenessProbe`和`ReadinessProbe`的；


### LivenessProbe作用
* 可以恢复 运行过程pod出现卡死的情况；
* 如果pod的该探针失败，则k8s会触发该pod的删除与重建流程；

### ReadinessProbe作用
* 影响pod的流量开关；
* 负责判断pod是否就绪，只有就绪状态后，才会将pod IP放到service的endpoints上，并开始接收流量；
* kubelet会通过`SetContainerReadiness`将container的condition设置为true：
```go
func (m *manager) SetContainerReadiness(podUID types.UID, containerID kubecontainer.ContainerID, ready bool) {
	    ......
    	containerStatus.Ready = ready
        ......
    	readyCondition := GeneratePodReadyCondition(&pod.Spec, status.ContainerStatuses, status.Phase)
    	......
    	m.updateStatusInternal(pod, status, false)
}
```

* k8s v1.12之前，pod是否处于ready是由kubelet根据容器状态来判断的，如果pod中容器全部处于ready，则pod处于ready状态；
* k8s v1.12之后，提供了一个`readinessGates`的功能来满足用于对于pod ready状态的控制需求，此时判断pod是否ready有两个前提条件：
    * Pod中所有容器全部ready，即`ContainersReady`为`True`；
    * `pod.spec.readinessGates`中定义一个或多个`conditionType`，需要这些`conditionType`都为`True`，pod才能为ready；
```yaml
apiVersion: v1
kind: Pod
spec:
  readinessGates:
  - conditionType: MyDemo
status:
  conditions:
  - type: MyDemo
    status: "True"
  - type: ContainersReady
    status: "True"
  - type: Ready
    status: "True"
```


