# P376 · PM 窗口没建出来时不再报成功

agent: dev · phase: apply · category: code · change: `-` · anchor: none (infra) — 既有行为修复
branch: `task/P376-pm-window-create-truth` · 代码 tip: `3b563c41` · time: 2026-10-26T06:37Z

**判定：delivered** —— `team_cmd_up` 里「建 PM 窗口」那条分支现在由 `team_tmux_new_window` 的返回码决定：
失败时给具名错误（含目标窗口与 tmux 自己的诊断）、退非 0、不打印成功行、也不按「窗口存在」继续；
成功路径逐字未变。产品只改 `cmd-watch.sh` 一处，测试只在既有的 §11b2 加了一组断言。

| 任务书的要求 | 结论 | 一行证据 |
|---|---|---|
| 失败时具名错误（含 tmux 目标）、保留 tmux 诊断、退非 0、不打成功行、不继续 | 成立 | 同一夹具同一命令：修前 `✓ 创建 PM 窗口 p376fix:pm` + `! PM 窗口状态异常（missing）`；修后 `✗ 创建 PM 窗口失败（p376fix:pm，tmux new-window rc=1…）` 后立即收口，`rc=1`（§2） |
| 成功路径不变（成功行 + 继续启动 PM） | 成立 | 私有 tmux 里只留 `keep` 窗口再跑 up：`✓ 创建 PM 窗口 p376fix:pm` → `✓ PM 已启动（… proof=spawn …）` → `list-windows` 出现 `2 pm`，`rc=0`（§4） |
| 既有门禁段里加一条行为断言，且旧实现下红、修复后绿 | 成立 | `--select 11b2`：红侧（旧 `cmd-watch.sh` + 新断言）`11b2 ✓34 ✗2`、全轮 `✓362 ✗2` rc=1，红的就是那两条成功行断言；绿侧（候选）`11b2 ✓36 ✗0`、全轮 `✓364 ✗0` rc=0（§5） |
| 只跑受影响段 + `bash -n` / `--check` / 账本禁令 / `git diff --check` | 成立 | §5、§6 的真实读数；全量门禁未跑（任务书要求「不跑全套」） |

## 1. 改了什么

```diff
   if ! team_pm_window_exists; then
-    team_tmux_new_window "$TEAM_SESSION" "$TEAM_PM_WINDOW" || true
-    team_ok "创建 PM 窗口 $TEAM_SESSION:$TEAM_PM_WINDOW"
+    local pm_win_rc=0
+    team_tmux_new_window "$TEAM_SESSION" "$TEAM_PM_WINDOW" || pm_win_rc=$?
+    if [ "$pm_win_rc" != "0" ]; then
+      team_err "创建 PM 窗口失败（$TEAM_SESSION:$TEAM_PM_WINDOW，tmux new-window rc=$pm_win_rc；上面是 tmux 的诊断）：窗口不存在，PM 没有起来"
+      team_dim "  修法：确认 tmux server 可用（tmux ls）后重跑 $TEAM_CLI up；窗口在、里面是空的：up 会重启 PM" >&2
+      team_up_backup_note
+      return 1
+    fi
+    team_ok "创建 PM 窗口 $TEAM_SESSION:$TEAM_PM_WINDOW"
   fi
```

`skills/teamsmith/scripts/lib/cmd-watch.sh`（+11 / −1）。

- 失败路径**提前返回**，所以后面的「PM 进程」判定与 `--agents` 续跑不会在「窗口不存在」的现场继续跑；
  `team_up_backup_note` 与 up 里其它早退分支同形（迁移备份提示不会因为这次失败被吞掉）。
- tmux 的 stderr 没有被重定向、也没有被替换成一句泛泛的「失败」：`team_tmux_new_window` 只做空目标校验，
  真正的诊断由 tmux 自己打在上方那两行（下面 §2 的实证里有原样保留的 `couldn't create directory …`）。
- 返回码进文案（`tmux new-window rc=$pm_win_rc`）：这是失败**原因**与失败**事实**的分离，读者不用猜是
  「窗口已存在」还是「tmux 起不来」。
- 成功行原样保留（逐字未改），仍是 `✓`；失败行用 `✗` + `team_err`（与 up 里「PM 启动失败」同一形式）。

测试：`skills/teamsmith/tests/smoke.sh` §11b2 新增 ①c（+11 行，见 §5 的红/绿读数）。

## 2. 复现（任务书第 1 条）

独立夹具：`/tmp/p376-fix/repo`（`team init --session p376fix`，假 pi 不在场），tmux 现场是**私有**的
—— `TMUX_TMPDIR` 指向一个**普通文件**，真 tmux 直接报错起不了 server 也不会回退默认 socket：

```bash
$ printf 'not a directory\n' > /tmp/p376-fix/notadir
$ cd /tmp/p376-fix/repo && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT -u TEAM_SESSION \
    -u TMUX -u TMUX_PANE TMUX_TMPDIR=/tmp/p376-fix/notadir \
    bash <worktree>/skills/teamsmith/scripts/team up
```

