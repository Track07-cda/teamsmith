# P61 · trust-prompt-and-fixtures 独立验证（verify 阶段）· dev3

agent: dev3   status: **DONE**（verify：brief 1–6 逐条 + 三条变异 + 三条验收命令；三处 finding 记录在案）
time: 2026-09-22T15:15Z（门禁长跑跨到此时）
branch: `task/P61-trust-prompt`（local 模式：**不 push**，分支留给 PM）   PR/MR: -
change: `trust-prompt-and-fixtures`（apply = **P59 dev-bob**，不是我 · verify = **P61 dev3**）
specs: `verification#A fixture's input-box judgement distinguishes an unexpected overlay` /
`init-skill#The project-local install names Pi's trust consequence`
被验基线: `8396749`（任务书提交；实现 = P59 的 `d0fc238`，其后无实现改动）
证据包: `docs/team/reports/P61-dev3/`（`pkg/` 可重跑，`logs/` 是原始输出）

**总结论**：两条 ADDED requirement 的承诺在我这一轮里成立，且红/绿两侧都能被独立复现：

1. **覆盖层 vs 草稿**（`verification`）：真信任弹窗被点名（`overlay=trust-prompt`）、夹具**非零退出且
   一个字节都没敲进去**（`10e` 的字节级键审计：keylog 为空；`10a` 真 pane 拒绝；`30b`/`30d`/`30e` 三个现场
   同样 0 退出、无投递步骤）；真 pane 的项目本地安装**没有被 `--no-skills` 绕过**（`30a` 留下现场检查
   `.pi/skills/teamsmith`，`30c` 读源码确认 init 调用行没有那个旗标，`30d` 容器里也在位）。
   多行真草稿照旧判「有草稿」（`10b` `state=BUSY`、`HOLDS_ONLY=yes`；`15c` 真 pane 对照 `BUSY`）。
   就绪门不再是「第一条整行 ─」：`20a`/`20c` 的慢帧序列里第 2 帧（真框）出现之前 pane 输入 0 字节，
   而 P59 之前的旧夹具原文（`20b`，从 git 取出）在同一序列上框还没画就放行并打字。
2. **安装提示行**（`init-skill`）：`team init` 恰好一行（`.pi/skills/` + `pi --approve` + `/trust` +
   `team init --no-skills`），`--no-skills`、冲突/失败路径都不打，退出码不变；重跑（skip）与
   `bootstrap` 的**既有 config 升级路径**也打（`50a`–`50f`）；文档两处同事实（`50f` 红侧：删掉即搜不到）。

**三处 finding（都不改变上面的结论，都记录在案，见 §8）**：

- **F1（既有判据 + Pi 0.87 布局，重要）**：真 pane 上的**单行**草稿落在紧贴下边框那一行（`OFFSET==1`），
  而 `team_input_box_text` 与帧级判据都按位置排除这一行 —— 单行草稿因此被判成 `EMPTY`：
  `input_box_text=[|]`（只有一个换行 = 内容为空）、`input_box_state=EMPTY`、`delivery_verdict=EMPTY`（`15b`）。后果：就绪门会带着人的
  单行草稿放行并投递（`15d`，keylog 收到输入）；生产投递路径也会把 payload 贴进那行草稿。
  根因不在本 change 的覆盖层逻辑（0.85.1 时那一行是框自带的提示/状态行，排除是对的；0.87.0 把它移到了框外），
  但**本 change 的就绪门复用了同一条判据**，所以我按 finding 上报而不是按本 change 的 bad 记账。
- **F2（低危、保守方向）**：草稿里同时写全 `Trust project folder?` + `Do not trust` + 导航行时，覆盖层谓词会
  误报 —— 后果是夹具拒绝/大声失败（不会往草稿里打字），不是静默错判（`40g`）。
- **F3（既有红，P47×P53；让两条 smoke 接受命令退出非 0）**：`container-tmux.sh` 的两个 `fpcheck*` 临时根不在
  P53 lint 的 owned 家族里。FAST `✓2367 ✗1`、全量 `✓2898 ✗1`，红的就是它；**base 树（`d0fc238^`）跑同一条 lint
  同样红**，P59 没碰这个文件 —— 与 P59 无关，但 PM 要决定它怎么收口。§31b2 是绿的。

