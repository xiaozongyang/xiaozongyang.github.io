---
title: 第 4 章 - 文件和目录
date: 2021-10-09 18:22:13
tags:
    - apue
    - unix
    - 读书笔记
---
## stat, fstat, fstatat, lstat
1. `int stat(const char *restrict pathname, struct stat *restrict buf)` 返回 pathname 指定的文件的信息结构
2. `int fstat(int fd, struct stat *buf)` 通过 fd 获取文件的结构信息
3. `lstat` 与 `stat` 类似，但是返回的是**符号链接**的信息
4. `strcut stat` 的基本结构
```c
    struct stat {
        mode_t st_mode; /* file type & mode (permissions) */
        inot_t st_ino; /* i-node number (serial number) */
        dev_t st_dev; /* device number (file system) */
        dev_t st_rdev; /* device nuber for sepecial files */
        nlink_t st_nlink; /* number of links */
        uid_t st_uid; /* user ID of owner */
        gid_t st_gid; /* group ID of owner */
        off_t st_size; /* size in bytes, for regular files */
        struct timespec st_atime; /* time of last access */
        struct timesepc st_mtime; /* time of last modification */
        struct timespec st_ctime; /* time of last file status change */
        blksize_t st_blksize; /* best I/O block size*/
        blkcnt_t st_blocks; /* number of disk blocks allocated */
    }
```
    
## 文件类型
1. 普通文件：包含某种形式的数据，内核必须理解可执行文件的格式
2. 目录文件：包含了其他文件的**名字**，以及指向这些文件信息的**指针**，**任何进程都可以读**目录的内容，**只有内核可以直接写目录文件**
3. 块特殊文件：提供对设备（如磁盘）**带缓冲**的访问，每次访问以固定长度为单位进行
4. 字符特殊文件：提供对设备**不带缓冲**的访问，每次访问长度可变（如键盘）。
5. FIFO：用于进程间通信，也称为命名管道（named pipe）
6. socket：用于进程间的**网络通信**，也可以用作一台宿主机之间的非网络通信
7. 符号链接(symbol link)：指向另一个文件，通过

## 文件和进程的 uid/gid
1. 设置用户 ID & 实际用户 ID & 保存的设置用户 ID
    1. 实际用户 ID：标识我们是谁，登录时确定
    2. 有效用户 ID：决定了我们的访问权限
    3. 保存的设置用户 ID：有效用户 ID 和实际用户 ID 的副本
    4. 可以通过 st_mode 的标志位设置一个特殊标志，当执行改文件时，将进程的有效用户 ID 设置为文件所有者的用户 ID（例如访问 `/etc/passwd`，会获得 root 权限）
## 文件访问权限：
RWX（read/write/execute）, user/group/other
    1. 通过名字打开任一类型的文件时，必须对该名字中包含的目录或隐含的当前工作目录具有执行权限(X)
    2. 对于一个文件是否有读/写权限，决定了是否能打开一个文件进行读操作，与 O_RDONLY/O_WRONLY 和 O_RDWR 标志相关
    3. open 文件时如果要设置 O_TRUNC，必须要有写权限
    4. 删除文件时，必须有写和执行权限
    5. 被 exec 函数执行的文件，必须是普通文件，并有执行权限
    6. 进程每次打开、创建、删除文件时，内核进行权限测试，对文件的 uid & gid，进程的有效 uid & gid，进程的附属组 ID 进行测试
        1. uid=0 的超级用户可以直接访问
        2. 如果进程有效 uid = 文件所属的 uid 且有适当权限则允许访问
        3. 如果进程的有效 gid = 文件所属的 gid 或进程的附属组 id = 文件 gid，且拥有释放权限则允许访问
        4. 如果文件的**其他用户**有适当权限，则允许访问
        5. 其他情况拒绝访问
10. 新目录/文件的所有权：使用 `open`/`creat` 创建新文件时，新文件的用户 id 为进程的有效用户 id，组 id 为进程的有效组 id 或所在目录的组 id

## 其他函数
1. access & faccessat
    1. 功能：用于测试当前进程对某个文件是否有对应权限，成功返回 0，出错范围-1
    2. 区别
        1. access 参数为 pathname
        2. faccessat 参数为 fd 和 pathname
2. umask 设置文件模式创建屏蔽字，并返回之前的值，即**屏蔽字中为 1 的位，关闭对应的权限**
3. chmod & fchmod & fchmodat 修改现有文件的访问权限
4. chown & fchown & fchownat & lchown 修改现有文件或符号链接的 owner
5. `int truncate(const char *pathname, off_t length)` 截断文件
    1. 如果文件当前长度大于 length，则 length 之后的数据不能再访问
    2. 如果文件当前**长度小于 length，则文件长度将增到到 length**，增加部分为**空洞**（读 0）
