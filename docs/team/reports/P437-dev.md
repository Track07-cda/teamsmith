# P437 · 关键回复内部诊断不得出现在 Pi 会话输出

agent: dev   status: delivered   time: 2026-11-09T09:53:56Z
branch: `task/P437-reply-diagnostics-ui`   PR/MR: -

结论：常规捕获/恢复诊断与非 PM 场景的启动提示已不再写入 Pi 终端；`recover-skip:ineligible` 仍写入本地 `diagnostics.log`。标记清理、绑定、发布后保存及恢复状态机均未改。

## Deliverables

| Path | What |
|---|---|
| `skills/teamsmith/extension/team-reply.ts` | 删除 `diagnostic()` 的 stderr 写入；删除未通过 PM 身份核验时的 stderr 提示。文件诊断、doctor/runtime 证据与发布流程保持不变 |
| `skills/teamsmith/tests/reply-capture-real.mjs` | 新增真实 Pi 的 `recover-skip:ineligible` 文件落盘/终端无泄漏断言；print stdout/stderr、TUI 原始输出和最终帧统一禁止 `[team-reply]`；默认套件加入恢复 stderr 的反向变异 |
| `docs/team/reports/P437-dev.md` | 本报告 |

## Verification evidence (must have actually been run)

既有 parser、状态机、writer 与所有权测试：

```
$ node skills/teamsmith/tests/reply-capture.mjs --all
PASS mutation restoration: parser green
PASS mutation restoration: source green
PASS flip no-owner-check: named assertion red (FAIL project config owned by another user is refused …)
reply-capture: passed=127 failed=0
rc=0
```

完整真实 Pi 私有套件（真实 Pi、tmux、扩展和 writer；loopback provider 只提供受控回复）：

```
$ P396_EVIDENCE=/var/tmp/p437-reply-capture-real-all bash skills/teamsmith/tests/reply-capture-real.sh
PASS real Pi builtin print/end/append/entry/settled/raw store/transcript
PASS real Pi interactive actual-marker raw PTY and authoritative final cleanup
PASS real Pi restoring diagnostic stderr makes the real Pi terminal assertion red; restoration is green
PASS real Pi owner mutation named red and restoration green in private Pi
PASS real Pi foreign context cannot clean/publish/register
PASS real Pi worker context cannot clean/publish/register
PASS real Pi ordinary context cannot clean/publish/register
PASS real Pi custom context cannot clean/publish/register
PASS real Pi inherited context cannot clean/publish/register
PASS real Pi config-link context cannot clean/publish/register
PASS real Pi two loaded paths share one owner and generation
PASS real Pi live registration distinct from disk, dead/reused process and readonly doctor
reply-capture-real: passed=24 failed=0 evidence=/var/tmp/p437-reply-capture-real-all
rc=0
```

其中正常 print/TUI 用例继续断言终稿无标记、journal 为 `saved`、回复存储恰增一条且正文一致。诊断控制臂实际留下：

```
[team-reply] recover-skip:ineligible; source=unbound; evidence=/var/tmp/…/.pi/team/state/reply-capture/….json
```

同一控制臂的 raw PTY 与最终帧均无 `[team-reply]`；正常 TUI 保存用例的最终帧 grep 计数也为 0。

关键回复 workflow 选段：

```
$ bash skills/teamsmith/tests/key-replies.sh --select workflow
  ✓ workflow：saved 后仍输出同一正文
  ✓ workflow：saved 不动 BOARD/outbox/inbox/pending/config
  ✓ workflow：任何诊断里没有正文
  ✓ workflow：五种结果后账本仍不变
  ✓ workflow：published 总数=2（saved+unconfirmed）
  ✓ 隔离守卫：真实仓库 …/.worktrees/dev 的编号回复存储前后逐字节不变
== P234 key-replies 结果 == ✓15 ✗0 SKIP0
rc=0
```

TS 执行/构建、shell 语法与结构检查：

```
$ node --experimental-strip-types skills/teamsmith/extension/team-reply.ts
$ node --check skills/teamsmith/tests/reply-capture-real.mjs
$ ~/.bun/bin/bun build skills/teamsmith/extension/team-reply.ts \
    --target=node --external @earendil-works/pi-coding-agent --outdir /var/tmp/p437-ts-build
Bundled 1 module in 24ms
  team-reply.js  5.42 KB  (entry point)
$ bash -n skills/teamsmith/tests/reply-capture-real.sh skills/teamsmith/tests/live-capture-probe.sh
syntax/build: PASS

$ bash skills/teamsmith/tests/section-select.sh --check
== 选段自检 ==  ok 13  bad 0  SKIP 1
$ bash skills/teamsmith/tests/section-select.sh --self-sufficient
== 段副本自足 == ok 139 bad 0（139 个键；段体函数 443 个，assert_* 未定义 0 个，整份套件的命令词 824 个）
rc=0
```

