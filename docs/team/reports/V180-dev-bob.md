# V180 · P478 独立复验

agent: dev-bob · status: 候选及合并版定点复验 PASS · time: 2026-11-19T03:00:34Z

branch: `task/V180-review-queue-report-verify` · PR/MR: -（本地）

## 结论

候选 `c97a8efef4b8141d95b86d9a8ff62654ea02f0a3` 通过五项定点检查。旧版在 `TMPDIR` 不存在时确实启动并收到子命令的退出 1，却把结果写成「排队超限、未运行」；候选在取锁之前报出路径、原因和修法，退出 1，原复验报告和日志字节不变。真正等满私有锁上限的是 `FAIL / 未运行`，真正被硬超时终止的是 `TIMEOUT / 已运行 2s`。

## 交付与证据位置

| 路径 | 内容 |
|---|---|
| `docs/team/reviews/P478.md`、`docs/team/reviews/P478-verify.log` | 原生 `team review` 输出，实际执行者 `dev-bob`，固定候选，外层退出 0、排队 0s、运行 13s。中央只由原生工具写这两份。 |
| `/var/tmp/v180-dev-bob-vnm0kz/` | 私有原件保留至 PM 接收。`short-review.sh` 与 `marker.sh` 是执行脚本；每项的 `.command`、`.console`、`.rc`、`.wall-ms`、报告和 `.verify.log` 分开保留。中央原件副本是 `central-candidate.{md,verify.log}`，与中央两文件 `cmp` 一致。 |
| `docs/team/reports/V180-dev-bob.md` | 本席位定点实测、旧新对照、未验范围和交接。 |

外层命令按任务书从本席位发起，工作树自带的 `cmd-review.sh` 与旧版相同，因此**不把外层执行算作产品修复的实测**。外层在 PM 固定检出内启动脚本；脚本先核对该检出的 SHA 和干净状态，再显式调用该检出的 `skills/teamsmith/scripts/team` 验证候选。旧版 CLI 从 `git archive 36c60698 skills/teamsmith` 提取，不切换分支。两侧使用同一私有项目、同一独立干净输入仓库、同一失败子命令和同一私有锁路径；内层报告里的 `pm` 是私有项目根的自动标签，不是实际执行者。外层锁 `locks/central` 与所有内层锁不同；标记和状态均写在专属目录，固定候选在运行前后 `git status --porcelain --ignored=matching` 均无输出。

## 定点运行回执

| 场景 | `review` 退出／记录 | 实际证据 |
|---|---|---|
| 候选，有效 `TMPDIR`，退出 0 | `0`，`PASS`，`limit=30s queued=0s ran=1s` | `candidate-pass.verify.log` 有 `V180 CHILD BEGIN candidate-pass` 和 `V180 CHILD EXIT candidate-pass rc=0`。 |
| 候选，有效 `TMPDIR`，退出 1 | `1`，`FAIL`，`limit=30s queued=0s ran=1s` | `candidate-fail.verify.log` 有 `V180 CHILD BEGIN candidate-fail` 和 `V180 CHILD EXIT candidate-fail rc=1`；报告为 `门禁：ran`，两项均未标记排队超限。 |
| 候选，显式 `TMPDIR` 不存在 | `1`，不写新记录 | `.console` 报 `临时根不可用：…/missing-tmp（source=tmpdir）不存在`，并给 `修法：mkdir -p '…/missing-tmp' 并确保可写；或把 TMPDIR 改到已存在的可写目录`。私有锁上级已存在且可写；调用后临时目录、两把锁及持有记录、子命令标记均未创建。 |
| 旧版，同样缺目录 | `1`，`FAIL`，`limit=30s queued=1s（等满上限）ran=未跑`，报告另写上限 `2s` | `.verify.log` 有 `V180 CHILD BEGIN bad-tmp` 和 `V180 CHILD EXIT bad-tmp rc=1`，标记文件也存在；缺失目录仍不存在，独立的私有锁 pair 确实被建好，控制台没有「排队未启用」。 |
| 候选，§34② 的外部持锁 | `1`，`FAIL`，`limit=30s queued=2s（等满上限）ran=未跑` | 实测总耗时 `3074ms`；调用前后独立 `flock -n` 都拿不到私有锁，且持有进程仍活。终端和报告点名 `cmd=p34-holder`，说明没有可用心跳；日志为空、标记不存在，不是 `TIMEOUT`。 |
| 候选，§34③ 的硬超时 | `1`，`TIMEOUT`，`limit=2s queued=0s ran=2s` | 私有日志先有 `V180 CHILD BEGIN timeout`，没有退出标记；GNU timeout 实际发出 TERM，包装器退出 `124`。未标记排队超限。 |

缺目录前后对**同一次已有记录**既比了 SHA 文件也分别 `cmp` 原始报告和日志，返回 0；两份的 SHA-256 始终分别是 `f21a4e94ede5377b6ee6cec358cba7cb84e98f406015e0fd6995ff078d51a762` 和 `a9a2b418c90da9368b94ef060c62f130aad091db8e9d6db8b62fbe84dedcefe0`。随后才对同一私有项目执行旧版对照；已接受的历史记录不参与写入。P476 的原记录是更长的不同批次，存在一项确实失败；本轮只重现记账错误，不改原 `FAIL`，也不把演示耗时当成历史耗时。

