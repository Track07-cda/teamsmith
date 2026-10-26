# V106 · PM 窗口创建失败的真伪报告 · 独立复验

**判定：PASS**（受检代码 `de39538c` 的 `skills/` 与分支 tip `544c0e45` 逐字节相同，见 §0）

一句话：修前实现在 tmux 起不来时仍然打印 `✓ 创建 PM 窗口 <session>:pm` 并继续按「窗口不在」之外的样子往下走；
候选在同一现场退 1、点名目标窗口、保留 tmux 自己的诊断、不打成功行、也不继续。成功路径逐字节未变（真私有 server 里
成功行照旧出现、PM 真的被拉起、`pm` 窗口真的出现）。门禁翻转：候选 `--select 11b2`（实跑 12 段）✓364 ✗0 / rc=0；把
`cmd-watch.sh` 换回修前版本（同一棵树、同一份断言）→ ✓362 ✗2 / rc=1，红的正是 P376 那两条；还原 → 又回 ✓364 ✗0。

本报告只写报告与复验证据：没改实现、没加守卫、没合并、没推送。现场全部在 `/tmp/v106-verify/`（两次独立 clone +
三个独立夹具仓库 + 每轮自己的 `TMPDIR`），没有碰主检出、没有碰任何席位的 `.worktrees/`、没有碰真实的 `teamsmith`
tmux session（私有 server 用完 `kill-server`；收尾时 `tmux list-windows -t teamsmith` 仍是 `pm zsh pulse dev verify`，
与开工时同一组窗口）。

## 0. 受检对象与 sha

| 项 | 值 |
|---|---|
| 任务书点名的候选 | `de39538c`（`task/P376-pm-window-create-truth`） |
| 实际分支 tip | `544c0e45`（我 clone 后 checkout 的就是它） |
| 实现 / 断言 | `fa691596`（`cmd-watch.sh`，+11/−1）· `3b563c41`（`smoke.sh` §11b2 ①c，+11） |
| tip 相对 `de39538c` 的差 | 只有 `docs/team/reports/P376-dev.md`（+4/−3） |

```
$ git diff --stat de39538c 544c0e45
 docs/team/reports/P376-dev.md | 7 ++++---
$ git diff --stat de39538c 544c0e45 -- skills/ scripts/ panel/ extension/
（无输出 = 逐字节相同）
```

`de39538c` 是被 amend 过来的两次（`git reflog task/P376-pm-window-create-truth`：`de39538c` → `89a69703` →
`544c0e45`，三次都叫同一个 docs 提交）；`fa691596` 也 amend 过一次，但 `git diff efc1128f fa691596` 为空，
**代码字节从一开始就没变**。所以判的是代码，不是某个 docs 版本。

## 1. 任务书第 1 条：失败现场（修前 / 候选，同一夹具同一命令）

夹具（独立造，不复用作者的 `/tmp/p376-*`）：`/tmp/v106-verify/repro/{old,cand}` 各是一个 `git init` 过的空仓库，
`team init --session v106oldrepo|v106candrepo --agents dev --task-models … --pm-model deepseek/deepseek-flash`；
`TMUX_TMPDIR` 指向仓库旁的**普通文件** `notadir`（真 tmux 起不了 server，也不回退默认 socket）。

```bash
$ printf 'not a directory\n' > /tmp/v106-verify/repro/old/notadir
$ cd /tmp/v106-verify/repro/old/repo && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT -u TEAM_SESSION \
    -u TMUX -u TMUX_PANE TMUX_TMPDIR=/tmp/v106-verify/repro/old/notadir \
    bash /tmp/v106-verify/old/skills/teamsmith/scripts/team up            # 修前树 = 596143e6
```

修前（`A-old-badtmux.log`，rc=1）：

```
couldn't create directory /tmp/v106-verify/repro/old/notadir/tmux-1000 (Not a directory)
✗ 建不出 tmux session v106oldrepo（tmux 起不来？后面的窗口操作都会失败）
couldn't create directory /tmp/v106-verify/repro/old/notadir/tmux-1000 (Not a directory)
✓ 创建 PM 窗口 v106oldrepo:pm
! PM 窗口状态异常（missing）：不抢窗口
```

候选（`B-cand-badtmux.log`，rc=1）：

```
couldn't create directory /tmp/v106-verify/repro/cand/notadir/tmux-1000 (Not a directory)
✗ 建不出 tmux session v106candrepo（tmux 起不来？后面的窗口操作都会失败）
couldn't create directory /tmp/v106-verify/repro/cand/notadir/tmux-1000 (Not a directory)
✗ 创建 PM 窗口失败（v106candrepo:pm，tmux new-window rc=1；上面是 tmux 的诊断）：窗口不存在，PM 没有起来
  修法：确认 tmux server 可用（tmux ls）后重跑 team up；窗口在、里面是空的：up 会重启 PM
```

