---
title: 第五章 - 分布式键值系统
date: 2021-09-27 23:19:14
tags:
    - 读书笔记
    - 存储
    - 分布式
    - kv
---

1. 分布式键值模型只支持单个 key 的 CRUD

## Dynamo
1. 设计是面临的问题及最终方案
    {% asset_img 2FABF51B-E5F1-4A52-9C1A-846B6073DAC1.png %}
2. 容错
    {% asset_img 0E7EC8B3-D8BE-4B34-9B58-55BEA4F96EFB.png %}
3. 负载均衡：取决于如何给每台机器分配虚拟节点，即 token
    1. 随机分配：没太物理节点加入时随机分配 S 个 token
        1. **可控性差**，有节点加入或离开时，集群中的原有节点都需要扫描所有的数据从而找出属于新节点的数据，Merkle 数也需要全部更新
        2. **无法支持增量归档、备份**
        3. S 足够大是，能保证负载比较均衡
    2. 数据范围等分 + 随机分配：将数据的哈希空间等分为 `Q=N*S` 份，每台机器随机选择 S 个分割点作为 token
        1. 每台机器只对负责范围的数据唯一可 Merkle 树，新节点接入时只需要扫描部分数据，从而支持增量归档
4. 读写流程
    1. 写入流程
        {% asset_img 27952988-CEF3-467D-9343-38E3CDE4BA4B.png %}
    2. 读取流程
        {% asset_img 89F33642-AFBD-4EC0-8FCC-FC5C5038AC65.png %}
        
## Tair
1. 架构
    {% asset_img 740A6564-AA51-46D2-BC3D-E4E8708EEBA9.png %}
2. 数据分布
    1. 根据数据的主键计算哈希值后，分布到 Q 个桶中，**桶是负载均衡和数据迁移的基本单位**，`Q >> N`，N 为机器数量
    2. 当主键均衡时，只需要保证桶中的数据基本均衡，就能保证数据分布的均衡性
3. 容错
    1. Config Server 能检测到 Data Server 不可用
    2. 每个哈系统在存储多个副本，每个副本在不同的 Data Server 上
    3. 如果主副本不可用，则 Config Server 会提升备为主，并增加新的备副本
4. 数据迁移（桶粒度）：假设 DS A 将桶 3,4,5 迁移到 Ds B
    {% asset_img 8783C1A1-8274-449B-A3CA-BFB16E2779C6.png %}
5. 客户端维护路由表的逻辑
    1. 客户端缓存路由表，大多数情况不需要请求 ConfigServer
    2. 每个路由变更，Config Server 会将新的配置信息推给 DataServer
    3. 客户端访问 DataServer 时会发送客户端缓存的路由表的版本，如果 DataServer 发现客户端缓存路由表版本过低，会通知客户端去 ConfgiServer 取新的路由表（DataServer 驱动 Client 缓存失效)
    4. 如果 Client 访问 DataServer 时出现了不可达的情况，客户端会主动去 COnfigServer 获取新路由表
6. DataServer
    {% asset_img B90F4531-AD9B-41FA-80EF-4F4D46681E5D.png %}
    