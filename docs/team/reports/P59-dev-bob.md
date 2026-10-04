# P59 · trust-prompt-and-fixtures apply：夹具区分覆盖层 + `team init` 说明信任后果

agent: dev-bob   status: 交付（apply：B1 判定与真帧 · B2 安装行与文档 · B3 门禁与现场证据）   time: 2026-09-22T14:25Z
branch: `task/P59-trust-prompt-apply`（local 模式，**不 push**）   PR/MR: -
change: `trust-prompt-and-fixtures`（提案复审 **ACCEPTED**：`docs/team/reviews/trust-prompt-and-fixtures-proposal.md`；
`phase: apply`，`deltas: verification, init-skill`，`specs: verification#A fixture's input-box judgement distinguishes an
unexpected overlay / init-skill#The project-local install names Pi's trust consequence`）
tip: `f7f1a31`（实现 + 文档的 tip；其后只有本报告与任务书勾选两个 docs 提交）
起点: `a05241d`（PM 的任务书提交）

**总结论**：两条 ADDED 都落地，翻转两侧都可见 ——

1. **判定**（`verification`）：就绪门只认「判定定位到的空输入框」（连续两次静默读同一帧），不再认「第一条整行 ─」；
   整屏覆盖层成为可命名的第三态（`overlay=trust-prompt`：点名、保留最后一帧、**非零退出且一个键都不敲**），
   `idle-read=NOT-EMPTY` 只留给「定位到的框里有文字」；真帧 + `M24_OVERLAY_DETECT=0` 红侧让分类可证伪。
   真 pane 仍然跑在 `team init` 装过 `.pi/skills/` 的项目里（不 `--no-skills` 绕过），用**单次运行的信任覆盖**
   （`pi --approve`）到达空框，trust store 前后指纹逐字节一致（容器里是 `absent`）。
2. **产品行**（`init-skill`）：`team_init_install_skills` 在**装完/已就位**时打一行说明信任后果与三条出路
   （`.pi/skills/` → 第一次跑 pi 会问 ｜ `pi --approve` ｜ `/trust` ｜ `team init --no-skills`），
   `--no-skills`、冲突/失败都不打，退出码一个字没改；`init` 与 `bootstrap`（含已存在配置的升级路径）
   共用这一个实现；skill 与 `bootstrap.md` 同步。

验收三条全绿：`openspec validate --all --strict` **23/23**、FAST smoke **✓2365 ✗0**、
全量门禁 **✓2896 ✗0**（§31b2 容器真 pi 体检在内），真现场三态（绿 / `--expect-overlay` / 红）在宿主与容器各跑通。

---

## 0 · 落点

| 任务书条目 | 落点 | 证据 |
|---|---|---|
| 1.1 存真帧 + README 行 | `tests/frames/pi-0.87.0-project-trust-prompt.txt`、`tests/frames/README.md` | §1.1（两次独立实拍 + 存件 sha256 相同） |
| 1.2 `--frame/--cursor` 纯帧判定 + `M24_OVERLAY_DETECT` 红侧 | `tests/lib/box-judge.sh`（`team_box_frame_verdict`）、`tests/pm-box-real.sh`（frame 模式） | §1.2 |
| 1.3 就绪门只认空框；覆盖层在投递步骤之前停手 | `tests/pm-box-real.sh`（判定驱动的就绪轮询、`overlay=…` 早停） | §1.3、§2.3 |
| 1.4 真 pane 到空框（`--approve`）+ `--expect-overlay` | `tests/pm-box-real.sh`（`M24_PI_ARGS`、`M24_TRUST`、trust 指纹） | §2.1–2.3、§5.3 |
| 1.5 FAST 段（真帧 + 红侧） | `tests/smoke.sh` 新段 `12b-h0c` | §1.2、§4.1 |
| 1.6 §31b2 形状不变 | `tests/smoke.sh`：`31b2` 的断言与调用原样 | §5.2 |
| 2.1 安装步一行 | `scripts/lib/cmd-init.sh`（`team_init_install_skills` 末尾） | §3.1 |
| 2.2 install-shape 四条 + 翻转 | `tests/install-shape.sh`（`chk_trust_hint*`、`chk_no_skills_silent`、flip ⑦a/⑦b） | §3.2、§4.3 |
| 2.3 文档同步 | `skills/teamsmith-init/SKILL.md`（§0 install beat）、`references/bootstrap.md`（project-skills 行） | §3.3 |
| 3.x 门禁 / 真现场 / 报告 | 本文件 + 下面各节 | §5、§2 |

