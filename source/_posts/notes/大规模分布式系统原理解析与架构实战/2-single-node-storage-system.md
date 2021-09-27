---
title: 第二章 - 单机存储系统
date: 2021-09-27 18:28:01
tags:
    - 读书笔记
    - 存储
    - 分布式
---
## 硬件基础
1. 架构设计很重要的一点就是合理选择并且能够最大限度发挥底层硬件的价值
2. CPU 架构
    1. SMP(Symmetric Multi-Processing) 对称多处理结构，处理器对等、无主从关系、扩展能力有限
    {% asset_img EB8AD2FB-EA7B-43E6-9647-9FD380ED5177.png %}
        
    2. NUMA(Non-Uniform Memory Access) 非一致存储访问
        1. 多个 NUMA 节点，每个节点是一个 SMP 结构，
        2. 每个节点拥有独立的本地内存、IO 槽口
        {% asset_img E38AE26B-5918-4DF9-8F53-0E2135839DA6.png %}
3. IO 总线
    1. 存储系统的性能瓶颈一般在 IO
    {% asset_img 727EB605-CF55-4EB5-91AA-0F1FFF064DEC.png %}
4. 网络拓扑
    1. 思科经典三层架构：接入层、汇聚层、核心层
        1. 3 层带宽
            1. 接入层：48 个 1Gb 端口、4 个 10 Gb 端口
            2. 汇聚层：128 个 10Gb 端口
            3. 核心层：128 个 10Gb 端口
        2. 同一个接入层下的服务器之间带宽为 1 Gb
        3. 不通接入层下的服务器之间带宽**小于** 1 Gb
        {% asset_img C71204BB-D59F-4821-A7F9-55D0C9F58B6B.png %}
        {% asset_img F39B7E4C-05AD-4F58-9D76-9BD0215D66E7.png %}
    2. 三级 CLOS 网络
        1. 同一个集群内最多支持 20480 台服务器
        2. 同一个集群内的**任何两台机器间有 1Gb 带宽**
        3. 需要投入**更多交换机**，但设计时**不需要考虑网络架构**，方便将集群做成一个资源池
    3. 硬件性能参数
        {% asset_img 27971004-936E-47AF-844A-9C575453591B.png %}
    4. 内存 & SSD & SATA 盘性能参数
        {% asset_img C5B3AFB2-C48E-42C9-801C-BEDFF20994C6.png %}

## 单机存储引擎

1. 单机存储引擎是**哈希表、B 树**等数据结构在**磁盘**上的实现
2. 存储引擎分类
    1. 哈希：支持增、删、改、随机读、**不支持顺序扫描**（hash 无序） 对应**键值存储系统**
    2. B 树：支持增、删、改、随机读、顺序扫描，对应关系数据库
    3. LSM 树：支持增、删、改、随机读、书按需扫描
        1. 表格存储系统 Google Bigtable、Facebook Cassandra
        2. KV 存储系统 LevelDB

### 哈希存储系统 Bitcask

1. 只支持追加操作 Append Only
2. 数据结构：key、value、key_size、value_size、timestamp、crc
    1. 内存：哈希表索引 `key → file_id + value_pos + value_size`
    2. 磁盘：完整数据
    3. 写入：追加写 key-value 到磁盘 → 更新内存哈希表
    4. 读取：内存读索引 → 磁盘读 value
    {% asset_img CE6C3FA3-9156-4FEA-A447-80B04A5E25AD.png %}
3. 定期合并：需要定期进行 GC，只保留最新的 value
    1. GC 过程扫描所有的老数据文件，生成新数据文件
4. 快速恢复
    1. 索引：通过磁盘上的索引文件（hint file）加速重建内存索引

### B 树存储引擎

1. 按页面（Page）组织数据，每个 Page 对应 B 树的一个节点，叶节点存数据，非叶节点存索引
2.数据结构如下（B+树根节点在内存中有缓存）
    1. 写流程：写 WAL 日志 → 写 B+ 树
    2. 读流程：读 B+ 树
    {% asset_img D203B47E-3CBB-4F62-96C0-E2768DBA0E3A.png %}
3. 缓冲区管理
    1. LRU（Least Recently Used）：每次淘汰最长时间没有读写过的元素
        - 在全面表扫描时会把 LRU 全刷一遍，导致缓存命中率下降
    2. LIRS 两级 LRU，分为新子链表（new sublist）和老子链表（old sublist），先插入老子链表，元素在老子链表中停留的时间超过阈值后才加入新子链表（类似 JVM gc 分新生代、老生代）

### LSM 树存储引擎

{% asset_img A91B8EDD-6BF5-4057-8F91-FA7D78329408.png %}

## 数据模型

1. 文件：目录树模型，支持操作 (POSIX API)
    1. open/close
    2. read/write
    3. opendir/closedir
    4. readdir 遍历目录
2. 关系：二维表模型，支持 SQL 操作
    1. SELECT
    2. INSERT
    3. UPDATE
    4. DELETE
3. 键值：哈希表模型，支持操作层
    1. put
    2. get
    3. delete
4. 表格：kv 操作 + scan
5. 关系模型在大规模数据下面临的挑战
    1. 事务
        1. 多节点事务协调，如何在多节点都保证 ACID
        2. 如何保证两阶段提交协议的性能和故障容忍
    2. 联表：数据记录需要的属性从多张表查到
        1. 性能和数据库范式的（冗余）的权衡
    3. 性能
        1. B+ 树引擎本身的写性能瓶颈
        2. 扩展性问题
6. NoSQL 系统在面临的问题
    1. 缺少统一的标准，如 SQL 之于关系数据库
    2. 使用及运维复杂：系统多、适用场景不一样

## 事务与并发控制

1. 隔离级别与对应的问题
    1. LU（Lost Update）：后一个事务回滚了前一个事务的变更
    2. SLU(Second Lost Update)：后一个事务提交覆盖了前一个事务的变更
    3. NRR: **同一数据项**
    4. PR：**同一个查询范围**
    {% asset_img AA646091-3FD8-4289-8454-8F7971D1749C.png %}

### 并发控制

1. Copy OnWrite
    {% asset_img 7E5AAAEF-14C4-4341-8272-7FAD36B920A2.png %}
2. MVCC
    1. 每条记录记两个版本号，一个生成版本，一个删除版本，版本号单调递增
    2. 记录更新版本号
        1. 插入时记录第一个版本号
        2. 删除时，为标记删除，即记录版本号
        3. 更新时，记录新的版本号
    3. 查询时对比查询版本号和更新版本号确定事务能看到哪个版本

### 操作日志
1. 操作日志分类
    1. 操作日志 <table, record, rollback_value, commit_value>
    2. UNDO 日志 <table, record, rollback_value>
    3. REDO 日志 <table, record, commit_value>
2. 优化手段
    1. 批量刷盘，减少 IO 次数
    2. checkpoint，减少重放时间