# P476 · 首次复验执行了检查，却写成排队超限

agent: verify · status: DELIVERED（只读探索） · time: 2026-11-19T02:31:05Z

branch: `task/P476-review-executed-status-explore` · PR/MR: -（本地）

## 结论

**调用者确实漏建了指定的临时目录；工具确实把已经执行的检查写成了「排队超限、未运行」。但首轮整批仍应是 `FAIL`。** 同一份首轮记录的输出里，完整剪贴板检查为 **26/0、退出码 0**，随后短反例在初始化时因缺少同级技能目录退出 3，目标断言没有执行。误判的是「没运行」和失败原因，不是把整批应有的 `PASS` 写成了 `FAIL`。补短检的 72 秒 `PASS` 没有重跑完整剪贴板。

责任分开：显式设置 `TMPDIR` 的调用者负责先建好可写目录，并备齐自己的短反例副本；`team review` 负责拒绝未满足的前提、按实际排队结果和实际子命令退出写记录。预先建目录可绕开本次触发条件，不是修复记录逻辑。

## 原件对照

依据 `docs/team/reports/V171-verify.md` 阶段 A、`docs/team/reviews/V171.md` 和 P466 保存索引。索引在 Git common dir 的上一级 `.pi/team/state/evidence/P466/manifest.json`；只读核对 `P464-P466-V171-A11-2026-11-16.tar.gz`，整包 SHA-256 与索引及 `SHA256SUMS` 一致，以下用到的 16 个 `verifier/` 成员摘要也逐份匹配索引，未解包改写。

| 对象 | 原始证据 | 对结论的影响 |
|---|---|---|
| 首轮正式复验 | `review-initial.md:3,10–13` 绑定 `790bfb35c` 与 `batch-a.sh`；`limit=1800s queued=73s（等满上限）ran=未跑`，持有者未知；同一 Markdown 的输出尾与 `review-initial.log` 相符（去除颜色码后） | `73s` 不等于 `1800s`；正文和其自身输出相矛盾。73 秒不能当成剪贴板或实际排队耗时。 |
| 完整剪贴板 | `review-initial.log:1–11` 从 `BEGIN one complete clipboard` 到 `normal actual rc=0`、`✓ 26 ✗ 0`，再到 `bad actual child rc=3`；`normal.rc=0`、`normal.log:64–67` 同证。`batch-a.sh:17–33` 仅对子进程取消 `TMPDIR` 和 `TEAM_TMP_ROOT`，`default-root.log` 确认使用磁盘默认根 | 完整剪贴板不是只被排进队列，也不是后来补跑的；外层临时目录准备错误没有阻断该子进程。 |
| 首轮短反例 | `bad-setup.rc=3`；`bad-setup.log:3–6` 是 `team init failed`，点名缺少 `teamsmith-init`、`handover`；`bad-setup.xtrace:22–25` 在 `server_up` 的 `team init` 失败处退出。`batch-a.sh:49–53` 先记录 3，再在 `set -e` 下要求 `bad_rc=1`，在目标断言搜索前退出 | **确有一项检查没做到**：短反例的目标动作和断言未运行；不是整个命令没运行。按保存的脚本及输出，批次在该比较处退出 1；不是把子项的 3 直接当外层退出。 |
| 后续两份正式记录 | `review-candidate.md:10–13` 明列 `continue-a.sh`、`queued=0s ran=72s`、`PASS`；对应日志第 1、2、5、22 行写明复用原 26/0、反例 1、恢复 0 和短检通过。`review-merged.md:10–13` 则是 `stage-b.sh`、`queued=1s ran=0s`；日志末行说明未重跑面板/构建/全检 | 后两次成功不是首轮的替代证明，也不能隔离证明「只改 TMPDIR」就修好短反例；续跑还补了同级技能布局。 |

## 从目录到复验记录

以下产品文件在 P466 候选 `790bfb35` 与本次探索起点 `2ac59d49` 之间无改动：`scripts/team`、`scripts/lib/{common,gate-lock,cmd-review}.sh`（均在 `skills/teamsmith/` 下）。首轮归因以保存的输出和当时 V171 报告为证，不以现有中央 `P466.md` 代替被后续覆盖的原记录。