**验收三命令**：`openspec validate` 绿（24/24）、`pm-box-real.sh --expect-overlay` 绿（rc=0、点名覆盖层、store 未变）；
`TEAM_SMOKE_FAST=1 smoke.sh` **rc=1** —— 唯一红是 F3（既有 lint），P59 的段全绿。全量 smoke 同样是
`✓2898 ✗1`，§31b2 两条容器真 pi 断言绿。

---

## 验收（brief 的三条，逐字跑）

```sh
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
… ✓ change/trust-prompt-and-fixtures …
Totals: 24 passed, 0 failed (24 items)                                   # rc=0（logs/60e-openspec-validate.log）

$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
✓ …（P59 的 12b-h0c 绿/红两侧在内，共 2367 条）
✗ 40 lint 有 finding（rc=1）：…/container-tmux.sh:159: 名字不在 owned 家族（${TMPDIR:-/tmp}/fpcheck.XXXXXX）…
== 结果 ==  ✓ 2367  ✗ 1                                                  # rc=1 —— 唯一红是 F3（base 树同样红）

$ bash skills/teamsmith/tests/pm-box-real.sh --expect-overlay
M24 真实 pi 窗格体检 · pi=<home>/.bun/bin/pi · 私有 socket=… · idle=8s · trust=prompt --expect-overlay
overlay=trust-prompt
✓ 覆盖层已点名（--expect-overlay）：Pi 的项目信任弹窗 —— 一个键都没敲进它，投递步骤一步没跑（都排在就绪门之后）
✓ 隔离自检：夹具 session 不在真实默认 server 上
✓ trust store 未变（$HOME/.pi/agent/trust.json：sha256=228edb30…97c5 mtime=1789370262）   # rc=0（logs/30b-expect-overlay.log）
```

brief 第 6 项还要的**全量 smoke**（不在接受命令三条里，但 item 6 点名）也跑了：

```sh
$ bash skills/teamsmith/tests/smoke.sh </dev/null      # flock 串行；日志 .pi/team/state/bg/p61-full-smoke.log
✓ M28 容器里跑真 pi 体检：输入框判据 + 收回在真实现场成立
✓ M28 容器里跑真 pi 体检：空闲空框被判 EMPTY（没被误判成忙）      # ← 本 change 修的那条红
✗ 40 lint 有 finding（rc=1）：…container-tmux.sh:159/215…（同 F3）
== 结果 ==  ✓ 2898  ✗ 1                                  # rc=1 —— 唯一红同样是 F3
```

---

## 0 · 怎么验的（可重跑）

```sh
# 全部段（真 pi 现场 + 容器；几分钟）
bash docs/team/reports/P61-dev3/pkg/run.sh
# 或单段：15（F1） 20（就绪门） 30（接受命令/trust store/容器） 40（真帧） 50（安装行） 60（零回归） 70（变异）
```

每个 tmux 调用都是 `env -u TMUX -u TMUX_PANE TMUX_TMPDIR=<包自己的 mkdtemp 目录> tmux`（目录先建好，
memory #1250 的两个回退形态都堵上），`run.sh` 前后给默认 server 留只读指纹；`team` 调用先清掉继承的
`TEAM_*` 身份；所有写操作都在 `$TMPDIR` 的临时仓库里；变异只打 scratch 副本。
「一个键都不许敲」用**测量仪** `pkg/fake-pi.py`（通过 `M24_PI_BIN` 顶替真 pi）：它画两段帧并把 pane 收到的
每个字节带毫秒时间戳抄进 keylog，阶段时刻写 mark —— 于是「第 2 帧之前有没有键」和 M2 变异体敲进弹窗的字节
都是原始数据（keylog/mark 都抄进了 `logs/`）。

## 1 · brief 第 1 项：覆盖层 vs 真草稿 vs 其它整屏界面

