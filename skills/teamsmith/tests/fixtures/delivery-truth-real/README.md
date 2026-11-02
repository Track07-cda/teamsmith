# tests/fixtures/delivery-truth-real · 真 Pi/model/tmux 配方（P163）

这条配方回答的问题是「**真**目标窗格上，第二封 `team say` 到底进没进模型」。它由 P147 的 apply 配方
（`docs/team/reports/P147-dev/pkg/`）与 P157 的复验副本（`docs/team/reports/P157-verify/pkg/`）提升而来，
逐字来源与两处**有意**改动如下。

| 文件 | 来源（sha256 为提升时源文件） | 说明 |
|---|---|---|
| `scenario.sh` | `docs/team/reports/P157-verify/pkg/scenario.sh` `3fa9d3d6…` | 改：读 `run.json` 运行戳 + 在判据读的事件文件第一行写单次 `run_start` 标记 |
| `run-case.sh` | `docs/team/reports/P157-verify/pkg/run-case.sh` `167c474c…` | 改：case 名 `*-p163-*`、现场强制重置 + `run.json`、变量名 `P163_EVIDENCE`；P380 起运行时默认解析最新版（`latest`）并记录实际版本（见下） |
| `judge-second.py` | `docs/team/reports/P157-verify/pkg/judge-second.py` `e6735be5…` | 改：严格单次运行校验（缺戳 / 多 run 标记 / 有旧文件 / observation 一律拒绝）；P197 起标记必须**恰好一条**（集合相等会吞掉同 ID 的重复）且在**第一行**，`run-start.txt` 必须存在/非空/`run=` 与 `run.json` 一致；P380 起不再硬编码版本号，改为要求记录值等于现场实测值 |
| `mock-server.py` | `docs/team/reports/P157-verify/pkg/mock-server.py` `629963db…` | 逐字相同（回环 mock 模型，`--network=none`） |
| `observe.ts` | `docs/team/reports/P157-verify/pkg/observe.ts` `3bab2cb4…` | 逐字相同（把 pane 帧/事件写成 jsonl 证据） |

## 运行时：默认最新版，记录实际版本（P380）

- **判据路线默认为 npm 上的最新版**。`run-case.sh` 的第 4 个参数不给（或给 `latest`）时，它在**每次证据运行开始时**
  解析一次 `@earendil-works/pi-coding-agent` 的最新版本，装进 `$E/.runtime/<版本>/`（网络只在安装这一步用），
  把这个目录挂只读进 `--network=none` 的 case 容器。`run.json.pi_version` 记**解析出的具体版本**，容器里
  `pi --version` 的**实测值**写进 `pi-version.txt`。
- `judge-second.py` 不再钉死任何版本号：`pi_version` 必须是**具体版本号**（`latest` 会被拒绝），且必须等于
  `pi-version.txt` 的实测值。两者不符就是可见的不兼容（判据 exit 2 点名两边），不会把旧钉版当通过。
- **复现历史运行**：第 4 个参数给具体版本（例如 `0.99.2`）走同一条安装/记录/核对路径；它只代表「这次跑的是它」，
  不再是「判据版本」。`tests/frames/pi-0.99.2-*`、`pi-1.0.0-*` 是**回放帧**（录制下来的真帧），不是运行时钉版。
- **解析或安装失败 → 非 0 退出并点名**（没有记住的旧版本可回落）；`$E/.runtime/<版本>` 里已装的是别的版本时直接拒绝。
- **单次运行的三重钉（P197）**：判据读的每个事件文件里 `run_start` 必须**恰好一条**、在**第一行**、
  且 `run` 等于 `run.json.run_id`；`run-start.txt` 必须存在、非空、`run=` 与 `run.json.run_id` 一致。
  数条数而不是比集合 —— 同 ID 的第二个标记正是「现场跨次累积」最坏的形状。红侧见
  `delivery-truth.sh --section judge`（含把「恰好一条」影子回集合相等的变异，以及版本别名 / 实测不符 / 观测模式三条红侧）。
