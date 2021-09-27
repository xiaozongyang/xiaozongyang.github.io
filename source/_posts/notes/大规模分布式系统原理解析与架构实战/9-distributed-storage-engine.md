---
title: 第九章 - 分布式存储引擎
date: 2021-09-27 23:23:25
tags:
    - 读书笔记
    - 存储
    - 分布式
---
1. OceanBase 分部式存储引擎层负责数据分布、负载均衡、容错、一致性协议、动态扩缩容
2. RootTable 通过有序数组实现，通过 Copy-On-Write 避免写阻塞读
    1. 同一个 ChunkServer 上报的一批子表一次性追加到 RootTable 并重新排序
    {% asset_img C257E1CB-771A-4D79-A89D-1769794773C4.png %}
3. 子表复制：定期扫描 RootTable 中的子表，如果子表副本数是否小于阈值，则选择一台新的 ChunkServer 进行副本复制
    1. 新的 ChunkServer 上不能有该子表的副本
    2. 新 ChunkServer 上不包含待迁移子表
    3. 新 ChunkServer 上子表数 < 平均子表数 - 可容忍个数
    4. 全局正在进行的迁移任务不超过阈值
4. 子表负载均衡：扫描 RootTable 中的子表，如果某台 ChunkServer 包含的子表数量 > 平均子表数 + 可容忍个数，则以这台 ChunkServer 为源 Server 生成子表迁移任务
5. 子表复制和负载均衡**不会立即执行**，而是在负载低峰执行
6. 子表分裂与合并
    1. ChunkServer 在定期合并过程中执行
    2. 每台 ChunkServer 采用**相同的分裂规则**，保证子表的副本之间的基线数据完全一致
    3. 子表合并：合并准备 -> 子表迁移 -> 子表合并
        1. 合并准备：选择若干主键范围连续的小子表
        2. 子表迁移：将待合并的小子表迁移到相同的 ChunkServer
        3. 子表合并：想 ChunkServer 发送子表合并命令，生成合并后的子表范围

## RootServer
1. RootServer 优雅退出：避免 RootServer 在升级期间 UpdateServer 上租约过期无法续约，*RootServer 退出时发一个超时时间很长的租约，承诺这段时间不进行 UpdateServer 选举*
2. RootServer 主备切换
    1. 主备 RootServer 挂在同一个 VIP 下面，正常情况下总是指向主
    2. 主 RootServer 故障时，被 Linux HA 检测到，将 VIP 飘移到备 RootServer
    3. 备 RootServer 感知到 VIP 飘移到自身，自动切换为主，对外提供服务

## UpdateServer
1. UpdateServer 模块组成：内存存储引擎、任务处理模型、主备同步模块
    1. 内存存储引擎：在**内存**中存储**修改增量**，支持**冻结**、**转存储**操作
    2. 任务处理模型：网络框架、任务队列、工作线程
    3. 主备同步：将更新事务以操作日志的形式同步到备 UpdateServer
2. UpdateServer 存储引擎：
    1. UpdateServer vs Bigtable
        1. UpdateServer 只存增量数据，而 Bigtable 同时存基线和增量
        2. 所有表格公用 MemTable 及 SSTable，而 Bigtable 每个表的 MemTable 和 SSTable 分开存放
        3. SSTable 存在本地 SSD，而 Bigtable 存在 GFS
    2. 操作日志
        1. 结构：日志头 + 日志序号 + 日志类型 + 日志内容
        2. 专门的提交线程确认多个写事务的顺序，使用 DirectIO 写文件，防止污染 OS Cache
        3. 成组提交：先将多个写操作的日志拷贝到相同的 buffer，然后一次性 flush 到磁盘文件
    3. MemTable：B 树，key 为 row key，value 为**行操作链表**
        1. 更新和删除操作只存操作，不存状态
        2. 实现优化：哈希索引、内存压缩
        {% asset_img D593C154-59F3-47C7-B2A3-C9F43BEC0BE9.png %}
3. UpdateServer 主备同步
    {% asset_img 8D678DAA-769D-4DB1-B230-C2F04C4371A6.png %}
    
## ChunkServer
1. 子表加载支持延迟加载，即有读操作时才加载
2. SSTable 格式格式
    1. Block Index 由 Block 最后一行的 Row Key 组成
    2. 每个 Block 有一个 BloomFilter
    3. 数据读取过程：
        1. 从 tablet index 读 SSTable Trailer offset，获取 Trailer 信息
        2. 从 Trailer 信息中获取 block index 的 size, offset
        3. 将 block index 加载到内存
        4. 二分查找定位 row 所在的 block
        5. 将 block 加载到内存，二分查找定位 row
    {% asset_img FA417757-8990-4DC2-9F26-8BEC786AA0E2.png %}
    {% asset_img 381CB9AF-A86B-405B-8A20-BD6408DEF9E0.png %}
3. 缓存实现
    {% asset_img 13785E75-2456-4325-84C3-660F1737CC43.png %}
4. 缓存惊群效应
    1. 问题：如果 ChunkServer 中有一个热点行，**ChunkServer 中的 N 个 worker thread 同时发现这一行缓存失效**，于是所有 worker thread 同时读取这个行数据并更新缓存。但实际上只有 1 个线程能成功，N-1 个线程做了无用功还增加了锁冲突
    2. 解决：第一个线程发现行缓存失效时，设置一个 fake 标记，其他线程看到标记后会等待一段时间，直到第一个线程从 SSTable 中读到这行数据并加入到缓存后，在从缓存中读取
        1. {% asset_img B067A202-2574-47C7-967B-2A31C7CBB5EA.png %}
5. IO 实现: DirectIO + 双 Buffer（current + ahead）