| 现场 | 命令（原文） | 结果（原始输出在 `logs/`） |
|---|---|---|
| ① 真信任弹窗 | `M24_TRUST=prompt bash skills/teamsmith/tests/pm-box-real.sh --idle-secs 3` | rc=**1**；`overlay=trust-prompt`；`✗ 覆盖层挡住了输入框：一个键都不敲，投递步骤一步不跑`；无 `deliver_text_lines=`；无 `idle-read=NOT-EMPTY`；`✓ trust store 未变`（`10a-real-prompt-refuse.log`） |
| ① 弹窗的字节级审计 | fake-pi 画真弹窗 + `M24_TRUST=prompt` / `--expect-overlay` | 两次运行 **keylog 0 行**；refuse 腿 rc=1、expect 腿 rc=0；输出 `overlay=trust-prompt` 且无投递步骤（`10e-fake-overlay-refuse*.log` / `10e-fake-overlay-expect*.log`） |
| ② 正常框 + 真草稿（夹具自己的多行 payload） | `bash …/pm-box-real.sh --idle-secs 3` | rc=0；`M45 idle-read=EMPTY ok`；粘贴后 `state=BUSY`、`HOLDS_ONLY=yes`、`RETRACT=ok`；`.pi/skills/teamsmith 仍在位`；`overlay_absent=ok`（`10b-real-draft-flow.log`） |
| ② 我自己造的真帧（空框 / 单行草稿） | 私有 socket 起真 pi（`--approve`）+ 生产投递函数打一行草稿 | 空框帧判 `EMPTY`、草稿帧**不是**覆盖层；单行草稿的判据级结论见 §8 F1（`10c-real-empty-box.log` / `10c-real-draft-box.log` / `15b-*.log`） |
| ③ 其它整屏界面（真 vim） | 私有 socket 起 `vim -u NONE`，全 30 个光标行跑判据 | 全部 `idle-read=NOT-EMPTY`、**从不** `overlay=trust-prompt`、从不 `EMPTY`（`10d-other-screen-vim.log`） |
| ③ 其它整屏 chrome（Pi 更新横幅真帧） | `--frame pi-0.85.1-update-banner.txt --cursor 26` | 不是覆盖层；真输入框仍在（`EMPTY`）（`10d`，帧在 `tests/frames/`） |

「一个键都不许敲」在真弹窗上还有一条独立证据：接受命令 `--expect-overlay` 的输出里
`✓ 覆盖层已点名 … 一个键都没敲进它，投递步骤一步没跑`，且 `✓ trust store 未变`（`30b-expect-overlay.log`）。

## 2 · brief 第 2 项：就绪等待的口径（慢帧序列）

`20a-new-fixture-slow`：fake-pi 先只画一条整行 ─（第 1 帧，正是旧等待的全部条件），5 秒后才画
**真 pi 实拍的空框**（第 2 帧）。原始时刻（`logs/20-mark-20a-new-fixture-slow.log`）：

```
phase1 1790088170746
phase2_due 1790088175746
phase2 1790088175746
```

新夹具：rc=0、`· 就绪：判定定位到输入框且为空（连续两次静默读同一帧）…`、`deliver_text_lines=` 出现；
**第 2 帧之前 keylog 0 行**（`logs/20-keys-20a-new-fixture-slow.log` 为空），之后 1 行（投递真的发生，
不是空转）。`20c`：把覆盖层谓词关掉（弹窗只剩几何形状）同一结论 —— 框没画就不放行、真框到了才放行。

红侧用的是 **P59 之前的旧夹具原文**（`git show d0fc238^:skills/teamsmith/tests/pm-box-real.sh`）：
在同一序列上它 `box_ready` 一看到整行 ─ 就放行，**第 2 帧计划时刻之前**就打进 1 行输入（fake-pi 甚至没
走到第 2 帧），随后 `verdict=UNKNOWN`/`box_rows=[NONE|]`、`M45 idle-read=NOT-EMPTY BAD`、rc=1
（`logs/20b-old-fixture-slow.log`、`logs/20-mark-old.log`、`logs/20-keys-old.log`）。

这一项还顺手复现了 P54 的 F2 形状：旧夹具对着一个**定位不到框**的 pane 走完了投递与收回步骤 ——
新夹具在同现场停在就绪门、一个键都不敲。

## 3 · brief 第 3 项：trust store 与 `--no-skills` 绕过

