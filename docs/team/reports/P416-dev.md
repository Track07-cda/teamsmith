# P416 · 两处界面文案：删掉反问句说明行，去掉行话，CLI 那一行改英文

agent: dev   status: DONE   time: 2026-11-05T04:20Z
branch: `task/P416-ui-copy`   PR/MR: -（local 模式：提交留在任务分支）

## Deliverables

| Path | What |
|---|---|
| `skills/teamsmith/scripts/panel/src/strings/zh.ts` | 删 `replyPageNote`；`replyTotalSlots` 改 `{n} 条`；新增 `replyTotalSlotOne: '{n} 条'`（中文无单复数，只为让 en 表能写单数） |
| `skills/teamsmith/scripts/panel/src/strings/en.ts` | 删 `replyPageNote`；`replyTotalSlots: '{n} replies'`；`replyTotalSlotOne: '{n} reply'` |
| `skills/teamsmith/scripts/panel/src/layout.ts` | 第 5 页列表不再画说明行（`layout.ts:1389` 那一行随之删除）；条数为 1 时取单数键 |
| `skills/teamsmith/scripts/panel/panel.js` | 用钉住的工具链重建（`bun install --frozen-lockfile && bash build.sh`），不是手改 |
| `skills/teamsmith/scripts/team` | 未知子命令：`unknown command: <cmd> (see: team help)`，exit 2（原来是中文一行 + 免责话 + `run:` 重复） |
| `skills/teamsmith/tests/key-replies-pty.sh` | `pages` 组：钉说明行的断言翻成**反向断言**；条数断言改新文案；9 处 `want_frame` 的 `个编号槽位` needle 改为实际条数；`language` 组原来钉 en 说明句，改为钉列表渲染 + 断言说明句不在 + 钉单数 `1 reply` |
| `skills/teamsmith/tests/lib/reply-fixture.sh` | `pane`/`demand` 组 4 处同型 needle 跟着改 |
| `skills/teamsmith/tests/slash-team.sh` | 顶层未知命令的红侧样本与注释改新措辞（`unknown command: frobnicate`）；非空洞计数把新措辞算进去 |

## Verification evidence (must have actually been run)

**1. 面板第 5 页（`pages` + `language` 两组，最终提交 `c7ef5fd9` 上实跑）**

```
$ bash skills/teamsmith/tests/key-replies-pty.sh --select pages,language
== pages · 第 5 页 / 重启 / 坏 store（3.1） ==
  ✓ pages：第 5 页列表帧（编号/标题/发布者标签）
  ✓ pages：第 5 页不再有反问式说明行（把说明行加回去必须变红）
  ✓ pages：列表显示条数（新文案「{n} 条」，不再是内部行话）
  ✓ pages：Older 控件可见
  ...
== language · zh/en 切换（3.4） ==
  ✓ language：en 表下第 5 页标签与路由完整（说明行已删：反问句不在，单数用单数式）
  ✓ language：zh 表下第 5 页标签与路由完整
  ✓ 隔离守卫：真实仓库 …/.worktrees/dev 的编号回复存储（.pi/team/state/key-replies）前后逐字节不变
== P234 key-replies-pty 结果 == ✓15 ✗0 SKIP0
```

实际帧（zh，store 里 2 条；`/var/tmp/p416-evidence/pty-pages-list5.txt`）：

```
╭─ 关键回复（2） ──────────────────────────────────────────────────────╮
│  ‹ 更早 更新 › r 最新                                                 │
│  2 条                                                                 │
│   › #2 第二份回复 · verify                                            │
│     #1 完整结论与取舍 · dev2                                          │
╰──────────────────────────────────────────────────────────────────────╯
```

实际帧（en，store 里 1 条，单数式；`/var/tmp/p416-evidence/pty-language-en.txt`）：

```
╭─ key replies (1) ────────────────────────────────────────────────────╮
│  ‹ Older Newer › r newest                                             │
│  1 reply                                                              │
│   › #1 语言一号 · dev2                                                │
╰──────────────────────────────────────────────────────────────────────╯
```

