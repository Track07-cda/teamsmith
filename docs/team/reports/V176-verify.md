# V176 · 提醒事件记录等待的独立验证

agent: verify   status: PASS — candidate behavior and merged identity verified   time: 2026-11-17T04:34:13Z
branch: `task/V176-reminder-recorder-wait-verify`   PR/MR: -

## 结论

**最终 PASS。** 候选阶段同一个已有 `adversarial-event-after` 场景只执行三次：原候选正常 `1/0、rc=0`，受控旧检查 `0/1、rc=1`，恢复候选等待 `1/0、rc=0`。旧检查失败时，真实 Pi `message_start` 已经过未改的产品 watcher，状态已为 `observed`，但下游测试记录尚未追加；恢复后等待实际记录出现，原 G2 保护断言和最终 receipt 均通过。候选正式 `team review P473` 为 PASS，实际执行者 verify，绑定 `7bf07b46f`，排队 1 秒、批次执行 13 秒；后台作业总计 19.1 秒、exit=0。

PM 已合入 `cea2b7f20eef5c006add5cd1f18ad70ff9692624`，本人在新的独立固定源完成一次正式同一性/语法短核对，结果 PASS；产品、驱动和 fixture 所在的授权比较路径与候选无差异，沿用上述行为证据，**merged 没有再次运行 Pi**。本席位没有执行合并、推送或发布。

这证明旧即时检查**可以在这个顺序下错误失败**，不证明现场已失的 V174 当次必由此引起；历史 V174 FAIL 不改。

## Deliverables

| Path | What |
|---|---|
| `docs/team/reports/V176-verify.md` | 本分支唯一修改；静态范围、三臂真实结果、状态/身份和证据边界 |
| `docs/team/reviews/P473.md`、`P473-verify.log` | 正式工具生成的主账本例外写入，实际 verifier/SHA/命令/结果 |
| `/var/tmp/v176-verify.YilY7B/` | 完整私有证据，23 MB，KEEP；三臂原件、临时 runner/控制、完整差异、文件同一性清单 |

## 固定输入及静态范围

- PM 独立只读源 `/var/tmp/p473-review-7bf07b46.VjwmsD` 的 HEAD 为 `7bf07b46f855fa8d0d6765c4b19f68c1df41f374`。运行前后 `git status --porcelain=v1 --untracked-files=all --ignored` 均无输出；正式工具同样记录 clean、ignored artifacts=0。
- 实现 `fed3184105bcfb5c8acd4f43a850bfc2240b18a3` 相对父提交只替换 `skills/teamsmith/tests/remind-tool-real.mjs:557` 一行。事件条件逐字相同；既有 90 秒/50ms、observed 等待、此前忙碌/intent 检查和此后 generation-ambiguous/on/generation=2/receipt 均未改，没有取消断言或跳过失败。
- 实际显式 Pi 为 `/home/<user>/.bun/bin/pi`，版本 `1.5.2`；Node `v24.22.1`，tmux `3.7b`。runner 保留机器上的真实绝对路径，报告只把用户目录通用化；当前 PATH 不含 Pi 所在目录，未依赖自动查找。
- 三次都用原选择参数、私有 HOME、私有 `tmux -S <本次run根>/socket` 及 `127.0.0.1` controlled provider；保留 `P442_KEEP=1`、`P442_PI` 绝对路径和本人独立 `P442_EVIDENCE`。启动参数有 offline/no-extensions/no-skills/no-context-files，仅显式装载本次扩展；没有外部模型调用或真实团队状态写入。三份 `launch-stderr.txt` 均为 0 字节。

## 临时观察控制与旧检查失败依据

正常臂直接执行固定源，不改文件。旧红和恢复共用私有 `c/skills/teamsmith` 副本，**只改测试驱动和测试记录器**，没有修改 handler、伪造 SDK event、放宽超时、加固定 sleep 或提交永久测试开关。

