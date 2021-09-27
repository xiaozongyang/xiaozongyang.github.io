---
title: 第四章 - 分布式文件系统
date: 2021-09-27 23:18:56
tags:
    - 读书笔记
    - 存储
    - 分布式
    - 文件系统
---
1. 分布式文件系统主要功能
    1. 存储文档、图像、视频类的 Blob 类型数据
    2. 作为分布式表格系统的持久化层
2. 数据模型
    1. 文件划分成块（Chunk），每个 chunk 3 个副本
3. GFS 架构
    {% asset_img FAB73224-E81B-4B50-967E-9BB979A51973.png %}
4. GFS 关键问题
    1. 租约机制
        1. GFS Master 通过租约机制将 chunk 写操作授权给 ChunkServer，避免每次追加都得请求 Master
        2. 持有租约的节点为主节点，主节点负责 chunk 的写操作
        3. 租约有过期时间，有效时间可续
    2. chunk 版本号：解决节点下线有上线时，数据发送更新下线节点数据需要回收的问题
        1. 为 chunk 维护版本号，每次续租时版本号加 1
    3. 一致性模型
        1. GFS 只支持追加(append)，而不支持改写（overwrite）
        2. GFS 支持多客户端并发追加，对于两个客户端的记录 R1 和 R2，R1 和 R2 可能不连续，**互相夹杂**
        3. 追加流程
            {% asset_img B00F2B9E-7F36-4FCC-B633-A9560DEC6C59.png %}
            - 步骤 1 客户端从 Master 请求要追加的 chunk 副本所在的 ChunkServer
            - 步骤 2 Master 返回 ChunkServer 位置信息，客户端缓存这些信息，**若客户端不发生故障，客户端不再请求 Master**
            - 步骤 3 客户端将要追加的记录发到每一个副本，每一个 ChunkServer 会缓存待追加的副本
            - 步骤 4 所有的副本收到了记录后，客户端向主副本**发送写操作命令**
            - 步骤 5 主副本将**写操作按顺序打包发给备副本**
            - 步骤 6 备副本写成功后**应答**主副本
            - 步骤 7 主副本应答客户端，如果有副本失败，则客户端需要重试
        4. GFS 追加流程特色
            1. 流水线
            2. 控制流和数据流分离：向副本发送数据和发送写操作命令分离，前提是写数据量很大
5. GFS Master 存储信息
    1. 命名空间：整个文件系统的目录结构及 chunk 基本信息
    2. 文件和 chunk 之间的映射关系
    3. chunk 副本的位置信息 
6. 容错机制
    1. Master 容错：操作日志 + checkpoint + Shadow Master 热备
        1. 所有元数据必须写完备 Master 才能算成功
        2. Master 持久化命名空间及文件和 chunk 映射关系，不持久化 chunk server 副本位置
    2. Chunk Server 容错
        1. 对于每个 chunk **所有副本写入成功才算成功**
        2. 如果 chunk 副本出现丢失或者不可恢复的情况，Master 将自动将副本复制到其他 Chunk Server
7. Chunk Server 负载均衡：需要考虑网络拓扑、机架分布、磁盘利用率等因素，GFS 会**避免同一个 chunk 的副本存放在同一个机架**
    1. chunk 初始副本位置选择
        1. 新副本的 Chunk Server **磁盘利用率小于平均值**
        2. 限制每个 Chunk Server “最近”创建的数量
        3. 每个 Chunk 的副本不再同一个机架
    2. chunk 负载均衡：Master 定期扫描当前副本分布情况，如果发现磁盘使用量或者机器负载不均衡，将执行负载均衡操作
8. Chunk GC：延迟 GC，删除文件时，将元数据中的文件改成特殊名字并记录时间戳，超过一定时间后删除元数据，低峰时期删除数据
9. TFS(Taobao File System) 设计时考虑的问题
    1. metadata 信息存储：单机无法存放所有的 metadata 信息
    2. 减少图片读取的 IO 次数：**多个逻辑图片共享同一个物理文件**
        - 普通文件系统读文件需要 3 次 IO （读目录元数据 + 读文件 inode 节点到内存 + 读实际文件内容）
10. TFS 架构（**NameServer 不需要保存目录树以及文件与 block 之间的映射关系**）
    {% asset_img 8FC2E0DB-7107-44FF-9AD6-FE0D9A0756BC.png %}
    1. 追加流程
       {% asset_img 4E8B1322-EF06-4E46-8476-62512DFCCCFC.png %}
    2. 查询过程：根据 Block 编号从 NameServer 查找 Block 所在的 DataServer → 根据 Block 偏移读取图片数据
    3. 主 NameServer 上的写操作会重放到备 NameServer，可以实时切换
    4. 写入 TFS 前数据需要去重（hash、md5）
    5. 由于一个 block 中有多个图片，如果一个 block 中有部分图片被删除了，整个 block 无法释放，需要等所有图片都删除了才可以
11. Facebook Haystack
    {% asset_img 70BA0F36-A324-4DDF-B000-BFB273E306D1.png %}
    - 只要写操作成功，能保证逻辑卷对应的**所有物理卷都存在**一个有效的照片文件，但在物理卷中的**偏移量可能不一样**
    {% asset_img 32703AFF-E95E-4545-B5C5-54CDE96B7BF7.png %}
    - 容错
        1. 存储节点：检测到存储节点故障时，所有物理卷对于的逻辑卷都被标为只读，即**停写**，未完成的写操作需要重试；如果故障不可恢复，则需要拷贝副本
        2. 目录容错：主备
    - Haystack 目录
        {% asset_img 5B333C5A-3B4E-4CA0-8F95-5D6638AE17A6.png %}
    - Haystack 存储
        1. 每个物理卷轴维护一个所有文件，保存 Needle（照片）查找相关的元数据
            1. 写操作先更新物理卷，后**异步更新索引文件**
            2. 写所有文件也是**追加操作**
            3. 当索引文件和物理卷不一致（索引较老）时，需要扫描物理卷中最后写入的几个文件
        2. 延迟删除回收：标记删除 + 定时 Compaction
        3. 数据格式
            {% asset_img 6075B811-7DEE-4B49-A70D-5F189786D7B4.png %}
12. CDN （Content Delivery Network）
    1. CDN 工作流程 
        {% asset_img 677B9885-ACD3-4EE9-8722-B6F74EF4C23B.png %}
    2. 淘宝 CDN 整体架构
        {% asset_img 438080FD-799A-41E1-B87D-409E91F0A480.png %}
    3. 单个 CDN 节点架构
        {% asset_img A8CC0116-D2E7-4E46-95F7-A657D3FAD2F3.png %}
