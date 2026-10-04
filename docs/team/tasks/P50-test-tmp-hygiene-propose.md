# P50 · 测试不许漏 /tmp：夹具的临时目录要回收 + 占用可见（propose）

```
task:   P50
agent:  （等席位）
issue:
change: test-tmp-hygiene
specs:  -
phase:  propose
anchor: change
deltas: verification, watchdog
deps:   2026-09-22 09:50 的 /tmp 100% 事故（dev3 的 ENOSPC 假红）
status: todo（等席位）
budget: 小到中（一个提案包）
```

> 本地模式：不 push。**只 propose。**

## 现场（PM 今日实测，提案要引用数字）

- **`/tmp` 是一个 15G 的 tmpfs**，09:50 时 **100% 满**（0 字节可用、inode 也满：3 811 434 中只剩 4 645）；
  dev3 的 `panel-p21 choices` 因此吃了 **ENOSPC 假红**（真红/假红分不清 → 门禁可信度受损）；
- 占用构成（PM 逐个量过）：**`config-cli.*` 607 个目录 / 3 204 MB**（`tests/config-cli.sh` 每次运行留一个
  **44MB** 的目录，**从不回收**；清理后仍在被新运行持续生成）；**`review-*` 127 项 / 约 6.0 GB**
  （历史复验检出：M4.7r/M5.1/M5.2/M6.2–M6.5 等，单份 900+MB）；`teamsmith-smoke.*` 3 份 / 134MB（其中一份是
  当时**正在跑**的门禁，不能删）；
- **孤儿夹具进程**也一起暴露：`/tmp/review-M58` 里挂着 `tmux new-session -d -s teamsmith-smoke-anchor` + `sleep 100000`
  （**23 小时**），`/tmp/m39-6k.*` 三组 `-zsh` + `bash --noprofile --norc`（**69 小时**）；
- **PM 的处置**：只删"**确认无进程占用**且**30 分钟未动**"的（腾出 ~7.0GB，`/tmp` 回到 33%），
  在用的门禁目录一个没碰；但**这是人工救火，不是机制**。

## 要裁决的设计问题

1. **夹具必须回收自己的临时目录**：`tests/*.sh`（尤其 `config-cli.sh`）创建的临时根必须有
   `trap … EXIT INT TERM` 清理；被强杀（`KILL`）留下的残骸要有**可回收的判据**（名字带指纹 + 年龄 + 无占用），
   并有一个**清理入口**（例如 `tests/tmp-hygiene.sh --sweep`，只删"年龄 > X 且无进程占用"的自家前缀）。
2. **不许删别人的东西**（D37 的同族）：sweep 只碰**自家前缀**（`config-cli.*`/`teamsmith-smoke.*`/`review-*` 等），
   且必须**先证明无占用**；删之前打印清单与总量（可审计）。
3. **占用要可见**：门禁开始/结束时打印**自己的**临时根用量；`team doctor` 增加一行**临时根可用空间**
   （`/tmp` 是共享的 tmpfs，满了会让测试假红——这正是今天的事故）；阈值与读数口径写清楚（`df -h`/`df -i` 都要看）。
4. **门禁级的守卫**（可证伪）：跑完一轮门禁后断言"**没有新增的自家临时目录残留**"（红侧：故意不清理 → 红）；
   以及"**sweep 不会删掉在用的目录**"（红侧：伪造一个占用中的目录 → sweep 必须跳过）。
5. **别把 `review-*` 的清理做成"删掉复验证据"**：`review-*` 是**检出**不是证据（证据在 `docs/team/reviews/`），
   但 sweep 要说明这一点，并把"复验记录已提交"作为前置断言（避免误删未提交的记录）。

## 硬要求

- policy B：delta 落 `verification`（门禁的临时资源规矩）+ 视需要 `watchdog`（doctor 行）；
  每条可证伪、MODIFIED 不删 base scenario；
- 每条 requirement 给复核方法；
- **不写实现**；矛盾 → `BLOCKED:` 交回 PM。

## Deliverables

- `openspec/changes/test-tmp-hygiene/{proposal.md,design.md,tasks.md}`
- `openspec/changes/test-tmp-hygiene/specs/*/spec.md`
- 报告 `docs/team/reports/P50-<agent>.md`

### 追加（PM，2026-09-22 10:5x）：`smoke.sh` 写死 `/tmp`

`skills/teamsmith/tests/smoke.sh:215` 是 `TMP="$(mktemp -d /tmp/teamsmith-smoke.XXXXXX)"` ——
**不看 `TMPDIR`**（我实测：`TMPDIR=/tmp/faketmp` 时它仍建 `/tmp/teamsmith-smoke.*`）。
影响：① 想让现场落在别处（例如 CI 里挂一个可上传的目录）做不到，只能把宿主目录**挂到容器的 /tmp**上
（本仓库 CI 现在就是这么做的，见 `.github/workflows/gates.yml` 的 GATES 步骤）；② 与上面的"占用可见/可回收"目标冲突。
提案要把这条一并裁决：临时根用 `${TMPDIR:-/tmp}`（或显式旋钮），并说明与既有夹具/文档的一致性。
