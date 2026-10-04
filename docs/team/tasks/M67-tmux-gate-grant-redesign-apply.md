# M67 · tmux-gate-grant-redesign apply（B1 判定+token → B2 夹具/lint/翻转）

```
task:   M67
agent:  dev-bob
issue:
change: tmux-gate-grant-redesign      # 提案已验收：docs/team/reviews/tmux-gate-grant-redesign-proposal.md（ACCEPTED）
specs:  boundary#A destructive tmux call is decided by the object it targets, never by an inherited environment / boundary#The gate's actions are logged / boundary#Destructive gate fixtures never touch the shared default socket
phase:  apply
anchor: change
deltas: boundary
grant:  scripts/shim/tmux · scripts/team · scripts/lib/cmd-config.sh · scripts/lib/cmd-project.sh（doctor 行）· scripts/lib/common.sh（如确需）· tests/smoke.sh（§31c 及其邻段，append-only）· tests/container-tmux.sh · tests/tmux-lint.pl · skills/teamsmith/references/config.md · skills/teamsmith/references/troubleshooting.md · skills/teamsmith/CHANGELOG.md
deps:   M63（propose，已合并 680deac）
status: todo
budget: 一个工作块；做不完交 PARTIAL（逐段列出完成/未完成）
```

> 本地模式：不 push。设计真源 = `openspec/changes/tmux-gate-grant-redesign/design.md`（D1–D8）与
> `tasks.md`（B1/B2 逐项）；**以它们为准，不要凭本简述发挥**。

## 关键纪律（违反任何一条 = 返工）

1. **环境变量不再授权**：shim 不读 `TEAM_ALLOW_DESTRUCTIVE_TMUX`；`scripts/team:19` 的 export 删掉；
   调用方环境里/server 全局环境里有这个键，**对判定零影响**（要有回归夹具证明）；
   `cmd-config.sh:65` 保留该行但改成退役说明（refuse 类不变）。
2. **判定按目标**：`kill-server` 与 `kill-session -a` 对共享默认 socket 永远 exit 64；
   其余三个子命令只在"`-t` 有效值非空、session 段字面等于绑定的 `TEAM_SESSION`"时放行
   （`act=allowed-owned`）；不可证明的一律拒绝。M41 的私有 socket 直通与两个假隔离形态**原样保留**。
3. **token 规则**：`--teamsmith-allow-destructive` **只在全局参数位**识别；消费后从 argv 剥掉、
   不进被执行进程的环境、记 `act=explicit-flag`；`=1` 形式不认识（fail closed）；
   **子命令之后的同名词是数据**（原样透传）。带 token 的调用对任何 socket 都执行（调用者的显式授权）。
4. **夹具**：refused/allowed-owned 探针把 `TEAM_TMUX_REAL` 钉到 argv 记录 stub（错判 = 执行 shell 脚本）；
   真实破坏调用只在私有 socket 或容器；**泄漏形状在容器里复现**（宿主指纹逐字节不变）。
   **严禁**把任何破坏性 argv 对着真实默认 socket 跑——包括"演示"（PM 已经用第 7 次死亡交过学费）。
5. **`override` 一词从闸门词汇表消失**（日志、报错、文档、注释）；审计词汇 = `pass` / `allowed-owned` /
   `refused` / `explicit-flag`。
6. **doctor 行**：运行中的 server 全局环境还带着退役键 → 提示一行（只读；tmux 缺席时可见 SKIP）。
7. `smoke.sh` 只 **append** 新段（§31c 的既有断言要改判定时，按 tasks.md 的逐项指示改，不许顺手重构别的段）。
8. 每个 B 批次结束：`TEAM_SMOKE_FAST=1 bash tests/smoke.sh </dev/null` 绿 + 小步提交；交付前跑一次全量。

## Acceptance（真跑，贴原始输出）

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
bash skills/teamsmith/tests/smoke.sh </dev/null
bash skills/teamsmith/tests/container-tmux.sh --selftest     # 无容器时可见 SKIP
perl skills/teamsmith/tests/tmux-lint.pl                      # 若该文件存在/有此入口
# 翻转（每条给红→绿原始输出）：
#   F1 环境里放 TEAM_ALLOW_DESTRUCTIVE_TMUX=1 + 默认 socket kill-server → 必须仍 exit 64
#   F2 kill-server 带 --teamsmith-allow-destructive（全局位）→ 执行（stub 收到）+ act=explicit-flag
#   F3 同名词出现在子命令之后（send-keys 载荷）→ 原样透传，不被剥
#   F4 -t teamsmith:win（绑定身份）→ allowed-owned；-t "" / -t other:win → exit 64
```

## Deliverables

- 按 `tasks.md` B1/B2 逐项的实现 + 翻转证据
- 报告 `docs/team/reports/M67-dev-bob.md`（逐项核对表 + 翻转原始输出 + 全量门禁结果行）

## Boundaries

- 只碰 `grant:` 列出的路径；`panel/**`、`extension/**` 不动；
- 不 push；不改 `docs/team/**`（PM 的台账）；发现设计与现实矛盾 → `BLOCKED:` 交回 PM。