**路径纪律**：`git diff --name-only main...HEAD` 恰好是任务书 `grant:` 列出的集合 ——
`tests/**`（`pm-box-real.sh`、`smoke.sh` append-only、`install-shape.sh`、`tests/lib/box-judge.sh`、`tests/frames/*`）、
`scripts/lib/cmd-init.sh`、`skills/teamsmith-init/{SKILL.md,references/bootstrap.md}`。
`outbox.sh`（投递守卫的判定语义）、`install-shape.sh` 既有的断言、`openspec/**`、其他 `scripts/**` 一个字节没动。

---

## 1 · 判定：覆盖层是第三态，不是「非空输入框」

### 1.1 真帧（存件与复现）

```
$ mkdir -p /tmp/trust-repro/{sock,sess} /tmp/trust-repro/proj/.pi/skills/teamsmith
$ cd /tmp/trust-repro/proj && git init -q -b main && printf '# x\n' > README.md && git add -A && git commit -qm init
$ env -u TMUX -u TMUX_PANE TMUX_TMPDIR=/tmp/trust-repro/sock tmux new-session -d -s trustrepro -x 120 -y 30 \
    -c /tmp/trust-repro/proj "HOME=$HOME pi --no-session --session-dir /tmp/trust-repro/sess"
$ sleep 8
$ env -u TMUX -u TMUX_PANE TMUX_TMPDIR=/tmp/trust-repro/sock tmux capture-pane -p -t trustrepro > /tmp/p59-capture-1.txt
$ sleep 2; … capture-2.txt            # 第二次独立实拍
$ env -u TMUX -u TMUX_PANE TMUX_TMPDIR=/tmp/trust-repro/sock tmux display-message -p -t trustrepro '#{cursor_y}'
15
STABLE: two captures byte-identical
$ sha256sum /tmp/p59-capture-1.txt /tmp/p59-capture-2.txt skills/teamsmith/tests/frames/pi-0.87.0-project-trust-prompt.txt
dd7cc04f509e552b62bc2d0e6365d748945452cde3f93a77b4a3d30f6b11fe47  /tmp/p59-capture-1.txt
dd7cc04f509e552b62bc2d0e6365d748945452cde3f93a77b4a3d30f6b11fe47  /tmp/p59-capture-2.txt
dd7cc04f509e552b62bc2d0e6365d748945452cde3f93a77b4a3d30f6b11fe47  skills/teamsmith/tests/frames/pi-0.87.0-project-trust-prompt.txt
```

帧内容（`awk '{printf "%2d|%s|\n", NR, $0}'`）：

```
 1|────────────（整行 ─ ×120）────────────|
 3| Trust project folder?|
 4| /tmp/trust-repro/proj|
 6| This allows pi to load .pi settings and resources, install missing project packages, and execute project extensions.|
 8| → Trust|
 9|   Trust parent folder (/tmp/trust-repro)|
10|   Trust (this session only)|
11|   Do not trust|
12|   Do not trust (this session only)|
14| ↑↓ navigate  enter select  escape/ctrl+c cancel|
16|────────────（整行 ─ ×120）────────────|
```

来源、光标行（1-based `16`）、复现命令与两条判据命令写进了 `tests/frames/README.md` 的新行/新段。

### 1.2 共享判据与两侧

`tests/lib/box-judge.sh`：
`team_box_overlay_kind`（stdin=帧 → `trust-prompt` | 空）只认**稳定文案三元组**（不认行号，因为存件是 0.87.0、
钉住的现场是 0.86.0 家族）：① 去空白后恰好 `Trust project folder?`；② 之后 16 行内 `Do not trust`（含
`(this session only)`）；③ 再之后 6 行内导航行（同时含 `navigate` 与 `enter select`）。
`team_box_frame_verdict <cy>`（stdin=帧）先看覆盖层、否则走**生产同一条**框几何（`_team_box_rows_of_frame`）
给出 `idle-read=EMPTY|NOT-EMPTY`。覆盖层优先于「框里有什么」是刻意的：光标落进弹窗时几何会把弹窗自己的两条
整行 ─ 配成「框」、把问题与选项读成框内容 —— requirement 点名的两种误判都在这条规则下消失。

