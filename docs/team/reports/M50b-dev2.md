# M50b · 把 main 并进 M50 分支并解决三处冲突（合并结果自己跑门禁）

agent: dev2   status: DONE（合并与三处语义解决完成；门禁 6 条红全部归因**主机 inotify 资源**，见 §4）   time: 2026-09-21T03:05Z（UTC）
branch: `task/M50b-m50-main`（HEAD `a548690` = merge commit `ff244b3` + `main` `6753f11`）   PR/MR: -（local 模式，不 push）

## Deliverables

| Path | What |
|---|---|
| `skills/teamsmith/scripts/lib/common.sh` | 冲突解决 ①②：M50 的扫描缓存 `team_board_ids()` **与** M48 的 `team_board_duplicate_ids/line()` 并存；`board add` 结尾的 `team_scan_invalidate board` **与** `--allow-dup` 审计行并存 |
| `skills/teamsmith/scripts/lib/cmd-review.sh` | 冲突解决 ③：M50 的 `team_scan_invalidate review` **与** P27 的 `queue_marker` 清理并存 |
| `skills/teamsmith/tests/smoke.sh` | 冲突解决 ④：M50 段号 34 → **37**，放在 main 的 36 之后；补回它自己的收尾 `fi`（共享行只关 main 的 `if/else`）；`bash -n` 通过 |
| `docs/team/reports/M50b-dev2.md` | 本报告 |
| `docs/team/reports/M50b-dev2/pkg/` | 独立证据包（`lib.sh` + `10/15/20/30/40/50` + `run.sh`；每段 `ok/bad/finding/skip` + `== N 结果 ==`） |
| `docs/team/reports/M50b-dev2/evidence/` | 原始输出：全量门禁（去 ANSI）、结果行、12b-pi 失败明细、`bash -n` 翻转、基点 vs 合并翻转、包内 6 段日志 |

验收对象只有**合并结果**：`a548690`（merge commit，两个父提交：`ff244b3` M50a tip、`6753f11` main tip）。

## 1. 合并与三处冲突的解决（按语义，不按行拼接）

`git switch task/M50b-m50-main`（从 M50a tip 切出）→ `git merge main`：只有任务书预告的 3 个文件冲突，其余全部自动合并（含 M50 在 smoke 26-i 的 gitshim 探针 hunk，行号移位后仍在，见 §2 段序）。

### ① `common.sh`：缓存层 vs 重复 ID 可见性（两处）

同一片区域的 `team_board_ids` / 新函数处，两侧是**不同函数**，不是同一函数的两版，所以两者都留：

```bash
team_board_ids() { # → 表里现有的 id（每行一个，给「未知 id」的报错用）
  if team_scan_cache_on; then
    _team_board_cache_load
    if [ "$_TEAM_BOARD_BROKEN" != "1" ]; then   # 坏源落回直读（M50/27-b）
      [ -n "$_TEAM_BOARD_IDS_OUT" ] && printf '%s\n' "$_TEAM_BOARD_IDS_OUT"
      return 0
    fi
  fi
  team_board_ids_direct
}

# M48：同一 ID 出现多行（历史遗留：不同任务共用 ID；PM 实测被同 ID 两行卡住了看板光标）。
team_board_duplicate_ids() { # → "M4.3 ×2" 每行一个
  ...
}

# M48：一行话的重复报告（board ls / digest / doctor 共用同一份判据，避免三处各写一份）。
team_board_duplicate_line() { # → "BOARD 有重复 ID：…"；没有 → 空
  ...
}
```

第二处是 `board add` 的收尾（M50 的失效调用 + M48 的审计行，两侧语义都要）：

```bash
  team_scan_invalidate board   # M50：写完再读（同进程）必须读到新行
  # 显式允许的重复：审计里留一条（谁在什么时候往同一个 ID 加了第二行、当时几行）
  if [ "$dup_prev" = "1" ]; then
    local dupline; dupline="$(team_board_duplicate_ids | grep -F "$1 ×" | head -1 || true)"
    team_wlog "board add $1 --allow-dup：显式新增同 ID 行（${dupline:-同 ID 多行}；标题「$2」）"
  fi
```

### ② `cmd-review.sh`：复验记录落盘后的两步（M50 失效 + P27 清理）

```bash
  } > "$report"
  team_scan_invalidate review   # M50：同进程里「写完再读」必须读到新记录
  [ -n "$queue_marker" ] && rm -f "$queue_marker" 2>/dev/null
  team_ok "复验记录：${report#"$TEAM_MAIN_ROOT"/}（$verdict）"
```

### ③ `smoke.sh`：段号撞车 + 共享的收尾行

