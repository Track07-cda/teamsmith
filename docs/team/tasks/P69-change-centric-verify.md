# P69 · change-centric-discipline 独立验证（verify 阶段，补 D31 那一步）

```
task:   P69
agent:  （等席位；**不得派给 P23/P24/P45 的作者**：propose=dev-bob、apply=P24 dev-bob + P45 dev2）
issue:
change: change-centric-discipline
specs:  dispatch#…（一条 change id / anchor / delta 单写者）/ verification#…（不许自验）/ board-and-status#A change's tasks are grouped in the digest
phase:  verify
anchor: change
deltas: dispatch, verification, board-and-status
grant:  docs/team/reports/P69-<agent>.md · docs/team/reports/P69-<agent>/**（只写报告与证据）
deps:   P23（propose）· P24 + **P45（B2，已合并）**
status: todo（等席位）
budget: 一个工作块
```

> 本地模式：不 push。

## 要对抗性验证的（给可复现命令 + 原始输出）

1. **dispatch 的三道守卫**（该 change 的核心）：① 一个任务两个 `change:` → 拒；② 无 change 的 brief 必须
   `specs:` 锚或 `anchor: none (infra)` + 理由 → 否则拒；③ **同一 delta 文件两个未结束任务** → 拒（点名双方）；
   ④ **verify 任务与 apply 作者同一人** → 拒（`--force` + 一行审计）。**每条都要红/绿两侧**。
2. **`team change status <id>`**：全部任务 done 时 exit 0，否则非 0；digest 的 `[6]` 与
   `team change status` 的 token **一致**（用同一个 fixture 对账）。
3. **B2 的界**：token ≤8 + 「+N」尾巴；change 列表有界；`[1]–[5]` 段头逐字节不变；
   面板在窄宽度下**丢弃 token 行而不是重排**。
4. **archive 前置**：一个 change 的兄弟任务未结束时，archive 阶段任务不能置 done。
5. **零回归**：`openspec validate --all --strict`、FAST + 全量 smoke（注意：**当前 main 上有一条既有 lint 红
   （`container-tmux.sh` 的 fpcheck 根，P64 在修）**——如仍红，点名区分，不算本 change 的回归）。

## 至少三条变异（红→绿原始输出）

- 去掉 delta 单写者检查 → 双写场景不再被拒（红侧）；
- 让 `team change status` 在未全 done 时 exit 0 → 断言红；
- 让面板在窄宽度下重排（而不是丢弃）→ 断言红；
- 还原后 `git status --porcelain` 干净。
