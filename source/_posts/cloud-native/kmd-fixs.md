---
layout: pages
title: karmada
date: 2024-05-17 09:52:01
tags: ["karmada"]
---
## CPP bug记录

* 正常日志：
```log
I0515 06:37:48.068444       1 detector.go:234] Reconciling object: v1, kind=ConfigMap, ai-ppt-beautify-test/atms-app-conf-outline-triton-test
I0515 06:37:48.068632       1 detector.go:494] Applying cluster policy(atms-app-cm-cpp) for object: v1, kind=ConfigMap, ai-ppt-beautify-test/atms-app-conf-outline-triton-test
I0515 06:37:48.068655       1 default.go:88] Default interpreter is not enabled for kind "/v1, Kind=ConfigMap" with operation "InterpretReplica".
I0515 06:37:48.068669       1 configurable.go:84] Get replicas for object: /v1, Kind=ConfigMap ai-ppt-beautify-test/atms-app-conf-outline-triton-test with configurable interpreter.
I0515 06:37:48.068675       1 customized.go:93] Get replicas for object: /v1, Kind=ConfigMap ai-ppt-beautify-test/atms-app-conf-outline-triton-test with webhook interpreter.


I0515 06:37:48.083504       1 detector.go:234] Reconciling object: v1, kind=ConfigMap, ai-ppt-beautify-test/atms-node-conf-outline-triton-test-v1
I0515 06:37:48.083999       1 detector.go:494] Applying cluster policy(team-1017-app-0-cluster-weight-policy-default-day-time) for object: v1, kind=ConfigMap, ai-ppt-beautify-test/atms-node-conf-outline-triton-test-v1
I0515 06:37:48.084065       1 default.go:88] Default interpreter is not enabled for kind "/v1, Kind=ConfigMap" with operation "InterpretReplica".
I0515 06:37:48.084082       1 configurable.go:84] Get replicas for object: /v1, Kind=ConfigMap ai-ppt-beautify-test/atms-node-conf-outline-triton-test-v1 with configurable interpreter.
I0515 06:37:48.084088       1 customized.go:93] Get replicas for object: /v1, Kind=ConfigMap ai-ppt-beautify-test/atms-node-conf-outline-triton-test-v1 with webhook interpreter.

I0515 06:37:48.090382       1 detector.go:574] Update ResourceBinding(atms-app-conf-outline-triton-test-configmap) successfully.
I0515 06:37:48.090455       1 recorder.go:104] "events: Apply cluster policy(atms-app-cm-cpp) succeed" type="Normal" object={Kind:ConfigMap Namespace:ai-ppt-beautify-test Name:atms-app-conf-outline-triton-test UID:ecebbc4b-b7a2-4f72-95f4-027db06c5fe8 APIVersion:v1 ResourceVersion:4880369 FieldPath:} reason="ApplyPolicySucceed"
```