逐条对判据（同一份脚本给出，`repro-run2.log` 尾部的判据表，13/13 ok，rc=0）：

| 判据 | 修前 | 候选 |
|---|---|---|
| 非 0 退出 | 1（但来自后面的 `pm_fail`） | 1（来自这次创建失败本身） |
| 打印成功行 | **有**（`✓ 创建 PM 窗口 v106oldrepo:pm`） | **没有** |
| 失败行点名 tmux 目标 | 无 | `创建 PM 窗口失败（v106candrepo:pm，…）` |
| 保留 tmux 自己的诊断 | 有 | 有（`…/notadir/tmux-1000 (Not a directory)` 原样在两行之前） |
| 是否按「窗口存在」继续 | 继续（`! PM 窗口状态异常（missing）` 等后续行） | 立即收口，后面一行都没有 |

「不继续」的准确定义：失败分支 `return 1` 在 `team_pm_state` 判定、`--agents` 续跑、容量行和版本提示之前，
所以那一段一行都不打印。这是任务书要的形状（“does not continue as if the window existed”），也是这次改动
对 `up --agents` 的唯一行为变化：窗口建不出来时不再顺带续跑 agent —— 这条没有单独的门禁断言，判据就是上面
「后面一行都没有」这段输出。

## 2. 任务书第 2 条：正向对照（成功路径没变）

同一份夹具脚本的 C 段：`TMUX_TMPDIR` 指向**真的空目录**，session 里只留 `keep` 窗口（这样才会走到「建 PM 窗口」
那条分支；空 session 时 `team_tmux_ensure_session` 自己就带 `pm` 窗口），PM 用 `TEAM_PI_BIN=<夹具>/fake-pi`
（`#!/bin/sh` + 记录 argv + `exec sleep 120`），避免真起一个 pi 会话。

```
$ env -u TMUX -u TMUX_PANE TMUX_TMPDIR=$FX/tmux tmux new-session -d -s v106posrepo -n keep 'sleep 60'
$ env … TMUX_TMPDIR=$FX/tmux bash <cand>/skills/teamsmith/scripts/team up        # rc=0
✓ 创建 PM 窗口 v106posrepo:pm
! PM 窗口里有非 PM 进程（tmux，cwd=/tmp/v106-verify/repro/pos/repo）：不算存活
✓ PM 已启动（替换了非 PM 进程；cli=pi，proof=spawn，model=deepseek/deepseek-flash）
--- 窗口 before ---  1 keep            # C-pos-windows-before.log
--- 窗口 after  ---  1 keep / 2 pm     # C-pos-windows-after.log
```

成功行与修前逐字相同（`team_ok "创建 PM 窗口 $TEAM_SESSION:$TEAM_PM_WINDOW"` 那一行在 diff 里没有被触碰，
见 §4），而且 up 仍然继续把 PM 拉起来（`proof=spawn` + 假 pi 收到 `--provider/--model/-e` 参数）。

## 3. 任务书第 3 条：门禁绿 + 翻转证据（红 → 绿）

三棵独立 clone、三轮 `--select 11b2`、每轮自己的 `TMPDIR`（门禁锁、临时根、tmux socket 全在私有目录里；
日志第 6 行是 `全量门禁互斥：本轮由 pid=… 持有 …/.teamsmith-smoke.lock.machine … 不再排队`，没有排队、没有碰别人的锁）。
红侧树是候选 clone 的副本，只做一件事：

```bash
$ git -C /tmp/v106-verify/red checkout -q 596143e6 -- skills/teamsmith/scripts/lib/cmd-watch.sh   # 换回修前实现
$ git -C /tmp/v106-verify/red checkout -q 544c0e45 -- skills/teamsmith/scripts/lib/cmd-watch.sh   # 还原
```

| 腿 | 树 | 11b2 | 全轮 | rc | 红的是哪两条 |
|---|---|---|---|---|---|
| 候选 | `/tmp/v106-verify/cand`（`544c0e45`） | ✓36 ✗0 | ✓364 ✗0 | 0 | — |
| 红侧 | 同候选 + 修前 `cmd-watch.sh` | ✓34 ✗2 | ✓362 ✗2 | 1 | ①c-② `不打印成功行`、①c-③ `失败行点名目标窗口` |
| 还原 | 同上，文件换回候选 | ✓36 ✗0 | ✓364 ✗0 | 0 | — |

