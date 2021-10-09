---
title: 第 14 章 - 高级 IO
date: 2021-10-09 18:22:27
tags:
    - apue
    - unix
    - 读书笔记
---
1. 非阻塞 IO：调用时不会阻塞调用方，而是立即返回，并将 errno 设置为 `EAGIN`
    1. 将 fd 指定为非阻塞 IO 的方法
        1. 使用 `O_NONBLOCK` 标志打开
        2. 通过 `fcntl` 打开
    2. 轮询：多次循环尝试同一个 IO 动作，如果失败不阻塞
2. 记录锁(byte-range locking)：保证一个进程**单独写**一个文件的部分数据，对文件中的部分区域加锁
    1. `int fctnl(int fd, int cmd, ... /* struct flock *flockptr */);` 
        1. cmd 为 `F_GETLK` / `F_SETLK` / `F_SETLKW`
            1. F_GETLK 判断由 flockptr 描述的锁是否会被另外一把锁排斥，即判断当前锁能不能加上，如果能加上保持 flock 结构不变，否则设置为排斥当前锁的信息
            2. F_SETLK 设置有 flockptr 描述的锁，如果该出差会立即返回，errno 为 EACCESS 或 EAGAIN
            3. F_SETLKW  F_SETLK 的阻塞版本，如果加锁失败则调用方被阻塞，如过锁可用，则被唤醒
        2. flock 结构
```c
struct flock {
    short l_type; /* F_RDLCK, F_WRLCK, FUNLCK */
    short l_whence; /* SEEK_SET, SEEK_CUR, SEEK_END */
    off_t l_start; /* offset in bytes, relative to l_whence */
    off_t l_len; /* length, in bytes; 0 menas lock to EOF */
    pid_t l_pid; /* pid of which process acquired the lock, returned with F_GETLK */
};
```
        3. 设置或释放文件上的锁时，系统按要求合并或分裂相邻区，如下图
            {% asset_img 1328CBAC-63D2-4EE2-9C36-AB968C0783A2.png %}
        4. 锁的隐含继承和释放
            1. 锁与进程和文件两者相关联
                - 进程终止时，它锁简历的锁全部释放
                - 无论一个 fd 何时关闭，改进程通过这个 fd 引用的文件上的**任何**一把锁都会释放
                    - 同一个文件打开多次，close 一次锁全部释放
                    - 如果fd1 通过 dup 复制出 fd2，close 任意一个 fd，都会释放文件上的锁
            2. 子进程**不会继承**父进程的文件锁，只会继承 fd，如果子进程需要加锁，需要另外通过 fcntl 加锁
            3. 执行 exec 后，新程序继承原程序的锁（同一个进程，pid 并没有发生变化）
                {% asset_img E38D6CDB-A173-4D6F-8371-6EDC7474C744.png %}
        5. 在文件尾端上加锁时要非常小心，因为大多数实现根据 l_whence 和 l_start 计算出的绝对偏移量，如下图
            {% asset_img 91248A6F-B85D-4600-A61F-6F591074D87C.png %}
            {% asset_img 5F497FD4-41FF-47D6-A2DD-BD8A50426FB4.png %}
        6. 建议性锁 & 强制性锁
            1. 建议性锁：使用相同的库函数或者实现方式才生效的加锁实现（例如其他有写权限的进程没用就可以在有锁的时候继续写）
            2. 强制性锁：OS kernel 保证锁实现有效