```text
$ TMPDIR=/var/tmp/v180-dev-bob-vnm0kz/tmp TEAM_SMOKE_LOCK=/var/tmp/v180-dev-bob-vnm0kz/locks/central GIT_OPTIONAL_LOCKS=0 TEAM_GATES='bash /var/tmp/v180-dev-bob-vnm0kz/short-review.sh' bash skills/teamsmith/scripts/team review P478 --dir /var/tmp/p478-review-c97a8efe.BTOmDp --branch c97a8efef4b8141d95b86d9a8ff62654ea02f0a3
✓ 门禁输出：docs/team/reviews/P478-verify.log（PASS，13s）
✓ 复验记录：docs/team/reviews/P478.md（PASS）
V180 PASS: five candidate cases and one old-version control, candidate checkout unchanged
review rc=0
```

`team_review_verdict` 以候选 `common.sh` 读取私有报告副本：`pass=PASS fail=FAIL held=FAIL timeout=TIMEOUT`，退出 0。对固定候选的 `bash -n …/scripts/lib/cmd-review.sh` 和 `git diff --check 36c60698 c97a8efe` 均退出 0。完整逐项命令以私有 `.command` 原件为准。

## OpenSpec 评估

| 维度 | 结论 | 证据 |
|---|---|---|
| 完整性 | 通过本轮范围 | 无 OpenSpec change 制品；依据 `verification#The hard timeout covers the gate run, not the queue` 与 `verification/spec.md:742–747`。运行证据分别覆盖真实退出 0/1、实际排队上限和硬超时，以及显式根缺失。 |
| 正确性 | 通过定点运行 | 表中五项候选结果、旧版对照、报告/日志原字节和原生解析器结果。 |
| 一致性 | 实际修改与现行约定一致 | `git diff 36c60698 c97a8efe -- skills/teamsmith` 只改 `cmd-review.sh`。显式根准备先于日志建立与取锁；`queuecap` 只由等待循环的 `lock_cap_hit` 产生；只在启动子命令后填写运行时长。`git grep` 未发现外部消费者读取旧计时文件内容；规范保留旧文件清理义务，清理仍可按家族名字辨认。 |

**CRITICAL：0；WARNING：0；SUGGESTION：0（在本次变更范围内）。** 旧有显示瑕疵不算本次回归：真实排队未运行时终端摘要仍有 `（FAIL，s）`，旧版同一分支也清空运行时长后无条件追加 `s`；两版入场互斥拒绝的 Markdown 也都保留 `mutexbroken` 抬头和通用 `ran` 行。后者仅审源码，不报实测通过；不因此扩展 P478。

**未运行：** 原完整剪贴板 26 项、§34 其余分支与全量、OpenSpec 全量校验均按定点任务范围未跑。祖辈已持锁、没有 `flock` 或锁路径无法建立、入场冲突、执行中锁丢失、心跳延长和排队后成功均未实跑；实际 diff 保留取锁、心跳和互斥复核机制，调整的是这些分支使用的计时输入。合并版不重复这些候选场景，仅执行下述定点核对。

## 合并版定点复验

合并版 `24ea698bbcc1603b68ca69b991ec9cd088f9cc6a` 通过：`git diff --exit-code` 和两份工作树文件的 `cmp` 均返回 0；`skills/teamsmith/scripts/lib/cmd-review.sh` 的候选与合并版 SHA-256 都是 `077ed05d6999db2a206c38da5cae7f9869ec65d5308640455cf5bfa6ad6a53bf`。固定合并版检出运行前后 `git status --porcelain --ignored=matching` 均无输出。

```text
$ TMPDIR=/var/tmp/v180-dev-bob-vnm0kz/tmp TEAM_SMOKE_LOCK=/var/tmp/v180-dev-bob-vnm0kz/locks/merged-central GIT_OPTIONAL_LOCKS=0 TEAM_GATES='bash /var/tmp/v180-dev-bob-vnm0kz/merged-check.sh' bash skills/teamsmith/scripts/team review P478 --dir /var/tmp/p478-merged-24ea698b.AClbaZ --branch 24ea698bbcc1603b68ca69b991ec9cd088f9cc6a
✓ 门禁输出：docs/team/reviews/P478-verify.log（PASS，2s）
✓ 复验记录：docs/team/reviews/P478.md（PASS）
V180 merged inner review rc=1
- 门禁：ran（判定 FAIL）
- 闸门计时：limit=30s queued=0s ran=1s（硬超时只量 ran；排队超限不会得到 TIMEOUT）
V180 CHILD BEGIN merged-inner
V180 CHILD EXIT merged-inner rc=1
V180 merged check PASS: one marked failure was recorded as executed; no queue cap
```

外层正式记录绑定 `24ea698bb`、执行者 `dev-bob`，退出 0，排队 1s、运行 2s。合并版 CLI 只实际运行了一条失败命令：内层退出 1 并写 `FAIL / ran=1s`，起止标记都在原日志，没有「排队超限」或「未跑」。外层和内层分别使用 `locks/merged-central` 和 `locks/merged-inner`，不共享锁。中央两文件与私有 `central-merged.{md,verify.log}` 副本 `cmp` 一致；内层 `merged-inner.{command,console,rc,md,verify.log,marker}` 独立保留，候选副本 SHA-256 仍一致。没有重跑候选五项或旧版对照。

## 本地检查与下一步

- Ledger ban（在本席位分支暂存本报告后执行）：

  ```text
  $ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
  ledger-ban: root=/home/<user>/Documents/syncthing/Work/Projects/pm-skills/.worktrees/dev-bob scope=published files=2906 hits=0 names=ok user=resolved
  ledger-ban rc=0
  ```
- 无范围变更。没有推送、合并、发布或改历史。候选及合并版定点证据均已交付，待 PM 接收；专属目录保留供核对。
