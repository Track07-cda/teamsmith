# P350 · 产品里那两处 `grep -q` + `pipefail`：先落变量再匹配

agent: dev-bob   status: delivered   time: 2026-10-21T03:32Z（`date -u`）
branch: `task/P350-sigpipe-product-defects`   phase: apply   change: -   anchor: none (infra) — 两处产品代码的管道判定
specs: `verification#The gate judges behaviour only, and never reports a skip as a pass`

## 结论（先看这一段）

**两处都修好，判据一个字没放宽，红侧/绿侧/翻回三段读数都在。** 改法是同一个范式：把被匹配的那份数据先落进变量，
匹配从 here-string 读，管道里不再有「读到命中就退出的进程 + 还在写的进程」。

- **`common.sh:5234`（explore 阶段证据）**：长标题流 + 点名条目不在末尾时，改前 **30/30** 把「有 PM 接受记录」
  报成「没有」；同一夹具**短标题流 30/30 判对**（证明红的是管道，不是夹具）；改后 **30/30 判对**。
- **`cmd-status.sh:155,158`（squash 合并两条腿）**：直读腿（`TEAM_SCAN_CACHE=0`）改前 **30/30** 把已 squash
  合并的分支报成「领先 1」；缓存腿在 `TEAM_SQUASH_LOOKBACK=200`（8200 B）时 30/30 正确、抬到 `400`（16 400 B）
  时 **30/30** 报错；改后三种配置 **30/30** 都是「已合并」。
- **翻回**：把这两处的管道原样写回一份私有副本（只改这两处），两个红侧立刻恢复（explore 10/10、squash 两腿各
  10/10），而默认配置仍是绿的 —— 绿是这处改动带来的，不是夹具变了。
- **一处与 brief 引用的数字不同，请 PM 按本节复核**：缓存腿的悬崖不在 8192 B（brief 的「8 字节余量」），
  我这套夹具实测在 **392 行（16 072 B）仍全对、393 行（16 113 B）起 100% 错**。结论不变（默认 200 靠缓冲侥幸，
  抬文档化开关就越过去），但边界数值按实测写。

## 1 · 改了什么（写集内两处）

**`skills/teamsmith/scripts/lib/common.sh` · `team_done_phase_evidence` explore 分支**（提交 `05dd6862`）

```sh
heads=""
if [ -f "$f" ] && heads="$(grep -E '^#{1,6}[[:space:]]' "$f")" \
     && grep -qE "(^|[^[:alnum:]_])$(team_regex_escape "$id")([^[:alnum:]_]|$)" <<< "$heads"; then
  printf 'PM 接受记录 %s（标题点名 %s）\n' "$TEAM_DOCS_DIR/DECISIONS.md" "$id"; return 0
fi
```

判据仍是原来那条 ERE（标题行 + id 两侧不是字母数字下划线），`team_regex_escape` 与 `[ -f ]` 都在；变的只是
「标题流先落变量、匹配从 here-string 读」，管道没了。

**`skills/teamsmith/scripts/lib/cmd-status.sh` · `team_branch_squash_merged`**（提交 `eedacbbe`）

```sh
if team_scan_cache_on; then
  _team_prot_trees_load
  trees="$_TEAM_PROT_TREES"
else
  trees="$(git -C "$wt" log --format=%T --max-count="$lookback" "$TEAM_PROTECTED_BRANCH" 2>/dev/null || true)"   # 留：查不到=空答案（不是故障）
fi
grep -qx "$tree" <<< "$trees"
```

两条腿（缓存 / 直读）落到同一个 `trees`，最后一行同一个精确行匹配。唯一新增的 `|| true` 与同文件
`_team_prot_trees_load`（`common.sh:381`）逐字同形、带 `留：` 注释：它盖的是 git 自己的「没有这个 ref」，
不是管道那 141（管道已经不存在）。

**没动的**：`outbox.sh` 那 6 处（P344 返修范围）、面板夹具三处（经 V84 判定无害）、`tests/**` 一个字没改。

## 2 · 红侧：改前的读数（真 CLI + 真 git 夹具）

夹具在 `/var/tmp/p350`（脚本 `/var/tmp/p350-harness/`，都还在盘上）：

- `team init --no-skills --agents s1 --task-models code=provider/model-x --pm-model provider/model-x` 建的项目；
- `main` 上 402 个提交（其中 400 个空提交，把「保护分支最近 N 个 tree」撑到 8 KB 以上）；
- 分支 `task/S1` 有一份真内容、`git merge --squash` 进 main（tip tree 相同、无共同提交 —— PM 的常规合并路径），
  工作树 `.worktrees/s1` 停在分支上；`task/S2` 是**未合并**的对照；
- explore 现场是一份 16 518 B / 304 行的标题流，点名条目在第 6 条，后面还有 295 条。

