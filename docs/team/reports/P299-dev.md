# P299 · `init` 信任提示两处新契约的 falsifier（`slash-team` 3.3）

agent: dev   status: delivered   time: 2026-10-16
branch: `task/P299-init-trust-falsifier`   PR/MR: -（local 模式：分支留本地，PM 复验后本地合并）

## 结论（先给答案）

3.3 缺的那半条契约现在有 falsifier 了，**产品代码与两处文档一个字都没改**——本轮只加断言与红侧：

- `team init` 的信任提示行在夹具里必须**同一行**同时点名 `.pi/skills/` 与 `.pi/extensions/`（缺哪个要点就
  点名哪个要点、并把行原文打出来），并带三条出路 `pi --approve` / `/trust` / `team init --no-skills`；
  `--no-skills` 必须安静；`team bootstrap` 的升级路径被同一行判据钉住（P59 起它只查过 `pi --approve` 在场）。
- 两处 init 文档（`skills/teamsmith-init/SKILL.md` 的安装节与 `references/bootstrap.md` 的项目技能行）用
  **稳定 token**（`.pi/skills/`、`.pi/extensions/`、`pi --approve`、`/trust`、`team init --no-skills`）同页走查，
  不是整句比对。
- 五条红侧证明这些断言承重：**只**删输出行里的 `.pi/extensions/` 必红并点名该行、`--no-skills` 打印该行必红、
  删掉 SKILL.md 的 `.pi/extensions/` token 必红、删掉 bootstrap.md 的 `/trust` token 必红、整行删掉（原有 ⑦a）必红。
- 缺口本身可复现：把同一处变异（输出行删掉 `.pi/extensions/`）打在 main 版夹具上，`install` 段**全绿**（✓47 ✗0）——
  变异存活；打在本轮的夹具上 **rc=1、3 条红**，逐条点名那一行。

## Deliverables

| Path | What |
|---|---|
| `skills/teamsmith/tests/install-shape.sh` | `chk_trust_hint` 加 `.pi/extensions/` 与逐要点点名；新增 `chk_init_docs_fact`（两文档五个稳定 token 同页走查）；`chk_bootstrap_installs` 改用同一行判据；flip 段新增 ⑦c（只删 `.pi/extensions/`）、⑨a（SKILL.md 删 token）、⑨b（bootstrap.md 删 token），并把 ⑦b 的注入行改成带两处资源的完整形状 |

其它没动的面（有意）：`scripts/lib/cmd-init.sh` 的输出行语义（三答案、一行、`--no-skills` 安静）不变；
两处文档不改（它们已经带上五个 token，红侧用 scratch 副本证明「缺了就红」）；既有断言没有放宽。

## Verification evidence

### 1. 闭包选段（D-口径）

```bash
$ bash skills/teamsmith/tests/section-select.sh --paths skills/teamsmith/tests/install-shape.sh docs/team/reports/P299-dev.md
decision=RUN
sections=133
keys=7
reason=0 ← prologue
reason=0b ← prologue
reason=0c ← prologue
reason=0d ← prologue
reason=12b-h0d ← skills/teamsmith/tests/install-shape.sh
reason=39 ← skills/teamsmith/tests/install-shape.sh
reason=40 ← skills/teamsmith/tests/install-shape.sh
reason=60 ← docs/team/reports/P299-dev.md
0	prologue
0b	prologue
0c	prologue
0d	prologue
12b-h0d	skills/teamsmith/tests/install-shape.sh
39	skills/teamsmith/tests/install-shape.sh
40	skills/teamsmith/tests/install-shape.sh
60	docs/team/reports/P299-dev.md
```

（`--paths` 里的报告路径就是最终 diff 的那条：分支相对 main 只多出 `skills/teamsmith/tests/install-shape.sh`
与这份报告，前者归 39/40/12b-h0d，后者归账本面 60。）