1. 下游测试 provider 的真实 `message_start` 回调收到 `role=custom/customType=team-reminder` 后，先保存 `recorder-held.json`：实际 SDK message、session 及刚读取的产品状态。此时产品 watcher 已执行，实际批次已 `observed`。
2. 驱动仍先等原 observed，再等上述小标记；原事件条件调用 `events(info)`，**先真实读取 events.jsonl**，然后把该次返回内容、实际状态和调用栈写成 `first-real-read.json`，最后原样返回已读内容。该文件不是伪造事件，也不让条件直接变真。
3. 记录器只有看到首次读取文件后才释放，复制为 `recorder-released.json`，执行原 `custom_start` 追加并写 `recorder-appended.json`。协调轮询使用 50ms/90秒观察上界，不靠固定时间差抢先后。
4. 旧 assert 的真实调用栈落在私有驱动 `567:16`；首次返回的列表中目标记录为 0，状态为 observed，故原断言在 `567:9` 报 `AssertionError`。释放后同一 batch/session 的真实目标记录变成 1；旧红不是启动、语法、注入或超时失败。旧驱动止于该断言，**没有执行后续 G2 断言，也没有 receipt**；其最终状态另外保存在 assessment/实际 state 中，不把它冒称原断言通过。
5. 恢复只把旧 assert 换回候选原 until，保留相同观察控制。首次读取调用栈 `567:27 → until`，仍是目标记录 0；实际追加后下一轮读取成立，继续完成原 G2 断言及 receipt。

完整差异是 `old-driver.diff`、`old-recorder.diff`、`restored-driver.diff`、`restored-recorder.diff`。`manifest-old.json`、`manifest-restored.json` 对源/副本各 278 个文件逐项核对；两次都仅上述两份测试文件不同，其余 276 份字节同一，产品文件没有变化。正常源在运行后仍 clean/ignored=0。

## 实际批次、会话与最终状态

每一行是一次独立运行，不把三次伪称为同一 Pi session。每次本场景只有 1 个 batch；该次 SDK message/details、记录器 custom_start 和状态里的 batchId/nonce/members/session 均核对相同。

| 臂 / 证据子目录 | 实际 batch | 实际 session | 原场景结果 / rc | 最终状态与 receipt |
|---|---|---|---|---|
| 正常 `n`，run-Kn1dWZ | `bat-8c009924-fe92-4d50-91eb-df9cbffea2ad-1` | `01a1e7bf-05c2-70e1-b216-d8034ad86908` | passed=1 failed=0 / 0 | observed；绑定G1；generation-ambiguous；on=true、generation=2、reason=G2；receipt存在 |
| 旧红 `e`，run-vUxtrg | `bat-9b64fc8a-8760-4858-b519-b916f5c8f3fb-1` | `01a1e7bf-1602-763c-88e7-32620758b427` | passed=0 failed=1 / 1 | observed；绑定G1；generation-ambiguous；on=true、generation=2、reason=G2；原断言之后未执行、receipt不存在 |
| 恢复 `r`，run-Rp6qEl | `bat-b91b7433-bbb6-4c29-82d5-43a004787a6e-1` | `01a1e7bf-25dd-722d-b150-8d9f3591b369` | passed=1 failed=0 / 0 | observed；绑定G1；generation-ambiguous；on=true、generation=2、reason=G2；receipt存在 |

三份 watcher 日志均实际记录 `intent-sent generation=1` 后的 `observed standby=generation-ambiguous generation=1`，然后 stopped。每份最终事件文件有且仅有 1 条该 batch/session 的提醒 `custom_start`；测试的这个名字是对 SDK 原 `message_start` 的记录名，不是另一个 SDK 事件。

原件定位：每臂 `<n|e|r>/adversarial-event-after/` 保存 `receipt.json`（旧红无）、`requests.jsonl`、`events.jsonl`、G1/off/G2 命令回执及 `launch-stderr.txt`；`<臂>/run-<上表后缀>/adversarial-event-after/.pi/team/state/` 保存 `reminders/state.json` 和 `inbox-watch.log`。受控两臂的四份 recorder/first-read JSON 位于同一场景目录；`assessment-{n,e,r}.json` 包含实际 state 路径和对齐结果。

最终三臂各保留 3 条 loopback 请求。原 receipt 的 `reminderRequests` 在正常为 1、恢复为 0，而恢复最终 requests 文件已有后到的提醒请求；receipt 在事件检查之后立即写出，并不等待整个 provider 轮次结束。本结论以实际 message_start/observed/G2 原断言为依据，不拿 receipt 的即时请求计数代替后续轮次完成证据，也不扩跑或改这个原字段。

## Verification evidence

本人工作树执行的唯一正式批次命令，未覆盖默认门禁：

```sh
TMPDIR=/var/tmp \
TEAM_GATES='bash /var/tmp/v176-verify.YilY7B/verify-recorder-wait.sh' \
  bash skills/teamsmith/scripts/team review P473 \
  --dir /var/tmp/p473-review-7bf07b46.VjwmsD \
  --branch 7bf07b46f855fa8d0d6765c4b19f68c1df41f374
```