* **前后指纹由我自己量**（不是读夹具自述）：`$HOME/.pi/agent/trust.json` 在 `30a`（`--idle-secs 3 --keep`）
  与 `30b`（接受命令 `--expect-overlay`，brief 原文，不清环境）前后都是
  `sha256=228edb30…97c5 mtime=1789370262`（`30a-keep-normal.log` / `30b-expect-overlay.log` 末尾，
  `30b` 里 `✓ trust store 未变` 只是夹具的自述，指纹是我另算的）。
* **容器**：`container-tmux.sh --with-pi --cmd "bash <skill>/tests/pm-box-real.sh --idle-secs 3"` → rc=0；
  `✓ trust store 未变（$HOME/.pi/agent/trust.json：absent）` —— 容器的 HOME 里**没有**它，跑完也**没被创建**
  （`30d-container-real-pi.log`）。同一个夹具的覆盖层模式在容器现场同样成立（rc=0、`overlay=trust-prompt`、
  无投递步骤、store 仍 absent；`30e-container-overlay.log`）。
* **没有 `--no-skills` 绕过**：`30c` 读源码 —— init 调用行是
  `$TEAM init --session "$SESS" --agents "dev" --vcs local --gates "true" --docs docs/team`（无该旗标），
  成功路径断言 `.pi/skills/teamsmith 仍在位`；`30a --keep` 留下的现场项目里 `.pi/skills/teamsmith` 是软链
  → 本轮运行树的 `skills/teamsmith`，`logs/30a-kept-init.log` 里有两条 `link` 行；`10b`/`30d` 的夹具自述同样在位。
* **`--frame` 纯帧模式不碰 tmux/pi**：把 `tmux` 与 `pi` 都换成会喊 `SHIM-CALLED-*` 的拦截 shim 后，
  `--frame … --cursor 16` 仍 rc=0、`overlay=trust-prompt`，输出里没有 `SHIM-CALLED-`（`30c-frame-no-tmux-no-pi.log`）。

## 4 · brief 第 4 项：帧的可证伪性与版本绑定

* **版本/来源**：本机 `pi --version` = **0.87.0**（`40a-pi-version.log`）；文件名带版本；帧目录 README 记了
  来源（真 pi 0.87.0、私有 socket、120×30、`--no-session`、`team init` 装过 `.pi/skills` 的项目、光标行 16）
  与复现命令；帧本身 30 行 raw capture、无注释、第 1/16 行是整行 ─、第 3 行是问题原文。
* **逐字节绑定**：按 design §1 的命令（同路径 `/tmp/trust-repro/proj`、私有 socket）用真 pi 重拍 →
  `diff` 与存下的帧**逐字节一致**（`40b-diff.log` 为空），重拍光标行 = 16，重拍也没写 trust store
  （`40b-recapture.log`、`40b-recapture.cursor`）。
* **可证伪性（全 30 个光标行）**：谓词开 → 30/30 `overlay=trust-prompt`；谓词关（`M24_OVERLAY_DETECT=0`）
  → 30/30 `idle-read=NOT-EMPTY`；两个方向**从不**出现 `idle-read=EMPTY`（`40c-cursor-sweep.log`，
  正是 spec 的 “with the overlay predicate disabled, the same frame MUST be judged a draft (never EMPTY)”）。
  记录的光标行上：`40d-flip-green.log`（overlay，rc=0）/ `40d-flip-red.log`（草稿，rc=1）。
* 对抗补充：帧目录里的另一份真帧不被点名；把问题行改成 `Trust this project?` 后谓词不命中、判据**不退成
  EMPTY**（就绪门不放行 → 响亮失败而不是假草稿）；草稿里写全三行标记会误报（§8 F2）。

## 5 · brief 第 5 项：安装提示行