```bash
$ bash skills/teamsmith/tests/smoke.sh --select 0,0b,0c,0d,12b-h0d,39,40,60
== 选段 == decision=RUN · 运行 8/133 段 · 未跑 125 段
  （先在机器锁上排过队：另一套全量 smoke（dev3 的 worktree）正在跑；轮到本套后开跑）
#1  0 · 临时仓库                   · 用时 0s   · ✓3  ✗0 SKIP0
#2  0b · skill 可被 pi 解析器加载     · 用时 0s   · ✓2  ✗0 SKIP0
#3  0c · 静态检查（set -e 陷阱）      · 用时 0s   · ✓7  ✗0 SKIP0
#4  0d · 冲突标记守卫               · 用时 1s   · ✓9  ✗0 SKIP0
#5  12b-h0d · P80 下边框判据        · 用时 11s  · ✓83 ✗0 SKIP0
#6  39 · npm CLI 与项目 skill 安装   · 用时 152s · ✓1  ✗0 SKIP0
      ✓ 39 install-shape.sh 全绿（143 条断言，含翻转绿/红两侧）
      == 结果 ==  ✓ 142  ✗ 0  SKIP 0
#7  40 · 临时根纪律                 · 用时 46s  · ✓21 ✗0 SKIP0
#8  60 · 账本禁令                   · 用时 9s   · ✓18 ✗0 SKIP1
账本自查： 8 段收口 · 增量 ✓144 ✗0 SKIP1 ｜ 结果行 ✓144 ✗0 —— 一致
== 选段结果 ==  ✓ 144  ✗ 0            # SMOKE_RC=0
```

没跑的段：剩下的 125 个键（`0e…65` 全表逐键列在门禁输出尾部的「这次没跑的段」里）；选段运行不是全套门禁。

（`/tmp` 下 `teamsmith-*` 根数：本轮开工前 102、门禁运行前 98、门禁运行后 93——门禁自己收走了本轮根与队列期
间留下的根，没有泄漏；40 段的泄漏断言也在本轮内绿。）

段 60 的 1 条 SKIP 是**具名可见**的：`P212 他项目名形状（真实账本） —— SKIP names —— 禁令名单未配置`
（段内找的是 `<worktree>/.pi/team/forbidden-names.txt`，而名单按设计只放在主检出侧）。这一项不是通过；带名单的
那次真实扫描见下面第 3 节的固定验收行（`names=ok hits=0`）。

### 2. 翻转证据（本轮新断言承重）

E1 对照（**缺口**，main 的夹具 = 没有新断言，打在同一处变异上）：

```bash
$ tree=/tmp/p299-control   # git archive main 展开后，把 cmd-init.sh 输出行的 .pi/extensions/ 删掉
$ bash "$tree/skills/teamsmith/tests/install-shape.sh" install
  ✓ P59 装完一行信任提示（触发资源 + 三条出路）：信任提示行打了一次：[提示：.pi/skills/ 与  是 pi 的项目资源，本…
  ✓ P59 重跑（skip）仍然打那一行：信任提示行打了一次：[提示：.pi/skills/ 与  是 pi 的项目资源，本…
...
== 结果 ==  ✓ 47  ✗ 0  SKIP 0     # rc=0：变异存活
```

E2 翻转（本轮的夹具打在同一处变异上）：

```bash
$ TEAM_INSTALL_TREE=/tmp/p299-control bash $PWD/skills/teamsmith/tests/install-shape.sh install
  ✗ P59 装完一行信任提示（触发资源 + 三条出路）：提示行缺要点： [.pi/extensions/] —— 行原文：[  提示：.pi/skills/ 与  是 pi 的项目资源…回答：pi --approve（只信这一次）｜pi 里 /trust（记住决定）｜team init --no-skills（跳过安装）]
  ✗ P59 重跑（skip）仍然打那一行：提示行缺要点： [.pi/extensions/] —— 行原文：[…同上…]
  ✗ bootstrap 对已存在的项目跑同一实现：bootstrap 升级路径的信任提示行不达标：[…同上…]
== 结果 ==  ✓ 44  ✗ 3  SKIP 0     # rc=1
```

夹具内置的红侧（`flip` 段；真实树不动，并在段尾比对 `git status` 指纹）：

