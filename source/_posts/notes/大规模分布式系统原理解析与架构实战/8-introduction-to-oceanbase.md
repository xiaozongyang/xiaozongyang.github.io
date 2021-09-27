---
title: 第八章 - OceanBase 架构初探
date: 2021-09-27 23:22:39
tags:
    - 读书笔记
    - 存储
    - 分布式
---
1. 设计思路
    1. 背景：淘宝店收藏夹数据量很大，但短时间内的增量相对不大
    2. 思路
        1. 采用单台 Update Server 来处理增量数据，之前的数据不变称为基线数据
        2. 所有的写操作集中在单台 Update Server 上，因此避免了分布式事务，高效地实现了跨行事务
        3. Update Server 上的修改增量定期分发到基线数据服务器中
        4. 查询时，同时查询基线数据和 Update Server 中的数据，进行合并
2. 架构设计
    {% asset_img 722B2D82-717C-4ADD-9CB8-9135DB65A2A1.png %}
3. 双机房部署
    {% asset_img DF156C6B-B5B7-47D0-90BC-C175085F12AE.png %}
4. 升级方案：停备集群流量 -> 升级备集群版本 -> 主备切换 -> 升级旧住集群版本
5. Root Server
    1. 保证集群内只有一个 Update Server Master，通过 Lease 机制保证
    2. 存储了子表划分及每个子表所在 Chunk Server 位置信息
        {% asset_img 34E4E61C-0B7A-4464-81C6-4506E184D11E.png %}
    3. Root Server 检测到 Chunk Server 发生故障时，触发对这台 Chunk Server 上的子表的**增加备份**操作
    4. Root Server 定期进行负载均衡，将子表从负载高的机器迁移到负责低的机器
6. Merge Server：SQL 计算层
    1. 本身无状态
    2. 缓存子表分布信息
    3. 按需对 SQL 请求拆分到对应的 Chunk Server 并聚合结果
    4. 转发写请求到 Update Server
7. Chunk Server：存储节点
    1. 数据按子表组织，每个子表约为 256MB，每个子表包含一个或多个 SSTable
    2. SSTable 内 key 有序，可以进行二分查找
    3. SSTable 支持 Block Cache 和 Row Cache
    4. OceanBase 定期触发合并或数据分发操作，在这个过程中，ChunkServer 从 UpdateServer 取一段时间之前的更新数据
8. Update Server 唯一的写入模块
    1. 内存表的数据量超过一定值时，生成快照存储到 SSD，组织方式类似 SSTable，数据稀疏
    2. 主 UpdateServer 更新内存表前先将操作日志同步到备 UpdateServer
    3. 重启后，先加载快照，然后重复操作日志
9. 定期合并 & 数据分发：将 UpdateServer 中的增量更新分发到 ChunkServer，流程如下
    1. UpdateServer 冻结当前内存活跃表 （Active MemTable），并开启新的内存活跃表，**后续写操作写入新的内存活跃表**
    2. UpdateServer 通知 RootServer 数据版本发送了变化，之后 RootServer 通过心跳通知 ChunkServer
    3. 每台 ChunkServer 启动定期合并或数据分发操作，从 UpdateServer 获取每个子表对应的更新操作
    4. **合并期间不停读**：如果合并没完成，则读旧子表 + 冻结内存表，否则读新子表
        {% asset_img DBF0DB85-5EA6-44D1-9766-3C6E7CAD87A7.png %}
10. 定期合并 & 数据分发的区别
    1. 定期合并：需要将本地 SSTable 中的**基线数据**与 UpdateServer 中冻结内存表中的**增量更新数据**执行一次**多路归并**，融合的数据写入到新的 SSTable
    2. 数据分发：将 UpdateServer 中冻结内存表中的增量更新**缓存到本地**
11. 数据结构
    1. 每个表按主键组成一颗**分布式 B+ 数**，每个叶子节点包含一个左开右闭的主键范围内的数据
        1. 每个叶子节点为一个子表（tablet），包含一个或多个 SSTable
        2. 每个 SSTable 内部按主键顺序划分为多个 block，并建立块索引(block index)
            1. 每个 block 大小通常在 4-64KB
            2. 在块内建行索引(row index)
            3. **block 是数据压缩的单元**
        3. 叶子节点可能合并或者分裂
        4. 通常情况下每个叶子节点有 2-3 个副本
        5. 叶子节点是**负载均衡和任务调度**的单元
        6. 叶子结点支持 bloom filter
    2. 增量数据为一颗**内存中的 B+ 树**，称为 MemTable，到达一定大小后会被冻结，并开启新的 MemTable 接受写操作
        1. 冻结的 MemTable 将以 SSTable 的形式存储到 SSD 中持久化
        2. 每个 SSTable 内部按主键范围有序划分为多个**块**
            1. 每个块大小通常为 4-8K
            2. 块内建行索引
            3. 一般不压缩
    3. 示意图
        {% asset_img 7DE19923-F67D-455D-BF85-B81765597B14.png %}
12. 读写事务
    1. 只读事务：MergeServer 解析 SQL 生成执行计划 -> MergeServer 将请求转发到 ChunkServer -> MergeServer 合并查询结果或处理链表、嵌套查询 -> MergeServer 向 Client 返回结果
    2. 读写事务：：MergeServer 解析 SQL 生成执行计划 -> MergeServer 从 ChunkServer 获取基线数据，将物理执行计划和基线数据一起发给 UpdateServer -> UpdateServer 执行读写事务 -> UpdateServer 向 MergeServer 返回事务执行结果 -> MergeServer 向 Client 返回结果
13. 数据校验措施
    1. 数据存储校验：每个存储记录保存 64-bit CRC，数据访问时做比对
    2. 数据传输校验：记录传输时同时传输 64-bit CRC，数据接收后作比对
    3. 数据镜像校验
        1. UpdateServer 为 MemTable 生成一个校验码，MemTable 每次更新时同步更新校验码，并记录在操作日志中
        2. 备 UpdateServer 重放操作日志时比对 MemTable 计算出的校验码和操作日志中的校验码
    4. 数据副本校验：ChunkServer 定期合并 MemTable 生成新 SSTable 时，为每个子表生成一个校验码，随新子表汇报给 RootServer，由 RootServer 比对不同副本的校验码
