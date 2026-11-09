# P438 · 模型配置变化不得停用关键回复捕获

agent: dev   status: delivered   time: 2026-11-09T10:31:55Z
branch: `task/P438-reply-config-change`   PR/MR: -

## Deliverables

实现提交：`baec7e19 fix(reply): ignore ordinary config changes in capture identity`。

| Path | What |
|---|---|
| `skills/teamsmith/scripts/reply-capture.mjs` | 捕获身份不再包含配置内容哈希、设备号或 inode；重新证明身份仍比较 root/state/config 路径、会话、进程与 tmux 证据。doctor 仍检查配置路径、普通文件与属主，但不再比较配置内容 |
| `skills/teamsmith/tests/reply-capture-real.mjs` | 新增真实 Pi + 产品 CLI 的任务模型修改、配置 inode 变化、标记回复保存、runtime/doctor ready 断言；加入旧哈希/inode 判据的红侧变异与恢复对照；恢复诊断改用真实 pm 窗口改名触发身份拒绝 |

## Verification evidence (must have actually been run)

真实缺陷先在旧实现上复现，再修产品代码：

```
$ P396_EVIDENCE=/var/tmp/p438-before-config bash skills/teamsmith/tests/reply-capture-real.sh --select=config-change
FAIL real Pi task-model CLI edit keeps live capture and doctor ready: AssertionError [ERR_ASSERTION]: task-model edit leaves runtime ready
'stale' !== 'ready'
reply-capture-real: passed=0 failed=1 evidence=/var/tmp/p438-before-config
$ echo $?
1
```

修复后的同一真实探针由完整套件中的 control 运行。它等待捕获 ready，执行
`team --root <隔离项目> config set-task-model routine p396/after-config --yes`，断言配置字节和 inode 均改变，再验证标记回复保存、消息清理、runtime 和 doctor：

```
$ tail -8 /var/tmp/p438-reply-capture-real-all/config-control.log
PASS real Pi task-model CLI edit keeps live capture and doctor ready
reply-capture-real: passed=1 failed=0 evidence=/var/tmp/p438-reply-capture-real-all/config-control

$ rg '关键回复运行' /var/tmp/p438-reply-capture-real-all/config-control/config-change/doctor.txt
关键回复运行       ✓ ready disk=e3607bb76d0c1d476bdeb3ca4cd690299343d5437b24b2a805e5fe8947bf0703 loaded=e3607bb76d0c1d476bdeb3ca4cd690299343d5437b24b2a805e5fe8947bf0703 …; live PM registered actual loaded source

保存记录：status=saved, no=1, title=决定 config-change, entryId=649a09fe
```

捕获单元套件（含符号链接、属主、普通配置/会话文件与写入面既有对照）：

```
$ node skills/teamsmith/tests/reply-capture.mjs --all
…
PASS project config owned by another user is refused and names the file
PASS our own runtime.json: 664 is written (mode is not a judgement)
PASS a runtime lock owned by another user is refused and names the file
…
reply-capture: passed=127 failed=0
```

真实 Pi 全套件（私有 loopback provider、私有 tmux socket，不读取真实模型凭据）：

```
$ P396_EVIDENCE=/var/tmp/p438-reply-capture-real-all bash skills/teamsmith/tests/reply-capture-real.sh
…
PASS real Pi restoring config hash/inode identity makes the real edit red; restoration is green
PASS real Pi restoring diagnostic stderr makes the real Pi terminal assertion red; restoration is green
…
PASS real Pi live registration distinct from disk, dead/reused process and readonly doctor
reply-capture-real: passed=25 failed=0 evidence=/var/tmp/p438-reply-capture-real-all
```

关键回复 workflow：

```
$ bash skills/teamsmith/tests/key-replies.sh --select workflow
== P234 key-replies 结果 == ✓15 ✗0 SKIP0
```

doctor 相关选段（选择器自动带出前置段）：

```
$ bash skills/teamsmith/tests/smoke.sh --select 1,2,3 </dev/null
#5 1 · doctor（未初始化应失败） · ✓2 ✗0 SKIP0
#6 2 · init · ✓39 ✗0 SKIP0
#7 3 · doctor（初始化后） · ✓7 ✗0 SKIP0
== 选段结果 ==  ✓ 72  ✗ 0
```

