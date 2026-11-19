# V181 · P480 只读检查与真实第 5 页独立验证

agent: verify   status: PASS — 候选行为检查及合并版短核对   time: 2026-11-19T03:08:49Z
branch: `task/V181-key-replies-readonly-tmux-verify`   PR/MR: -

**合并版 `3b44b960c7c64d861618427ee90a5ea333892acd` 与已实测候选的三个测试文件逐字节相同，语法检查全部通过。** 合并版未重复行为检查。

**候选 `00f184fac002e0b4b8bc2bc4c3f620690c40c65b` 实测通过。** 三组只读检查各初始化一个独立项目，读到了真实数据，共 110 条通过、0 失败、0 跳过；没有启动、重启或清理终端。真实终端组 13 条通过、0 失败、0 跳过；重新打开面板后仍在第 5 页，两条原回复均在列表中。

## Deliverables

| 路径 | 可核对的证据 |
|---|---|
| `docs/team/reviews/P480.md`、`docs/team/reviews/P480-verify.log` | 当前正式记录为合并版 PASS，执行者 `verify`；候选正式记录已由 PM 收存，候选检查执行 132 秒。 |
| `/var/tmp/v181.lW72MA/{run.sh,bin/tmux,receipt.py,review.out,ui.out,pty.out,ui.tmux.tsv,pty.tmux.tsv}` | 一次运行的驱动、实际命令输出、tmux 参数、目录与目标套接字；转发给 `/usr/bin/tmux`，不替换允许调用的结果。拒绝次数为 0。 |
| `/var/tmp/v181.lW72MA/tmp/{teamsmith-p234-reply-ui-pm_skills-deb708fe.prUp48,teamsmith-p234-reply-pty-pm_skills-deb708fe.JXKrBd}` | 每个项目的 `init.log`、独立 Git 仓和配置，原测试生成的画面、CLI 输出；`pages/restart.txt` 保存重开后的实际画面。原件保留待 PM 收存。 |

## OpenSpec assessment

N/A — `change: -`，锚定 `openspec/specs/panel/spec.md` 的 `Key reply blocks are async demand reads and absent from machine exits`。`git diff 71d3ae0a..00f184fa` 只改 `key-replies-ui.sh`、`lib/reply-fixture.sh` 并新增作者报告，无产品或规格改动。仅复验原有检查在新的准备方式下仍能执行，不作整项规格验收声明。

## CRITICAL

None — 候选差异保留三个项目的种子、原读者、原断言与路由组函数；只读组以 `fixture_prepare` 代替 `fixture_up`，退出仅回收临时根。`init` 经 `kr_cli` 显式传入 `--root` 并清除继承的配置路径；四份 `init.log` 均指向各自临时项目。未增加替身、跳过项或面向正式脚本的新参数。`key-replies-pty.sh` 与基线逐字相同，`fixture_up` 仍保留私有套接字判定、终端启动及清理；`pages` 原有两次面板启动和重开断言都执行了。

## WARNING

None — 622 次只读 tmux 调用全部指向本次私有目录，包含 `has-session` 58 次、`list-windows` 419 次、`show-environment` 145 次；没有启动或清理命令，也没有请求共享套接字。这里的“只读”不是“不调用 tmux”。

## SUGGESTION

None — 本次用外部记录得到可核对的调用次数和目录，无须更改正式测试。

## Final assessment

- CRITICAL 0 · WARNING 0 · SUGGESTION 0。候选行为检查通过，PM 合并后按范围复核三份测试文件，均与候选逐字节相同且通过语法检查；没有在合并版重复行为批次。
- 未执行旧版整组、`routing-regression`、设置、独立存储 FIFO、其余八个真实终端组或完整套件。`machine` 内原有的坏存储/FIFO 断言照常执行，不等于另跑独立 FIFO 批次。两次时长仅为本次观测，无旧版计时对照，不推断全套收益。

## Verification evidence

```text
$ TEAM_GATES='bash /var/tmp/v181.lW72MA/run.sh' bash skills/teamsmith/scripts/team review P480 --dir /var/tmp/p480-review-00f184fa.r77bEA --branch 00f184fac002e0b4b8bc2bc4c3f620690c40c65b
✓ review checkout: /var/tmp/p480-review-00f184fa.r77bEA @ 00f184fac（分支 00f184fac002e0b4b8bc2bc4c3f620690c40c65b，干净）
✓ 门禁输出：docs/team/reviews/P480-verify.log（PASS，132s）
✓ 复验记录：docs/team/reviews/P480.md（PASS）
review rc=0

$ bash skills/teamsmith/tests/key-replies-ui.sh --select blocks,machine,snapshots
== P234 key-replies-ui 结果 == ✓110 ✗0 SKIP0
ui rc=0 wall=116s

$ bash skills/teamsmith/tests/key-replies-pty.sh --select pages
✓ pages：重启后仍在第 5 页且回复可读
✓ pages：panel-page 记的是 5
== P234 key-replies-pty 结果 == ✓13 ✗0 SKIP0
pty rc=0 wall=16s
suite exits ui=0 pty=0 receipt=0
```

