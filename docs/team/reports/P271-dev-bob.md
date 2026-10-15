# P271 · startup-self-heal 清单按事实勾选

agent: dev-bob   status: done（交付；两项留空待 PM 裁定）   time: 2026-10-15
branch: `task/P271-self-heal-checklist`（local 模式，无远端，未推送）   PR/MR: -

## Deliverables

| Path | What |
|---|---|
| `openspec/changes/startup-self-heal/tasks.md` | 30 条里 26 条按事实勾选，每条带一条可复核的证据指针（报告段 / 提交 / 命令+rc / 夹具名）；5.2 与 7.1–7.3 留空 |
| `docs/team/reports/P271-dev-bob.md` | 本报告 |

改动面就是这一个文件加这份报告：`git diff --stat main..HEAD` 只有 `openspec/changes/startup-self-heal/tasks.md`（51 增 53 删）。`skills/**`、`openspec/specs/**`、别的 change 一律没碰。

## 测试状态（先说）

- 验收命令（`openspec validate --all --strict` / `ledger-ban.sh` / `git diff --check`）已在本分支树上真跑，全绿（下面有原始输出）。
- 清单里引用到 smoke 的那几条（2.2、4.5、6.1），我这轮补跑了原始尾巴：§1b/§2/§17 取自本轮 `TEAM_SMOKE_FAST=1` 全量快跑，§11b3/§11b4 取自本轮 `--select 11b3,11b4`（非 FAST，真 tmux 会话）。
- **全量门禁（不带 FAST）没有跑**，按纪律留给 PM 复验。本轮全量 FAST 快跑是 `✓4041 ✗5`；5 条红里 4 条已被并入 main 的 P266/面板工作修掉（本轮复验绿），剩下 1 条是 **main 上的既有红**（§39），干净克隆上的 A/B 见下。
- 本轮工作顺序：先合了一次 main（`8aa525aa`）→ 勾选并提交 → 跑了 70 分钟的 smoke → main 又前进了 13 个提交 → 再合一次 main（`6e329b1a`）→ 在合并后的树上重跑验收命令。

## Verification evidence (must have actually been run)

### 验收命令（在合并 main 之后的 `6e329b1a` 上跑）

```
$ git diff --stat main..HEAD
 openspec/changes/startup-self-heal/tasks.md | 104 ++++++++++++++--------------
 1 file changed, 51 insertions(+), 53 deletions(-)

$ "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict | tail -2
✓ spec/watchdog
Totals: 22 passed, 0 failed (22 items)
rc=0

$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: names：名单已配置（/home/<user>/…/.pi/team/forbidden-names.txt，命中即红）
ledger-ban: root=/home/<user>/…/.worktrees/dev-bob scope=published files=1521 hits=0 names=ok user=resolved
$ echo $?
0

$ git diff --check; echo rc=$?; git status --short
rc=0
（无输出）

$ bash skills/teamsmith/tests/section-select.sh --paths openspec/changes/startup-self-heal/tasks.md | head -3
decision=RUN
sections=129
keys=5
```

`section-select` 对我这条路径给的是 `decision=RUN`（这次改动命中 5 个键，逐键原因表里 `0`/`0b`/`0c` 是前导段）。

### 本轮复跑：清单里引用的 smoke 段

```
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh          # 全量快跑，129 段
#11 1b · bootstrap（一条命令初始化） · 用时 1s · ✓24 ✗0 SKIP0 · ticks 24
#13 2 · init · 用时 1s · ✓42 ✗0 SKIP0 · ticks 42
#69 17 · 迁移指南与 doctor 指引（M7.1） · 用时 10s · ✓34 ✗0 SKIP0 · ticks 34
…
账本自查： 129 段收口 · 增量 ✓4041 ✗5 SKIP54 ｜ 结果行 ✓4041 ✗5 —— 一致
== 结果 ==  ✓ 4041  ✗ 5
FAST 模式：跳过 39 个真进程段落…

$ bash skills/teamsmith/tests/smoke.sh --select 11b3,11b4          # 非 FAST，真 tmux
#12 11b3 · 启动中的 PM：一拍只拉起一次（M7.2） · 用时 29s · ✓56 ✗0 SKIP0 · ticks 56
#13 11b4 · PM 交接：--fresh-pm 与同 cwd 活会话提示（P36） · 用时 11s · ✓33 ✗0 SKIP0 · ticks 33
== 选段结果 ==  ✓ 433  ✗ 0
RC[11b3,11b4]=0
```

