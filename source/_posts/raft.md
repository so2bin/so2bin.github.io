---
layout: pages
title: raft
date: 2024-02-19 20:36:37
tags: ["raft"]
---

## 资料
* https://raft.github.io/

## 特点
1. 随机超时：避免同时发起选举请求
<img src="raft-random-timeout.png" width="50%" alt="raft random timeout">

2. 任期Term：用于标记选举任期，可用于让故障回复后的leader变成follower，任期小的选举请求会被拒绝；
3. 角色：leader, follower, candidate
4. leader选择出来后，leader会定时向follower发起心跳，如心跳超时，则最先timeout的节点会发起选举请求，此时该节点会从follower转变成cadidate；

<!-- more -->