```
$ bash /var/tmp/p350-harness/repro-explore.sh long 30      # 改前
explore site (long DECISIONS.md, 30 trials): accepted 0 / refused(wrong: heading stream names the task) 30 / other 0
$ bash /var/tmp/p350-harness/repro-explore.sh short 30     # 同一夹具、标题流只有那一条（对照）
explore site (short DECISIONS.md, 30 trials): accepted 30 / refused(wrong: heading stream names the task) 0 / other 0
$ bash /var/tmp/p350-harness/repro-squash.sh 30            # 改前
squash site (default, 30 trials): 已合并 30 / 领先N (wrong: the branch IS squash-merged) 0
squash site (lookback400, 30 trials): 已合并 0 / 领先N (wrong: the branch IS squash-merged) 30
squash site (cacheoff, 30 trials): 已合并 0 / 领先N (wrong: the branch IS squash-merged) 30
```

改前的可见症状（同一份 16 518 B 标题流，`D9100` 明明点名了 `Z3`）：

```
$ team --root . board set Z3 done
✗   ③ 阶段 explore 的交付：PM 把接受结论落盘：docs/team/DECISIONS.md 里用一个标题条目点名 Z3，或写 docs/team/reviews/Z3.md
✗ BOARD.md 更新失败
```

```
$ TEAM_SQUASH_LOOKBACK=400 team --root . roster        # 改前
s1         · 无窗口 task/S1                       0        1       -  ·unavailable
```

**机制（同一份负载直跑，不经过产品）**：

```
cached-leg shape lookback=400 bytes=16400 -> pipeline rc=141      # pipefail 把命中判成失败
lookback400 PIPESTATUS(printf,grep)=141 0                        # 写端 SIGPIPE 141，匹配端 0（命中了）
uncached-leg shape -> pipeline rc=141
uncached PIPESTATUS(git,grep)=141 0
```

### 2.1 缓存腿的边界（实测，与 brief 的「8 字节余量」不同）

同一夹具，只改 `TEAM_SQUASH_LOOKBACK`，每档 10 次（391–394 每档 20 次）：

| lookback | 负载 | 判定 |
|---|---|---|
| 180 / 190 / 195 / 199 / 200 / 201 / 205 / 220 / 250 / 300 / 350 / 380 / 390 / 391 / 392 | 7 380 … 16 072 B | 全对（0 错） |
| 393 / 394 / 395 / 398 / 399 / 400 / 402 | 16 113 … 16 482 B | 全错（10/10 或 20/20） |

即：这台机器的悬崖落在 **16 072 B 与 16 113 B 之间**，而不是 8 192 B；brief 里「8200 B / 恰好 8 字节余量」说的是
负载相对 `F_GETPIPE_SZ=8192` 的位置（V84 报告里有这条 `python3 -c "fcntl.fcntl(r,1032)"` 的读数），不是实测翻转点。
**结论不变**：默认 `200` 是缓冲侥幸，`TEAM_SQUASH_LOOKBACK` 是文档化开关，抬到 ~393 以上缓存腿 100% 报错；
直读腿与开关无关，`TEAM_SCAN_CACHE=0` 下按默认 200 就 30/30 错。

## 3 · 绿侧：改后的读数（同一夹具、同一脚本）

```
$ bash /var/tmp/p350-harness/repro-explore.sh long 30      # 改后
explore site (long DECISIONS.md, 30 trials): accepted 30 / refused(wrong: heading stream names the task) 0 / other 0
$ bash /var/tmp/p350-harness/repro-squash.sh 30            # 改后
squash site (default, 30 trials): 已合并 30 / 领先N (wrong: the branch IS squash-merged) 0
squash site (lookback400, 30 trials): 已合并 30 / 领先N (wrong: the branch IS squash-merged) 0
squash site (cacheoff, 30 trials): 已合并 30 / 领先N (wrong: the branch IS squash-merged) 0
```

```
$ team --root . board set Z4 done
  done 证据：OK：阶段 explore 的交付证据：PM 接受记录 docs/team/DECISIONS.md（标题点名 Z4）
✓ board Z4 → done
$ TEAM_SQUASH_LOOKBACK=400 team --root . roster
s1         · 无窗口 task/S1                       0 已合并       -  ·unavailable
$ TEAM_SCAN_CACHE=0 team --root . roster
s1         · 无窗口 task/S1                       0 已合并       -  ·unavailable
```

## 4 · 翻回：把管道写回去，红侧必须复发（flip evidence）

私有副本 `/var/tmp/p350-harness/skill-broken/`（= 修复后的技能整棵树，只把那两处改回管道形状，别的一个字节没动），
用同一个 `TEAM_BIN` 跑同一套夹具：

```
$ TEAM_BIN=/var/tmp/p350-harness/skill-broken/scripts/team bash /var/tmp/p350-harness/repro-explore.sh long 10
explore site (long DECISIONS.md, 10 trials): accepted 0 / refused(wrong: heading stream names the task) 10 / other 0
$ TEAM_BIN=/var/tmp/p350-harness/skill-broken/scripts/team bash /var/tmp/p350-harness/repro-squash.sh 10
squash site (default, 10 trials): 已合并 10 / 领先N (wrong) 0
squash site (lookback400, 10 trials): 已合并 0 / 领先N (wrong) 10
squash site (cacheoff, 10 trials): 已合并 0 / 领先N (wrong) 10
```