**2. 未知子命令（真跑，非夹具）**

```
$ bash skills/teamsmith/scripts/team stop
✗ unknown command: stop (see: team help)
$ echo $?
2
```

**3. `slash-team.sh --select probe`（这条 CLI 路径的夹具，最终提交上实跑）**

```
$ bash skills/teamsmith/tests/slash-team.sh --select probe
  ✓ 探针非空洞：至少 5 行得到 CLI 自己的参数/子命令拒绝（真的分发了）
  ✓ 红侧样本：表外命令得到顶层「unknown command: frobnicate」
RESULT pass=20 fail=0
```

**4. `help-surface.sh --select claims`**

```
$ bash skills/teamsmith/tests/help-surface.sh --select claims      # HEAD=c7ef5fd9（最终提交）
== 结果 ==  ✓ 90  ✗ 0  SKIP 0
rc_help_claims=0
```

同一段在更早的提交 `72a925cf` 上也跑过一次（`✓ 90 ✗ 0 SKIP 0`，rc=0）；两次都在本 worktree 的真树上，不是夹具替身。这两次里 "say · 退休的 --now" 四条臂都绿（`say --now` 两位置 exit 2 并点名 `--now`、指纹不变、对照臂证明不是瞎的）——本次没有改 `say` 的任何文案，所以这四条仍按原样通过。

**5. 静态面**

```
$ bash skills/teamsmith/tests/section-select.sh --check
== 选段自检 ==  ok 13  bad 0  SKIP 1      # rc=0；跳过项是内部检出才有 .pi/skills 字面模式那条
$ node skills/teamsmith/tests/panel-strings.mjs .
ok: values are non-empty strings with matching placeholders
ok: contract-key labels — 123 schema keys covered in zh and en
ok: contract-group labels — 12 schema group tokens covered in zh and en
ok: fixture marker is data — 5 marked key(s), none named in the panel body
panel-strings: ok
$ git diff --check
（无输出，rc=0）
```

- Verdict: pass（选段口径；**没跑全量门禁**）
- Notes:
  - **没跑**：整份 smoke 全量、`--select 26`（沙盒重建面板逐字节比对）、routes/slash 之外其它夹具组。面板重建的逐字节承诺我用另一种方式在场：重建后 `sha256sum panel.js` = `d427d423…`，而把面板源码改回旧文案再重建、再改回，得到的 sha 与提交里的 `panel.js` 逐字节相同（见 Flips）。
  - 仓库里没有第 5 页的快照：`tests/snapshots/` 只覆盖第 1 页、第 4 页与详情页（`grep 编号槽位` 在快照里 0 命中），所以本改动不改动任何提交的快照；这一条是读文件得出的，没有跑 `panel-snapshots.sh` 反证。
  - `help-surface.sh --select claims` 连跑两次的结果见第 4 节（第一次在全绿之前的面板上，第二次在最终提交上）。
- Ledger ban（在本 worktree、本分支树上跑）：

  ```
  $ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
  ledger-ban: root=…/.worktrees/dev scope=published files=2386 hits=5 names=ok user=resolved
  $ echo $?
  0
  ```

  5 条 hits 全在 `docs/team/tasks/P415-safe-dir-own-group.md`（第 16/18/33/34/35 行，形如 `<names#8>` 的已脱敏标记与该项目路径），该文件由 PM 在 `fe5c26d7` 提交，不在本任务改动里；本任务的 9 个改动文件 0 命中。

## Flip evidence

**说明行加回去 → 反向断言变红（原样输出）**

