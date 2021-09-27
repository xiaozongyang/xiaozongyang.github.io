---
title: 第十章 - 数据库功能
date: 2021-09-27 23:23:40
tags:
    - 读书笔记
    - 存储
    - 分布式
---
1. 数据库功能层整体架构
    1. CS-SQL：单子表的 SQL 查询，（读事务）
    2. UPS-SQL：实现写事务
    3. MS-SQL：SQL 语句解析，包括词法分析、语法分析、预处理、生成执行计划、按照子表范围合并多个 ChunkServer 返回的部分结果，实现多表的物理操作如 join、subquery 等
    {% asset_img F4C301B8-C29B-42BE-9417-3D9317941A1D.png %}
2. SQL 执行本地化：保持数据节点与计算节点一致，只要 ChunkServer 能实现的操作，原则上都应该由它完成
    1. TableScan：每个 ChunkServer scan 各自子表范围内的数据，由 MergeServer 合并 ChunkServer 返回的部分结果
    2. Filter：
        1. 对基本表的过滤集成在 TableScan 中，由 ChunkServer 完成
        2. 对分组后的记过执行过滤集成(Having)集成在 GroupBy 中，一般由 MergeServer 完成
        3. 如果能确定多每个分组的所有数据行都属于同一个子表，比如 SQL 请求只涉及一个 tablet，则 having 可以由 ChunkServer 完成
    3. Projection
        1. 对基本表的投影集成在 TableScan 中，由 ChunkServer 完成
        2. 对最终结果的投影有 MergeServer 完成
        3. GroupBy 如果读取数据只在一个子表上，由 ChunkServer 完成；否则，每台 ChunkServer 各自完成部分数据的分组操作，执行聚合运算后的部分结果，再由 MergeServer 合并最终结果
    4. Sort
        1. 如果读取的数据在一个子表上，由 ChunkServer 完成排序操作
        2. 由 ChunkServer 各自完成部分数据排序，再由 MergeServer 执行多路归并
    5. Limit 一般由 MergeServer 完成，如果请求只在一个子表上，由 ChunkServer 完成
    6. Distinct：类似 GroupBy，ChunkServer 完成部分去重，再由 MergeServer 完成整体去重
3. MVCC 实现：写操作拆分为两步，事务版本为提交的系统时间，读事务只会读取事务开启之前提交的写事务的更新操作
    1. 预提交（多线程）：事务执行线程先**锁住待更新行**，再将对数据行的**操作追加**到该行的**未提交操作链表中**
    2. 提交（单线程）：
        1. 提交线程从提交队列中**取出提交任务**，将任务的**操作日志追加到日志 buffer**
        2. 如果日志 buffer 达到一定大小，则将 buffer 中的**数据同步到备机**，同时**写入主机的磁盘**日志文件
        3. 操作日志写成功后，**将未提交行操作链表中的 cell 操作追加到已提交操作链表的末尾**
        4. 释放锁并回复客户端写操作成功
    {% asset_img 2678DE8A-3A18-4E41-A0D0-D1D2713A6FEE.png %}
4. 锁机制
    1. 单行只写：预提交时对修改的数据行加写锁，事务提交时释放
    2. 多行只写：预提交时对多个数据行加写锁，事务提交时释放，采用**两阶段提交**实现
    3. 读写事务：读操作读某个版本的快照，写操作与只写事务相同
    4. 死锁处理：如果超过一定时间无法获取写锁，则自动回滚