| 场景 | 命令 | 结果 |
|---|---|---|
| 全新 init | `team init --session <s> --agents dev --vcs local --gates true` | rc=0；提示行**恰好一行**，含 `.pi/skills/` + `pi --approve` + `/trust` + `team init --no-skills`；`.pi/skills/teamsmith` 在位（`50a-fresh-init.log`） |
| `--no-skills` | 同命令 + `--no-skills` | rc=0；`pi --approve` **0 行**；没有 `.pi/skills/`（`50b-no-skills.log`） |
| 重跑（skip） | 再跑一次 | rc=0；`skip  <repo>/.pi/skills/teamsmith`；提示行**恰好一行**（`50c-rerun-skip.log`） |
| bootstrap 升级路径 | 既有 `config.sh` + 删掉 `.pi/skills` → `team bootstrap --no-pulse --agents dev` | rc=0；提示行恰好一行；`config.sh` 哈希不变；`.pi/skills/teamsmith` 重新装上（`50d-bootstrap-upgrade.log`） |
| 失败路径（未识别条目） | 同 init | rc≠0；**不打**提示行（提示行不改变退出码）（`50e-conflict-fail.log`） |
| 文档 | `skills/teamsmith-init/SKILL.md`、`references/bootstrap.md` | 两处都点名 `.pi/skills/`、`pi --approve`、`/trust`、信任弹窗；红侧：删掉 `pi --approve` 行后同样的搜索为空（`50f-doc-*.log`） |

`install-shape.sh` 的四条新断言与 ⑦a/⑦b 两侧翻转也在零回归里跑绿（§6）。

## 6 · brief 第 6 项：零回归

| 检查 | 命令（原文） | 结果 |
|---|---|---|
| FAST smoke（接受命令之二） | `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null` | **rc=1**，`== 结果 == ✓ 2367 ✗ 1`；唯一一条红是 `40 lint 有 finding`（`container-tmux.sh:159` 的 `fpcheck.XXXXXX`、`:215` 的 `fpcheck2.XXXXXX`）—— **既有红 F3**；其余全绿，包括 P59 的 `12b-h0c` 段（`60a-fast-smoke.log`） |
| 全量 smoke（含 §31b2） | `bash skills/teamsmith/tests/smoke.sh </dev/null`（flock 串行；完整日志 `.pi/team/state/bg/p61-full-smoke.log`） | **rc=1**，`== 结果 == ✓ 2898 ✗ 1`；同一条既有 lint 红；**§31b2 两条容器真 pi 断言都绿**：`✓ M28 容器里跑真 pi 体检：输入框判据 + 收回在真实现场成立`、`✓ M28 容器里跑真 pi 体检：空闲空框被判 EMPTY（没被误判成忙）` —— 这正是本 change 修的那条红（`60b-full-smoke-plain.log`） |
| install-shape.sh | `bash skills/teamsmith/tests/install-shape.sh` | rc=0，`== 结果 == ✓ 97 ✗ 0 SKIP 0`；P59 的四条提示行断言与 ⑦a/⑦b 两侧翻转都在（`60c-install-shape.log`） |
| pm-box-real.sh 三态 | `--idle-secs 3` / `--expect-overlay` / `M24_TRUST=prompt` | 三态分别在 `10b`、`30b`、`10a` 绿：正常框 `EMPTY`+投递+`RETRACT=ok`；覆盖层点名且 0 退出；覆盖层拒绝且非零退出（`60d` 从三条日志逐条核对） |
| openspec | `PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict` | rc=0，`Totals: 24 passed, 0 failed (24 items)`（当前树多了未归档的 `test-tmp-hygiene`，所以是 24 而不是 P59 那时的 23）（`60e-openspec-validate.log`） |

**结论**：本 change **没有引入任何新红**；`§31b2`（这本 change 修的那条红）在全量 smoke 里绿。
两条 smoke 接受命令的退出码不是 0，唯一原因是 **F3**（P47 加进 `container-tmux.sh` 的两个 `fpcheck*` 临时根
与 P53 lint 相撞；base 树同样红）。三态与 install-shape、openspec 全绿。

另外如实记录一处不一致：P59 的报告/复验记录写的是全量 `✓2896 ✗0`、FAST `✓2365 ✗0`；本分支现在是
全量 `✓2898 ✗1`、FAST `✓2367 ✗1`，差的正是这条 lint 红。P53 的 lint 落地（14:31:33）比 P59 的 apply
（14:32:41）只早一分钟 —— 若 P59 的门禁跑在拿到 P53 之前的树上，这个差异就解释得通；我无法从证据里
判定当时跑的是哪棵树，只如实记录**当前分支**的状态。