- M50 的段整块搬到 main 的 **36** 之后，改名 `section "37 · 读路径性能：根一次解析 + 单进程扫描（M50）"`（注释块同步改 37）；
- 冲突标记后那一行 `fi` 只能属于一侧：它关 main 段 36 的 `if/else`，所以**保留在 main 侧**；M50 段自己补一个收尾 `fi`（复制自 HEAD 侧原文）。直接并排拼接会造成 `unexpected end of file from 'if'`（§5 的翻转证据就是按 PM 那次失败形状做的）；
- 合并后段序（门禁日志原文）：`33 → 12e → 12g → 12h → 12i → 12j → 12k → 34 → 35 → 36 → 37 → 15`。

三个文件 `bash -n` 全过；`git diff --check` 干净。

## 2. 合并结果的**全量门禁**（唯一有效验收对象）

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh </dev/null
openspec_rc=0
== 结果 ==  ✓ 2664  ✗ 6
smoke_rc=1
```

- openspec：全部 spec ✓（原始输出在 `evidence/00-full-gate-plain.log` 头部）。
- smoke：**2664 ✓ / 6 ✗**，6 条 ✗ **全部**是 `12b-pi` 的扩展夹具族（fs.watch 唤醒），逐条在 §4 定性；其余段落全绿，包括合并进来的 P24/P26/P27/P28/M48/M51 与 M50 的段 37。
- M50 段 37 在门禁里真跑了且全绿（原始行）：

```
✓ M50-① board row 的 git 调用数 ≤ 1（实测 1）
✓ M50-①b 子目录里 board row 的 git 调用数 ≤ 1（实测 1）
✓ M50-①c cache 开/关 board row 输出逐字节一致
✓ M50-② digest 的 git 调用数 ≤ 50（实测 19）
✓ M50-② SKIPPED 记录照旧带标记列出（判定语义没动）
✓ M50-②c [3] 待复验列全 34 行（生产者不在带记录的报告上死掉）
✓ M50-②b 夹具非空转：cache-off 同口径 260 次 git > 50（旧形状会被这扇门抓住）
✓ M50-②c digest cache 开/关输出逐字节一致（滤时间戳与容量行）
✓ M50-③ status cache 开/关输出逐字节一致（滤容量行）
✓ M50-③b __panel-data cache 开/关逐字段一致（掩 timestamp 与 capacity 块）
```

## 3. 任务书第 4 条：三条语义/性能证据（合并后）

独立证据包（不复用实现方夹具、不复用 M50-dev/pkg；每个夹具先 `team paths` 证明 `main_root = 沙盒` 再写盘）：

```
$ rm -rf /tmp/m50b-dev2-pkg && bash docs/team/reports/M50b-dev2/pkg/run.sh
== 10-perf 结果 == ✓8 ✗0 finding 0
== 15-invalidate 结果 == ✓5 ✗0 finding 0
== 20-m48-dup 结果 == ✓7 ✗0 finding 0
== 30-p27-queue 结果 == ✓6 ✗0 finding 0
== 40-iw-harness 结果 == ✓1 ✗0 finding 4        # 4 条 finding = 环境，不是代码（§4）
== 50-inotify-rootcause 结果 == ✓5 ✗0 finding 1
证据包：全部段脚本退出码 0
```

### 3.1 M48 重复 ID 可见性（合并后被保留）

```
✗   team board add D1 <标题> --allow-dup   （会往 state/watchdog.log 落一条审计）     # 不带 --allow-dup 的新增被拒
!   BOARD 有重复 ID：D1 ×2（board add 会拒绝新重复；board set / assign 按 ID 寻址）   # digest 原文（M48 行）
2026-09-21T02:58:48Z board add D1 --allow-dup：显式新增同 ID 行（D1 ×2；标题「dup two」）  # --allow-dup 审计
```

控制组：同一夹具里没有重复 ID 时 digest **没有**这一行；`D2`（唯一行）没有被误报。

### 3.2 P27 排队记账（合并后被保留）

用私有锁制造排队（`TEAM_SMOKE_LOCK=<沙盒>/lock`，绝不碰机器锁）：

```
- 闸门计时：limit=60s queued=8s ran=2s（硬超时只量 ran；排队超限不会得到 TIMEOUT）
```

排队形状 `rc=0`、`team_review_verdict = PASS`；对照组（无竞争）`queued=0s` —— `queued` 真的在量排队，不是常量。

### 3.3 M50 性能数字（合并后仍成立，独立 gitshim 探针）

| 读数 | 合并结果（我的包） | 门禁段 37（实现方夹具） |
|---|---|---|
| `team board row` git 调用 | **1**（判据 ≤1） | 1 |
| `team digest` git 调用（cache on） | **19**（判据 ≤50） | 19 |
| 对照：`digest` cache-off（旧逐文件形状） | **210** > 50（夹具非空转） | 260 > 50 |

git argv 摘要、逐条断言、沙盒路径都在 `evidence/pkg-logs/10-perf.sh.log`。

### 3.4 额外：合并点「写路径失效」的破/立（15-invalidate）

同一进程里 warm 看板缓存 → `team_board_add` 新行 → 再看 `team_board_row`：

```
✓ 合并结果：INVALIDATE=ok（写完再读看到新行）
✓ 合并后的 board add 结尾有 `team_scan_invalidate board`（M50 侧）
✓ 断点对照：删掉 `team_scan_invalidate board` 后探针红（INVALIDATE=stale（写完再读还是旧缓存））—— 门是活的
```

（断点组用 `/tmp` 里的实现副本 + 独立新行 ID，不动工作树；共享看板文件的两个探针用不同 ID，避免第一次探针的行让第二次空转。）

## 4. 任务书第 5 条：12b-pi 的 6 条红 = **主机 inotify 配额耗尽**（不是合并/M50 回归）

> 任务书写「5 条红」；这一轮门禁实际是 **6 条**（1 条夹具失败行 + S2/S4/S10/S12/S21b 五条「找不到 PASS」行）。下面按 6 条给证据，结论不变。

### 4.1 现象（门禁原始行）

```
✗ 12b-pi 扩展夹具失败（runner=<home>/.bun/bin/bun）
✗ 12b-pi 唤醒用的是 sendMessage(followUp+triggerTurn)（…/piw-harness.log 中找不到 [TEAM-IW-CASE PASS S2 …]）
✗ 12b-pi 唤醒只带截断预览（不带 payload 全文）（… S4 …）
✗ 12b-pi 端到端：真 CLI 投递 → 监视扩展唤醒（零模型调用）（… S10 …）
✗ 12b-pi M43：shrink 后的 rescan 有界（只投最近 N 条真新）且计数进账本（… S12 …）
✗ 12b-pi P28：只含过期行的重扫 deliver=0 + stale=<n>（… S21b …）
```

夹具自身：**81 PASS / 31 FAIL**，首条 `TEAM-IW-CASE FAIL S2 a new spool line wakes the session (fs.watch, polling disabled) :: messages=0`；`S12 total … 0 -> 0`、`S13 seen=0` 与 PM 复验在旧基点看到的**是同一签名**。12b-pi 的 ①–⑩（CLI 侧）全部 ✓，只有 ⑨ 的扩展夹具红。

### 4.2 真因（三重证据，全部可复现）

1. **最小复现器**：本机此刻**连一个** `fs.watch` 都建不出来 —— node 与 bun 同错：

```
node → WATCH=err ENOSPC: System limit for number of file watchers reached, watch '/tmp/…/watch-node'
bun  → WATCH=err ENOSPC: no space left on device, watch '/tmp/…/watch-bun'
```

2. **配额占用**（只读主机扫描，`distrobox-host-exec`）：

```
/proc 值：max_user_watches=65536  max_user_instances=1024  max_queued_events=16384
主机 inotify 占用：65312 / 65536 watches
主要占用者：2245974  64737  /bin/syncthing
```

3. **main 与合并结果同形**：把 `main` 的 `skills/teamsmith` 用 `git archive` 取到 `/tmp` 跑同一夹具：

```
main：FAIL=31 · 首条：TEAM-IW-CASE FAIL S2 a new spool line wakes the session (fs.watch, polling disabled)
合并：FAIL=31 · 首条：TEAM-IW-CASE FAIL S2 a new spool line wakes the session (fs.watch, polling disabled)
```

三连跑（quiet#1/2/3）结果字节一致：**确定性**，不是 M47 复验记录里那种负载时序 flake；且合并点里的 `extension/team-inbox-watch.ts` 与 `main` **逐字节相同**（M50 分支根本没碰扩展）。

4. **判据本质**：夹具第 60 行 `TEAM_INBOX_WATCH_POLL_MS = '3600000'`（注释「先关掉轮询兜底：这一段只允许 fs.watch 叫醒」）—— fs.watch 不可用时这一族**必然**红，与树的内容无关。

### 4.3 结论与「变绿」条件

- 这不是合并、M50、M51 或任何代码引入的回归：同一主机上 `main` 与合并结果**同样红、同一条首条签名**；红的原因是环境级 inotify 资源耗尽（Syncthing 一户占了 64737/65536 watches）。
- 我这侧无法在本轮把它变绿：容器里写 `fs.inotify.max_user_watches` 被拒（`Permission denied`），`unshare -U -r` 新建 user ns 后**仍然 ENOSPC**（配额记在宿主机的 uid 户头上），Syncthing 是宿主机服务、不归我动 —— 见「Suggested next steps」。
- **没有**把它当「已知问题」放过：上面 4 项证据 + 包内 `50-inotify-rootcause.sh` 是常驻探针；一旦主机配额恢复（或 Syncthing 的 watch 面缩小），该段会自动回到「main 与合并两侧都绿」，门禁那 6 条也会随之消失（历史上 M47/M51 的门禁在这台机器上是绿的）。

## 5. Flip evidence

### ① 破坏/恢复（合并处收尾 `fi`，即 PM 那次拼接失败形状）

```
$ diff smoke-merged.sh smoke-no-fi.sh        # 只删掉恢复回来的 fi
11407d11406
< fi
$ bash -n smoke-no-fi.sh                     # 破坏后
/tmp/m50b-flip/smoke-no-fi.sh: line 11425: syntax error: unexpected end of file from `if' command on line 11403
rc=2
$ bash -n smoke-merged.sh                    # 恢复后
rc=0
```

