---
title: 全书总结
date: 2021-09-27 18:14:41
tags:
    - 读书笔记
    - 存储
    - 分布式
---
全书内容整理如下：
1. 存储系统分类
    1. 文件：文件抽象，面向 block
    2. KV：hashtable 抽象，面向 key-value
    3. Table：列存、一般由列族概念
    4. DB：分布式数据库，提供事务(ACID)的保证
2. 分布式系统关注问题
    1. 数据分布 & 路由
        1. hash
        2. region
    2. 数据同步
        1. 主备（Primary-Based）
        2. 多写（NWR）
    3. 负载均衡
        1. 感知负载 & 数据迁移
        2. 表格合并和分裂
    4. 自动扩容、缩容
    5. 容错：大多依赖分布式锁服务，如 chubby、zookeeper
        1. lease or paxos 保证主可用 （leader election）
        2. p2p
        3. 多副本