## IO 多路复用
1. 动机：一个进程处理多个 fd，轮询感兴趣的 fd
2. 工作流程
```mermaid
graph LR
start((start)) --> A[构造感兴趣 fd 列表]
A --> B[注册 A 中的 fd 列表]
B --> C[检查任一 fd 就绪]
C --> D[处理就绪 fd, 进行 IO]
D --> B
```
3. `int select(int maxfdp1, fd_set *restrict readfds, fd_set *restrict writefds, fd_set *restrict exceptfds, struct timeval *restrict tvptr)` 告诉内核关心哪些 fd 的那些状态（可读、可写、异常），返回已就绪的 fd 总数量、哪些 fd 已就绪
    1. 参数
        1. tvptr 超时时间，分下列几种情况
            1. `tvptr == NULL` 永远等待，除非被信号中断
            2. `tvptr->tv_sec == 0 && tvptr->tv_usec == 0` 不等待，立即返回
            3. `tvptr->tv_sec != 0 || tvptr->tv_usec != 0` 等待指定时长，到时间或有 fd 就绪则返回
        2. readfds/writefds/writefds： fd 集合指针，每个 fd 维护一个 bit
        3. maxfdp1: `max fd + 1`，最大的 fd 编号 + 1，最大值通常为 1024
    2. 返回值
        1. `-1`：出错，例如没有 fd ready 是收到信号
        2. `0`：没有 fd 就绪
        3. `> 0`：就绪 fd 数量，如果一个 fd 读写都就绪，则会被计数两次
4. `int poll(struct pollfd fdarray[], nfds_t nfds, int timeout)` 类似 select，用来检查感兴趣的 fd 是否就绪
```c
struct pollfd {
    int fd; /* file sescriptor to check, or < 0 to ingore */
    short events; /* events of interest on fd */
    short revents; /* events that occurred on fd */
};
```
5. select vs poll
    1. select fd 数量一般有上限限制，而 poll 没有
    2. select 会修改传入的 fd_set，而 poll 不会修改 events，因此 select 每次调用前都需要重新设置 fd_set，二 poll 不需要重新设置 events
    3. select 和 poll 都不受 fd 是否阻塞影响
    4. select 和 poll 都会被信号中断
    
## 异步 IO
1. POSIX AIO 的问题
    1. 每个异步操作有 3 处可能产生错误的地方
        1. 操作提交
        2. 操作本身的结果
        3. 决定异步操作状态的函数
    2. 涉及大量的额外设置和处理规则
    3. 错误恢复很难
2. AIO 的 io 请求加入操作系统 IO 队列就返回成功，在 IO 操作完成之前需要保证缓冲区稳定

## 散布读(scatter read) & 聚集写(gather write)
1. `readv` 从一个 fd 中将数据读到多个 buffer 中，先填满一个 buffer 再填下一个
2. `writev` 将多个 buffer 的数据写入到一个 fd 中
3. readv/writev 需要指定每个 buffer 的起始地址和长度
    {% asset_img EBDAF9BC-428B-44A2-987C-7F022E539642.png %}
4. 好处：能够减少系统调用次数

## readn & writen
1. 背景：管道、FIFO、网络设备有下面两种性质，导致需要多次调用 read/write
    1. 一次 read 操作返回的数据少于要求的数据
    2. 一次 write 操作的返回值少于指定输出字节数

## 存储映射(memory-mapped) IO
1. Memory-mapped IO：将磁盘文件存储空间的一个缓冲区上，通过读写内存 buffer 的方式读写文件，而不用使用 read/write，映射区域位于堆栈之间
2. 映射区域保护要求，不能超过文件 open 模式访问权限
    1. PROT_READ 可读
    2. PROT_WRITE 可写
    3. PROT_EXEC 可执行
    4. PROY_NONE 不可访问
3. 存储区映射方式
    1. MAP_FIXED 返回值必须等于 addr 参数
    2. MAP_SHARED 指定存储操作修改映射文件，即存储操作相等于对该文件的 write，由内核觉得何时写回脏页
    3. MAP_PRIVATE 对存储区的操作导致**创建该映射文件的一个副本**，后续的引用都引用该副本
4. 示意图
    {% asset_img 4219B0DF-E7B2-48EB-872F-970C204DE5B6.png %}
5. mmap 时的 addr 和 offset  需要和虚拟存储页长度对齐（即是page size 的整数倍）
	1. 如 page size 是 512B，映射 100B 的文件，也会提供 512B 的映射区
	2. 操作映射文件长度之外的内存区域不会反映在文件上，而是需要先增加文件长度
6. mmap 相关的信号
	1. `SIGSEGV` 试图写只读的映射区
	2. `SIGBUS` 试图访问已截断的映射区
7. mmap 与子进程
	1. fork 出的子进程继承父进程的存储映射区
	2. exec 切换执行程序后，不继承存储映射区
