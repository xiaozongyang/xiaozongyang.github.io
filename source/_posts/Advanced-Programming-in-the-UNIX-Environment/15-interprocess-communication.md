---
title: 第 15 章 - 进程间通信
date: 2021-10-09 18:22:28
tags:
    - apue
    - unix
    - 读书笔记
---
1. UNIX IPC 摘要
    > UDS(Unix Domain Socket)
    {% asset_img D7893677-92B4-4EF7-BC24-7DCF46ED7189.png %}

## 管道
1. 管道的限制
    1. 历史上是半双工的，处于兼容性考虑，不应该作出支持全双工的假设
    2. 只能在具有公共祖先的两个进程间使用
2. 管道的操作
    1. 创建管道 `int pipe(int fd[2]);` 由**参数返回**两个 fd
        - `fd[0]`用于读
        - `fd[1]`用于写
        - `fd[1]` 的输出是 `fd[0]` 的输入
    2. fstat 测试管道
3. 进程与管道的示意图
    1. 单进程
        {% asset_img D22F337E-E294-4E93-BC00-2BDC6D38F6E5.png %}
    2. 父、子进程，先调用 pipe 再调用 fork，然后关闭部分 fd 达到想要的数据流向
        {% asset_img 8CDF3BE9-20A5-4FB8-B062-9EBBE3D54482.png %}
        {% asset_img E1B04A6B-F2AB-44AC-95C1-925AFB1F9C47.png %}
4. 可以用两个管道做父、子进程同步，实现 `TELL_WAIT`/ `TELL_PARENT` / `TELL_CHILD` / `WAIT_PRENT` / `WAIT_CHILD`，read 操作阻塞，write 唤醒

## 协同进程
1. 协同进程：通常在 shell 后台运行，其标准输入和标准输出通过管道连接到另一个程序

## 命名管道 FIFO
1. 为什么需要命名管道：因为匿名管道只能在两个相关的进程间使用，并且这两个相关的进程还必须有一个公共祖先进程，**而FIFO 可以使不同的进程之间交互数据**
2. 如何使用
    1. 创建: `int mkfifo(const char *path, mode_t mode)`：mode 与 open 的 mode 相同，创建成功返回 0，否则返回 -1
    2. 创建之后需要用 `open` 打开
        1. `O_NONBLOCK` 标志的影响
            1. 没有指定 `O_NONBLOCK` 的时候，只读 open 要阻塞到某个进程为写打开一个 FIFO 为止，只写 open 阻塞到某个进程为读打开一个 FIFO 为止
            2. 如果指定了 `O_NONBLOCK`，并且此时没有进程为写打开 FIFO，只读 open 会立即返回 -1，并将 errno 设置为 `ENXIO`
3. 用途
    1. shell 命令使用 FIFO 将数据从一条管道传递到另一条时，无需创建中间临时文件
        {% asset_img EAE51746-BAC1-48AA-8187-9CD7BE9F38CE.png %}
    2. 客户进程-服务器进程应用程序中，FIFO 用作汇聚点，在客户进程和服务器进程之间传递数据
        {% asset_img 1784D2DD-B991-463C-8EC8-62B24BEA1E25.png %}

## XSI IPC
1. 内核 IPC 结构：消息队列、信号量、共性存储器
2. 每个内核中的 IPC 结构用一个非负正数 id 引用
    1. 如向一个消息队列发消息，只用知道其队列 id
    2. 消息队列创建再删除，相关 id 连续加 1，直至 int 最大值，然后 reset 到 0
3. IPC 结构外部命名：使多个合作进程能在同一个 IPC 结构上汇聚，即需要提供一个 key
    1. 实现方式
        1. 服务器进程指定 key IPC_PRIVATE 创建一个新 IPC 结构，所返回的标识符可供 fork 出的子进程使用，子进程又可将此标识符作为 exec 的一个参数传给新程序
        2. 在公共头文件中定义 client/server 公认的 key，然后 server 以此 key 创建一个 IPC 结构用以通信
        3. client 和 server 认同一个路径名和项目 id（0-255 间的字符），然后使用 ftok 然后将这两个值变为一个 key，然后用 2 中的方法使用该 key
4. IPC 的问题
    1. 创建 IPC 的进程退出后，IPC 结构（如消息队列）不会删除、IPC 中的数据也不会删除
5. IPC 不用 fd，因此不能使用 IO 多路复用
6. 消息队列：存储在内核中的消息链表，支持先进先出和按消息的类型字段取消息
    1. 每个队列都有一个 msqid_ds 结构，包含了权限、消息数、队列最大长度(byte)
    2. 操作
        1. `msgsnd` 发消息
        2. `msgrcv` 接收消息
        3. `msgctl` 获取 msqid_ds 结构/设置权限或队列祖达长度/删除队列及队列中的消息
7. 信号量：计数器，用于为多个进提供对共享数据对象的访问
	1. 访问共享数据前需要获得信号量，如果获取失败，则被阻塞；使用完需要释放信号量
	2. 操作
		1. `semget` 使用 XSI 信号量前需要先获得一个信号量 ID，如果是新创建需要指定信号量数，否则指定为 0
		2. `semctl` 操作信号量，包括获取信号量状态、设置权限、删除信号量、获取 semval、设置 semval、获取 pid、获取 semncnt、获取 senzcnt、获取所有信号量的值、设置所有信号量的值
		3. `semop` 自动执行信号量集合上的操作数组，提供原子性保
8. 共享存储：允许两个或多个进程共享（同步访问）一个给定的存储区
	1. 内核为每个共享存储段维护一个数据结构，包括访问权限、段大小（byte）、创建进程的 pid、上次操作共享存储的 pid、当前共享存储段 attach 技术、last-attach time、last-detach time、last-change time
	2. 操作
		1. `shmget` 创建新的或引用现有的共享存储段
		2. `shmctl` 操作共享存储段，包括获取 shmid_ds 结构、设置权限或 uid/gid、删除共享存储段
		3. SHM_LOCK/SHM_UNLOCK 对共享存储段加锁/解锁，只有特权用户可以，不是 Single UNIX Specification 定义的
		4. `shmat` 将共享存储段连接（attach）到调用进程的某个地址上，可以通过参数指定由内核指定地址还是用户进程指定地址
		5. `shmdt` 讲共享存储段与调用进程的地址分离(detach)，并不会删除共享存储段
	3. 使用 mmap + /dev/zero 的方式可以在相关联的进程之间实现共产存储段类似的效果
9. POSIX 信号量：简化了 XSI 信号量的接口，优化了删除时的行为，POSIX 信号量删除后仍然可以正常工作，直到该信号量的最后一次引用被释放
	1. 匿名信号量：只在内存中存在，要求使用信号量的进程必须可以访问内存
