---
title: 第 2 章 - UNIX 标准及实现
date: 2021-10-09 18:22:11
tags:
    - apue
    - unix
    - 读书笔记
---
1. ISO ANSI 标准：由国际标准化组织制定，定义了 ISO C 标准
2. IEEE POSIX：Portable Operating System Interface，定义了操作系统标准接口，而没有提供实现
3. Single UNIX Specification：POSIX.1 的超集，定义了一些附加接口，扩展了 POSIS。1 提供的功能
4. 只有遵循 XSI(X/Open System Interface)的实现才能称为 Unix 系统
5. UNIX 环境的限制
    1. 编译时限制：头文件，如 int 的最大值
    2. 运行时限制
        1. 与文件或目录**无关**的运行时限制，(sysconf)
        2. 与文件或目录**有关**的运行时限制，(pathconf, fpathconf)