（FAST 快跑里 11b3 是 `SKIP1`、11b4 是 `✓12 ✗0 SKIP1`，因为它们是真进程段；所以这两段另跑了非 FAST 的选段。）

### 那 5 条红的去向（同选段 A/B）

```
# 本轮（合并 main 后，6e329b1a）
$ bash skills/teamsmith/tests/smoke.sh --select 6e,28,38,39
#10 6e · 外部项目实测反馈 · 用时 2s · ✓13 ✗0
#14 28 · 控制台表面 · 用时 34s · ✓176 ✗0
#15 38 · 设置选项 · 用时 347s · ✓22 ✗0
#16 39 · npm CLI 与项目 skill 安装 · 用时 40s · ✓0 ✗1
  ✗ 39 install-shape.sh 有失败
        ✗ teamsmith-init/SKILL.md 超行数（102）
== 选段结果 ==  ✓ 569  ✗ 1
RC[6e,28,38,39]=1

# 同一个选段，在 main 的干净克隆上（/tmp/p271-base，同一天，`git clone --no-local --single-branch --branch main`）
$ bash skills/teamsmith/tests/smoke.sh --select 6e,28,38,39
#10 6e · ✓13 ✗0     #14 28 · ✓176 ✗0     #15 38 · ✓22 ✗0     #16 39 · ✓0 ✗1
RC[6e,28,38,39]=1
```

两份输出逐段一致：§6e/§28/§38 在旧基线上红过，P266 与面板工作并入 main 后已绿；**§39 在干净的 main 上照样红**，与我这份改动无关。

§39 的归因（只读查历史，`install-shape.sh:409` 断言 `lines -le 100`）：

```
$ wc -l < skills/teamsmith-init/SKILL.md                        # 现在
102
$ git show 23f42b04:skills/teamsmith-init/SKILL.md | wc -l      # P261 的合并提交
102
$ git show 23f42b04^:skills/teamsmith-init/SKILL.md | wc -l     # P261 之前
100
```

### 我自己踩到的假红：`--select 1b,2`

我原以为可以用 `--select 1b,2,17,11b3,11b4` 一次拿到四条尾巴。它**在中途按设计中止了**：

```
$ bash skills/teamsmith/tests/smoke.sh --select 1b,2,17,11b3,11b4
#5 1b · bootstrap（一条命令初始化） · 用时 1s · ✓24 ✗0 SKIP0 · ticks 24
  ✗ 写入配置（缺 /tmp/teamsmith-smoke.…/repo/.pi/team/config.sh）
  ✗ 身份隔离失败（team 认错项目/session）：{ "project": "bootrepo", "main_root": "/tmp/…/bootrepo", … }
=== 中止：为避免误伤真实项目/session，不再继续跑 ===
SELECT_RC=1
```

原因在选段机制本身，不在被测代码：`smoke.sh:1831` 的 §1b 里 `cd "$BR"` 之后**没有回到 `$REPO`**，只有它后面的 §1c 在收尾（`smoke.sh:1997`）才 `cd "$REPO"`。选段跳掉 §1c 时，§2 就在 `bootrepo` 里跑 `team init`，于是 `$REPO` 一个文件都没写、`team paths` 报的是 `bootrepo` 的身份，隔离守卫按纪律中止。全套门禁不会遇到它（§1c 夹在中间）。

中止后我立刻查了本工作树与主工作树：两处都干净（`git status --short` 无输出），没有任何真实项目/会话被写到。

## Flip evidence

本任务不是缺陷修复，没有「改坏实现 → 守卫必红」的翻转可做（清单里 1.3/2.3/3.2/4.2 的翻转是 P261 的实现面，见 `P261-dev-bob.md`「红侧」八臂与 `V35.md`）。这一轮真正带红→绿性质的是上面两段定性：§6e/§28/§38 从旧基线的红变成合并 main 后的绿，以及 `--select 1b,2` 那条**选段自身**的假红（不是产品红）。

## Decisions and deviations