```
$ bash skills/teamsmith/tests/pm-box-real.sh --frame skills/teamsmith/tests/frames/pi-0.87.0-project-trust-prompt.txt --cursor 16
frame=skills/teamsmith/tests/frames/pi-0.87.0-project-trust-prompt.txt cursor=16 mode=frame
overlay=trust-prompt
rc=0
$ M24_OVERLAY_DETECT=0 bash skills/teamsmith/tests/pm-box-real.sh --frame skills/teamsmith/tests/frames/pi-0.87.0-project-trust-prompt.txt --cursor 16
frame=skills/teamsmith/tests/frames/pi-0.87.0-project-trust-prompt.txt cursor=16 mode=frame
idle-read=NOT-EMPTY
rc=1
```

FAST 段 `12b-h0c` 把这两条 + 合成帧钉住（全量门禁日志里的原文）：

```
== 12b-h0c · P59 输入框判据：覆盖层（Pi 的项目信任弹窗）≠ 非空输入框 ==
  ✓ P59：真实信任弹窗帧（真 pi 0.87.0 实拍）在 tests/frames/
  ✓ P59 对照：真帧里就有两条整行 ─（老等待「第一条整行 ─」会在这帧上放行 → 更严的就绪门是必需的）
  ✓ P59 绿侧：真帧被判成覆盖层（rc=0）
  ✓ P59 绿侧：真帧点名 overlay=trust-prompt
  ✓ P59 绿侧：覆盖层**不许**被报成非空输入框
  ✓ P59 红侧：关掉覆盖层判据 → 同一份帧退回非空（rc≠0）
  ✓ P59 红侧：谓词关掉后同一帧被判成草稿（可证伪，不是空转）
  ✓ P59 红侧：谓词关掉后不再点名覆盖层
  ✓ P59：像弹窗的 chrome（两条整行 ─、没有真输入框）不许让就绪门放行（rc≠0）
  ✓ P59：合成帧没有可定位的空框 → 判定非空（就绪永远不放行）
  ✓ P59：合成帧绝不许被判成空框
  ✓ P59 对照：真输入框且为空 → rc=0（就绪门确实会放行）
  ✓ P59 对照：空框判成 EMPTY
  ✓ P59 对照：框里有草稿 → 非空（判定力不降）
  ✓ P59 对照：草稿照旧被判成非空
```

### 1.3 就绪门（比判据更早的一道）

`pm-box-real.sh` 的等框循环把「`grep -qE '^(─)+$'` 第一条整行 ─」换成**判定驱动的轮询**（0.5s × 120）：
每一拍抓帧 + 光标 → `team_box_frame_verdict`；**连续两拍判定 EMPTY 且帧逐字节相同**才放行；
一旦判定是 `overlay=trust-prompt` 立刻停（不等满 60s）。因此弹窗自带的两条整行 ─ 骗不过它，
「没有可定位的空框」的帧也永远不放行（§1.2 的合成帧断言：`idle-read=NOT-EMPTY`，不是 EMPTY）。

---

## 2 · 真现场（宿主 + 容器）

### 2.1 绿：`--approve` 到达空框（信任 store 不动）

```
===== 2 · 新夹具 --idle-secs 3（--approve，绿） =====
M24 真实 pi 窗格体检 · pi=<home>/.bun/bin/pi · 私有 socket=/tmp/teamsmith-pmbox.…/tmux · idle=3s · trust=approve
· 就绪：判定定位到输入框且为空（连续两次静默读同一帧），空闲 3s（复现「PM 空闲」形状）…
  M45 idle-read=EMPTY ok
  deliver_text_lines=3 bracketed=yes
  RETRACT=ok
✓ 隔离自检：夹具 session 不在真实默认 server 上
✓ trust store 未变（$HOME/.pi/agent/trust.json：sha256=228edb30… mtime=1789370262）
✓ .pi/skills/teamsmith 仍在位（这一轮跑在 team init 装过的项目里）
overlay_absent=ok（就绪与投递时刻都没有覆盖层）
rc=0
```

`trust before`/`trust after`（整段脚本前后）同为 `sha256=228edb30… mtime=1789370262` —— 三次运行（绿、
`--expect-overlay`、红）全落在这一对指纹之间。

### 2.2 `--expect-overlay`：点名它、0 退出、一步投递都不跑

