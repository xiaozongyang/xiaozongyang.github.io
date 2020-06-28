---
title: hello-jmh
date: 2020-06-29 00:43:31
tags:
- java
- jmh
- benchmark
- kotlin
---
# Hello Jmh
> 本文将介绍如何使用 jmh 工具做简单的 benchmark

## 主要步骤
1. 在项目中引入依赖
2. 编写 benchmark 方法
3. 配置 pom
4. 构建并启动 benchmark

### 引入依赖
1. 在 maven 中添加如下依赖
```xml
<properties>
    <jmh.version>1.23</jmh.version>
</properties>

<dependency>
    <groupId>org.openjdk.jmh</groupId>
    <artifactId>jmh-core</artifactId>
    <version>${jmh.version}</version>
</dependency>
```
2. 编写 benchmark
```kotlin
package io.xiaozy

import org.openjdk.jmh.annotations.Benchmark
import org.openjdk.jmh.annotations.BenchmarkMode
import org.openjdk.jmh.annotations.Fork
import org.openjdk.jmh.annotations.Measurement
import org.openjdk.jmh.annotations.Mode
import org.openjdk.jmh.annotations.OutputTimeUnit
import org.openjdk.jmh.annotations.Scope
import org.openjdk.jmh.annotations.State
import org.openjdk.jmh.annotations.Threads
import org.openjdk.jmh.annotations.Warmup
import java.util.*
import java.util.concurrent.TimeUnit

/**
 * @author xiaozy01
 * @date 2020-06-18
 */
@State(Scope.Benchmark)
@OutputTimeUnit(TimeUnit.SECONDS)
@BenchmarkMode(Mode.Throughput)
open class SlaveReaderBenachmark {

    companion object {
        private const val ITERATION_COUNT = 10
        private const val WARMUP_COUNT = 10
        private const val THREAD_COUNT = 4
        private const val FORK_COUNT = 4
    }

    var singleDb: JdbcTemplate = createSingleDb()
    var connectionClusterDb: JdbcTemplate = createConnectionClusterDb()
    var datasourceClusterDb: JdbcTemplate = createDataSourceClusterDb()

    @Benchmark
    @Fork(value = FORK_COUNT)
    @Threads(value = THREAD_COUNT)
    @Warmup(iterations = WARMUP_COUNT)
    @Measurement(iterations = ITERATION_COUNT)
    fun concate(): String {
        return "a" + " " +"b";
    }

    @Benchmark
    @Fork(value = FORK_COUNT)
    @Threads(value = THREAD_COUNT)
    @Warmup(iterations = WARMUP_COUNT)
    @Measurement(iterations = ITERATION_COUNT)
    fun format(): String {
        return java.lang.String.format("%s %s", "a", "b")
    }

}
```

3. 配置 pom
```xml
    <build>
        <plugins>
            <!--
                1. Compile Kotlin sources first.
            -->

            <plugin>
                <artifactId>kotlin-maven-plugin</artifactId>
                <groupId>org.jetbrains.kotlin</groupId>
                <!--
                   Put an approriate Kotlin compiler version here.
                 -->
                <version>${kotlin.version}</version>

                <executions>
                    <execution>
                        <id>process-sources</id>
                        <phase>generate-sources</phase>
                        <goals>
                            <goal>compile</goal>
                        </goals>
                        <configuration>
                            <sourceDirs>
                                <sourceDir>${project.basedir}/src/main/kotlin</sourceDir>
                            </sourceDirs>
                        </configuration>
                    </execution>

                    <execution>
                        <id>process-test-sources</id>
                        <phase>test-compile</phase>
                        <goals>
                            <goal>test-compile</goal>
                        </goals>
                    </execution>
                </executions>
            </plugin>

            <!--
                2. Invoke JMH generators to produce benchmark code
            -->

            <plugin>
                <groupId>org.codehaus.mojo</groupId>
                <artifactId>exec-maven-plugin</artifactId>
                <version>1.2.1</version>
                <executions>
                    <execution>
                        <phase>process-sources</phase>
                        <goals>
                            <goal>java</goal>
                        </goals>
                        <configuration>
                            <includePluginDependencies>true</includePluginDependencies>
                            <mainClass>org.openjdk.jmh.generators.bytecode.JmhBytecodeGenerator</mainClass>
                            <arguments>
                                <argument>${project.basedir}/target/classes/</argument>
                                <argument>${project.basedir}/target/generated-sources/jmh/</argument>
                                <argument>${project.basedir}/target/classes/</argument>
                                <argument>${jmh.generator}</argument>
                            </arguments>
                        </configuration>
                    </execution>
                </executions>
                <dependencies>
                    <dependency>
                        <groupId>org.openjdk.jmh</groupId>
                        <artifactId>jmh-generator-bytecode</artifactId>
                        <version>${jmh.version}</version>
                    </dependency>
                </dependencies>
            </plugin>

            <!--
                3. Add JMH generated code to the compile session.
            -->

            <plugin>
                <groupId>org.codehaus.mojo</groupId>
                <artifactId>build-helper-maven-plugin</artifactId>
                <version>1.8</version>
                <executions>
                    <execution>
                        <id>add-source</id>
                        <phase>process-sources</phase>
                        <goals>
                            <goal>add-source</goal>
                        </goals>
                        <configuration>
                            <sources>
                                <source>${project.basedir}/target/generated-sources/jmh</source>
                            </sources>
                        </configuration>
                    </execution>
                </executions>
            </plugin>

            <!--
                4. Compile JMH generated code.
             -->

            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-compiler-plugin</artifactId>
                <version>3.8.0</version>
                <configuration>
                    <compilerVersion>${javac.target}</compilerVersion>
                    <source>${javac.target}</source>
                    <target>${javac.target}</target>
                    <compilerArgument>-proc:none</compilerArgument>
                </configuration>
            </plugin>

            <!--
                5. Package all the dependencies into the JAR
             -->

            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-shade-plugin</artifactId>
                <version>3.2.1</version>
                <executions>
                    <execution>
                        <phase>package</phase>
                        <goals>
                            <goal>shade</goal>
                        </goals>
                        <configuration>
                            <finalName>${project.artifactId}-benchmark</finalName>
                            <transformers>
                                <transformer implementation="org.apache.maven.plugins.shade.resource.ManifestResourceTransformer">
                                    <mainClass>org.openjdk.jmh.Main</mainClass>
                                </transformer>
                                <transformer implementation="org.apache.maven.plugins.shade.resource.ServicesResourceTransformer"/>
                            </transformers>
                            <filters>
                                <filter>
                                    <!--
                                        Shading signed JARs will fail without this.
                                        http://stackoverflow.com/questions/999489/invalid-signature-file-when-attempting-to-run-a-jar
                                    -->
                                    <artifact>*:*</artifact>
                                    <excludes>
                                        <exclude>META-INF/*.SF</exclude>
                                        <exclude>META-INF/*.DSA</exclude>
                                        <exclude>META-INF/*.RSA</exclude>
                                    </excludes>
                                </filter>
                            </filters>
                        </configuration>
                    </execution>
                </executions>
            </plugin>
        </plugins>
    </build>
```

4. 构建并启动
- 构建 `mvn package`
- 启动 `java -jar ${project.artifactId}-benchmark.jar`，`${project.artifactId}` 为 benchmark 所在module name

## References
1. https://openjdk.java.net/projects/code-tools/jmh