OpenSpec 使用 CI 钉住的 1.8.0，在本分支完整 strict 校验：

```
$ npm exec --cache /var/tmp/p437-npm-cache --yes --package=@fission-ai/openspec@1.8.0 -- \
    openspec validate --all --strict
Totals: 23 passed, 0 failed (23 items)
rc=0
```

源码静态复查与空白检查：

```
$ rg -n 'process\.(stderr|stdout)\.write|console\.(error|log|warn)' \
    skills/teamsmith/extension/team-reply.ts
(no output)
$ git diff HEAD^ --check
(no output)
rc=0
```

- Verdict: pass（产品验收全绿，作者自验；独立复验尚未进行。账本禁令只有任务书既有的一条，基线对照相同）
- 未跑全量 smoke、夜间套件或 61b，符合任务边界。未运行消耗远端模型的 `live-capture-probe.sh`；采用任务书允许的等价私有真实 Pi 探针，未接触真实团队会话、凭据或共享 tmux server。
- Ledger ban（报告落盘后的真实结果）：

  ```
  $ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
  docs/team/tasks/P437-reply-diagnostics-ui.md:18: [names] <names#5> 的 PM 会话显示：
  ledger-ban: root=/home/<user>/…/.worktrees/dev scope=published files=2514 hits=1 names=ok user=resolved
  rc=1
  ```

  唯一命中在 PM 的只读任务书，不在本报告或实现。对基线提交 `HEAD^` 的 `git archive` 副本运行同一扫描，结果同为该一行、`hits=1`、`rc=1`（基线 `files=2513`；本分支只新增本报告，`files=2514`）：

  ```
  $ git archive HEAD^ | tar -x -C /var/tmp/p437-ledger-base
  $ bash skills/teamsmith/tests/ledger-ban.sh --root /var/tmp/p437-ledger-base --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
  docs/team/tasks/P437-reply-diagnostics-ui.md:18: [names] <names#5> 的 PM 会话显示：
  ledger-ban: root=/var/tmp/p437-ledger-base scope=published files=2513 hits=1 names=ok user=resolved
  rc=1
  ```

## Flip evidence (required for defect-fix tasks)

先在未修产品上运行新增真实 Pi 行为断言，旧写法被实际抓红：

```
$ P396_EVIDENCE=/var/tmp/p437-before-diagnostic \
    bash skills/teamsmith/tests/reply-capture-real.sh --select=diagnostics
FAIL real Pi recover-skip:ineligible is file-only and never appears in the Pi terminal: AssertionError [ERR_ASSERTION]: raw PTY must not contain internal diagnostics
reply-capture-real: passed=0 failed=1 evidence=/var/tmp/p437-before-diagnostic
rc=1
```

修复后，测试把 `process.stderr.write(line)` 恢复到私有源码副本，同一断言必须再次变红；恢复本产品后控制臂变绿：

```
$ tail -4 /var/tmp/p437-reply-capture-real-all/diagnostics-flip.log
FAIL real Pi recover-skip:ineligible is file-only and never appears in the Pi terminal: AssertionError [ERR_ASSERTION]: raw PTY must not contain internal diagnostics
reply-capture-real: passed=0 failed=1 evidence=/var/tmp/p437-reply-capture-real-all/diagnostics-flip

$ tail -2 /var/tmp/p437-reply-capture-real-all/diagnostics-control.log
PASS real Pi recover-skip:ineligible is file-only and never appears in the Pi terminal
reply-capture-real: passed=1 failed=0 evidence=/var/tmp/p437-reply-capture-real-all/diagnostics-control
```

## Decisions and deviations

- 未新增字符串显示过滤器；两处终端写入均从扩展源头删除。
- 未改 `scripts/reply-capture.mjs`、writer、存储、正文清理、发布资格或 message/turn/settled 时机。
- 无规格 delta：本任务落实现有“本地诊断”行为，不引入新接口或发布语义。

## Suggested next steps

- 由非作者在独立检出复验并决定是否本地合并；本分支未推送、未合并、未发布。