1. **5.2 留空，不勾**。它的第一半（四处「只能走 `team config upgrade-models`」的句子改成「启动事务或手工事务」）确实做了并已并进 main；但它的第二半「`references/migration.md` 的 §5b 与升级步骤同步（形状表结构写清楚）」被 P261 的任务书明文挡掉了：`docs/team/tasks/P261-startup-self-heal-apply.md` 写的是「**不许碰** `references/migration.md`（P255）」。可 change 自己的 `proposal.md:110` 与 `design.md:96` 又把「`references/migration.md` 的 §5b 与升级步骤」列在 startup-self-heal 的文档面里 —— 两边对同一条 requirement 的说法相反，这是任务书与 change 契约之间的真冲突，不是我漏做。请 PM 裁定：改任务书、改 change 文本、还是把这一半明确归 P255。

2. **7.1–7.3 留空**，是 verify 席位的条目（协议：没有人验证自己的活），不是我该勾的。

3. **0.2 的「没有第二个未归档 change 动 `init-skill`」今天已不成立**。到本轮交付为止，同时动 startup-self-heal 那两条能力的未归档 change 有**两个**：`slash-team`（提案已并入 main，`363c7b2f`，带 `init-skill` delta）与 `tmux-identity-scope`（提案已并入 main，`6de0abfb`，带 `pm-lifecycle` delta）。我按当时的真话写了指针并在那里点明了这一点；独立树投影自证本轮复跑仍绿（`archive -y startup-self-heal` → `archived as '2026-10-15-startup-self-heal'`，随后 `validate --all --strict` → `Totals: 20 passed, 0 failed`），所以这是**排序问题不是阻塞**：三者归档时若 delta 落到同一个 requirement，谁后归档谁要按前者的结果重写。

4. **勾选粒度**：每条只给「到哪去找证据」，没有把实现细节复制进任务书（协议禁止在任务书里另建一套 spec）。指针优先指 P261 的报告段与 V35 的复验记录，其次才是命令+rc。任务书里与实现实际做法不一致的 5 处按 P245 的写法加了「实际做法：」注记（1.1 手工事务不写形状号、1.4 备份名里的「版本」是引入版本、2.3 先用两条替代臂、5.3 真动了 `section-budgets.tsv`、6.1 三组只在全量档），原文一个字没改。

5. **先合 main 再交付**：按任务书「交付前 `git merge main`」。这一轮 main 前进过两次，我合并了两次（第二次是 `6e329b1a` 的合并提交），验收命令是在合并后的树上重跑的。

## 给 PM 的发现

1. **main 上有一条既有红：§39 `teamsmith-init/SKILL.md` 102 行 > 100 行预算**。来源是 startup-self-heal 自己的文档改动（100 → 102，见上面三个 `wc -l`）。全量门禁在归档前会红在这里；我按边界没碰 `skills/**`，需要一条独立的小任务（削 2 行，或由 P255 的完整重写覆盖）。它同时也是这份清单 5.2 的直接后果，两条一起裁比较省事。

2. **`--select 1b,2`（不选 §1c）会给假红并中止**：§1b 把 cwd 留在自己的夹具里，只有 §1c 收尾才 `cd "$REPO"`。选段是 P98 的能力，这个漏 cwd 的形态值得单开一条小修（§1b 收尾加 `cd "$REPO"`），否则以后任何人按「改了 init 相关文件」选段都会撞上它，并可能被误读成产品红。要 PM 派单我才动 —— 它不在本任务范围里。

3. `slash-team` 与 `tmux-identity-scope` 分别与 `startup-self-heal` 同动 `init-skill` / `pm-lifecycle`（上面偏离 3）。

## Suggested next steps

- 裁定 5.2（任务书 vs change 文本），我可以按裁定补勾或保持留空。
- 派一条小任务修 §39 的行数（或明确归 P255），以及可选的 `smoke.sh` §1b 收尾 `cd "$REPO"`。
- 归档前跑全量门禁；`6e/28/38` 预期绿，`39` 预期仍红直到上面那条修掉。
- 7.1–7.3 派给 verify 席位（`startup-self-heal` 的 verify 尚未做，V35 是 P261 的 apply 复验，不是 change 的 `opsx-verify`）。