候选（`smoke-cand.log:382-385,412,420,422`）：

```
  ✓ P376：PM 窗口建不出来时 up 退非 0（失败不许看起来成功）
  ✓ P376：窗口没建出来时不打印成功行
  ✓ P376：失败行点名目标窗口
  ✓ P376：失败保留 tmux 自己的诊断（坏路径原样上屏）
#12 11b2 · PM 存活必须被证明（M6.5：空窗 ≠ PM 在运行） · 参考 用时 15s · ✓36 ✗0 SKIP0 · ticks 36
账本自查： 12 段收口 · 增量 ✓364 ✗0 SKIP0 ｜ 结果行 ✓364 ✗0 —— 一致
== 选段结果 ==  ✓ 364  ✗ 0
```

红侧（`smoke-red.log:382-385,412,420,422`）：

```
  ✓ P376：PM 窗口建不出来时 up 退非 0（失败不许看起来成功）
  ✗ P376：窗口没建出来时不打印成功行（不该出现 [创建 PM 窗口 teamsmith-smoke-2683835:pm]）
  ✗ P376：失败行点名目标窗口（…/up-badtmux.log 中找不到 [创建 PM 窗口失败（teamsmith-smoke-2683835:pm]）
  ✓ P376：失败保留 tmux 自己的诊断（坏路径原样上屏）
#12 11b2 · … · ✓34 ✗2 SKIP0 · ticks 36
账本自查： 12 段收口 · 增量 ✓362 ✗2 SKIP0 ｜ 结果行 ✓362 ✗2 —— 一致
== 选段结果 ==  ✓ 362  ✗ 2
```

还原（`smoke-green.log:382-385,412,422,428`）：`✓36 ✗0` / `✓364 ✗0` / `rc=0`，与候选那轮同一读数。

**这组新断言里只有两条能分辨修前/修后**：`rc≠0` 与「tmux 诊断还在」在修前那轮也是 ✓（修前的 rc=1 来自后面的
`pm_fail`，诊断本来就没被重定向）。所以读翻转证据时，**✓36 里真正承载这次修复的是 ①c-② 和 ①c-③**；另外两条
钉的是「修法不是只加一行警告」和「不许靠吞 stderr 变绿」，不是判别器。这不是缺陷（任务书要的两件事都在），
但它决定了「红侧只红 2 条」是**预期读数，不是覆盖不足**。

## 4. 任务书第 4 条：产品 diff（只有创建分支变了）

```
$ git diff 596143e6..544c0e45 --stat -- skills/teamsmith/scripts/ skills/teamsmith/tests/
 skills/teamsmith/scripts/lib/cmd-watch.sh | 12 +++++++++++-
 skills/teamsmith/tests/smoke.sh           | 11 +++++++++++
$ git diff 596143e6..544c0e45 -- skills/teamsmith/scripts/     # 一个 hunk，@team_cmd_up
-    team_tmux_new_window "$TEAM_SESSION" "$TEAM_PM_WINDOW" || true
+    # V60 R2：…（4 行注释）
+    local pm_win_rc=0
+    team_tmux_new_window "$TEAM_SESSION" "$TEAM_PM_WINDOW" || pm_win_rc=$?
+    if [ "$pm_win_rc" != "0" ]; then
+      team_err "创建 PM 窗口失败（$TEAM_SESSION:$TEAM_PM_WINDOW，tmux new-window rc=$pm_win_rc；…）"
+      team_dim "  修法：… $TEAM_CLI up；窗口在、里面是空的：up 会重启 PM" >&2
+      team_up_backup_note
+      return 1
+    fi
     team_ok "创建 PM 窗口 $TEAM_SESSION:$TEAM_PM_WINDOW"
```

逐条核过任务书列的四条边界：

- **没有新增 `|| true`，也没有泛化**：这个 hunk 是**删掉**这一处 `|| true`，新增行里一个都没有（文件里还有 61 处
  同族写法，本 diff 一处没动、也没新增 —— 只替换了 `up` 建 PM 窗口这**一处**的判定）。
- **没有吞 stderr**：`team_tmux_new_window` 的调用没有重定向，`team_err` 走 stderr，`team_dim` 显式 `>&2`；
  实证是 §1 里那两行 `couldn't create directory …` 原样留在失败行之前。
- **没有 adapter / PM 身份 / session 设计改动**：整个产品 diff 只有这一个 hunk，`team_pm_state`、身份 guard、
  启动路径、`TEAM_PM_*` 解析全都没碰；断言的落点是既有 §11b2，没有新段、没有新夹具框架。