6. `link` 创建指向给定 inode 的目录项，增加该 inode 的链接计数，`unlink` 删除目录项，即减少 path 对于对应 inode 的链接计数
    1. 一个文件的链接计数为 0，并且打开它的进程数也为 0 时，才会被删除
    2. 文件 *unlink* 后，会删除对应名称的目录项，没法通过 `ls -l` 在文件系统中看到
    3. 一个进程可以用 *unlink* 它创建的临时文件，保证进程崩溃后临时文件也被删除
7. `remove` 解除对文件或目录的链接，类似 `unlink`
8. `rename(const char *oldname, const chat *newname)` 对文件或目录进行重命名
    1. 如果 oldname 是文件，为该文件或目录重命名，**要求如果 newname 若已存在不能是目录**，会删除 newname 的目录项，然后将 oldname 修改为 newname
    2. 如果 oldname 是目录，**要求如果 newname 存在，则 newnmae 必须是空目录（只含 `.`, `..`）**
    3. 如果 oldname 或 newname 引用符号链接，则处理的是符号链接本身，而不是所引用的文件
    4. 不能对 `.` 和 `..` 重命名，即 `.` 和 `..` 不能出现在路径最后
    5. 如果 oldname 和 newname 相同，则不进行任何修改
9. `symlink` 创建符号链接，`readlink` 读取符号链接
10. `futimens`/`utimensat` 更新文件数据的访问和修改时间
11. `mkdir`/`mkdirat` 创建新的空目录
12. `rmdir` 删除空目录，如果该目录没有进程打开，则直接释放该目录占用的空间；如果该目录被进程打开，则删除 `.` 和 `..`后返回，无法在该目录下不能创建新文件，进程关闭它之间不释放磁盘空间
13. `chdir` 修改当前进程的工作目录（搜索相对路径的起点），不影响其他进程
14. `getcwd` 获取当前进程的工作目录

## 文件长度
1. stat 结构体中 st_size 表示文件长度，单位为字节，**只对普通文件、目录文件和符号链接有意义**
2. 普通文件长度可以为 0，开始读时，直接返回 EOF
3. 符号链接的文件长度为文件名中的实际字节数
4. 带空洞的文件长度大于磁盘中的 byte 数

## 文件系统
1. 磁盘、分区与文件系统：一个磁盘可能有多个分区，每个分区可能有各自的文件系统
    {% asset_img A8A5CD64-5368-42EF-8C98-7636319E0E36.png %}
2. inode 和数据块
    1. inode 中存储了 links 数，即指向该 inode 的目录项数，links 数为 0 时，才会删除文件
        1. 可以通过 unlink 删除目录项到 inode 的链接
        2. 符号链接并不会增加 inode 中的链接计数，因为符号链接是被链接文件的路径
    2. inode 中包含了文件有关的所有信息，stat 中的大部分信息取自 inode
3. **文件名和 inode 编号存放在目录项（dentry）中**
4. 同一个文件系统下，重命名文件只会构造一个执行现有 inode 的目录项(dentry)并删除老的 dentry，因此**mv不会改变链接计数**
5. 一个 dentry 不能指向另一个文件系统的 inode，因为 dentry 中的 inode 编号必须是同一个文件系统，因此 hard link 不能跨文件系统
6. 任何一个目录文件至少包含 2 个 inode 链接计数（1 个文件名称 + 1 个 `.`），如果含有子目录，每有一个子目录，增加一个 inode 链接计数（`..`）
    {% asset_img 1647FEC4-90B5-4315-B5A4-BD0C576619F4.png %}


## 链接文件
1. 硬链接：指向文件 inode，符号链接指向另一个文件的路径
2. 引入软连接的原因：避开硬链接的限制
    1. 硬链接通常要求**链接和文件处于同一文件系统**
    2. **只有超级用户才允许对目录进行硬链接**

## 文件时间
1. 时间戳 atime, mtime, ctime
    1. atime 文件**数据**最后**访问**时间，如 read 会更新 atime
    2. mtime 文件**数据**最后**修改**时间，如 write 会更新 mtime
    3. ctime 文件**inode状态**最后更改时间，如果 chmod, chown, ln
2. 文件系统不维护对一个 inode 的最后一次**访问**时间，即 `access` 和 `stat` 并不改变任何一个时间戳
3. ctime 不能通过函数修改

## 设备特殊文件
1. 每个文件系统所在的存储设备都由其主、次设备号表示
    1. 主设备号：标识设备驱动程序
    2. 次设备号：标识特定子设备
2. 使用 major、minor 宏来访问主、次设备号
3. 文件系统中与每个文件名关联的 st_dev 值是文件系统的设备号
4. 只有字符特殊设备和块特殊设备才有 st_rdev 值，包含实际设备的设备号