```bash
$ bash skills/teamsmith/tests/install-shape.sh surfaces install flip
  ✓ ⑦c 翻转：信任行删掉 .pi/extensions/：翻转后红（提示行缺要点： [.pi/extensions/] —— 行原文：[…]）
  ✓ ⑨a 翻转：SKILL.md 删掉 .pi/extensions/ token：翻转后红（init 文档没同页点名触发资源/答案： skills/teamsmith-init/SKILL.md[.pi/extensions/]）
  ✓ ⑨b 翻转：bootstrap.md 删掉 /trust token：翻转后红（init 文档没同页点名触发资源/答案： skills/teamsmith-init/references/bootstrap.md[/trust]）
  ✓ ⑦a 翻转：去掉安装步的信任提示行：翻转后红（输出里没有信任提示行…）
  ✓ ⑦b 翻转：提示行也打进 --no-skills 分支：翻转后红（--no-skills 下打了信任提示行）
  ✓ ⑥ 夹具没碰真实树（git status 指纹不变）
== 结果 ==  ✓ 85  ✗ 0  SKIP 0     # rc=0（对照侧全绿）
```

改动前的同一条夹具全量基线（产品未改，夹具未改）：`== 结果 ==  ✓ 136  ✗ 0  SKIP 0`。

### 3. 其它固定验收行

```bash
$ "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
✓ spec/agent-adapters … ✓ change/slash-team … ✓ spec/writing-discipline
Totals: 22 passed, 0 failed (22 items)          # rc=0

$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: names：名单已配置（…/.pi/team/forbidden-names.txt，命中即红）
ledger-ban: root=/home/<user>/…/.worktrees/dev scope=published files=1680 hits=0 names=ok user=resolved
rc=0

$ git diff --check && git status --short
（无输出、rc=0：没有空白错误，报告提交后工作树干净）
```

- Verdict: pass（五条固定验收行全绿；门禁闭包写回 143 条断言含六条新绿侧与五条新/旧红侧）
- Notes: 本轮**没有**改产品实现与两处 init 文档（所以「同步两处文档」这条是核对既有内容 + 补 falsifier，
  不是重写文案）；本轮**没有**跑全量门禁——按任务书只跑闭包选段（125 个键没跑，见上）；运行用的是默认全量档
  （不设 `TEAM_SMOKE_FAST`），段 39 里的 npm 真跑因此也跑了。
- 段 39 用时 152s 越过它的 39s 实测带：这是**历史值**，不是本轮引入（同一份夹具在改动前单跑一次是 170s——它的
  面随 `npm pack` 等真跑段落长大；门禁把超带只记为「记录，不是判定」）。本轮的夹具改动只加断言，不新增真跑段落。

## Decisions and deviations

- **文档侧断言放在安装面夹具里**（任务书第 3 条说「既两个 init 文档里任选一处」）：实现取的是**两处都走查**
  （`chk_init_docs_fact` 逐文件五个 token），因为 `init-skill` 的场景 3 写的是「both are searched … a scratch copy
  with the note deleted fails the same search」；红侧也各给一条（⑨a SKILL.md、⑨b bootstrap.md）。这是**加严**，
  不是放宽既有断言。
- **`chk_bootstrap_installs` 从「`pi --approve` 在场」改成同一行判据**：规格场景 2 要求 init 与 bootstrap 两条
  调用点「one implementation and one wording」；这是同一条契约的另一个调用点，不是新契约。
- **文档 token 用了五个而不是四个**：`.pi/skills/`、`.pi/extensions/`（触发资源）与 `pi --approve`、`/trust`、
  `team init --no-skills`（三条答案）。场景 3 的搜索词列了前四个；第五个是同一个需求正文里点名的第三条出路，
  两处文档当前都带它，红侧也覆盖了其中一处（⑨b）。
- 没有为了绿改产品输出行、没有删/弱化任何既有断言、没有新开套件。

## Suggested next steps

- 3.3 的证据可以按本轮补齐（夹具 + 红侧都在 `install-shape.sh`），复验建议**换人**定点复检：重点看
  `chk_trust_hint` 的逐要点点名、`chk_init_docs_fact` 的两文档覆盖面，以及 ⑦c/⑨a/⑨b 三条新红侧是否真的在
  「只删一个 token」时红。
- `docs/team/tasks/P299-init-trust-falsifier.md` 是 PM 的文件，3.3 那一行的证据留空由 PM 填。