- **只改了 `up` 的创建分支**：`grep -n "team_tmux_new_window" cmd-watch.sh` 的另一处是 `:677`（pulse 重建），
  仍是 `|| true`。作者在报告 §3 把这处交回 PM 知悉，说它「没有成功行、失败由 `team_warn "pulse: PM 拉起失败"` 说出来」——
  我读了那一段（`:676` 的 `team_wlog "PM 窗口丢失，重建"` → `:677` 的 `team_tmux_new_window … || true`，失败后继续走到
  `:697` 的 `team_pm_start`，失败由 `:705` 的 `team_warn "pulse: PM 拉起失败（…）"` 收口），**这句披露是准确的**，
  不存在「在 pulse 里也有一个报成功的谎」。

## 5. 任务书第 5 条：静态检查（候选树，`/tmp/v106-verify/cand`）

```
$ bash -n skills/teamsmith/scripts/lib/cmd-watch.sh        rc=0
$ bash -n skills/teamsmith/tests/smoke.sh                  rc=0
$ bash skills/teamsmith/tests/section-select.sh --check    rc=0
    ok: 映射表 key 唯一（135 行）｜ok: 段 ↔ 行一一对应（135/135）｜ok: needs 声明全部存在且指向更早的段（109 条）
    ok: 字面模式（647 条）里 646 条在位；1 条检出前提按缺失跳过 ｜ok: 前导段声明有效 ｜ok: 分片是地板的精确划分 …
    == 选段自检 ==  ok 12  bad 0  SKIP 1
$ bash skills/teamsmith/tests/ledger-ban.sh                rc=3
    ledger-ban: SKIP names —— 禁令名单未配置（…/.pi/team/forbidden-names.txt 不存在；这一项不是通过）
    ledger-ban: root=… scope=published files=2185 hits=0 names=missing user=resolved
$ git diff --check 596143e6..544c0e45                       rc=0（无输出）
```

`ledger-ban` 的 rc=3 是它自己的「有子项跳过」语义（门禁按 0|3 都算无命中），命中数 0。全套门禁**没有**跑
（任务书要求「不跑全套」），跑的是 12 段：`0 0b 0c 0d 2 4 5 3b 6 6i 11b 11b2`（每轮 362–364 条断言、SKIP0），
其余 123 个键没跑 —— 引用本报告的读者必须按这条边界读「绿」。

## 6. 结论的边界（这些都不作数 / 不许外推）

- **失败形态只有一种**：`TMUX_TMPDIR` 不可用会先打掉 session 创建，再打掉窗口创建。所以「server 活着、session 活着、
  只有 `new-window` 失败」那一格没有被这组夹具覆盖（不是这次改动的判据，任务书点名的也是 TMUX_TMPDIR 这一种）。
- **新断言是 live-only**：`§11b2` 在 `TEAM_SMOKE_FAST=1` 下整段 `fast_skip`（`smoke.sh:6269-6270`），所以这条修复
  不会被 FAST 模式的门禁跑到。`TEAM_SMOKE_FAST=1` 的全绿**不能**当作这次修复的证据。
- **规格里没有这句话**：`openspec/specs/pm-lifecycle/spec.md` 只对 `foreign` 占用写了「exits non-zero」，没有一句
  要求「PM 窗口建不出来必须报失败」。任务书把 `change:`/`deltas:` 都写成 `-`，所以这是 PM 的裁定；从守卫角度不算
  裸奔（§11b2 的断言就是那条守卫），但如果以后有人问「这条行为写在哪」，答案是「只在门禁里」。
- **不是全量门禁**：见 §5 的 12 段 / 123 个键。

## 7. 交付状态

- 分支 `task/V106-pm-window-truth-review`，只多了本报告这一个提交；**按任务书不推送**（`git remote -v` 里虽然配了
  `origin`/`public`，本任务没有推送授权，本地分支交付、PM 复验后自己处理）。
- 复验证据（脚本 + 全部原始日志，188 KB）在 `docs/team/reports/V106-verify/`：`repro.sh`（§1/§2 的三段夹具）、
  `run-smoke.sh`（§3 的三轮门禁）、`logs/`（`A-*` `B-*` `C-*` `repro-run2.log` `smoke-{cand,red,green}.log`
  `static-checks.log`）。该目录被 `.gitignore:33` 的 `docs/team/reports/**` 忽略（只放行顶层 `*.md`），
  所以它**只在本机磁盘上**，没有进提交 —— 要复核时按 §1/§3 的命令原样重跑即可。
- 没修实现、没加守卫、没合并、没改任何其他人目录。