```
===== 3 · 新夹具 --idle-secs 3 --expect-overlay（点名弹窗，绿） =====
M24 真实 pi 窗格体检 · … · trust=prompt --expect-overlay
overlay=trust-prompt
✓ 覆盖层已点名（--expect-overlay）：Pi 的项目信任弹窗 —— 一个键都没敲进它，投递步骤一步没跑（都排在就绪门之后）
✓ 隔离自检：夹具 session 不在真实默认 server 上
✓ trust store 未变（…）
rc=0
```

该段输出里 `deliver_text_lines=` 与 `RETRACT=` 的出现次数都是 **0**（`awk` 切段后 `grep -c`：run 3 = 0、run 4 = 0）。

### 2.3 红：夹具对着弹窗跑投递 → 非零退出、不敲键

```
===== 4 · 新夹具 --idle-secs 3 · M24_TRUST=prompt（对着弹窗跑投递 → 红，不许敲键） =====
M24 真实 pi 窗格体检 · … · trust=prompt
✗ 夹具：就绪门 60s 内没有放行（最后判定=overlay=trust-prompt）—— 没有定位到空的输入框
overlay=trust-prompt
✗ 覆盖层挡住了输入框：一个键都不敲，投递步骤一步不跑（要接受它请显式 --expect-overlay）
--- 最后一帧（原样，留给报告）---
          1	────────────（整行 ─ ×120）────────────
          3	 Trust project folder?
          4	 /tmp/teamsmith-pmbox.…/proj
         11	   Do not trust
         14	 ↑↓ navigate  enter select  escape/ctrl+c cancel
         16	────────────（整行 ─ ×120）────────────
✓ 隔离自检：夹具 session 不在真实默认 server 上
✓ trust store 未变（…）
rc=1
```

### 2.4 容器（`container-tmux.sh --with-pi`，与 §31b2 同一条路）

```
$ bash skills/teamsmith/tests/container-tmux.sh --with-pi \
    --cmd "bash $PWD/skills/teamsmith/tests/pm-box-real.sh --idle-secs 3"
  · 运行时：distrobox-host-exec podman（回宿主）
  · pi 包装器：…/shim/bin/pi → node …/@earendil-works/pi-coding-agent/dist/bundle/cli.js（不挂 $HOME）
M24 真实 pi 窗格体检 · … · idle=3s · trust=approve
· 就绪：判定定位到输入框且为空（连续两次静默读同一帧），空闲 3s…
  M45 idle-read=EMPTY ok
  RETRACT=ok
✓ 隔离自检：夹具 session 不在真实默认 server 上
✓ trust store 未变（$HOME/.pi/agent/trust.json：absent）
✓ .pi/skills/teamsmith 仍在位（这一轮跑在 team init 装过的项目里）
overlay_absent=ok（就绪与投递时刻都没有覆盖层）
ctr rc=0
```

---

## 3 · 安装行与文档

### 3.1 一行（共用实现）

```
$ cd <fresh repo> && team init --session p59line --agents dev --vcs local --gates true --docs docs/team   # rc=0
20:  提示：.pi/skills/ 是 pi 的项目资源，本项目第一次跑 pi 会问「是否信任此项目」——回答：pi --approve（只信这一次）｜pi 里 /trust（记住决定）｜team init --no-skills（跳过安装）
$ team init … --no-skills                                                                                # rc=0
17:  skip  …/.pi/skills（--no-skills：只做配置/文档，没装项目本地 skill）
（`提示：` 出现次数 = 0；`.pi/skills/` 目录不存在）
```

落点在 `team_init_install_skills` 的 `team_gitignore_add ".pi/skills/"` 之后、`return 0` 之前 ——
所以：`--no-skills` 在函数开头就返回（不打）、冲突/失败在更早的 `return 1`（不打）、
`init` 与 `bootstrap`（含已存在配置的升级路径，`cmd-bootstrap.sh:246`）打的是同一个函数。

### 3.2 install-shape（四条 + 两侧翻转）

```
  ✓ P59 装完一行信任提示（触发资源 + 三条出路）：信任提示行打了一次：[提示：.pi/skills/ 是 pi 的项目资源，本项目…]
  ✓ P59 重跑（skip）仍然打那一行：信任提示行打了一次：[提示：.pi/skills/ 是 pi 的项目资源，本项目…]
  ✓ P59 --no-skills 不打信任提示行：--no-skills 安静（没打信任提示行）
  ✓ bootstrap 对已存在的项目跑同一实现：已存在配置也装了 skill，config.sh 未动，信任提示行也在
```

