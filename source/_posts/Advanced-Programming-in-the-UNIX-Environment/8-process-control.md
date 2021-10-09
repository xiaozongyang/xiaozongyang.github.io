---
title: 第 8 章 - 进程控制
date: 2021-10-09 18:22:19
tags:
    - apue
    - unix
    - 读书笔记
---
1. 进程标识 PID：每个进程都有，唯一标识一个进程，可回收复用
    1. id = 0 的进程通常是调度进程，也称为交换进程（swapper）
    2. id = 1 的进程通常是 init 进程，在自举过程结束时由内核调用
2. `fork` 函数用来创建新进程
    1. 一次调用，两次返回
        1. 父进程返回子进程的 pid，因为一个父进程可能有多个子进程，无法通过其他手段获取子进程的 pid
        2. 子进程返回 0，一个进程只会有一个父进程，因此使用 `getppid` 可以方便的获得父进程的 pid
    2. fork 之后子进程通过 Copy-On-Write 和父进程共享地址空间
    3. fork 之后**父、子进程谁先执行的顺序不确定**，有操作系统调度器决定
    4. 如果父进程的标准 IO 缓冲区中有数据，fork 后子进程的标准 IO 缓冲区中也有数据（本质也是内存）
    5. 如果父进程的标准输出被重定向，则子进程的标准输出也会被重定向
    6. fork 后父、子进程**共享同一个文件偏移量**
    7. 如果父、子进程写同一 fd 指向的文件，又没有任何形式的同步（如父等子），那么它们的**输出会相互混合**
    8. 父、子进程的相同和区别
        1. 相同
            1. uid, gpid, euid, egid
            2. 附属组 id
            3. 进程组 id
            4. 会话 id
            5. 控制终端
            6. 设置用户 id 标志和设置组 id 标志
            7. 当前工作目录
            8. 根目录
            9. 文件模式创建屏蔽字 umask
            10. 信号屏蔽和安排
            11. 对任一文件描述符的执行时关闭(close-on-exec)标志
            12. 环境
            13. 链接的共享存储段
            14. 存储映像
            15. 资源限制
        2. 不同
            1. fork 返回值
            2. pid & ppid
            3. 子进程的 tms_utime, tms_stime, tms_cutim tms_ustime 设置为 0 （CPU 时间）
            4. **不继承**父进程设置的文件锁
            5. 子进程未处理 timer 被清楚
            6. 子进程的未处理信号集设置为空集
    9. fork 失败的原因
        1. 系统中进程太多
        2. 该实际用户 id 的进程总数超过了系统限制(CHILD_MAX)
    10. 用法
        1. 父进程复制自己，父、子进程执行不同的代码段
        2. 一个进程执行一个不同的程序，如 shell
    11. 如果子进程的父进程已经终止，则子进程的父进程变为 init 进程（pid=1）
3. wait/waitpid 父进程等待子进程运行结束时调用
    1. 子进程的退出是异步动作，通过内核向父进程发送信号 SIFCHILD 实现，可能在父进程执行的任何时间收到
        1. 父进程调用 wait/waipid 的行为
            1. 如果其所有子进程都还在运行，则阻塞
                1. waitpid 可以通过选项设置不阻塞
                2. 有任何一个子进程终止，则立即获取该子进程的终止状态
            2. 如果一个子进程已终止，正等待父进程获取其终止状态，则取得该子进程的终止状态立即返回
            3. 如果它没有任何子进程，则立即出错返回
        2. `pid_t waitpid(pid_t pid, int *statloc, int options)` 的 pid 参数行为
            1. `pid == -1` 等待任一子进程，如 wait 等效
            2. `pid == 0` 等待组 id 等于调用进程组 id 的任一子进程
            3. `pid > 0` 等待进程 id 与 pid 相等的子进程
            4. `pid < -1` 等待组 id 等于 pid 绝对值的任一子进程
        3. 其他等待函数
            1. `int waitid(idtype_t idtype, id_t id, siginfo_t *infop, int options);` idtype 控制等待特定进程、特定进程组还是任一子进程，options 表示关心那些状态变化
            2. `wait3`/`wait4` 能够获取子进程执行的统计信息，包括 用户/系统CPU 时间总量、缺页次数、接收信号次数等
4. 父、子进程通过信号同步：`TELL_WAIT`, `TELL_PARENT`. `TELL_CHILD`, `WAIT_PARENT`, `WAIT_CHILD`
5. `exec` 函数：改变当前进程执行的程序，本质是替换当前进程的正文段、数据段、堆、栈
    1. 调用时需要提供程序的**路径/文件名/fd中的任意一个**
    2. 调用时可以穿度参数表、环境表
    3. 变种之间的区别和关系
        {% asset_img EBCDD559-0ECB-4E1C-AF79-CE3DD2F7430D.png %}
        {% asset_img 86D37BE8-1EA9-4E68-9D44-16896E62C18B.png %}
    6. 进程调用 exec 后，除了 close-on-exec 相关的 fd 发生变化外，其他属性（pid, ppid, timer 资源等）都不变
7. 更改用户 id 或组 id
    1. 原因：程序需要增加特权、降低特权或阻止访问资源时，需要更改用户 id 或组 id
        {% asset_img 14EE36E5-332B-450F-8B2F-FC8AAEB30874.png %}
8. `system` 函数用于执行 shell 命令并收集命令终止状态
9. `nice` 函数用于设置进程的优先级，从而影响进程的调度行为
10. 进程的时间：墙上时间、用户 CPU 时间、系统 CPU 时间
    1. tms_utime: user CPU time
    2. tms_stime: system CPU time
    3. tms_cutime: user CPU time, terminated children
    4. tms_cstime: system CPU time, terminated chilren