结构与规格检查：

```
$ node --experimental-strip-types skills/teamsmith/extension/team-reply.ts
$ node --check skills/teamsmith/scripts/reply-capture.mjs
$ node --check skills/teamsmith/tests/reply-capture-real.mjs
$ bash -n skills/teamsmith/tests/reply-capture-real.sh skills/teamsmith/tests/live-capture-probe.sh
（全部 rc=0，无输出）

$ bash skills/teamsmith/tests/section-select.sh --check
== 选段自检 ==  ok 13  bad 0  SKIP 1
$ bash skills/teamsmith/tests/section-select.sh --self-sufficient
== 段副本自足 == ok 139 bad 0（139 个键；段体函数 443 个，assert_* 未定义 0 个，整份套件的命令词 824 个）

$ npm exec --cache /var/tmp/p438-npm-cache --yes --package=@fission-ai/openspec@1.8.0 -- openspec validate --all --strict
Totals: 23 passed, 0 failed (23 items)
```

- Verdict: pass。任务书要求的定向验收均已实际运行。
- 未跑全量、夜间或 61b，符合任务书限制。doctor 命令只是选段；其输出另列 132 个未运行键，不据此宣称全套门禁通过。
- Ledger ban（最终报告写入后，在本 worktree 运行）：

  ```
  $ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
  ledger-ban: root=/home/<user>/Documents/syncthing/Work/Projects/pm-skills/.worktrees/dev scope=published files=2534 hits=0 names=ok user=resolved
  $ echo $?
  0
  ```

## Flip evidence (required for defect-fix tasks)

旧实现红 → 新实现绿见首节。完整套件还在隔离 skill 副本中同时恢复 `configHash` 与 `configIno` 身份字段及 doctor 哈希比较；同一真实 CLI 修改立即变红，未变异副本保持绿：

```
$ tail -12 /var/tmp/p438-reply-capture-real-all/config-flip.log
reply-capture-real: passed=0 failed=1 evidence=/var/tmp/p438-reply-capture-real-all/config-flip
FAIL real Pi task-model CLI edit keeps live capture and doctor ready: AssertionError [ERR_ASSERTION]: task-model edit leaves runtime ready
'stale' !== 'ready'

$ tail -2 /var/tmp/p438-reply-capture-real-all/config-control.log
PASS real Pi task-model CLI edit keeps live capture and doctor ready
reply-capture-real: passed=1 failed=0 evidence=/var/tmp/p438-reply-capture-real-all/config-control
```

身份边界没有放宽：原诊断探针过去靠追加配置制造拒绝，本任务将它改成真实 `tmux rename-window pm → not-pm`。运行中重新证明身份仍拒绝，未保存回复，并留下本地诊断：

```
$ P396_EVIDENCE=/var/tmp/p438-diagnostics bash skills/teamsmith/tests/reply-capture-real.sh --select=diagnostics
PASS real Pi recover-skip:ineligible is file-only and never appears in the Pi terminal
reply-capture-real: passed=1 failed=0 evidence=/var/tmp/p438-diagnostics

诊断：recover-skip:ineligible; source=unbound; evidence=<隔离项目>/reply-capture/<journal>.json
```

既有真实 runtime 对照还继续覆盖 dead/reused process、disk source stale、foreign/worker/ordinary/custom/inherited/config-link 拒绝；这些均在上述 25 项全套件中通过。

## Decisions and deviations

- 没有新增配置开关，没有读取或采用新的任务模型映射来决定捕获归属。
- 配置内容元数据从身份对象中移除，因此 `team-reply.ts` 的现有深比较自然只覆盖捕获归属字段；无需另建一套字段白名单。
- `inspectRuntime()` 仍调用 `readRegular(config)`，保留配置符号链接、文件类型和属主检查；仅删除内容哈希比较。
- 分支保持本地，未推送、未合并、未发布。

## Suggested next steps

- 由非作者独立复验；重点重跑 `--select=config-mutations` 与真实保存/doctor 证据。