### ② 合并前红 → 合并后绿（M48 / P27 探针，基点 `ff244b3` vs 合并 `a548690`）

```
== 20-m48-dup 结果 == ✓4 ✗3 finding 0     # 基点：不带 --allow-dup 的重复新增成功；digest 无重复行；无审计
== 20-m48-dup 结果 == ✓7 ✗0 finding 0     # 合并：拒绝 + digest 点名 + 审计都在
== 30-p27-queue 结果 == ✓4 ✗2 finding 0   # 基点：记录无 queued/ran 记账（记账缺失 + 对照失败）
== 30-p27-queue 结果 == ✓6 ✗0 finding 0   # 合并：queued=8s ran=2s、verdict 仍 PASS、无竞争时 queued=0s
```

### ③ 缓存失效的破/立（合并结果上，§3.4）：删掉 `team_scan_invalidate board` → 探针 stale（红）→ 恢复 → ok（绿）。

## 6. Decisions and deviations

- **段 37 的位置**：放在 main 的 36 之后、`section "15 · 完成"` 之前 —— 段号顺序与执行顺序一致；M50 段的断言文本（`M50-①…③b`）一个字节未改，唯一改动是段头与注释里的 `34`→`37`。
- **不动实现语义**：只碰冲突解决所需的三个文件；缓存层行为与 M50a 一致（门禁段 37 的 cache on/off 逐字节对照仍绿），M48/P27 语义按原样保留。
- **自报一次隔离事故（已修复）**：写证据包时我用一个临时调试 shell 直接跑探针，那个 shell **继承了 dev2 的 `TEAM_*` 身份**，于是 `team_board_add` 把一行 `| NEWINV2 | invalidate probe | dev | - | - | todo |` 写进了**主工作树** `docs/team/BOARD.md`（02:57Z 前后）。发现后逐行删除（`sed` 只删那一行，不用 `checkout`，避免碰到 PM 未提交的改动），现在主工作树 `BOARD.md` 的 diff 只剩 PM 自己的改动（`git diff --stat`：3 insertions(+), 1 deletion(-) = M51 改 done + M50a/M50b 建行），无我留下的字节。证据包本身一直走 `m50b_sandbox`（逐个 `env -u TEAM_*` + 写盘前 `team paths` 自证），包内 6 段日志里没有真实仓库的痕迹。这个事故记在此处备查。
- **未做**：没有给 smoke 加 inotify 能力探针/跳过（那会改门禁语义，且不在本任务书范围内）；若 PM 认为需要，应另开任务派给 `tests/**` 的 owner。

## 7. Suggested next steps

- **BLOCKED（主机层，只有用户/PM 能决定）**：12b-pi 那 6 条红要变绿，需要宿主机放开 inotify 配额（`fs.inotify.max_user_watches` 65536 已用 65312，其中 Syncthing 64737）。两条路：① 主机 `sysctl -w fs.inotify.max_user_watches=524288`（并写进 `/etc/sysctl.d/` 持久化）；② 缩小 Syncthing 的监视面（忽略 `node_modules`/构建产物等）。容器内做不到（写 sysctl 被拒、新 user ns 同样 ENOSPC）。
- 配额处理后请复跑验收命令（`openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh </dev/null`），预期 2664+6 条全绿；`pkg/run.sh 50` 会自动给出「main 与合并两侧都绿」。
- 若要在这个交付上直接盖章：本报告 §2 的门禁是**在合并结果上实跑**的，6 条红有 §4 的三重证据归因环境；请在复验记录里按此口径判定（我这边没有把任何红当「通过」）。
- 复跑入口：`bash docs/team/reports/M50b-dev2/pkg/run.sh [10 15 20 30 40 50]`（40 段加 `M50B_IW_LOAD=1` 会额外做一次压满机器的复现尝试；50 段是 inotify 常驻探针）。