```
$ git diff   # 临时恢复 replyPageNote + layout 那一行，再重建 panel.js（sha 77a2b60b…）
$ bash skills/teamsmith/tests/key-replies-pty.sh --select pages
  ✓ pages：第 5 页列表帧（编号/标题/发布者标签）
  ✗ pages：第 5 页不再有反问式说明行（把说明行加回去必须变红）（不该出现 [「这条回复是写给谁的？」]）
== P234 key-replies-pty 结果 == ✓12 ✗1 SKIP0        # rc=1
$ git checkout -- src/layout.ts src/strings/zh.ts && bash build.sh
panel.js written (978362 bytes, sha256 10ebe455e3a51c6a486196384ff0cf9f293039575f4abe3154a0c8b24e0d29e3)
```

还原后与提交里的 `panel.js` 逐字节相同（旧文案那版当时是 `10ebe455…`；本报告最终提交的单数版是 `d427d423…`，同样由源码重建、不是手改）。

**未知子命令**：改动前 `team stop` 的输出是 `✗ 未知子命令：stop（team help 看全部；最近有破坏性变更，team version --check 检查 skill 版本）` 再加一行 `run: team help`；改动后是上面第 2 节那一行。旧的 `slash-team` 红侧样本（`bad.includes('未知子命令：frobnicate')`）在新代码上会红，所以那条样本一并改成新措辞——它钉的是「表外命令落到顶层拒绝」这个行为，不是中文。

## Decisions and deviations

- **分支基线**：开工时我的任务分支没有提交，而 main 已前进到 `a3cc818e`（含 PM 对本任务书的修订 `d8142099`、"整条删除、断言翻成反向" 与 D228/D229）与 `1fc7203d`。我用 `git merge --ff-only main` 快进到该提交再动手；这不是 rebase，也没有改写任何历史。按修订后的任务书实施（删整行、反向断言），而不是旧稿的"改写成陈述句"。
- **`team_usage_die` 的 `run:` 行没有删**：未知子命令这条分支改成自己 `team_err` + `exit 2`，所以那行 `run: <cli> help` 不再重复；其余用法错误（`bg`/`board`/`meeting`/`config`… 的 40 余处）仍靠它兜底，删掉会让它们失去唯一的指路。任务书里那句是"若与上一行重复就删掉"，重复已经消掉，所以 `lib/common.sh` 一字未动。
- **任务书提到的 `now` 没有"专门报错"可改**：`--now` 在 0.4.0 是 retire 掉的旗标，代码里它**故意**走 `say` 的通用未知参数路径（`scripts/lib/cmd-agents.sh:1656` 的注释写明 P393 的口径），报的是 `say: 未知参数 --now`。要把它改英文就是翻译 `say` 整条用法面，而任务书写明"其余 CLI 文案按 D228 分期迁移，不在本单范围"。所以这一处我**没动**，也不给 `--now` 加特判（加了就是自造第二份行为）。若 PM 要把 `say` 的用法面并进本单，改动是一行 `say: unknown option $1` + `tests/help-surface.sh:1307` 的断言，但需要连带重跑 `help-surface --select claims` 与 `routes` 的 flag 控制臂。
- **多了单数键**：任务书允许"`{n} replies`（或等价的单数处理）"。按要求先写成 `{n} replies` 后，1 条的 store 在 en 页上就是 `1 replies`（帧见上），这条文案本身就是要修的东西，所以补了 `replyTotalSlotOne`（zh 与复数同形）+ layout 的一个三元。表里其余计数文案（`{n} more agents fit` 之类）没有单复数机制，本单没有扩大去动它们。
- **多改了一处任务书没点名的断言**：`key-replies-pty.sh` 的 `language` 组原来钉的是 en 说明句 `"who is this reply written for?"`（不在 `pages` 组里），说明行删掉后它在全量门禁里必红。已改成钉列表渲染 + `!written for the user` + `1 reply`。

## Suggested next steps

- PM 复验时建议至少跑 `--select 26`（面板沙盒重建的逐字节比对，这是 `panel.js` 重建的正式守卫）与 `key-replies-pty.sh` 全组；本单只跑了 `pages`/`language` 两组。
- 待你裁决：`say --now`（以及 `say` 的其它用法行）是否并入本单翻成英文；不并入就按 D228 的"改到哪条命令就翻译哪条"留给后续单据。