默认配置在翻回后仍绿、只在两处缺陷的触发条件下变红 —— 这也说明红侧量的是缺陷，不是「任何改动都会红」。

## 5 · 负向对照：判据没有被放宽（改后的树上跑）

| # | 现场 | 读数 | 期望 |
|---|---|---|---|
| C1 | 标题只有 `E1000`，探针是 `E100`（id 词边界） | REFUSE | REFUSE |
| C2 | `E200` 只出现在正文（不是标题行） | REFUSE | REFUSE |
| C3 | 标题点名 `E300` | ACCEPT | ACCEPT |
| C4 | 没有 `DECISIONS.md` | REFUSE | REFUSE |
| C5 | 三条配置下 `s1`（已合并）/`s2`（未合并） | 已合并 / 领先 | 已合并 / 领先 |

另：`TEAM_PROTECTED_BRANCH=no-such-branch` 时两条腿都退到「领先 `?`」，与改前那份副本的读数逐字相同
（空答案的边界没有被改动碰到）。

## 6 · 验收命令与读数

```
$ bash -n skills/teamsmith/scripts/lib/common.sh && bash -n skills/teamsmith/scripts/lib/cmd-status.sh
bash -n: both OK
$ git diff --check
git diff --check: clean
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=$HOME/Documents/syncthing/Work/Projects/pm-skills/.worktrees/dev-bob scope=published files=1998 hits=0 names=ok user=resolved
LEDGER_BAN_RC=0
$ $HOME/.bun/bin/openspec validate --all --strict
Totals: 21 passed, 0 failed (21 items)
```

一处环境事实：`openspec` **不在**登录 shell 的 PATH 上（`bash -lc 'openspec validate --all --strict'` →
`openspec: command not found`），本机装在 `$HOME/.bun/bin/openspec`；上面的读数用绝对路径跑。PM 复验别照抄裸命令。

选段（受影响的段，不跑整套）：

```
$ bash skills/teamsmith/tests/smoke.sh --select 11i,20,24,37
== 选段结果 ==  ✓ 166  ✗ 0      # 9 段收口（前导 0/0b/0c/0d/2 + 11i/20/24/37），账本自查 ✓166 ✗0 一致
  #6 11i · 信号诚实：报告草稿不指 review、squash 合并不喊 push（M4.3 C/D） · ✓15 ✗0
  #7 20 · done 证据的阶段感知（M9.2） · ✓43 ✗0
  #8 24 · done 证据：② 要求分支里已提交的报告（M9.6） · ✓24 ✗0
  #9 37 · 读路径性能：根一次解析 + 单进程扫描（M50） · ✓23 ✗0
```

选这四段的理由：**11i** 是唯一断言 squash 合并信号的两条消费路径（digest 的「已合并（squash，内容一致）」与
roster 的 `^m43d.*已合并`），即缓存腿的消费者；**37**（M50）是 cache 开/关逐字节等高对照，直接盖住直读腿；
**20** 与 **24** 走 `team_done_phase_evidence` 的 explore 路线（含 24 的 ⑥ 控制组：阶段证据到位仍允许 done）。
不用 `--paths`：拿这两个核心库喂它得到的决定是 `decision=RUN sections=135 keys=74`（≈整套），brief 明确要求不跑整套。

**没跑的**：其余 126 个键（`state/bg/p350-select.log` 末尾逐个列出）；整套交给 PM 在合并时跑。

## 7 · 与 brief 对不上的一处（请 PM 裁）

brief 引「`docs/team/reports/V84-verify.md` §4.1/§4.2」，但这份文件不在我派单时的那棵树上（它提交在 verify 席位的
分支上：`fff91b6d`、`d56ef813`）。我按 brief 正文的数字复现，另外自己去读了 verify 工作树里的原文做对照，两处差异：

1. **缓存腿边界**：V84 写「lookback 200（8200 B）→ 0/60；400（16400 B）→ 60/60」；我同意两个端点，并把中间的
   翻转点实测到了 392→393 行（16 072→16 113 B）。「8 字节余量」应理解为负载相对 pipe 容量 8192 的位置，不是翻转点。
2. **explore 现场的 0/30 vs 30/30**：V84 在本仓真账本（标题流 16 178 B）上走产品路径是 0/30，+1 KB 后 30/30。
   我这套夹具 16 518 B 的标题流里点名条目**不在末尾**（后面还有 295 条），改前是 30/30。两者不矛盾，指向同一个
   触发条件：点名条目不是最后一行的标题，且标题流跨过写端缓冲边界。真账本里接受条目是末尾那条，所以不现形。

## 8 · 下一步

- PM 复验：两个提交 `05dd6862`、`eedacbbe`（分支 tip `eedacbbe`），看 §2/§3/§4 三张读数即可复跑（夹具脚本在
  `/var/tmp/p350-harness/`，夹具仓库 `/var/tmp/p350`，都是本轮现造、未碰本仓文件）。
- 同族未修（不在本任务写集）：`outbox.sh` 6 处归 P344 返修范围；面板夹具三处 V84 已判无害。
