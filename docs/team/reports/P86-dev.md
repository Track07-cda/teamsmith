# P86 · 修 F1：定位出的框必须包含光标行（下边框候选的准入条件）

agent: dev   status: DONE   time: 2026-09-22T22:22Z
branch: `task/P86-f1`（local 模式，**不 push**）   PR/MR: -（本仓库没有远端投递）
change: `bottom-border-candidate-selection`（apply 返工 · P84 的 F1）   phase: apply

## Deliverables

| Path | What |
|---|---|
| `skills/teamsmith/scripts/lib/outbox.sh` | 准入条件：候选配到的上边框必须严格在光标行之上（`_team_box_top_border_max_row` 是这项决策的唯一实现）；不满足 → 跳过、继续找更近的候选 |
| `skills/teamsmith/tests/frames/p86-f1-{mixed-width,spinner-top,narrower-width}-disjoint-box.txt` | P84 复验自造的 F1 帧 + 两个变体，逐字节相同（sha256 在门禁 §46 里钉住） |
| `skills/teamsmith/tests/frames/README.md` | 三份新帧的形状/光标行/现场 + P86 小节（准入规则、红侧影子、单调性口径、实测边界） |
| `skills/teamsmith/tests/smoke.sh` | 新增 §46（append-only）：三份 F1 帧的红/绿/最近优先三侧 + 全语料（16 帧）的框含光标/无 BUSY→EMPTY 断言 |
| `openspec/changes/bottom-border-candidate-selection/specs/delivery-guard/spec.md` | requirement 里那句被证伪的「框只会变大 / 不许 BUSY→EMPTY」换成准入条件 + 可机读的语料口径；新增两条场景 |
| `openspec/changes/bottom-border-candidate-selection/design.md` | D1 的单调性论证删掉（P84 实测为假），D3/D4/D5/D8/D9 同步 |
| `skills/teamsmith/references/troubleshooting.md` | §3 的判据描述改成含光标口径；镜像代价加上它仍成立的前提；「同类洞」清单补上实测边界 |
| `docs/team/reports/P86-dev/pkg/` | 自验包（`lib.sh` + `run.sh` + 4 个 section + `logs/`）：翻转、全语料、边界、零回归，纯函数、不开 tmux |
| `docs/team/reports/P86-dev.md` | 本报告 |

`skills/teamsmith/tests/lib/box-judge.sh` **未改**：它的帧级判定已经走共享的生产提取
（`_team_box_text_of_frame`），准入条件自动继承——§46 的「同源」断言在 F1 帧上钉住了这一点。

## Verification evidence (must have actually been run)

### 自验包（纯函数；不开 tmux、不写仓库）

**独立复验包**：`docs/team/reports/P86-dev/pkg/` 是一份自写的纯函数包（**不复用** smoke 的断言文本：它自己建影子、
自己对比两侧、自己解析结果行），入口 `docs/team/reports/P86-dev/pkg/run.sh`（可带编号只跑一部分，如 `run.sh 10 20`）。

```
$ bash docs/team/reports/P86-dev/pkg/run.sh
########## 10-flip.sh ##########
...
== 10-flip 结果 == ok=29 bad=0 finding=0
########## 20-corpus.sh ##########
...
== 20-corpus 结果 == ok=7 bad=0 finding=0
########## 30-residual.sh ##########
finding 边界帧上准入条件把修前的忙翻成 EMPTY（几何 5 7 → 1 3）：形状=草稿自己画的 rule 成为最近候选；
        已存 16 帧上不触达，是否收口由 PM 裁决
== 30-residual 结果 == ok=1 bad=0 finding=1
########## 40-existing.sh ##########
...
== 40-existing 结果 == ok=39 bad=0 finding=0
########## 汇总 ##########
sections=4  ok=76  bad=0  finding=1  →  PASS
```

`40-existing` 的 13 份旧帧逐字对比是**两个方向**的：修后 == 修前（真树，从 `454874ac` 取
`outbox.sh` 覆写）；修后 == 准入关掉（影子）。两者都逐字相同 → 准入条件对这 13 份不触达，零回归。

