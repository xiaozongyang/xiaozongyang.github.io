---
title: 第 5 章 - 标准 IO 库
date: 2021-10-09 18:22:15
tags:
    - apue
    - unix
    - 读书笔记
---
1. 标准 IO 库的操作围绕**流** (stream) 进行
2. 流的定向（orientation）决定了所读、所写的字符是单字节还是多字节
    1. 流最初被创建时，没有定向
    2. 如果在**未定向的流**上使用一个**多/单字节的 IO 函数**，则将该留的定向设置为**宽/字节定向**
    3. `freopen` 函数可以**清除**一个流的定向
    4. `fwide` 函数可以**设置**流的定向，但**不改变已定向流的定向**
3. 缓冲：尽可能减少使用 read 和 write 系统调用的次数
    1. 缓冲类型
        1. 全缓冲：填满标准 IO 缓冲区后才进行实际 IO 操作
            1. 驻留在磁盘上的文件通常由标准 IO 库实施全缓冲
            2. flush 说明标准 IO 缓冲区的写操作，可以标准库自动 flush（如缓冲区填满）或者调用 fflush 进行 flush
        2. 行缓冲：输入和输入遇到**换行符**时，标准 IO 库执行 IO 操作
            1. 流涉及到一个终端时（如 stdin, stdout）时，通常使用行缓冲
            2. 行缓冲的限制
                1. 标准 IO 库收集每一**行的缓冲区长度是固定**的，如果缓冲区填满了即使还没遇到换行符也进行 IO 操作
                2. 任何时候只要通过标准 IO 从(a)一个不带缓冲的流或(b)一个行缓冲的流（需要从内核得到数据）**得到输入数据**，那么就会 **flush 所有行缓冲输出流**
        3. 不带缓冲：不对字符进行缓冲存储，stderr 通常不带缓冲
4. ISO C 要求的缓冲特征
    1. 当且仅当当前标准输入和标准输出不指向交互式设备时，他们才是全缓冲的
    2. 标准错误不能是全缓冲的，通常是不带缓冲
    3. 若是指向终端设备的流，则是行缓冲的，否则是全缓冲
5. `setbuf`/`setvbuf` 可以修改缓冲类型
    1. `setbuf` 打开或关闭缓冲机制，设置的缓冲区长度为 BUFSIZ（由 stdio.h 定义），通常设置之后就是全缓冲的
    2. `setvbuf` 可以设置上述任何一种缓冲类型和缓冲区长度，也可以有标准 IO 库自动分配合适的缓冲区长度
    {% asset_img 918D8379-3C7F-4B30-8BCF-BD5C7EB831A5.png %}
6. 打开流的函数：`fopen`, `freopen`, `fdopen`
    1. *type* 参数控制打开流的选项
        {% asset_img C362332D-5353-44AD-B99B-5B02428F91AA.png %}
    2. 如果多个进程用标准 IO 追加写方式打开同一个文件，每个进程的数据都将正常地写到文件中
    3. 读写类型（+）打开文件时的限制
        1. **输出后面如果没有 fflush/fseek/fsetpos/rewind，不能直接跟随输入**
        2. 如果读操作没有达到文件尾端，或没有 fseek/fsetpos/rewind 不能直接跟随输出
    4. fopen 无法控制文件的访问权限(RWX)
7. 关闭流：`fclose`，**flush** 缓冲区中的**输出**数据，**丢弃**缓冲区的中的**输入**数据
8. 当一个进程**正常中止**（exit 或从 main 函数返回），则所有写缓冲数据的标准 IO 流都被 **flush**，所有打开的标准 IO 流都被**关闭**
9. 流的非格式化字符 IO
    1. 每次一个字符
        1. 输入 getc/fgetc/getchar
            1. getc 不应该是有副作用的表达式
            2. fgetc 一定是函数，可以作为参数传给其他函数
            2. 返回 **int** 需要和 EOF 做比较
        2. 将字符压回流 ungetc
            1. 回送的字符不一定是上次读到的字符
            2. 不能回送 EOF
        3. 输出 putc/fpuc/putchar
    2. 每次一行
        1. 输入 gets/fgets
            1. fgets 遇到换行或者读到 n-1 个字符时返回
            2. 不推荐使用 gets，会造成缓冲区溢出问题
        2. 输出 puts/fputs
            1. fputs 不写终止符(null)，需要自己写换行符
            2. puts 不写终止符，自动添加换行符
10. 流的二进制 IO：解决字符 IO 场景遇到 null 停止的问题，fread/fwrite
    - 不同机器或者不同编译程序和系统的区别导致，对象的成员变量偏移量不一样，从而无法正常工作，因此需要应用程序进行**序列化**和**反序列化**
11. 定位流：ftell/fseek/ftello/feeko/fgetpos/fsetpos/rewind 修改读写文件流的位置
12. 格式化 IO：printf/fprintf/dprintf/sprintf/snprintf
13. 创建临时文件：`tmpnam`/`tmpfile`/`mkdtemp`/`mkdstemp`
    1. 重复调用会清楚静态区，因此文件名应该使用 `char[]  f = "foo"` 而不是 `char *f = "foo"`
    2. tmpfile 会先调用 tmpnam 生成一个唯一路径名，使用该路径名创建一个文件，然后立即 unlink 它，（存在时间窗口，不推荐使用）
    3. mkdtemp/mkstemp 创建的临时文件不会 unlink
14. 内存流：没有底层文件，但是可以使用标准 IO 库读写
    1. fmemopen 创建内存流，可以指定内存流开始位置、大学、读写类型
    2. 任何时候需要增加流缓冲区中的数据量以及调用 fclose, fflush, fseek, fseeko, fsetpos 时都会**在当前位置写入一个 null 字节**
    3. 因为避免了内存溢出（缓冲区大小是固定的），内存流分非常适用于创建字符串