| 组别 | 通过 / 失败 / 跳过 | 初始化与实际读取 | tmux 调用 / 启动 |
|---|---:|---|---|
| `blocks` | 48 / 0 / 0 | `blocks/root`；`bl-body.txt` 有原文“块夹具正文” | 120 次查询 / 0 |
| `machine` | 6 / 0 / 0 | `machine/root`；发布前后 print/JSON 一致，`m-json-after.txt` 可解析 | 42 次查询 / 0 |
| `snapshots` | 55 / 0 / 0 | `snapshots/root`；读到 60 条，`snap-view.txt` 有“长文快照” | 460 次查询 / 0 |
| `pages` | 12 / 0 / 0 | `pages/root`；重开画面仍有 `#2 第二份回复`、`#1 完整结论与取舍` | 120 次调用 / 1 个私有会话、2 次面板启动 |

两个脚本各有一条额外的仓库回复存储前后比对，均通过，已计入原始汇总。只读查询的 `TMUX_TMPDIR` 是 `/var/tmp/v181.lW72MA/tmp/teamsmith-p234-reply-ui-pm_skills-deb708fe.prUp48`，目标为其下 `tmux-1000/default`，没有继承调用者的会话。`pages` 的 `TMUX_TMPDIR` 是 `/var/tmp/v181.lW72MA/pty`，目标为其下 `tmux-1000/p234kr-pty-4120173`；记录有会话前置清理和退出清理各一次。作业结束后 `/proc/net/unix` 无该证据根下的套接字。两次测试没有连接在用团队的终端，没有使用其回复、队列或模型。

静态核对：从本席位对固定源执行 `git -C /var/tmp/p480-review-00f184fa.r77bEA diff --check 71d3ae0a HEAD`、三个测试脚本 `bash -n`、`git diff --exit-code 71d3ae0a HEAD -- skills/teamsmith/tests/key-replies-pty.sh`，均退出 0；固定检出执行前后 `git status --porcelain` 无输出。

```text
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=/home/<user>/Documents/syncthing/Work/Projects/pm-skills/.worktrees/verify scope=published files=2912 hits=0 names=ok user=resolved
ledger-ban rc=0
```

## Flip evidence

N/A — 本任务去掉的是测试准备中的三次无用启动，不是产品缺陷修复。对照来自静态差异（原三个 `fixture_up` 调用会走 `new-session`）和候选实际记录（0 次启动）；未重跑旧版，不把差异当作旧版实测。

## Decisions and deviations

无。将 `TEAM_TMP_KEEP=1` 仅用于保留本次证据，不改变 tmux 退出流程；实际只执行任务书指定的两个选择命令。V179 为独立清理事项：`lsof +D` 未列出占用者，但提示其他挂载无法检查；进程参数、套接字清单及目录下套接字均未发现该路径。`rm -rf -- /var/tmp/v179-verify.TnHL8G` 退出 0，随后确认该路径不存在；未删除别的根。

## 合并版短核对 · 2026-11-19T03:08:01Z

```text
$ TEAM_GATES='bash /var/tmp/v181.lW72MA/merged.sh' bash skills/teamsmith/scripts/team review P480 --dir /var/tmp/p480-merged-3b44b960.Jc43uO --branch 3b44b960c7c64d861618427ee90a5ea333892acd
✓ review checkout: /var/tmp/p480-merged-3b44b960.Jc43uO @ 3b44b960c（分支 3b44b960c7c64d861618427ee90a5ea333892acd，干净）
✓ 复验记录：docs/team/reviews/P480.md（PASS）
review rc=0

$ # 正式检查输出（从上述合并版目录读取）
cmp rc=0: skills/teamsmith/tests/key-replies-ui.sh
bash -n rc=0: skills/teamsmith/tests/key-replies-ui.sh
cmp rc=0: skills/teamsmith/tests/key-replies-pty.sh
bash -n rc=0: skills/teamsmith/tests/key-replies-pty.sh
cmp rc=0: skills/teamsmith/tests/lib/reply-fixture.sh
bash -n rc=0: skills/teamsmith/tests/lib/reply-fixture.sh
3 identical files; 3 syntax checks passed; no behavior checks run
```

`merged.sh` 与正式命令回执 `merged-review.out` 保存在 `/var/tmp/v181.lW72MA`。`cmp` 读取两个固定检出的实际文件，`bash -n` 只读取合并版；两处检出无未提交文件或忽略产物。合并版行为未重跑，110 条和 13 条是上面候选阶段的原始结果。

## Suggested next steps

交 PM 接受合并版证据。候选原始输出、画面与调用记录仍保留，不清理固定检出和运行目录。
