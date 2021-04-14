<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

- [背景](#%E8%83%8C%E6%99%AF)
  - [为什么要做这个调研](#%E4%B8%BA%E4%BB%80%E4%B9%88%E8%A6%81%E5%81%9A%E8%BF%99%E4%B8%AA%E8%B0%83%E7%A0%94)
  - [Blackbox Exporter 工作原理](#blackbox-exporter-%E5%B7%A5%E4%BD%9C%E5%8E%9F%E7%90%86)
- [调研目的](#%E8%B0%83%E7%A0%94%E7%9B%AE%E7%9A%84)
- [调研方案](#%E8%B0%83%E7%A0%94%E6%96%B9%E6%A1%88)
- [结论](#%E7%BB%93%E8%AE%BA)

---

title: Blackbox Exporter Url Probe 调研
date: 2021-04-14 14:28:58
tags:

- balckbox_exporter
- prometheus
- monitoring

---

## 背景

### 为什么要做这个调研

Q2 计划做域名的拨测，需要能够对给定域名或 url 进行探活，将探活结果转换成指标收集到监控系统中。在 Prometheus 的生态中，Blackbox Exporter 是专门为了探针场景设计的，本文对使用 Blackbox_exporter 进行拨测进行可行性调研。

### Blackbox Exporter 工作原理

Blackbox Exporter  是 [Multi-Part Exporter Pattern](https://prometheus.io/docs/guides/multi-target-exporter/)，这种模式下 Blackox Exporter 作为 同时暴露 以下两类指标。Blackbox Exporter 本身不维护需要探哪些目标，而是作为被探目标的 Proxy，由 Prometheus 主动发起抓取动作。

1. Blackbox Exporter 自身的指标，如探针是否存活、探针任务相关指标
2. 被探针探的 target 的指标，例如探活是否成功(`probe_success`)、探活耗时、http 探活状态码等

## 调研目的

1. 验证 Blackbox Exporter 是否能对域名进行探活，并生成指标
2. 验证 Blackbox Exporter 能够探测 https url

## 调研方案

调研方案架构如下图，Blackbox Exporter 和 Prometheus 都为本地部署。

1. Blackbox Exporter 作为 Proxy 去执行真正的探活动作并生成指标
2. Prometheus 为 Blackbox Exporter 配置单独的抓取任务，告诉 Blackbox Exporter 应该去探哪个 url
   {% asset_img architecture.png [方案架构] %}

## 结论

1. Blackbox Exporter 可以用任意指定的 url 进行探活，如 `https://baidu.com`，使用何种协议与指定的 `module` 有关
   1. Blackbox Exporter 的 `http_2xx` module 同时支持 http 和 https，不指定协议的时候默认使用 http 进行探活
   2. Blackbox Exporter http/https 探活同时支持 `GET` 和 `POST` 两种方式，通过 `module` 参数在采集时指定
   3. Blackbox Exporter 在探活 http 时可以指定 `Http Header`，如 `Origin: example.com`
   4. Blackbox Exporter 支持通过 http 状态码、 响应体、响应头来自定义某个 url 是否成功
      1. 成功状态码默认为 2xx，可以通过配置修改
      2. 可以通过 `fail_if_body_matches_regexp` 和 `fail_if_body_not_matches_regexp` 来指定特定响应体才成功
      3. 可以通过 `fail_if_header_matches_regexp` 来指定 `fail_if_header_not_matches_regexp` 来执行特定响应头才成功
2. Blackbox Exporter 具备一定的 debug 能力，能够 debug 某个 url 探活失败的原因
   1. Blackbox Exporter 暴露 `probe_success` 来标识本次探活是否成功
   2. Blackbox Exporter 暴露 `probe_failed_due_to_regex` 来标识探活失败的原因是否是正则匹配失败引起的，即请求返回了 2xx 但是响应头或响应体内容不如何制定的正则，可以用这个指标做报警，人工接入
   3. Blackbox Exporter 保存了最近 100 个（数量可配置）请求和失败请求的历史，能看到请求中的 debug log，对排查问题很方便，通过 `http://<blackbox_exporter_host>:<port>` 访问即可
