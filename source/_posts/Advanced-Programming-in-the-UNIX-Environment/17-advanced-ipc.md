---
title: 第 17 章 - 高级进程间通信
date: 2021-10-09 18:22:31
tags:
    - apue
    - unix
    - 读书笔记
---
1. UNIX Domain Socket：用在**同一台计算机**上运行的**进程之间的通信**，比网络 socket 通信效率高，*仅复制数据不执行协议处理*
    1. 一对相互连接的 unix domain socket 起到**全双工**管道的作用，两端对读写开放
2. `socketpair` 创建相互连接的套接字，且创建的套接字**没有名字**
3. 命名 socket，通过 `socket` 函数创建 socket，然后 `bind` 到某个路径上
4. 传送 fd：使一个进程能够处理打开一个文件所做的一切操作以及**向调用进程送回一个描述符**，该描述符用于以后的所有 IO 函数
    1. 两个进程，共享同一个 v 结点，但是有个自己的文件表项
    {% asset_img BDA762A2-2EE9-4CB8-90FD-236D40D28C5F.png %}
5. `send_fd`/`recv_fd` 发送/接收 fd