## 7 · 变异（红→绿原始输出）

| 变异 | 打法 | 红 | 绿 |
|---|---|---|---|
| **M1** 关掉覆盖层判据 | scratch 树里 `team_box_overlay_kind() { return 0; }`（源码级，不是内置旋钮） | 同一份真帧 → `idle-read=NOT-EMPTY`、rc=1（`70m1-red-predicate-killed.log`） | 真树 → `overlay=trust-prompt`、rc=0（`70m1-green-real-tree.log`） |
| **M2** 夹具在弹窗上继续跑投递 | scratch 副本把 `overlay=trust-prompt` 也当就绪（`READY=1`） | 弹窗现场 `deliver_text_lines=` 出现、**keylog 收到敲进弹窗的 1 行字节**、夹具自己红了（`就绪之后仍看到覆盖层`）、rc≠0（`70m2-mutant-delivers-into-overlay.log`） | 真夹具同现场：rc=1、无投递步骤、keylog 0 行（10e） |
| **M3** `--no-skills` 也打提示行 | scratch 树在 `--no-skills` 分支加打印 | 变异体下该命令输出 1 行 `pi --approve`（静默断言必须红）（`70m3-red-no-skills-prints-hint.log`） | 真树下 0 行、rc 仍 0（`70m3-green-no-skills-silent.log`） |
| **M4** 还原 | 全部变异都在 `$V61_WORK` scratch 副本 | — | `git status --porcelain -- skills/ openspec/` **空**（`70m4-tree-clean.log`；全树只剩 `?? docs/team/reports/P61-dev3/`） |

另外用**历史实现**做了第 4 条红侧（不属于三条要求里的变异，但更硬）：P59 之前的夹具原文在同一慢帧序列上
提前放行并打字（`20b`），对着定位不到的框走完投递/收回 —— 新夹具在同现场停在就绪门。

## 8 · Findings

### F1（重要，既有判据 × Pi 0.87 布局；不是本 change 引入，但在它的作用面上）

**现象**：真 pane 上的**单行**草稿被判成空框。原始输出（`logs/15b-prod-verdicts.log`）：
`input_box_text=[|]`、`input_box_state=EMPTY`、`delivery_verdict=EMPTY`、`rows=[1|HUMAN-ONE-LINE-DRAFT|26 ]`。

**根因**：0.87.0 的输入框是「上边框 / 内容行 / 下边框」，框外的状态行（`0.0%/1.0M … deepseek`）在
下边框**下方**；于是单行草稿就是 `OFFSET==1`（紧贴下边框）那一行，而 `team_input_box_text`
（`outbox.sh`）与帧级判据（`tests/lib/box-judge.sh`）都按位置排除这一行。0.85.1 的真帧里那一行是
框**自带**的提示/状态行（` deepseek-flash  Deepseek  max`，`logs/15a-banner-0815-rows.log`），排除它是对的 ——
0.87 把状态行移出框后，这条位置规则就吃掉了真实内容。

**后果**（都可复现）：
1. 就绪门带着人的单行草稿放行并投递：fake-pi 画真 pi 的**单行草稿帧**，夹具 rc=0、`M45 idle-read=EMPTY ok`、
   `deliver_text_lines=` 出现、keylog 收到 1 行输入（`15d-fixture-over-draft.log`）。
2. 生产投递路径 `team_delivery_verdict` 同判 `EMPTY`；`team_box_holds_only` 在这种现场返回 `yes`（空框语义），
   于是 payload 会被贴进人的草稿（进入复检后才可能被判污染并收回）。

**对照（多行没问题）**：夹具自己的多行 payload → 框内 3 行（offset 3/2/1），`state=BUSY`、`holds_only=yes`
（`15c-multi-line-control.log`；`10b` 同结论）。所以 F1 限定在「单行草稿」这一形状。

**为什么没按本 change 的 bad 记账**：本 change 的 spec 场景（覆盖层不是草稿、空框可达、覆盖层前停下）全部成立；
这一步坏在**共享判据的既有排除规则**与 Pi 0.87 布局的组合，P59 只是把同一条判据复用进了就绪门。
建议：开一个自己的 change（`delivery-guard` 侧），把 `OFFSET==1` 的排除改成「按布局/内容识别框自带提示行」，
或让判据在「框只有一行且非空」时优先认内容；红侧就用本包的 `15b/15d` 两份现场。

