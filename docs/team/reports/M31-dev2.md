# M31 · 容器镜像补 procps + digest 警告未入账的复验/报告记录

agent: dev2   status: DONE   time: 2026-09-18T12:05:00+00:00
branch: `task/M31-procps-digest`   PR/MR: -（本地模式：不 push，分支留在 `.worktrees/dev2`）

## Deliverables

| Path | What |
|---|---|
| `skills/teamsmith/tests/container-tmux.sh` | 镜像加 `procps` + 构建期断言 `ps -o args= -p 1`；新增 `image_ps_caps` 能力探针（旧缓存镜像自动重建；显式 `TEAM_TMUX_IMAGE` 只跳过，不擅自重建别人的镜像）；`--selftest` 加两条 ps 断言；`--rebuild` 现在真的强制重建（文档一直这么写，代码以前不是） |
| `skills/teamsmith/scripts/lib/cmd-status.sh` | digest [4] 新增「记录未入账」：`team_untracked_records` = **一次** `git status --porcelain --untracked-files=all`（只 `reviews/`+`reports/`，过滤 `.gitkeep`/`.gitignore` 脚手架）；`team_record_task_id` + `team_task_name_suffix` 给每条记录贴任务名（M16 口径） |
| `skills/teamsmith/tests/smoke.sh` | 新 7b 段（专用夹具仓库）：干净树不报 / records 之外的 untracked 不报 / 未跟踪记录被逐条点名（含报告包里的文件）/ 带名字 / 提交后消失 / 退回未入账又回来 |
| `docs/team/reports/M31-dev2/pkg/{lib.sh,run.sh,10-container-ps.sh,20-digest-flip.sh,30-readonly.sh}` | 独立对抗验证包（自写，不复用 smoke 夹具；不调用 tmux） |
| `docs/team/reports/M31-dev2.md` | 本报告 |

## Verification evidence (must have actually been run)

### 1) 容器内 ps 能力 + 自检（auto-rebuild 命中旧缓存）

```
$ bash skills/teamsmith/tests/container-tmux.sh --selftest        # 首次运行自动识别旧镜像并重建
镜像 teamsmith-tmux-test:alpine 是旧缓存（ps 不支持所需参数，缺 procps）→ 自动重建（V18 F-V18-2）
构建 tmux 测试镜像 teamsmith-tmux-test:alpine（一次，之后缓存；base=docker.io/library/alpine:latest）…
    ok   容器内 ps 支持 -o args= -p（procps） (yes)
    ok   容器内 ps 读得出 pid 1 的 args（非空） (yes)
    ok   容器 uid（决定 socket 目录 = tmux-N） (0)
    ok   裸 tmux kill-server 成功
宿主 tmux 指纹（后）：791b313299bb45aa70bc1894167ccf05
✓ 自检通过：容器内 tmux 生死正常（含裸 kill-server），宿主 server 指纹逐字节不变（791b313299bb45aa70bc1894167ccf05）
```

### 2) 容器内 panel-b3 detail+collapse（对照：旧镜像 ✗6 / 新镜像 ✓0）

```
$ # red before：旧镜像（BusyBox ps）+ 修复前 harness（git show HEAD:…container-tmux.sh 的同目录副本）
$ TEAM_TMUX_IMAGE=teamsmith-tmux-test:alpine-old bash …/container-tmux-old.sh -- bash …/panel-b3.sh detail collapse
== 结果 ==  ✓ 29  ✗ 6
panel-b3 有失败项（TEAM_B3_KEEP=1 保留现场）
exit=1

$ # green after：新镜像 + 新 harness
$ bash skills/teamsmith/tests/container-tmux.sh -- bash skills/teamsmith/tests/panel-b3.sh detail collapse
  ✓ 收前后窗口数不变（一个后端、一个窗口）
  ✓ pulse up 原地恢复控制台
== 结果 ==  ✓ 35  ✗ 0
panel-b3 全绿
exit=0
```

### 3) 独立验证包（自写；不依赖实现者的 smoke 夹具；不调用 tmux）