- **宿主机路线（`host`）仍仅供人工观察**：`run-case.sh … host` 用宿主当前的 pi，把 `run.json.mode` 写成
  `observation`，并在终端打印醒目提示；`judge-second.py` **拒绝**给这种现场出判据（exit 2）。夹具绝不
  `pi update` / `npm i -g` 改宿主。为什么宿主路线不出判据：版本变化会把夹具自造的框内行（例如宿主 Pi 把夹具那条 git
  命令的报错画进输入框，`fatal: no upstream configured …`）暴露成产品行为差异 —— 产品把框内异物当内容扣住、不回字，
  正是要钉住的行为（用例见 `skills/teamsmith/tests/frames/pi-1.0.0-git-error-in-box.txt` 与 `delivery-truth.sh --section foreign`）。

运行时目录由脚本自己建（第一次用某个版本需要网络），不需要再手工安装：

## 运行（每次先清空自己的 case 现场）

```sh
E="$PWD/docs/team/reports/P163-dev-bob"
P138_SECOND=1 P143_DRAFT=1 \
  P163_EVIDENCE="$E" \
  bash skills/teamsmith/tests/fixtures/delivery-truth-real/run-case.sh tmux-p163-after-latest-dirty HEAD 0 latest
P163_EVIDENCE="$E" python3 skills/teamsmith/tests/fixtures/delivery-truth-real/judge-second.py tmux-p163-after-latest-dirty
```

`run-case.sh` 每次 `rm -rf "$E/logs/$CASE"` 并写 `run.json`；`scenario.sh` 再把单次 `run_start` 标记写进
`dev-events.jsonl` / `requests.jsonl` 第一行；`judge-second.py` 只信这一对证据。旧配方留下的现场
（没有 `run.json`、或同一现场里出现第二个 run id、或有早于本次运行的文件）会被**明确拒绝**，
不会把跨次累积算成一条。

## 已知的失败形状：没有 upstream 的分支（P380 实测，2026-10-27）

worker 分支没有 upstream 时（`git worktree add -b task/…` 的默认形状），`team-notify` 的
`git rev-parse --symbolic-full-name @{upstream}` 探测会失败；`run()` 里的 `execFileSync` 没带 `stdio`，
git 的 `fatal: no upstream configured for branch …` 被写到 pane 上。Pi 1.4.0 下它留在编辑框矩形里，产品读到
的就是「框里有草稿」：不写键、报 queued，第二封 say 因此到不了模型（`second_received=0`、判据 FAIL）。同一份
产品代码、同一个 case 在 Pi 0.99.2 下 `box_text=[]`、判据 PASS —— 差别在运行时这一层（0.99.2 下那行没有留在
屏幕上；具体是重绘还是 stdio 接线的差别没有单独证到），所以**钉住 0.99.2 曾把这个产品侧的问题挡在门外**。

诊断开关：`P163_BRANCH_UPSTREAM=1` 给分支一个本地 upstream（`branch.task/P138.remote=.` → 本仓 `main`，
无远端、不联网），把「第二封 say 能不能送达」与「探测的 stderr 漏到 pane」分开；默认**关**，保持真实工作树
形状。根治在产品侧（`skills/teamsmith/extension/team-notify.ts` 的 `run()` 需要
`stdio: ['ignore', 'pipe', 'pipe']`；最小复现见 `docs/team/reports/P380-dev3.md`），修好后这个开关可以删掉。

## 纪律

- 只调 `distrobox-host-exec podman`；容器 `--network=none`、回环 mock 模型、无凭据挂载；
  容器有自己的 tmux server（`scenario.sh` 里的 `tmux kill-server` 只在这个一次性容器里）。
- 不 checkout/切分支：被测源码用 `git archive` 进容器。
- 不改别人的 case 目录：case 名必须是 `tmux-p163-*` / `watch-p163-*`，现场目录由 `P163_EVIDENCE` 指到本任务。