1. **准备失败被吞掉。** `common.sh:4217–4249,4333–4352` 优先采用调用者的 `TMPDIR`，并要求显式目录已存在且可写；只自动建平台默认根。V171 阶段 A 记下父目录在首次调用时尚未建立。`cmd-review.sh:1144–1145` 把准备错误及 `mktemp` 错误都丢弃，导致记录取锁时刻的文件路径为空。
2. **锁目录随后可被建好，但时间文件不会补建。** `gate-lock.sh:74–76,147–162` 的发布锁默认在 `$TMPDIR/teamsmith-smoke.lock`；首轮记录的实际锁路径正位于这个父目录。`cmd-review.sh:1156–1171` 对锁路径所在目录另做 `mkdir -p`，再取发布锁与伴生锁；`1224–1225` 向仍为空的路径写时刻，失败又被忽略。之后 `batch-a.sh:5–6` 自己也会创建目录，但已晚于工具创建时间文件。这里不需要假定任何持锁者占满等待上限。
3. **是否启动和是否超出排队上限本来已有不同证据。** `cmd-review.sh:1196–1198` 只有实际等待达到上限才置 `lock_cap_hit=1`；`1257–1264` 只在该标志或入场互斥检查拒绝时不执行，否则从受验目录启动命令，将输出写进正式日志、非零值收进 `gate_rc`。首轮独立日志上确有 `batch-a.sh` 的执行输出，所以「没有拿到锁而不启动」不是这次的路径。
4. **写报告时却重新猜了一次。** `cmd-review.sh:1270–1299` 从缺失的文件拿不到时刻，`queue_state=queued` 加读不到内容便被当成 `queuecap`，并抹去运行用时；没有采用已有的 `lock_cap_hit`。`1307–1319` 又单独按 `gate_rc` 重算 `PASS/FAIL/TIMEOUT`；`1383,1406–1435,1480–1495` 把错误的「没运行」原因和该判定一起写入、最后按判定返回。首轮整批应失败，因而显示 `FAIL + queuecap`。如果同样缺少时间文件但命令退出 0，按源码会形成 `PASS + queuecap`（**推导，非本案观察**）；`team_review_verdict` 是读判定词的消费者，不能靠读者发现这两句冲突。

这里没有保存首轮外层 `review` 的 xtrace、`mktemp` 的原始错误或独立数值退出回执；代码重定向并忽略了文件错误，不能从现有原件断言操作系统当时的具体错误码、精确实际排队秒数或先前持有者身份。首轮确有执行、为何误记以及短反例没走到断言，已有同次输出和对应源足以区分，无需模拟历史现场。

## 建议 PM 处理的最小范围

- **调用者继续负责显式临时目录。** 确认 `TMPDIR` 存在且可写后再发起复验；私有反例另行备齐包内同级技能。不要改成自动替调用者选目录或静默回落；`openspec/specs/verification/spec.md:742–747` 已规定显式根的责任以及报出路径、原因和修法。
- **产品修复限于 `team review`。** 在建锁目录和启动之前使用现有临时根准备结果；准备不成立，打印原有路径/原因/修法并非零退出，不伪造排队超限，也不要覆盖旧日志来假装启动过。排队超限只由 `lock_cap_hit` 判定，时间信息不可读不等于任务没跑。可优先用同一父 shell 已有的排队起点和实际启动前时间记账，避免 `review` 再通过文件把时刻传给自己；若保留文件，则把创建失败当准备错误、读不到时刻时不编造用时。保留真实排队、入场拒绝、运行中失去互斥、退出码与硬超时各自的含义；不改锁路径、不改 smoke 的文件机制、也不加新判定词（依据 `verification#The hard timeout covers the gate run, not the queue`）。
- **后续若批准修复，复用 §34 的现有复验入口。** 使用同一条可见标记命令核对：真实锁等待到上限，标记不存在且记 `queuecap`；显式目录缺失，标记不存在且显示目录准备错误、未启动，而不是 `queuecap`；有效目录下标记出现，按命令退出记录已运行而非排队超限。收在既有检查内，不为本次新增框架或再跑剪贴板。

## 交付与检查

- 唯一交付：`docs/team/reports/P476-verify.md`。OpenSpec 实现/归档评估及修复前后翻转证据不适用：本任务是 `opsx-explore`，只对照现行规范和保存原件，未修产品。
- 实际只读命令：`tar -tzf` 找原件；`python3` 使用 `tarfile`、`hashlib` 与 `manifest.json` 逐字节核对，输出 `archive SHA256 OK`、`16/16 verifier member SHA256 OK`、`initial Markdown output tail equals separate log: True`。执行 `git diff --name-only 790bfb35 HEAD -- skills/teamsmith/scripts/{team,lib/cmd-review.sh,lib/gate-lock.sh,lib/common.sh}` 无输出。
- 本轮未运行剪贴板、模拟门禁、全量、真实模型或 OpenSpec 门禁；没有改主检出、历史复验记录、活动状态、规范或产品，也未合并或推送。
- 提交前检查（在本席位工作树上）：

  ```text
  $ git diff --check
  diff-check rc=0
  $ git diff --cached --check
  cached-diff-check rc=0
  $ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
  ledger-ban: root=/home/<user>/Documents/syncthing/Work/Projects/pm-skills/.worktrees/verify scope=published files=2884 hits=0 names=ok user=resolved
  ledger-ban rc=0
  ```