```
$ bash docs/team/reports/M31-dev2/pkg/run.sh
############ 10-container-ps.sh ############
  ok 容器里 ps -o args= -p 1 成功且有输出（ps -o args= -p 1）
  ok 镜像里的 ps 来自 procps（ps from procps-ng 4.0.6）
  ok 负对照：BusyBox ps 的镜像被拒（exit 77），不会假红
  ok 负对照的 SKIP 说明点名了 ps/procps
  ok 容器里跑 panel-b3 detail+collapse 的退出码
  ok panel-b3 结果行 ✓ 35（修复前是 ✗ 6 的那两个场景）
  ok panel-b3 全绿
  ok panel-b3 结果行 ✗ 0
== 10 container ps 结果 == ok=8 bad=0 finding=0 skip=0

############ 20-digest-flip.sh ############
  ok team paths 的 main_root 就是夹具仓库
  ok 干净树不打「记录未入账」
  ok records/ 之外的 untracked 文件不触发警告
  ok 未跟踪的复验记录被点名
  ok 未跟踪的报告被点名
  ok 报告包里的文件被点名（不是只报目录）
  ok 份数统计与实际一致（3 份）
  ok 提交后警告消失（翻转）
  ok 退回未入账后警告回来（翻转双向）
  ok 带空格的文件名仍然被列出来（git 的引号形式）
  ok 暂存用例的基线：清场后无警告
  finding 暂存未提交（git add 后未 commit）的记录不报警：brief 把检查限定为 untracked…
  ok 改动用例的基线：其余记录都已提交时没有其它警告
  finding 已跟踪但改动未提交（' M'）的记录不报警：检查只读 untracked（??）…
== 20 digest records 结果 == ok=12 bad=0 finding=2 skip=0

############ 30-readonly.sh ############
  ok digest 前后 git 状态 / 记录目录 / state 逐字节不变
  ok 警告确实出现（否则这条只读检查是空转）
== 30 digest readonly 结果 == ok=2 bad=0 finding=0 skip=0

############ 总计 ############
ok=22 bad=0 finding=2 skip=0
failed sections: none
M31 包：没有 bad（pkg_exit=0）
```

digest 输出实录（夹具仓库，一份未跟踪复验记录 + 一份未跟踪报告）：

```
[4] 待收尾（脏工作区 / 相对 upstream 未 push 的提交；领先按 main 另计；squash 已合并单独标注）
  记录未入账       2 份 untracked（squash 合并只带分支内容，先提交再合并/归档）：
    · docs/team/reports/M31-sample-dev.md
    · docs/team/reviews/M31-sample.md
```

### 4) 门禁

```
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
== 结果 ==  ✓ 1637  ✗ 0
smoke 全绿
```

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh
- Validating...
✓ spec/agent-adapters … ✓ spec/watchdog（14 项）
Totals: 14 passed, 0 failed (14 items)
（全量 smoke 排队等另一套门禁后开跑）
  ✓ M28 lint --selftest：双向夹具全部符合预期（检查器这两方向都可信）
  ✓ M28 容器自检：容器内裸 tmux 开窗/杀 server 正常，宿主 server 指纹逐字节不变
  ✓ M28 容器里跑真 pi 体检：输入框判据 + 收回在真实现场成立
  ✓ M28 容器里跑真 pi 体检：空闲空框被判 EMPTY（没被误判成忙）