### 门禁（brief 第 6 项）

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
Totals: 30 passed, 0 failed (30 items)

$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
  ...（新增 §46 全绿；新增/既有断言逐条见 pkg/logs/fast.log）
== 结果 ==  ✓ 2619  ✗ 0
FAST 模式：跳过 33 个真进程段落（… 42·P67-真pane|44·P80-真pane）——完整门禁请不带 TEAM_SMOKE_FAST 重跑
smoke 全绿

$ bash skills/teamsmith/tests/guard-matrix.sh
== 结果 ==  ✓ 31  ✗ 0
guard matrix 全绿

$ bash skills/teamsmith/tests/smoke.sh </dev/null
<见下方「全量门禁」>
```

（`pkg/logs/` 里有完整日志：`flip-prefix.log`、`fast.log`、`guard-matrix.log`、`mutation-red.log`、`full-gate.log`。）

### 交付前实测的红侧（修前树）

```
$ # /tmp/p86/old = HEAD 454874ac 的 skills/teamsmith 副本；探针与 P84 复验用的同一份
$ bash /tmp/p86/probe.sh /tmp/p86/old/skills/teamsmith <frame> 2
--- f1-mixed-width-disjoint-box            --- f1-spinner-top-disjoint-box          --- f1-narrower-width-disjoint-box
geometry=[5 7]                              geometry=[5 7]                          geometry=[5 7]
box_nows=[]                                 box_nows=[]                             box_nows=[]
verdict=idle-read=EMPTY rc=0                verdict=idle-read=EMPTY rc=0            verdict=idle-read=EMPTY rc=0
```

完整对照（四列：修前 / 修后 / 最近优先影子 / 准入关掉影子）见 `pkg/logs/flip-prefix.log`；三份帧上
「准入关掉影子」与真·修前树**逐字相同**（`cmp` 级别的一致，10-flip 小节逐帧断言）。

## Flip evidence (required for defect-fix tasks)

两侧逐字对照如下（上为失败侧、下为通过侧）：

**Red before**（HEAD `454874ac`，本 change 的 apply 版本；失败侧）：

```
$ # 红侧：修前实现，三份 F1 帧（P84 自造、逐字节存进 tests/frames/）
$ bash /tmp/p86/probe.sh /tmp/p86/old/skills/teamsmith /tmp/p86/frames/f1-mixed-width-disjoint-box.txt 2
geometry=[5 7]          ← 框整个落在光标下方、与光标框 [1 3] 不相交
box_nows=[]             ← 框读空
verdict=idle-read=EMPTY rc=0   ← 就绪门放行（payload 会打进人的草稿 = P84 的 F1）
（f1-spinner-top-… 与 f1-narrower-width-… 两份逐字相同）
```

**Green after**（本分支 tip；通过侧）：

```
$ # 绿侧：同一份帧、同一份探针，修后的树
$ bash /tmp/p86/probe.sh "$PWD/skills/teamsmith" /tmp/p86/frames/f1-mixed-width-disjoint-box.txt 2
geometry=[1 3]          ← 回落到最近的合格候选（框含光标行）
box_nows=[HUMANDRAFTLINE]      ← 光标行的草稿留在框内
verdict=idle-read=NOT-EMPTY rc=1   ← 判忙、投递等待
```

**破坏实现 → 守卫必须失败 → 还原**（第二形式的翻转证据；对判据本身做的变异测试）：

```
$ sed -i 's/-v maxrow="\$maxrow"/-v maxrow="999999"/' skills/teamsmith/scripts/lib/outbox.sh   # 拆掉准入上界
$ bash docs/team/reports/P86-dev/pkg/run.sh 10 20
bad p86-f1-mixed-width-disjoint-box.txt 修后几何 = [1 3]（含光标）（期望 [1 3]，实际 [5 7]）
bad p86-f1-mixed-width-disjoint-box.txt 修后框里有光标行的草稿（[geometry=[5 7]
bad p86-f1-mixed-width-disjoint-box.txt 修后判定 = 忙（就绪门不放行）（期望 [idle-read=NOT-EMPTY]，实际 [idle-read=EMPTY]）
bad p86-f1-spinner-top-disjoint-box.txt 修后几何 = [1 3]（含光标）（期望 [1 3]，实际 [5 7]）
bad p86-f1-spinner-top-disjoint-box.txt 修后框里有光标行的草稿（[geometry=[5 7]
bad p86-f1-spinner-top-disjoint-box.txt 修后判定 = 忙（就绪门不放行）（期望 [idle-read=NOT-EMPTY]，实际 [idle-read=EMPTY]）
bad p86-f1-narrower-width-disjoint-box.txt 修后几何 = [1 3]（含光标）（期望 [1 3]，实际 [5 7]）
bad p86-f1-narrower-width-disjoint-box.txt 修后框里有光标行的草稿（[geometry=[5 7]
bad p86-f1-narrower-width-disjoint-box.txt 修后判定 = 忙（就绪门不放行）（期望 [idle-read=NOT-EMPTY]，实际 [idle-read=EMPTY]）
== 10-flip 结果 == ok=20 bad=9 finding=0
bad ① 定位出的框总是包含光标行（top < cy < bottom，全部帧）（期望 [none]，实际 [ p86-f1-mixed-width-disjoint-box.txt([5 7] cy=2) p86-f1-narrower-width-disjoint-box.txt([5 7] cy=2) p86-f1-spinner-top-disjoint-box.txt([5 7] cy=2)]）
bad ② 全部帧：修后翻成忙的恰好是三份 F1 帧（期望 [p86-f1-mixed-width-disjoint-box.txt p86-f1-narrower-width-disjoint-box.txt p86-f1-spinner-top-disjoint-box.txt ]，实际 [ ]）
bad ③ 全部帧：相对最近的旧顺序也没有 BUSY→EMPTY（期望 [none]，实际 [ p86-f1-mixed-width-disjoint-box.txt p86-f1-narrower-width-disjoint-box.txt p86-f1-spinner-top-disjoint-box.txt]）
== 20-corpus 结果 == ok=4 bad=3 finding=0
sections=2  ok=24  bad=12  finding=0  →  FAIL

$ bash <门禁 §46 的同一段断言，单独跑>
  ✗ P86 绿侧 p86-f1-mixed-width-disjoint-box.txt：……回落最近的合格候选 [1 3]（不是 [5 7]）
  ✗ P86 绿侧 …：光标行的草稿留在框内（框含光标）
  ✗ P86 绿侧 …：判忙 —— 就绪门不再放行（P84 的 F1 修掉）
  ✗ P86 同源：pm-box-real.sh --frame 在 F1 帧上也判忙（rc=1）（期望 [1]，实际 [0]）
  ✗ P86 ① 定位出的框总是包含光标行（top < cy < bottom，全部帧）
  ✗ P86 ② 全部帧：修后翻成忙的恰好是三份 F1 帧（修复的效果，不多不少）
  ✗ P86 ③ 全部帧：相对最近的旧顺序也没有 BUSY→EMPTY
== 结果 == ✓ 27 ✗ 15
（§46 的 15 条红：三份帧 × 3 绿侧断言 + 3 条同源 + 3 条语料断言；逐字见 pkg/logs/mutation-red.log）

$ git checkout -- skills/teamsmith/scripts/lib/outbox.sh   # 还原
$ git status --porcelain skills/teamsmith/scripts/lib/outbox.sh   # 空（= 已还原）
$ bash docs/team/reports/P86-dev/pkg/run.sh
sections=4  ok=76  bad=0  finding=1  →  PASS
```

（变异运行的原文见 `pkg/logs/mutation-red.log`；逐字还原后 `pkg/run.sh` 回到 76/0/1 PASS。）

## Decisions and deviations

- **准入决策做成了可影子覆盖的第二个决策点**（`_team_box_top_border_max_row`，与 P80 的
  `_team_box_bottom_candidate_order` 同一模式）。理由：brief 第 2 项要求「旧/新逐帧对比」是**可机读的断言**
  ——没有这个接缝，门禁里就跑不了「修前」那一侧（只能钉一份静态记录）。生产里没有开关，函数体是固定的；
  测试进程把它影子成极大行号即可逐字复现修前行为（三份 F1 帧 + 13 份旧帧上都验证过）。
- **requirement 里那句假话按 brief 第 3 项处死**：没有保留「框只会变大」，也没有换成另一句更强的承诺——
  写的是「定位出的框一律含光标」这个**真的**性质，加上门禁要跑的语料口径（含光标 + 两侧无 BUSY→EMPTY）。
- **发现并如实记录了准入条件自己的边界**（findings，不是失败）：当光标下方那对规则行全都配不到光标以上的
  规则行时，它们会被跳过，而更近的候选仍可能是草稿自己画的 rule → 那一帧读空（修前读忙）。实测形状
  `rule(A) / 空行(光标) / rule(A) / 空行 / rule(B) / 文本 / rule(B) / footer`（A≠B），只出现在混宽度
  （裁切型 TUI）帧上，**已存 16 帧语料里没有它**（所以门禁的「无 BUSY→EMPTY」断言绿）。写进 design §8 的
  风险表、`troubleshooting.md` §3 的「仍开着的洞」清单，并在此点名：**是否收口由 PM 裁决**（本 brief 钉的是
  「跳过 → 继续找更近的候选」，我按 brief 实现，没有自作主张改成 NONE）。
- **改了 `openspec/changes/**`**：brief 第 3 项明确要求改 requirement/design，`grant:` 行没逐字列出这个目录，
  但任务书头部 `deltas: delivery-guard` + OWNERSHIP「`openspec/changes/<change>/**` 归该 change 当前阶段的
  owner（任务书明授）」覆盖了它（delta 文件就是这条 requirement 的载体）。**如果 PM 认为越界，这两处
  可以原样回退**（`62274a6b`）。
- **帧名带 `p86-` 前缀**（`p86-f1-mixed-width-disjoint-box.txt` …）：与语料现状（`p78-*`、`pi-*`）一致；
  brief/review 里的名字 `f1-mixed-width-disjoint-box.txt` 作为子串仍可检索到。
- **没有改 `box-judge.sh`**（brief 的 grant 列了它，但没必要）：它走的是共享判据，准入条件自动继承。
- **没有把边界帧提交进 `tests/frames/`**：提交它会让 brief 第 2 项要求的全语料单调性断言变红，也会改变
  brief 钉死的帧集合（4 份新帧 ≠ 3 份）。它只存在于自验包的工作目录（30-residual 小节会生成并断言它
  不在仓库里）。
- **tasks.md 未改**：它是 P78 propose 的批次计划（B1–B3），P86 是 apply 返工，brief 没有要求更新它。

## Suggested next steps

- PM 复验：`bash docs/team/reports/P86-dev/pkg/run.sh`（76 ok / 0 bad / 1 finding）+ `team review P86 --strong`
  在独立 checkout 上跑 `openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh`。
- **PM 裁决 finding**：准入条件的边界形状（见上）。三个选项：① 记为已知边界（现状，已写进 design/troubleshooting）；
  ② 派后续 change 收口（例如「候选被准入条件拒绝时不再回落到更近的候选」——代价是 unknown-shape 路径会多走，
  那意味着「按今天的行为投递 + 一次警告」）；③ 改本 brief 的范围重新实现。
- 归档前记得：本 change 的 delta（ADDED requirement）已被 P86 改过一遍，提案审查（`reviews/<change>-proposal.md`）
  的 ACCEPTED 结论早于这次修改——建议 archive 前补一次提案复审或至少在归档记录里点名这次改动。
