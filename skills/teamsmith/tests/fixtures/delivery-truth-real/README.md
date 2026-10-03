# tests/fixtures/delivery-truth-real · 真 Pi/model/tmux 配方（P163）

这条配方回答的问题是「**真**目标窗格上，第二封 `team say` 到底进没进模型」。它由 P147 的 apply 配方
（`docs/team/reports/P147-dev/pkg/`）与 P157 的复验副本（`docs/team/reports/P157-verify/pkg/`）提升而来，
逐字来源与两处**有意**改动如下。

| 文件 | 来源（sha256 为提升时源文件） | 说明 |
|---|---|---|
| `scenario.sh` | `docs/team/reports/P157-verify/pkg/scenario.sh` `3fa9d3d6…` | 改：读 `run.json` 运行戳 + 在判据读的事件文件第一行写单次 `run_start` 标记 |
| `run-case.sh` | `docs/team/reports/P157-verify/pkg/run-case.sh` `167c474c…` | 改：case 名 `*-p163-*`、现场强制重置 + `run.json`、变量名 `P163_EVIDENCE`、版本路线 0.99.2/host |
| `judge-second.py` | `docs/team/reports/P157-verify/pkg/judge-second.py` `e6735be5…` | 改：严格单次运行校验（缺戳 / 多 run 标记 / 有旧文件 / observation 一律拒绝）；P197 起标记必须**恰好一条**（集合相等会吞掉同 ID 的重复）且在**第一行**，`run-start.txt` 必须存在/非空/`run=` 与 `run.json` 一致 |
| `mock-server.py` | `docs/team/reports/P157-verify/pkg/mock-server.py` `629963db…` | 逐字相同（回环 mock 模型，`--network=none`） |
| `observe.ts` | `docs/team/reports/P157-verify/pkg/observe.ts` `3bab2cb4…` | 逐字相同（把 pane 帧/事件写成 jsonl 证据） |

## 判据版本钉死（P163 F2①）

- **判据路线 = 容器里的 Pi `0.99.2`**，由 `run-case.sh` 默认并校验（`$E/.runtime` 挂只读进容器）；
  `judge-second.py` 也要求 `run.json.pi_version=0.99.2`、现场 `pi-version.txt=0.99.2`。
- **单次运行的三重钉（P197）**：判据读的每个事件文件里 `run_start` 必须**恰好一条**、在**第一行**、
  且 `run` 等于 `run.json.run_id`；`run-start.txt` 必须存在、非空、`run=` 与 `run.json.run_id` 一致。
  数条数而不是比集合 —— 同 ID 的第二个标记正是「现场跨次累积」最坏的形状。红侧见
  `delivery-truth.sh --section judge`（含把「恰好一条」影子回集合相等的变异）。
- **宿主路线（当前 Pi 1.0.0）仅供人工观察**：`run-case.sh … host` 会把 `run.json.mode` 写成
  `observation`，并在终端打印醒目提示；`judge-second.py` **拒绝**给这种现场出判据（exit 2）。
  为什么：宿主 1.0.0 会把夹具自己那条 git 命令的错误行（`fatal: no upstream configured …`）画进输入框，
  那是夹具自造的框内行，不是产品缺陷 —— 产品把它当内容扣住、不回字，正是要钉住的行为
  （用例见 `skills/teamsmith/tests/frames/pi-1.0.0-git-error-in-box.txt` 与 `delivery-truth.sh --section foreign`）。

安装判据版本（一次性，需要网络；装进**任务自己的、被 gitignore 的**目录）：

```sh
E="$PWD/docs/team/reports/P163-dev-bob"
mkdir -p "$E/.runtime"
distrobox-host-exec podman run --rm --userns=keep-id -e HOME=/tmp \
  -v "$E/.runtime:/runtime:rw" \
  localhost/teamsmith-gate:local npm install --prefix /runtime --no-audit --no-fund \
  @earendil-works/pi-coding-agent@0.99.2
```

## 运行（每次先清空自己的 case 现场）

```sh
E="$PWD/docs/team/reports/P163-dev-bob"
P138_SECOND=1 P143_DRAFT=1 \
  P163_EVIDENCE="$E" \
  bash skills/teamsmith/tests/fixtures/delivery-truth-real/run-case.sh tmux-p163-after-0992-dirty HEAD 0 0.99.2
P163_EVIDENCE="$E" python3 skills/teamsmith/tests/fixtures/delivery-truth-real/judge-second.py tmux-p163-after-0992-dirty
```

`run-case.sh` 每次 `rm -rf "$E/logs/$CASE"` 并写 `run.json`；`scenario.sh` 再把单次 `run_start` 标记写进
`dev-events.jsonl` / `requests.jsonl` 第一行；`judge-second.py` 只信这一对证据。旧配方留下的现场
（没有 `run.json`、或同一现场里出现第二个 run id、或有早于本次运行的文件）会被**明确拒绝**，
不会把跨次累积算成一条。

## 纪律

- 只调 `distrobox-host-exec podman`；容器 `--network=none`、回环 mock 模型、无凭据挂载；
  容器有自己的 tmux server（`scenario.sh` 里的 `tmux kill-server` 只在这个一次性容器里）。
- 不 checkout/切分支：被测源码用 `git archive` 进容器。
- 不改别人的 case 目录：case 名必须是 `tmux-p163-*` / `watch-p163-*`，现场目录由 `P163_EVIDENCE` 指到本任务。