### F2（低危、保守方向）

草稿里同时出现 `Trust project folder?`（整行去空白后恰好相等）、16 行内 `Do not trust`、其后 6 行内同时含
`navigate` 与 `enter select` 时，覆盖层谓词会命中（`40g-marker-draft-verdict.log`）。后果是夹具把草稿当覆盖层
→ **拒绝投递/大声失败**（rc=0 的 overlay 分支、无投递步骤），不往草稿里打字；真 pane 上要三行同时在框里
才触发。design §5.2 已把这个形状列为残余（谓词按文案标记识别），我把它记成 finding 而不是缺陷。

### F3（既有红：P47 × P53 的 lint；不在本 change 的 diff 里）

`skills/teamsmith/tests/container-tmux.sh:159/215` 用 `${TMPDIR:-/tmp}/fpcheck.XXXXXX` /
`fpcheck2.XXXXXX` 建私有目录，而 P53 的 `tmp-hygiene.sh --lint` 要求所有 `mktemp -d` 模板都是
`${TMPDIR:-/tmp}/teamsmith-<kind>.XXXXXX` → `40 lint 有 finding`，FAST 与全量各 1 条红。

证据：

- 引入者：`git blame` 两行都是 P47（`6ca5595c`，11:46:03）；P53 的 lint 随后落地（`34e6c00c`，14:31:33）。
- P59 没碰这个文件：`git show --stat d0fc238 -- skills/teamsmith/tests/container-tmux.sh` 为空。
- **base 树同样红**：`git archive d0fc238^ | tar -x -C /tmp/p61-base` → 在 base 树里
  `bash skills/teamsmith/tests/tmp-hygiene.sh --lint` rc=1，同样两条 `container-tmux.sh:159/215`
  （`README` 的 `60-regression.sh` 每次跑都会现场复现：`base 树（d0fc238^）lint rc=1，finding 行：2`）。

修法很小（把两个目录名改成 `teamsmith-fpcheck.XXXXXX` / `teamsmith-fpcheck2.XXXXXX`），但它落在 P47/P53 的
地盘，不在我这条 verify 的 grant（只写报告与证据）里；建议 PM 开一条小 task 或并入 P60/P53 的尾巴。

### 给 PM 的判定建议

- P59 的两条 ADDED requirement：**满足**（每一条都有现场 + 两侧翻转 + 门禁）。本 change 可以进归档流程，
  **前提**是 PM 对 F3 做一个决定（它是既有红，会让两条 smoke 接受命令退出非 0；不修它而归档的话，归档后的
  保护分支仍然是 `✓2367 ✗1`）。
- F1：不阻塞本 change，但它影响**生产投递**（单行草稿会被贴进 payload）；建议另开一条 `delivery-guard` change，
  红侧直接用 `pkg/15-one-line-draft.sh`。
- F2：无行动项（保守方向、design §5.2 已登记）。

## 9 · 交付物与边界

| 路径 | 内容 |
|---|---|
| `docs/team/reports/P61-dev3.md` | 本报告 |
| `docs/team/reports/P61-dev3/README.md` | 证据包说明与重跑方式 |
| `docs/team/reports/P61-dev3/pkg/**` | 可重跑脚本（`lib.sh`、`run.sh`、`10`–`70` 段、测量仪 `fake-pi.py`） |
| `docs/team/reports/P61-dev3/logs/**` | 原始输出（本报告引用的所有 `logs/*.log`，含 keylog/mark） |

grant 只给报告与证据：本任务**没有**改 `skills/**`、`openspec/**` 或任何钉子（`70 M4` 的
`git status --porcelain -- skills/ openspec/` 为空）。`docs/team/tasks/P61-trust-prompt-verify.md` 未修改。
报告与证据提交后，工作树的 `git status --porcelain` 为空（它们本身就是那次提交的内容）。
本地模式：不 push；分支 `task/P61-trust-prompt` 留在本地等 PM 复验。
