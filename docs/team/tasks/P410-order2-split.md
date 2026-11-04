---
id: P410
title: 每次的门禁只跑一阶测试，把"测试测试本身"的段移到低频元套件
agent: dev
category: code
phase: apply
change: -
specs: verification
anchor: openspec/specs/verification/spec.md
deltas: -
branch: task/P410-order2-split
---

# P410 · 一阶留在门禁，二阶搬到低频

用户 2026-11-04 决策：**每次的全量门禁只跑一阶测试**（验产品行为的），"验测试本身"的那类段改为低频后台跑。这不是省事，是位置错配：那些段测的是**测试有没有牙齿**，而测试套件改动频率远低于产品。

## PM 已经量出来的账（用 2026-10-30 那次全量门禁的逐段计时，134 段，合计 185 分钟）

| 段 | 名称 | 实测 | 类别 |
|---|---|---|---|
| 61b | 任务类别模型路由：翻转变异自检 | 5724s | **二阶**（31 个变异，验测试有没有牙齿） |
| 36 | 选段与分段账本自检 | 964s | **二阶**（验选择器与预算账本） |
| 51 | 用法诚实性：help 每条承诺都有夹具兑现 | 1037s | **二阶**（验文档承诺与夹具的对应） |
| 38 | 设置选项（choices 读 / 一致性走查 / 选择器夹具） | 718s | **混合**，见下 |
| 61 | 路由分组前门（16 组正常） | 566s | 一阶，留着 |

其余段都在 131s 以下，多数 < 80s。

## 要做的

1. **给出二阶清单并落地成机制**：`smoke.sh` 里那些只验"测试/夹具/选择器/文档承诺"的段，默认**跳过**并打印一行显式理由（段号 + 为什么是二阶 + 最近一次绿记录的时间与路径）。`TEAM_META=1` 时才跑它们。
   - 起步清单（你可以按同一条判据增删，每处都要在报告里写理由）：`61b`、`36`、`51`、`0d`、`0e`、`14b`、`14c`、`40`，以及独立的元命令 `section-select.sh --check`、`checkout-shape-probe.sh`。
   - **判据一句话**：段失败意味着"我们的测试/夹具/断言错了" → 二阶；意味着"产品对用户做错了事" → 一阶。`38` 是混合的：请先量出它里面"choices 读"（产品）与"一致性走查 + 选择器夹具"（二阶）各占多少秒，再决定拆还是整段归二阶；不许为了省时间把产品行为也搬走。
2. **元套件入口**：`bash skills/teamsmith/tests/meta-suite.sh`，跑上面全部二阶段与元命令，写一份带时间的记录（绿/红、每段耗时、总耗时），路径固定可引用。它自己**不许**再套一层"验它自己"。
3. **不许静默消失**：一条断言证明 `一阶段 ∪ 二阶段 = 全部段`（用 `smoke.sh` 的段清单与选择器同源数据），少一段就红；并且逐段跳过行必须出现在输出里。
4. **CI**：`.github/workflows/gates.yml` 加 `schedule: cron` 的 nightly 作业跑元套件；push 触发的门禁里不含二阶段。
5. **发版清单**：`docs/team/reviews/release-0.4.0-prep.md` 里加一条——发版前必须有不超过 7 天的元套件绿记录，引用路径。

## 红侧（必须各自能红）

- 从二阶清单里删一段（它就会在一阶门禁里跑）→ 上面那条"并集等于全部"的断言必须红；
- 把一段产品行为段（例如 `7 notify/inbox/digest`）错放进二阶清单 → 必须有一条断言指出"这段在 FAST/一阶里本该跑到"；
- 跳过行的理由缺失 → 红。

## 验收（自己跑，贴 rc 与输出尾）

- 一阶全量：`bash skills/teamsmith/tests/smoke.sh </dev/null`（记录总时长；预期从 185 分钟降到 60–75 分钟，`38` 若整段归二阶则更低）
- 元套件：`bash skills/teamsmith/tests/meta-suite.sh`（记录总时长，预期约 2 小时；这一条可以放后台跑）
- `openspec validate --all`、`spec-refs.sh --check`、`section-select.sh --check`、`ledger-ban.sh --names-file .pi/team/forbidden-names.txt`、`git diff --check`
- 报告 `docs/team/reports/P410-dev.md`，含"一阶 vs 二阶"最终清单与每段耗时来源，提交推分支，通知 PM

## 边界

- 只改 `skills/teamsmith/tests/**`、`.github/workflows/gates.yml`、`docs/team/reviews/release-0.4.0-prep.md`（那一条）。
- **不删任何测试、不放宽任何断言**：只是改变它们被跑的频率与位置。
- 不改产品代码、不合并/归档/发布。