**修前**（`HEAD~2` 的 `cmd-watch.sh`）—— 窗口没建出来，成功行照样出现：

```
teamsmith up · repo（只负责 PM）
! tmux session 'p376fix' 不存在：重建
couldn't create directory /tmp/p376-fix/notadir/tmux-1000 (Not a directory)
✗ 建不出 tmux session p376fix（tmux 起不来？后面的窗口操作都会失败）
couldn't create directory /tmp/p376-fix/notadir/tmux-1000 (Not a directory)
✓ 创建 PM 窗口 p376fix:pm
! PM 窗口状态异常（missing）：不抢窗口
  agent 不归 pulse/up 管：需要续跑时跑 team resume [--dry-run]
…
rc=1
```

**修后**（候选）—— 同一条命令，具名失败、没有成功行、不问「窗口状态」、直接收口：

```
teamsmith up · repo（只负责 PM）
! tmux session 'p376fix' 不存在：重建
couldn't create directory /tmp/p376-fix/notadir/tmux-1000 (Not a directory)
✗ 建不出 tmux session p376fix（tmux 起不来？后面的窗口操作都会失败）
couldn't create directory /tmp/p376-fix/notadir/tmux-1000 (Not a directory)
✗ 创建 PM 窗口失败（p376fix:pm，tmux new-window rc=1；上面是 tmux 的诊断）：窗口不存在，PM 没有起来
  修法：确认 tmux server 可用（tmux ls）后重跑 team up；窗口在、里面是空的：up 会重启 PM
rc=1
```

两次 `rc` 都是 1（修前那 1 来自后面的 `pm_fail`，不是这次创建失败）——所以判据是**成功行与具名失败行**，
不是返回码本身；§5 的断言里返回码只作为「修法不是只打一行警告」的配套钉子。

## 3. 没改的那一处（边界，交 PM 知悉）

`cmd-watch.sh:677`（pulse 的重建分支）也是 `team_tmux_new_window … || true`，但它**没有成功行**：失败后
继续走 `team_pm_start`，失败由 `team_warn "pulse: PM 拉起失败"` 说出来，不存在「报告创建成功」。
任务书把范围限定在这次创建分支，所以它按原样留着；要不要给它补一条具名行是另一个决定。

## 4. 正向对照（任务书第 2 条）

同一夹具、改成**真的私有 socket 目录**（`TMUX_TMPDIR=/tmp/p376-fix/tmux`；夹具把 `TEAM_PI_BIN` 指向一个
`#!/bin/sh` + `exec sleep 120` 的脚本，以免真起一个 pi 会话 —— `cli=` 那行仍显示 `pi`：`team_pm_cli_name`
只看 `TEAM_PM_BIN`/`TEAM_PM_CMD`，`TEAM_PI_BIN` 是回落到 `pi` 的那条），把 session 里只留一个 `keep`
窗口 —— 这样才会走到「建 PM 窗口」那条分支：

```bash
$ env -u TMUX -u TMUX_PANE tmux new-window -t p376fix -n keep -d 'sleep 60'
$ env -u TMUX -u TMUX_PANE tmux kill-window -t p376fix:pm
$ env -u TMUX -u TMUX_PANE tmux list-windows -t p376fix -F '#{window_index} #{window_name}'
1 keep
$ cd /tmp/p376-fix/repo && env -u TEAM_ROOT … TMUX_TMPDIR=/tmp/p376-fix/tmux \
    bash <worktree>/skills/teamsmith/scripts/team up
teamsmith up · repo（只负责 PM）
✓ 创建 PM 窗口 p376fix:pm
! PM 窗口里有非 PM 进程（tmux，cwd=/tmp/p376-fix/repo）：不算存活
  续跑：pi -c（本目录上一个会话）
✓ PM 已启动（替换了非 PM 进程；cli=pi，proof=spawn，model=deepseek/deepseek-flash）
  agent 不归 pulse/up 管：需要续跑时跑 team resume [--dry-run]
…
$ env -u TMUX -u TMUX_PANE tmux list-windows -t p376fix -F '#{window_index} #{window_name}'
1 keep
2 pm
rc=0
```

成功行照旧出现、窗口真的建出来、up 照旧继续把 PM 拉起来。该私有 server 已 `kill-server` 收起，夹具里的
`TEAM_PI_BIN` 已还原成 `pi`。

## 5. 门禁：受影响段（任务书第 3、4 条）

红/绿是**同一段、同一棵候选代码的其它字节**、只是把 `cmd-watch.sh` 换成修前版本（`git show HEAD~2:`），
新断言原样在里面。绿侧读数对应 `3b563c41` 的产品与测试字节；它之后只有本报告这一份 docs 提交。
红侧树是 `/tmp/p376-red`（`git init` 过的检出，否则 §0d 冲突标记守卫会因为「不在 git 树里」
自己红一条，与 P376 无关）。

