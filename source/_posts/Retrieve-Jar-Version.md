---
title: Retrieve Jar Version
date: 2021-09-14 23:05:06
tags: java, maven
---
# 获取 Jar 包版本号


<!-- vim-markdown-toc GitLab -->

* [背景](#背景)
* [方案](#方案)
    * [读 maven pom 文件](#读-maven-pom-文件)
    * [反射](#反射)
        * [maven 打包写入版本号](#maven-打包写入版本号)
        * [使用反射获取版本号](#使用反射获取版本号)
    * [方案对比](#方案对比)
* [参考](#参考)

<!-- vim-markdown-toc -->

<!-- vim-markdown-toc GitLab -->

<a name='-背景'></a>

<!-- vim-markdown-toc -->
## 背景

在运行时获取当前 Jar 包的版本信息是很常见的诉求，用于观测等场景。常见的方案包括读 maven 的 pom 文件和反射两种方式。

<!-- vim-markdown-toc GitLab -->

<a name='-方案'></a>

<!-- vim-markdown-toc -->
## 方案

<!-- vim-markdown-toc GitLab -->

<a name='-读-maven-pom-文件'></a>

<!-- vim-markdown-toc -->
### 读 maven pom 文件

此方案的原理是，maven 在打包时会在 jar 包下创建一个命名为 `META-INF/maven.$groupId.$artifactId/pom.properties` property 文件，以 `netty` 为例，存在如下文件，文件名为 `META-INF/maven.io.netty.netty.properties/pom.properties`

```proeprties
version=3.7.0.Final
groupId=io.netty
artifactId=netty
```

在代码中从 classpath 中读取该 Properties 文件，代码来自 [StackOverflow](https://stackoverflow.com/questions/5270611/read-maven-properties-file-inside-jar-war-file)

```java
String path = "META-INF/maven.io.netty.netty/pom.properties";

Properties prop = new Properties();
InputStream in = ClassLoader.getSystemResourceAsStream(path );
try {
  prop.load(in);
} 
catch (Exception e) {

} finally {
    try { in.close(); } 
    catch (Exception ex){}
}
System.out.println("maven properties " + prop);
```


<!-- vim-markdown-toc GitLab -->

<a name='-反射'></a>

<!-- vim-markdown-toc -->
### 反射

通过 `Foo.class.getPackage()#getSpecificationVersion` 方法获取类所在 jar 包的版本。本方法要求 jar 包中包含 Manifest 文件。具体做法如下。
1. 在 maven 打包过程中，向 Manifest 文件中写入 `Version`
2. 在需要获取版本的地方，使用反射获取版本号

<!-- vim-markdown-toc GitLab -->

<a name='-maven-打包写入版本号'></a>

<!-- vim-markdown-toc -->
####  maven 打包写入版本号

在 maven 的 `pom.xml` 文件加入如下内容：
```xml
  <build>
    <plugins>
      <plugin>
        <groupId>org.apache.maven.plugins</groupId>
        <artifactId>maven-jar-plugin</artifactId>
        <version>3.2.0</version>
        <configuration>
          <archive>
            <manifest>
              <addDefaultSpecificationEntries>true</addDefaultSpecificationEntries>
            </manifest>
          </archive>
        </configuration>
      </plugin>
    </plugins>
  </build>
```

<!-- vim-markdown-toc GitLab -->

<a name='-使用反射获取版本号'></a>

<!-- vim-markdown-toc -->
#### 使用反射获取版本号
如下图的 `getVersion` 方法获取给定 class 的 jar 包版本
```java
    public static String getVersion(Class clazz) {
        return clazz.getPackage().getSpecificationVersion();
    }
```

<!-- vim-markdown-toc GitLab -->

<a name='-方案对比'></a>

<!-- vim-markdown-toc -->
### 方案对比
1. 方案一 maven 的实现，不需要 jar 包提供方额外做什么事情，但是其他 build 方式不支持
2. 方案二是 java 官方的实现，需要 jar 包提供方提供 Manifest 文件，但是版本本身是强依赖、获取方式简单，个人推荐这种方式

<!-- vim-markdown-toc GitLab -->

<a name='-参考'></a>

<!-- vim-markdown-toc -->
## 参考
1. [Maven Archiver Manifest](https://maven.apache.org/shared/maven-archiver/index.html#manifest)
2. [Setting Package Version Information](https://docs.oracle.com/javase/tutorial/deployment/jar/packageman.html)