通过 `team_bg_run` 启动 job `v176-recorder-wait`，结束回合，完成唤醒后 `team_bg_wait` 收取 exit=0。review 锁和 1800 秒 timeout 保持原值，没有绕锁或覆盖。实际开始 `2026-11-17T04:23:37Z`，结束 `04:23:49Z`，review 记运行 13 秒：

```text
V176 arm=n command: P442_EVIDENCE=/var/tmp/v176-verify.YilY7B/n node /var/tmp/p473-review-7bf07b46.VjwmsD/skills/teamsmith/tests/remind-tool-real.mjs --select=adversarial-event-after
V176 arm=n rc=0
PASS real Pi busy follow-up emitted after manual G2 keeps the unprovable order boundary
remind-tool-real: passed=1 failed=0 evidence=/var/tmp/v176-verify.YilY7B/n

V176 arm=e command: P442_EVIDENCE=/var/tmp/v176-verify.YilY7B/e node /var/tmp/v176-verify.YilY7B/c/skills/teamsmith/tests/remind-tool-real.mjs --select=adversarial-event-after
V176 arm=e rc=1
FAIL real Pi busy follow-up emitted after manual G2 keeps the unprovable order boundary: AssertionError [ERR_ASSERTION]: The expression evaluated to a falsy value:
  assert(events(info).some(e => e.type === 'custom_start' && e.customType === 'team-reminder'))
    at .../tests/remind-tool-real.mjs:567:9
remind-tool-real: passed=0 failed=1 evidence=/var/tmp/v176-verify.YilY7B/e
V176 e: EXPECTED-ASSERTION-FAIL verified (not startup/injection failure)

V176 arm=r command: P442_EVIDENCE=/var/tmp/v176-verify.YilY7B/r node /var/tmp/v176-verify.YilY7B/c/skills/teamsmith/tests/remind-tool-real.mjs --select=adversarial-event-after
V176 arm=r rc=0
PASS real Pi busy follow-up emitted after manual G2 keeps the unprovable order boundary
remind-tool-real: passed=1 failed=0 evidence=/var/tmp/v176-verify.YilY7B/r
V176 r: PASS including original G2 assertions and receipt
V176 PASS: normal=0 old=1(exact missing-record assertion) restored=0; fixed source still clean
```

runner 仅在正常/恢复成功、旧红为具名 AssertionError 且实际状态/标记/真实事件都吻合时返回 0；不是忽略一次任意非零退出。runner/准备/结果消费脚本 SHA-256 依次为：

```text
b22401a0745bec56852cd4982bf509fb7991a902818f3afa52cf0334b499a406  verify-recorder-wait.sh
69d49ace167dcd51d609429720f331695f14bd5c5686580096443b229f5a4460  prepare-controls.mjs
4f4385a01da747924839fab6587a6164eca33dc0f51375baa4dc260e51769ee3  assess-arm.mjs
cc002cc8ef508b8de7628384e553a515a09242e2ad7b47a4b10edb07c9967803  n.log
be96b099a2fe38461d87a062a8f29ec4e12ebe4fd92f1c52e0a13f47becaa01c  e.log
f2c98aebb21d2bd23ec00e264541057c11dbc5ea9cc76e296b07a81721ad12fe  r.log
```

正式批次内 `node --check` 原驱动与私有旧/恢复驱动均 rc=0；准备阶段额外只做两份临时 mjs 的 `node --check`、runner 的 `bash -n` 和差异生成，均 rc=0，没有额外行为预跑。

报告暂存后，从本人工作树、本人任务分支执行：

```text
$ TMPDIR=/var/tmp bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=/home/<user>/Documents/syncthing/Work/Projects/pm-skills/.worktrees/verify scope=published files=2863 hits=0 names=ok user=resolved
ledger_rc=0
$ git diff --check -- docs/team/reports/V176-verify.md
（无输出）
diff_check_rc=0
$ git diff --cached --check -- docs/team/reports/V176-verify.md
（无输出）
cached_diff_check_rc=0
```

## OpenSpec assessment

N/A — `change: -` 的既有检查同步修正，没有 change 工件或归档。已只读核对 `verification#A gate that cannot judge says so` 的证据及真实失败要求；旧检查产生真实失败而非跳过，最终候选仍执行原后续断言。不新建规格或运行任务书排除的 OpenSpec 校验。

## CRITICAL

