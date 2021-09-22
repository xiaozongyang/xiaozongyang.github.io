---
title: '[RocketMQ 源码阅读] TopicConfigManager'
date: 2021-09-22 12:20:27
tags:
    - RocketMQ
    - 源码阅读
---
## 模块职责
1. 负责 topic 管理的类为 TopicConfigManager，提供了TopicConfig 的 CRUD 功能
2. TopicConfigManager 继承自 ConfigManager，具有 `load` 和 `persist` 功能

## 关键细节
1. 内置 topics
    1. SYS_SELF_TEST
    2. AUTO_CREATE_TOPIC_KEY 默认 topic 配置的 key，当自动创建 topic 开关打开后，会用这个 topic 的配置作为 topic 的默认配置
    3. SYS_BENCHMARK
    4. clusterName
    5. brokerName
    6. SYS_OFFSET_MOVED
    7. SYS_SCHEDULE：用于暂存待发送的延时消息
    8. Trace Topic
    9. Replace Topic: `ClusterName + REPLAY_TOPIC_POSTFIX`
2. 内存数据结构：`ConcurrentHashMap`，key 为 topicName，value 为 TopicConfig

### 处理流程梳理
1. `createTopicInSendMessageMethod`： 在 `AbstractSendMessageProcessor#msgCheck` 中调用，当根据当前 request 的 topic 属性选择 Config 失败时，会调用此方法
```mermaid
    graph TD
    s((start)) --> A[尝试锁住整个 topicConfigTable]
    A --> B{加锁成功?}
    B --> |N|C[返回 null ]
    C --> C1((end))
    B --> |Y|D[根据 topic 获取一次 TopicConfig]
    D --> D1{TopicConfig 已存在?}
    D1 --> |Y|D2[返回 TopicConfig]
    D2 --> C1
    D1 --> |N|E[根据 defaultTopic 获取 TopicConfig]
    E --> F{defaultTopicConfig 存在?}
    F --> |Y|F1{defaluTopic 是 AUTO_CREATE_TOPIC_KEY_TOPIC?}
    F1 --> |Y|F11{自动创建 topic 开关打开?}
    F11 --> |Y|F111[将 defaultTopicConfig 权限设为读写]
    F --> |N|G[topicConfig 创建失败并打印 log]
    F111 --> F2{producer 有 defaultTopic 的权限?}
    F2 --> |Y|F21[新建 TopicConfig]
    F2 --> |N|G
    F21 --> H[TopicConfig 加入到内存 topicConfigTable]
    H --> I[topicConfigTable 版本号自增]
    I --> J[topicConfigTable 持久化到本地文件]
    J --> D2
    G --> C
```

2. `createTopicInSendMessageBackMethod`：在`SendMessageProcessor#asyncCOnsumerSendMessageBack` 方法中调用
```mermaid
graph TD
    s((start)) --> A[尝试锁住整个 topicConfigTable]
    A --> B{加锁成功?}
    B --> |N|B1[返回 null ]
    B1 --> B11((end))
    B --> |Y|B2[根据 topic 获取 TopicConfig]
    B2 --> B3{TopicConfig != null ?}
    B3 --> |Y|B31[返回 TopicConfig]
    B31 --> B11
    B3 --> |N|B4[新建 TopicConfig]
    B4 --> B5[TopicConfig 加入到内存 topicConfigTable]
    B5 --> B6[topicConfigTable 版本自增]
    B6 --> B7[topicConfigTable 持久化到本地文件]
    B7 --> B31
```

3. `createTopicOfTranCheckMaxTime`：实现逻辑和 `createTopicInSendMessageBackMethod` 一致，区别是 `createTopicOfTranCheckMaxTime` 中的 topic 是 `RMQ_SYS_TRANS_CHECK_MAX_TIME_TOPIC`，是一个内置的事务消息专用 topic

4. `updateTopicConfig`/`deleteTopicConfig` 修改或删除某个 TopicConfig，基本逻辑相同，分为如下 3 步
```mermaid
graph LR
    A((start)) --> B[修改内存 topicConfigTable]
    B --> C[数据版本自增]
    C --> D[变更持久化到本地文件]
    D --> E((end))
```

## 总结
1. RMQ 的 TopicConfigManager 由`内存 ConrrentHashMap + 版本号 + 持久化文件`组成
2. TopicConfig 每次变更（新增、更新、删除）都会让版本号自增，版本号由`时间戳 + AtomicLong` 组成
3. TopicConfigManager 支持从文件加载初始配置，逻辑和 `ConfigManager` 相同