* 异常日志：
```log
I0515 06:45:38.512342       1 detector.go:234] Reconciling object: v1, kind=ConfigMap, ai-ppt-beautify/atms-app-conf-image-retrieval
I0515 06:45:38.512519       1 detector.go:494] Applying cluster policy(atms-app-cm-cpp) for object: v1, kind=ConfigMap, ai-ppt-beautify/atms-app-conf-image-retrieval
I0515 06:45:38.512544       1 default.go:88] Default interpreter is not enabled for kind "/v1, Kind=ConfigMap" with operation "InterpretReplica".
I0515 06:45:38.512558       1 configurable.go:84] Get replicas for object: /v1, Kind=ConfigMap ai-ppt-beautify/atms-app-conf-image-retrieval with configurable interpreter.
I0515 06:45:38.512564       1 customized.go:93] Get replicas for object: /v1, Kind=ConfigMap ai-ppt-beautify/atms-app-conf-image-retrieval with webhook interpreter.


I0515 06:45:38.527802       1 detector.go:234] Reconciling object: v1, kind=ConfigMap, ai-ppt-beautify/atms-node-conf-image-retrieval-v1
I0515 06:45:38.527831       1 policy.go:144] ClusterPropagationPolicy(team-1017-app-0-cluster-weight-policy-default-night-time) has been removed.

I0515 06:45:38.531970       1 detector.go:574] Update ResourceBinding(atms-app-conf-image-retrieval-configmap) successfully.
I0515 06:45:38.532029       1 recorder.go:104] "events: Apply cluster policy(atms-app-cm-cpp) succeed" type="Normal" object={Kind:ConfigMap Namespace:ai-ppt-beautify Name:atms-app-conf-image-retrieval UID:cc870302-33f7-4857-b8c5-523f34d00e14 APIVersion:v1 ResourceVersion:4881407 FieldPath:} reason="ApplyPolicySucceed"


I0515 06:45:38.533158       1 binding_controller.go:71] Reconciling ResourceBinding ai-ppt-beautify/atms-app-conf-image-retrieval-configmap.
I0515 06:45:38.533199       1 rb_status_controller.go:61] Reconciling ResourceBinding ai-ppt-beautify/atms-app-conf-image-retrieval-configmap.
I0515 06:45:38.533673       1 workstatus.go:83] New aggregatedStatuses are equal with old resourceBinding(ai-ppt-beautify/atms-app-conf-image-retrieval-configmap) AggregatedStatus, no update required.
I0515 06:45:38.533698       1 default.go:88] Default interpreter is not enabled for kind "/v1, Kind=ConfigMap" with operation "AggregateStatus".
I0515 06:45:38.533713       1 customized.go:85] Hook interpreter is not enabled for kind "/v1, Kind=ConfigMap" with operation "AggregateStatus".
I0515 06:45:38.533741       1 recorder.go:104] "events: Update resourceBinding(ai-ppt-beautify/atms-app-conf-image-retrieval-configmap) with AggregatedStatus successfully." type="Normal" object={Kind:ResourceBinding Namespace:ai-ppt-beautify Name:atms-app-conf-image-retrieval-configmap UID:e44e8c27-4c2e-463c-8554-2cda677ea023 APIVersion:work.karmada.io/v1alpha2 ResourceVersion:4881411 FieldPath:} reason="AggregateStatusSucceed"
I0515 06:45:38.533752       1 recorder.go:104] "events: Update resourceBinding(ai-ppt-beautify/atms-app-conf-image-retrieval-configmap) with AggregatedStatus successfully." type="Normal" object={Kind:ConfigMap Namespace:ai-ppt-beautify Name:atms-app-conf-image-retrieval UID:cc870302-33f7-4857-b8c5-523f34d00e14 APIVersion:v1 ResourceVersion:4881407 FieldPath:} reason="AggregateStatusSucceed"
I0515 06:45:38.534736       1 overridemanager.go:151] Applied cluster overrides(atms-app-cm-covr) for resource(ai-ppt-beautify/atms-app-conf-image-retrieval)
I0515 06:45:38.534857       1 recorder.go:104] "events: Apply cluster override policy(atms-app-cm-covr) for cluster(ali-bj-f-01-88) succeed." type="Normal" object={Kind:ConfigMap Namespace:ai-ppt-beautify Name:atms-app-conf-image-retrieval UID:cc870302-33f7-4857-b8c5-523f34d00e14 APIVersion:v1 ResourceVersion:4881407 FieldPath:} reason="ApplyOverridePolicySucceed"
```
* 资源的label显示用的是`night-time`策略：
![res use night cpp](use-night-cpp.png)
* 但策略已经切换过来了：
![cpp list](current-cpps.png)


## CPP处理流程
### 删除
1. `ReconcileClusterPropagationPolicy`
2. `HandleClusterPropagationPolicyDeletion`
  - `rbs = GetResourceBindings()`
  - `for binding in rbs`
    - `CleanupLabels`：删除`binding.Spec.Resource`上的cpp label；
```go
func (d *ResourceDetector) CleanupLabels(objRef workv1alpha2.ObjectReference, labelKeys ...string) error {
	workload, err := helper.FetchResourceTemplate(d.DynamicClient, d.InformerManager, d.RESTMapper, objRef)
	...

	workload = workload.DeepCopy()
	util.RemoveLabels(workload, labelKeys...)
	...
	newWorkload, err := d.DynamicClient.Resource(gvr).Namespace(workload.GetNamespace()).Update(context.TODO(), workload, metav1.UpdateOptions{})
	if err != nil {
		klog.Errorf("Failed to update resource %v/%v, err is %v ", workload.GetNamespace(), workload.GetName(), err)
		return err
	}
	klog.V(2).Infof("Updated resource template(kind=%s, %s/%s) successfully", newWorkload.GetKind(), newWorkload.GetNamespace(), newWorkload.GetName())
	return nil
}
```
    - `CleanupResourceBindingLabels`：删除rb上的cpp label；
```go
func (d *ResourceDetector) CleanupResourceBindingLabels(rb *workv1alpha2.ResourceBinding, labels ...string) error {
	bindingLabels := rb.GetLabels()
	for _, l := range labels {
		delete(bindingLabels, l)
	}

	return retry.RetryOnConflict(retry.DefaultRetry, func() (err error) {
		rb.SetLabels(bindingLabels)
		updateErr := d.Client.Update(context.TODO(), rb)
		if updateErr == nil {
			return nil
		}
		... // retry
		return updateErr
	})
}
```
3. 在对资源对象的label进行清理后，自动会进一步触发出resource的事件，此时resource如果后续未匹配到CPP，则会被加入到`waitingObjects`等待队列中，等待后续CPP触发匹配；

### 新增/更新
1. `ReconcileClusterPropagationPolicy`
2. `HandleClusterPropagationPolicyCreationOrUpdate`
  - `cleanCPPUnmatchedResourceBindings`: CPP变更/新增，筛选出当前label已经匹配CPP的rb资源，判断如`rb.Spec.Resource`资源不再匹配当前的CPP筛选条件，则同时remove掉rb与resource上的CPP label标识；
    - `removeResourceBindingsLabels`
