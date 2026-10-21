# P357 · 发布门禁的 4 条红：归因 + 最小修复（发布阻塞）

task: P357
agent: dev3
phase: apply
category: analysis
change: -
specs: verification#The gate judges behaviour only, and never reports a skip as a pass
anchor: none (infra) — 只归因 + 最小修复
deltas: -
branch: task/P357-release-reds

## 证据（PM 已保存，不许再重跑整套）

串行 + 默认约定 + 钉死镜像，冻结树 `65e0398b` 的整套运行（3h50m）结果：

```
账本自查： 134 段收口 · 增量 ✓4935 ✗4 SKIP18 ｜ 结果行 ✓4935 ✗4 —— 一致
== 结果 ==  ✓ 4935  ✗ 4
  ✗ 51c 打断入口夹具有失败（rc=1）
  ✗ 57 delivery-truth 有失败（rc=1）
  ✗ 61b 路由翻转变异有失败（rc=1；RESULT pass=200 fail=1 selected=flip）
  ✗ 62 key-replies 有失败（rc=1）
```

全量日志：`$HOME/.cache/logs031/ser/full.log`（宿主上，可直接 grep；里面已带每段尾部的失败明细）。**容器的现场目录没保住**（当时 TMPDIR 是容器内的默认路径），所以复现要你自己造。

同一个树**上一次**整套（同镜像、同样串行）是 **✓4927 ✗13**，即这四段里有**数量会变**的成分——这个差异本身是线索，别把它当噪声放过。

## 要回答的（每段一格）

对 `51c`、`57`、`62`、`61b` 各给：

1. **在宿主上单独跑一次**（私有 `TMPDIR` 在 `/var/tmp` 下、默认锁名、串行）：红/绿？贴命令与结果行。若绿，再跑一次看是不是**容器独有**或**时序相关**。
2. **定性**：产品缺陷 / 夹具缺陷（含「以默认值或独自运行或容器环境为前提」） / 环境差异。依据要具体到断言与现场。
3. **最小修法**（若你判是缺陷）：改哪一处、为什么这是最小、红侧怎么造。
4. `61b` 那条要特别处理：日志里给了三条 `FAIL <arm 名>`（`monitor-missing-A-unavailable`、`pm-publication-failure-stops-uncommitted`、`flip-template-shadow-red`）。**逐条判**：是「变异没被抓住（=真覆盖洞）」还是「臂本身跑不起来」。若是覆盖洞，指出是哪一段本该抓它的断言失效了。

## 边界与节奏

- 写集：`docs/team/reports/P357-dev3.md` 与你判定为最小修复的那几处（**每处改前先报告一次判断**，别一次改四段；`smoke.sh` 现在没别的写者）。
- **不要重跑整套**；单段复现可以，`61b` 除外（它一次 82 分钟，你最多跑一次，且先用日志判断值不值得）。
- 不提高任何时限、不放宽断言、不新增夹具。
- 报告先给四格结论表，再给证据。