`chk_trust_hint` 还要求那一行**恰好一次**（`grep -cF 'pi --approve'` = 1）且同一行同时含
`.pi/skills/`、`pi --approve`、`/trust`、`team init --no-skills`。

### 3.3 文档

`grep -c` 三个标记（`.pi/skills/` / `pi --approve` / `/trust`）：`teamsmith-init/SKILL.md` = 4/1/1；
`teamsmith-init/references/bootstrap.md` = 2/1/1。两处都写了触发资源与三条出路。

---

## 4 · 翻转证据（红 → 绿 / 破坏 → 必须红）

### 4.1 覆盖层判据关掉 → 同一份真帧退回老判定

见 §1.2：`M24_OVERLAY_DETECT=0` → `idle-read=NOT-EMPTY`、rc=1（红）；去掉这个 env → `overlay=trust-prompt`、rc=0（绿）。
FAST 段 `12b-h0c` 常驻钉住两侧；把 `M24_OVERLAY_DETECT=0` 注入绿侧那条调用（scratch 副本）会让它变红 ——
这正是本 change 要防的「静默退化」。

### 4.2 夹具对着弹窗跑投递 → 红（且一个键都不敲）

见 §2.3：`M24_TRUST=prompt`（不带 `--expect-overlay`）→ rc=1、`overlay=trust-prompt`、最后一帧、
**没有**任何投递步骤（`deliver_text_lines=` / `RETRACT=` 计数为 0）；同一现场加 `--expect-overlay` → §2.2 rc=0。
旧夹具（改前的 `grep -qE '^(─)+$'` 等待 + EMPTY-only 判定）在这种现场会打印 `M45 idle-read=NOT-EMPTY BAD`
并继续跑投递 —— 这是 P54 的 F2、§31b2 在 main 上的红；本单的判据把这条链切断在打字之前。

### 4.3 安装行：删掉 → 红；在 `--no-skills` 下出现 → 红

install-shape 的 flip 段（scratch 树，真实树不动）：

```
  ✓ ⑦a 对照：真实树装完打信任提示行：信任提示行打了一次：[提示：.pi/skills/ 是 pi 的项目资源，本项目…]
  ✓ ⑦a 翻转：去掉安装步的信任提示行：翻转后红（输出里没有信任提示行（要一行点名 .pi/skills/ + pi --approve + /trust + team init --no-skills））
  ✓ ⑦b 对照：真实树 --no-skills 安静：--no-skills 安静（没打信任提示行）
  ✓ ⑦b 翻转：提示行也打进 --no-skills 分支：翻转后红（--no-skills 下打了信任提示行）
  ✓ ⑥ 夹具没碰真实树（git status 指纹不变）
```

### 4.4 还原后干净

报告与任务书勾选提交前，整棵树只有这两个文件（没有夹带任何临时物）；提交后 `git status --porcelain` 为空
（`openspec validate` 也不报未完成的任务项）：

```
$ git status --porcelain
 M openspec/changes/trust-prompt-and-fixtures/tasks.md
?? docs/team/reports/P59-dev-bob.md
$ git status --porcelain          # 提交后（空）
```

---

## 5 · 门禁（验收三条）

### 5.1 FAST

```
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
== 结果 ==  ✓ 2365  ✗ 0
FAST 模式：跳过 30 个真进程段落（… | 31b·容器 tmux 自检（podman） | …）——完整门禁请不带 TEAM_SMOKE_FAST 重跑
smoke 全绿
（其中 39：✓ install-shape.sh 全绿（97 条断言，含翻转绿/红两侧））
```

### 5.2 全量门禁

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh </dev/null
Totals: 23 passed, 0 failed (23 items)      # 含 change/trust-prompt-and-fixtures、spec/verification、spec/init-skill
  ✓ M28 容器自检：容器内裸 tmux 开窗/杀 server 正常，宿主 server 指纹逐字节不变
  ✓ M28 容器里跑真 pi 体检：输入框判据 + 收回在真实现场成立
  ✓ M28 容器里跑真 pi 体检：空闲空框被判 EMPTY（没被误判成忙）