```go
func (d *ResourceDetector) removeResourceBindingsLabels(bindings *workv1alpha2.ResourceBindingList, selectors []policyv1alpha1.ResourceSelector, removeLabels []string) error {
	var errs []error
	for _, binding := range bindings.Items {
		// 移除resource上的label
		removed, err := d.removeResourceLabelsIfNotMatch(binding.Spec.Resource, selectors, removeLabels...)
		if err != nil {
			...
			continue
		}
		if !removed {
			continue
		}
		// 移除rb上的label
		bindingCopy := binding.DeepCopy()
		for _, l := range removeLabels {
			delete(bindingCopy.Labels, l)
		}
		err = d.Client.Update(context.TODO(), bindingCopy)
		...
	}
	...
	return nil
}
```
3. `resourceBindings, err := d.listCPPDerivedRB(policy.Name)`
4. 添加rb到resource队列中等待`resource detecotr` reconcile:
```go
    for _, rb := range resourceBindings.Items {
		resourceKey, err := helper.ConstructClusterWideKey(rb.Spec.Resource)
		if err != nil {
			return err
		}
		d.Processor.Add(resourceKey)
	} 
```
5. 在处理完通过`policy.Name`匹配到的绑定资源逻辑后，还需要处理`waitingObjects`等待队列中的资源对象，以传播之前未匹配到CPP/PP的资源：
> 这里也就处理到了新增CPP时，能触发之前未匹配到CPP的旧应用的传播
```go
	// 从队列中查找匹配CPP/PP的资源key
	matchedKeys := d.GetMatching(policy.Spec.ResourceSelectors)
	klog.Infof("Matched %d resources by policy(%s)", len(matchedKeys), policy.Name)
	...
	// 重新加入resource事件队列中
	for _, key := range matchedKeys {
		d.RemoveWaiting(key)
		d.Processor.Add(key)
	}
```

### 总结
* 从上面的CPP事件处理过程可知，CPP的更新/创建事件处理中不会作rb相关的同步操作，仅会将不再匹配CPP的resource/rb的label移除掉；
* CPP的更新/创建事件，最终是将事件传递出CPP关联的resource事件队列中，所以同步的操作是在resouce reconcile；


## resource处理流程
### 新建CPP触发的正常resource流程
* 入口函数：`ResourceDetector.Reconcile`
1. `propagateResource`，该函数有多个分支：
    - 资源label绑定了PP name
    - 资源label绑定了CPP name
    - 搜索当前ns下的匹配的PP
    - 搜索当前匹配的CPP
	- 如资源未匹配到CPP/PP，则会将对象加入到waitingList队列中

这里我将介绍上述第4个分支。
2. `clusterPolicy, err := d.LookForMatchedClusterPolicy(object, objectKey)`
3. `d.ApplyClusterPolicy(object, objectKey, clusterPolicy)`：给当前resource应用CPP函数，其最核心的代码如下所示，主要是创建/同步rb资源对象：
```go 
func (d *ResourceDetector) ApplyClusterPolicy(object *unstructured.Unstructured, objectKey keys.ClusterWideKey, policy *policyv1alpha1.ClusterPropagationPolicy) (err error) {
 	...
		binding, err := d.BuildResourceBinding(object, objectKey, policyLabels, policyAnnotations, &policy.Spec)
		if err != nil {
			klog.Errorf("Failed to build resourceBinding for object: %s. error: %v", objectKey, err)
			return err
		}
		bindingCopy := binding.DeepCopy()
		err = retry.RetryOnConflict(retry.DefaultRetry, func() (err error) {
			operationResult, err = controllerutil.CreateOrUpdate(context.TODO(), d.Client, bindingCopy, func() error {
				...
				if util.GetLabelValue(bindingCopy.Labels, workv1alpha2.ResourceBindingPermanentIDLabel) == "" {
					bindingCopy.Labels = util.DedupeAndMergeLabels(bindingCopy.Labels,
						map[string]string{workv1alpha2.ResourceBindingPermanentIDLabel: uuid.New().String()})
				}
				...
				bindingCopy.Labels = util.DedupeAndMergeLabels(bindingCopy.Labels, binding.Labels)
				...
				bindingCopy.Spec.ConflictResolution = binding.Spec.ConflictResolution
				return nil
			})
			if err != nil {
				return err
			}
			return nil
		})
	...
}
```
4. 对于未匹配到CPP/CPP的情况，资源key会被加入到waitingList队列中，等待后续CPP/PP重新触发这些资源的事件：
```go
d.AddWaiting(objectKey)
```
相关日志：
```log
I0528 13:57:28.181631       1 detector.go:1101] ClusterPropagationPolicy(team-1005-app-0-cluster-weight-policy-default-day-time) has been removed.
I0528 13:57:28.188587       1 detector.go:234] Reconciling object: v1, kind=ConfigMap, lwd-test2/atms-node-conf-lwd-test-v216-app-0425-v1
I0528 13:57:28.189036       1 detector.go:860] Add object(v1, kind=ConfigMap, lwd-test2/atms-node-conf-lwd-test-v216-app-0425-v1) to waiting list, length of list is: 240
```

 