None — 三臂真实输出及状态均满足本次限定验收；不把此项扩展成 V174 历史失败已解决或发布已通过。

## WARNING

None — 本次范围内没有未解决问题。历史现场缺失限制 V174 归因；merged 同一性/语法现已实际通过，具体记录见末节。

## SUGGESTION

None — 不新增永久控制、测试、开关或其它场景。

## Final assessment

- Counts: CRITICAL 0 · WARNING 0 · SUGGESTION 0，仅指本次单场景和合并后短核对。
- Readiness: PASS，候选行为与 merged 同一性/语法均交付，可供 PM 接受结案；非发布授权。正常/恢复均实际完成原 G2 保护断言和 receipt；旧红的原后续断言没有执行。
- Unverified applicable checks and reasons: 本 brief 本次适用检查均已完成。其余提醒 cases、§69 其它内容、smoke/FAST/meta/61b、完整计时、构建、真实 PM 外部模型和其它项目预览均按 brief 排除，没有称其通过。merged 按授权只做同一性/语法，没有再跑 Pi；没有重建 V174 已失历史现场。

## Flip evidence

上列旧红为真正原 assert 失败：首次实际读取 0 条目标记录，产品 observed、session/batch 相同；释放后追加 1 条。同一观察控制下只恢复原 until 就 rc=0，并完成原 generation-ambiguous/on/generation=2/receipt。完整输出/差异/状态保留于证据根，不以源码推导代替实验。

## Decisions and deviations

无范围偏离。先以 `97e2a396` 提交静态范围，再补本次真实结果；本分支只改本人报告，主检出只由正式工具写授权的两份 P473 review 文件。未改真实队列、配置、待命或 P471/旧徽章检查；未 push/merge/tag/npm。固定源和 23 MB 完整原件均未清理。

## Suggested next steps

PM 接受本次 merged 短核对后办理结案。本席位不再运行检查或清理；23 MB 原件及两份固定源全部保留，等 PM 收存并另行明确授权。

## 合并后短核对 · 2026-11-17

- 实际固定 SHA：`cea2b7f20eef5c006add5cd1f18ad70ff9692624`；PM 准备的独立源为 `/var/tmp/p473-merged-cea2b7f2.IuHXl2`。
- 正式 `team review P473` 本次实际执行者仍为 verify，记录时间 `2026-11-17T04:33:37Z`，绑定 `cea2b7f20`，判定 PASS。工具记录 checkout clean、ignored artifacts=0，排队 1 秒、命令运行 0 秒（按工具整秒计），保留原锁及 1800 秒 timeout。
- 实际只执行以下一次正式短核对，经 `team_bg_run` job `v176-merged-short` 启动并结束回合；唤醒后 `team_bg_wait` 收取 exit=0、总计 10.9 秒，没有行为预跑或追加 Pi。

```sh
TMPDIR=/var/tmp \
TEAM_GATES='git diff --exit-code 7bf07b46f855fa8d0d6765c4b19f68c1df41f374 HEAD -- skills/teamsmith extension ci package.json && node --check skills/teamsmith/tests/remind-tool-real.mjs' \
  bash skills/teamsmith/scripts/team review P473 \
  --dir /var/tmp/p473-merged-cea2b7f2.IuHXl2 \
  --branch cea2b7f20eef5c006add5cd1f18ad70ff9692624
```

```text
review checkout: /var/tmp/p473-merged-cea2b7f2.IuHXl2 @ cea2b7f20（干净）
门禁输出：docs/team/reviews/P473-verify.log（PASS，0s）
复验记录：docs/team/reviews/P473.md（PASS）
job v176-merged-short finished exit=0 after 10.9s
```

组合命令无输出、rc=0，故授权路径 `skills/teamsmith extension ci package.json` 的 `git diff --exit-code` 和其后 `node --check` 均返回 0；`P473-verify.log` 为空是这两个安静命令的真实输出，不是未执行。候选行为证据及原始 SHA 保持前文原件，候选正式 record/log 已由 PM 在本次授权前保存在主根私有 `.pi/team/state/evidence/P473/candidate/`（保存位置来自 PM 任务书，本轮未重复扫描该包）。本轮只生成 merged 正式记录和追加本人报告，不重跑 ledger 或已有检查。本人报告暂存前 `git diff --check -- docs/team/reports/V176-verify.md` 无输出、rc=0；暂存后 `git diff --cached --check -- docs/team/reports/V176-verify.md` 无输出、rc=0。