== 结果 ==  ✓ 2070  ✗ 0
smoke 全绿
gate_exit=0
```

（`openspec validate` 的 stdout 落在后台作业日志 `.pi/team/state/bg/m31-full-gate.log`：`&&` 的 `>` 只重定向了 smoke。）

## Flip evidence

**F-V18-2（容器镜像缺 procps）— red before → green after（真跑，不是推断）：**

- red before：旧镜像（只有 BusyBox `ps`，`ps: unrecognized option: p`）+ 修复前 harness → `panel-b3 detail collapse` 在容器里 `✓ 29 ✗ 6`，退出码 1（6 条全部依赖 `ps -o args= -p`）。另：负对照 `TEAM_TMUX_IMAGE=alpine`（BusyBox ps 的镜像）在新 harness 上被**拒绝**（exit 77），不会假红。
- green after：新镜像（procps-ng 4.0.6，构建期断言 + `--selftest` 两条断言）+ 新 harness → 同一夹具 `✓ 35 ✗ 0`、`panel-b3 全绿`、退出码 0；宿主 tmux 指纹前后一致。

**F-V18-4（记录未入账没有信号）— 破坏实现 → 守卫测试红 → 恢复 → 绿：**

```
$ sed -i 's|^team_untracked_records() { # |team_untracked_records() { return 1; # |' skills/teamsmith/scripts/lib/cmd-status.sh
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
  ✗ M31：未跟踪的复验/报告记录触发警告行（… 中找不到 [记录未入账]）
  ✗ M31：警告点名未跟踪的复验记录（… 找不到 [docs/team/reviews/M31-flip.md]）
  ✗ M31：警告点名未跟踪的报告（… 找不到 [docs/team/reports/M31-flip-dev.md]）
  ✗ M31：报告包里的文件也被点名（不是只报一个目录）（… 找不到 [M31-flip-dev/pkg/run.sh]）
  ✗ M31：警告行带代号时必须随身带名字（M16 口径）（… 找不到 [reviews/M31A.md（夹具：未入账也要带名字）]）
  ✗ M31：记录退回未入账状态 → 警告回来（翻转双向）（… 找不到 [记录未入账]）
== 结果 ==  ✓ 1631  ✗ 6
$ git checkout -- skills/teamsmith/scripts/lib/cmd-status.sh   # restore
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
== 结果 ==  ✓ 1637  ✗ 0
```

正向翻转（同一个信号跟着 git 状态走，双向）见验证包 20 段：干净树不报 → 未跟踪记录被点名 → `git commit` 后消失 → `git reset` 退回未入账又出现。

## Decisions and deviations

- **`skills/teamsmith/scripts/**` 名义归 PM**：任务书 Boundaries 明确要求「digest 的『待收尾』段加一条检查」，因此按任务书改了 `cmd-status.sh`（只动 digest 部分），未碰 panel/投递/巡检。
- **检查只盯 untracked（`??`）**，按 brief 原文；`git add` 未 commit（暂存）与已跟踪文件被改动（` M`）**不报警**。这两条已在验证包里作为 finding 记录（不判红），是否扩到「所有未提交状态」请 PM 裁（扩了要同步任务书/spec；面板/巡检门禁都不读它，改起来是局部改动）。
- **每条记录单独一行并贴名字**：M16 契约是「凡出现代号的行都必须带名字」，且某条查不到名字时不能因为同行别处出现括号而被判成「给它编了名字」——所以不做多记录拼行，查不到名字就只印路径（M16 负对照同口径）。
- **只读 + 性能**：检查只有一次 `git status --porcelain --untracked-files=all`（限定两个目录），没有写入；`scripts/panel/src/data.ts` 的块从不调用 digest，因此**没有**新增/调整任何面板 TTL 块，也没有加重板面每拍的数据块。
- **`--rebuild` 语义修正**：原实现里 `--rebuild` 对已存在的镜像不起作用（与 `--help` 的「强制重建」不符）；既然 F-V18-2 要处理旧缓存镜像，顺手把这一行改成真的强制重建。这是独立的一行行为修正，若 PM 认为超范围可单独回退。
- 未动 `skills/teamsmith/tests/panel-b3.sh`（F-V18-2 是镜像问题，夹具本身在宿主上一直全绿）。

## Suggested next steps

- 复验：`team review M31`（报告里有 `docs/team/reports/M31-dev2/pkg/run.sh`；强复验的翻转证据在本报告 `## Flip evidence`）。
- 归档：本任务 `change: -`，无 spec 改动；M31 归档只需复验通过 + 用户确认。
- 可选项（要 PM 决策）：把 digest 的未入账检查从「untracked」扩到「任何未提交状态」（暂存/已改动）；包里两条 finding 是它的完整现场。
