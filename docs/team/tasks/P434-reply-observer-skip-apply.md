---
id: P434
title: reply-observer-skip-focus 实施
agent: dev
category: code
phase: opsx-apply
change: reply-observer-skip-focus
specs: key-replies verification
anchor: openspec/changes/reply-observer-skip-focus/proposal.md
deltas: key-replies, verification
branch: task/P434-reply-observer-skip-apply
---

# P434 · 实施已接受的缺观测器检查替代

## 唯一依据与分工

完整阅读 `openspec/changes/reply-observer-skip-focus/` 全部规划、`docs/team/reviews/reply-observer-skip-focus-proposal.md`、V133/V134 报告。提案已在 main，不重新设计、不扩大范围。

你未参与提案。执行 tasks 1.1–3.2；**3.3 由另一非作者独立复验，不由你完成或勾选。**

## 范围

只改：

- `skills/teamsmith/tests/key-replies.sh`；
- 本 change 的任务勾选与 `docs/team/reports/P434-dev.md`。

不改 `proc-io.sh`、产品回复实现、其它测试、正式规格、CI、配置或文档。需要超出时写 BLOCKED，不自行扩张。

## 必做行为

1. 正常 bounded 先完成坏最新、不可枚举、不可读正文及权限恢复，再调用共享观测入口；观测入口在任何观测专属准备之前判能力。正常九臂与真实 full_scan 内核证据保持。
2. 短缺席样本走实际驱动通知、bounded 观测入口、full_scan probe 和正常结果消费者；三条具体诊断、两项未验证、无产品通过/失败、真实 rc 与结果行。不得手写日志或只测 `kr_io_supported`。
3. 清理前断言样本项目没有生成观测专属 `index.v1`，自有根没有第二份大存储；用一槽真实准备反例证明顺序错误会红，不恢复 400MB。
4. 删除 skip-path 两处完整 `bounded,flip` 和 SKIP 总数判据，删除 bounded 对 full_scan 的重复预告。正常九臂不转移运行模式。
5. 三类反例用 subshell 函数覆盖，不递归、不新增入口/开关；缺诊断、误算成功、误判产品失败都按具体身份报错并还原。无关 SKIP 不能顶数。
6. 父级样本失败必须产生具名 `✗ skip-path：缺席诊断/分类不完整` 并进入 FAIL；一次性外部 scratch 另证：损坏时出现，吞掉样本失败时即使 rc=1 也不得出现。rc 本身不是证据。
7. 外部 scratch 留在 `skills/teamsmith/tests/` 内或复制完整 tests，确保能解析 `lib/proc-io.sh`。子样本使用 `== reply-observer absence sample 结果 ==`，其输出只写自己的文件，不能进入 smoke 或 §36 的通用结果读取。
8. 计数按 7→6 的明确映射，子样本 `✓0 ✗0 SKIP2` 不并入父级；不凑旧总数，不增加第七条来包住顺序反例。

## 验收

不要先跑旧整组。实现后在固定隔离环境执行并保留完整磁盘日志：

```bash
bash -n skills/teamsmith/tests/key-replies.sh
bash skills/teamsmith/tests/key-replies.sh --select skip-path
bash skills/teamsmith/tests/smoke.sh --select 62 --keep </dev/null
bash skills/teamsmith/tests/spec-refs.sh --check
bash skills/teamsmith/tests/section-select.sh --check
openspec validate --all
openspec validate reply-observer-skip-focus --type change --strict
bash skills/teamsmith/tests/ledger-ban.sh --names-file <主检出名单>
git diff --check
```

容器使用 `distrobox-host-exec podman`，不要直接 podman；日志和 TMPDIR 落本次专属 `/var/tmp` 目录。§62 必须非 FAST，逐项核对正常 bounded、九臂坏/恢复、full_scan 内核读量和其它回复组没有丢失。无需追加 UI 全套、全量、夜间或 61b。

## 交付

小步提交。`docs/team/reports/P434-dev.md` 先给结论，附真实命令与日志、三条父级消费侧原始输出、旧执行删除点、三层计数和实测耗时；无法比较的旧分支时间明确未知。通知 PM 后由另一非作者复验。

不合并、不归档、不发布、不推 main；真实归档仍需用户确认。