```bash
# 红侧：旧实现 + 新断言
cd /tmp/p376-red && bash skills/teamsmith/tests/smoke.sh --select 11b2
# 绿侧：候选
cd <worktree> && bash skills/teamsmith/tests/smoke.sh --select 11b2
```

红侧（`/tmp/p376-logs/red2.log`，rc=1）：

```
  ✓ P376：PM 窗口建不出来时 up 退非 0（失败不许看起来成功）
  ✗ P376：窗口没建出来时不打印成功行（不该出现 [创建 PM 窗口 teamsmith-smoke-1603379:pm]）
  ✗ P376：失败行点名目标窗口（…/up-badtmux.log 中找不到 [创建 PM 窗口失败（teamsmith-smoke-1603379:pm]）
  ✓ P376：失败保留 tmux 自己的诊断（坏路径原样上屏）
#12 11b2 · PM 存活必须被证明（M6.5：空窗 ≠ PM 在运行） · 参考 用时 15s · ✓34 ✗2 SKIP0 · ticks 36
== 选段结果 ==  ✓ 362  ✗ 2
```

绿侧（`/tmp/p376-logs/green.log`，rc=0）：

```
  ✓ P376：PM 窗口建不出来时 up 退非 0（失败不许看起来成功）
  ✓ P376：窗口没建出来时不打印成功行
  ✓ P376：失败行点名目标窗口
  ✓ P376：失败保留 tmux 自己的诊断（坏路径原样上屏）
#12 11b2 · PM 存活必须被证明（M6.5：空窗 ≠ PM 在运行） · 参考 用时 17s · ✓36 ✗0 SKIP0 · ticks 36
账本自查： 12 段收口 · 增量 ✓364 ✗0 SKIP0 ｜ 结果行 ✓364 ✗0 —— 一致
== 选段结果 ==  ✓ 364  ✗ 0
```

断言的现场（§11b2 ①c）：

```bash
  printf 'not a directory\n' > "$TMP/p376-notadir"
  ( cd "$REPO" && env -u TMUX -u TMUX_PANE TMUX_TMPDIR="$TMP/p376-notadir" $TEAM up ) >"$TMP/up-badtmux.log" 2>&1; RC_BADTMUX=$?
```

`TMUX`/`TMUX_PANE` 必须摘掉：有它们在时 tmux 用那条 socket，`TMUX_TMPDIR` 根本不参与判定（人在窗口外
跑 `team up` 本来就没有它们）。

## 6. 其余检查（`bash -n` / `--check` / 账本禁令 / `git diff --check`）

```
$ bash -n skills/teamsmith/scripts/lib/cmd-watch.sh && bash -n skills/teamsmith/tests/smoke.sh
（无输出，rc=0）
$ for f in $(git ls-files 'skills/teamsmith/scripts/**/*.sh' 'skills/teamsmith/scripts/team' 'skills/teamsmith/tests/*.sh'); do bash -n "$f" || echo "SYNTAX FAIL: $f"; done
bash -n: 98 files ok
$ bash skills/teamsmith/tests/section-select.sh --check
== 选段自检 ==  ok 12  bad 0  SKIP 1          （rc=0）
$ bash skills/teamsmith/tests/ledger-ban.sh
ledger-ban: SKIP names —— 禁令名单未配置（…/.pi/team/forbidden-names.txt 不存在；这一项不是通过）
ledger-ban: root=<worktree> scope=published files=2185 hits=0 names=missing user=resolved   （含本报告；rc=3 =「有子项跳过」，就是上面那行 names 名单未配置，门禁按 0|3 都算「无命中」）
$ git diff --check HEAD~2..HEAD && echo "no whitespace errors"
no whitespace errors
```

## 7. 没跑的段（引用本报告的读者必须知道）

`--select 11b2` 实际跑的是前导段 + 路径选的 12 段：`0 0b 0c 0d 2 4 5 3b 6 6i 11b 11b2`；其余 123 个键
没跑（日志里逐键列出）。全量门禁、容器跑法、面板各段、以及 `--paths skills/teamsmith/scripts/lib/cmd-watch.sh`
选出的那 51 个键（含前导段）**都没跑** —— 任务书明确要求「不跑全套」。选择依据：改动的行为只发生在 `team up` 的
「建 PM 窗口」分支，承载它的既有段是 §11b2（`up` 建 session/窗口 + PM 存活证据链），新断言就加在那里。

## 8. 分支与后续

- 提交：`fa691596`（产品修复）+ `3b563c41`（门禁断言），都带 `Task: P376` / `Agent: dev`。
- local 模式：分支 `task/P376-pm-window-create-truth` 留在本地，未 push、未合并、未动发布。
- 独立验证是另一条任务：本报告的红/绿是同一席位在同一台机器上的读数。