== 结果 ==  ✓ 2896  ✗ 0
smoke 全绿
```

§31b2 的调用与断言形状**未改**（它照旧跑 `container-tmux.sh --with-pi --cmd "bash …/pm-box-real.sh --idle-secs 3"`
并 grep `RETRACT=ok` / `verdict=EMPTY`）；它在本单的代码上通过。

### 5.3 真现场（宿主）

任务书第三条验收命令原样跑（默认 `--idle-secs 8`，无额外 env）：

```
$ bash skills/teamsmith/tests/pm-box-real.sh ; echo "ACCEPTANCE_RC=$?"
M24 真实 pi 窗格体检 · pi=<home>/.bun/bin/pi · 私有 socket=/tmp/teamsmith-pmbox.…/tmux · idle=8s · trust=approve
· 就绪：判定定位到输入框且为空（连续两次静默读同一帧），空闲 8s（复现「PM 空闲」形状）…
  M45 idle-read=EMPTY ok
  deliver_text_lines=3 bracketed=yes
  RETRACT=ok
✓ 隔离自检：夹具 session 不在真实默认 server 上
✓ trust store 未变（$HOME/.pi/agent/trust.json：sha256=228edb30… mtime=1789370262）
✓ .pi/skills/teamsmith 仍在位（这一轮跑在 team init 装过的项目里）
overlay_absent=ok（就绪与投递时刻都没有覆盖层）
ACCEPTANCE_RC=0
```

`--expect-overlay` / 红侧见 §2.2 / §2.3；容器见 §2.4。

---

## 6 · 决策与偏差

1. **覆盖层优先于框判定**（而不是「框里没有覆盖层标记才算覆盖层」）：requirement 明确点名的两种误判
   （找不到框 / 光标落进弹窗）都要消失，任何「先信框」的顺序都会在第二种形状上退回 `NOT-EMPTY`。
   代价是「草稿里恰好抄了三行弹窗文案」会被当成覆盖层 —— 方向是保守的（点名 + 不敲键 + 非零退出），
   且设计 §5 的 Residual 2 已记录「Pi 改文案 → 判据不命中但等待仍不放行、失败可见」。
2. **`--frame/--cursor` 是同一份共享判据**（`tests/lib/box-judge.sh`），框几何继续来自生产的
   `outbox.sh` 纯函数（`_team_box_rows_of_frame`）—— 纯帧与真 pane 不会分叉；没往 `outbox.sh` 里加东西。
3. **没有动 `protocol.md`**：`grant:` 写的是「若需一句」，但 protocol 讲的是团队协议与投递通道，
   不描述夹具的框判据；本 change 的残余（守卫的 `UNKNOWN → 照旧投递` 可以往 modal 里打字）已由 design §5
   Residual 1 记录，属于 `delivery-guard` 的范围，不在这里扩。
4. **冲突/失败不打那行**：spec 的措辞是「这一步结束时 skills 在位（本次装好或报 skip）」；冲突时 rc=1、
   用户正在读冲突与三条出路，再叠一行信任提示是噪音。任务书的四个案例（fresh / skip / bootstrap / `--no-skills`）
   全部覆盖，退出码在所有分支未改。
5. **多加了三条现场自证**（超出任务书字面，但都直接支撑 requirement 的句子）：夹具断言
   `.pi/skills/teamsmith` 仍在位、`overlay_absent=ok`（就绪与投递时刻都没有覆盖层）、
   trust store 前后指纹一致（容器里 `absent` → 仍 `absent`）。
6. **`M24_TRUST=prompt` 这个旋钮**是新加的（任务书只点了 `--expect-overlay`）：它让「同一现场的红侧」
   可复现（§4.2），而不需要手工去敲弹窗或去改 Pi 的配置。

---

## 7 · 建议下一步（给 PM）

- 请另一个席位做 `opsx-verify`（独立复验）：重点看 ①就绪门的两拍静默与「覆盖层早停」是否真的在
  `team_box_frame_verdict` 的返回码上（不是 grep）；②`--no-skills`/冲突两条路不发提示行；
  ③§31b2 在独立容器里重跑仍绿（本报告 §2.4 是同一台宿主上的直跑）。
- 归档前请顺手确认 `openspec/changes/trust-prompt-and-fixtures/tasks.md` 的勾选与本报告一致（本单只勾了
  有证据的条目）。
