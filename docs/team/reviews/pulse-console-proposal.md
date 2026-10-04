# pulse-console · PM proposal review

```
change:  pulse-console   phase:  propose   task: P11 (agent: dev2)
reviewer: pm             verdict: **ACCEPTED**
```

## Commands run (real output)

```console
$ openspec validate --all --strict            （在提案分支 worktree）
Totals: 13 passed, 0 failed (13 items)
$ openspec change show pulse-console          → 五件齐全（含 MODIFIED/REMOVED 逐名手核与需求→任务覆盖图）
$ # scratch 副本：
$ openspec archive -y pulse-console           → Specs updated successfully（试归档应用）
```

## Findings, one line per checklist item

1. **忠实于已批设计稿**（docs/team/designs/pulse-console.md，用户 2026-09-16 批）——三页+设置浮层+消息入口+
   鼠标+i18n+响应式四档全在；"只读+三动作"纪律在；"坏数据不拖垮整屏"在（1.2 区块隔离 `—`）。
2. **D26 前置条件被放在了它该在的位置**——B1 是独立第一批，任务 0.1 要求把"改前实测"（7.2s/6.3s、
   按键失真翻转夹具的红日志）贴进报告才算开始；消息入口（B2）明确排在其后。
3. **可证伪**：每条任务带"能跑挂它的命令"；翻转夹具（1.4 按键失真、0.1 改前计时）是验收的一部分；
   布局四档快照 × 深浅主题进测试；字符串键集合断言进门禁。
4. **覆盖与边界**：v1 砍线用 `[v1.1]` 非勾选项如实标注（钻详情页、队列丢弃、里程碑条等）；OWNERSHIP
   路径授权写明（panel 源码/bundle/cmd-watch.sh/config.md 显式授予，tests 归 dev）；`--print`/`--json`
   契约钉死（0 ESC/退出 0/不写 state/JSON 键只增）；panel.conf 与 config.sh 的边界清晰。
5. **规格操作安全**：MODIFIED/REMOVED 块已在提案里逐名对照 specs（D23 的洞它自己先防了）；试归档应用成功。

## Conditions for apply

1. 三批三个任务书（P12=B1、P13=B2、P14=B3），每批独立独立验证（verify 不自己验自己的批——按独立性规矩换人或我验）。
2. B1 的报告没有"改前实测+翻转红日志"= 直接打回，不看代码。
3. `--print`/`--json` 的逐字节兼容（除时间戳与只增字段）每批都要重钉。
