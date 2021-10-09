---
title: 第 16 章 - 网络 IPC：套接字
date: 2021-10-09 18:22:29
tags:
    - apue
    - unix
    - 读书笔记
---
1. socket 统一的接口既可以用于计算机间通信，也可以用于计算机内通信
2. socket descripter 应用程序用来访问套接字，在 unix 下为 fd
3. socket 相关的操作
    1. `int socket(domain, int type, int protocol)` 创建 socket
        1. domain 决定通信特性，包括 `AF_INET`, `AF_INET6`， `AF_UNIX` （网络层 ip 还是 unix 文件）
        2. type 进一步决定通信特性，包括 `SOCK_DGRAM`, `SOCK_RAW`, `SOCK_SEQPACKET`, `SOCK_STREAM` （传输层, udp / 原始ip / tcp）
        3. protocol 选择网络协议，`0` 表示选择默认协议
        4. 数据报(SOCK_DGRAM 接口，UDP)不需要逻辑连接，字节流（SOCK_STREAM 接口, TCP）需要逻辑连接，可靠报文服务（SOCK_SEQPACKET, SCTP）需要逻辑连接
    2. `shutdown` 关闭 socket，可以选择关闭读端还是写端（双工通道）
    3. 网络协议定义了字节序，socket 头文件提供了相关的函数，将本地主机的 int 转为网络协议 int（TCP 是大端字节序）
4. 绑定：将 socket fd 与地址关联，**一般只有 server 需要显式调用 bind，client 调用 connet 时会绑定到随机地址上**
    1. 指定的地址必须有效，不能指定指定其他机器的地址
    2. 地址必须和创建 socket 的地址族支持的格式相匹配
    3. 地址中的端口号不小于 1024，除非是特权进程
    4. 一个 socket 端点一般只能绑定到一个地址上
5. 连接(connect)：与给定地址建立连接，如果没有绑定地址，会绑定到本机随机端口，*connect 失败需要关闭 socket*
6. 监听（listen）：宣告愿意接受连接请求，指定 backlog（未完成连接器请求数量）
7. accept：获得连接请求并建立连接，accept 返回的 fd 是 socket fd（用于调用客户端），原始的 fd 继续接受其他连接请求
    1. 可以设置为非阻塞模式，没有连接请求到来时 accepet 返回 -1, errno 设置为 EAGAIN 或 EWOULDBLOCK
