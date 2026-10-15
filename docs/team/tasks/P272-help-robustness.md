# P272 · 帮助面的三条收尾（V38 的观察 O1 / O2 / O6）

task: P272
agent: verify
phase: propose
category: code
change: help-robustness
specs: help-surface
deltas: help-surface
branch: task/P272-help-robustness-propose
deps: P260（已并入 main）、**cli-help 已归档**（`openspec/changes/archive/2026-10-15-cli-help/` 已在）（新变更要修改的 `help-surface` 能力得先落到规格库里；本任务排在它归档之后）；独立复验 V38 的观察表（`docs/team/reviews/V38.md` §0）

## 为什么单开一个变更（PM 2026-10-15）

这三条是 V38 复验里**新发现**的收尾项（非阻塞观察），不是 `cli-help` 原范围的一部分：原来把它挂在 `change: cli-help` 上，会让那个变更永远关不掉（它已经交付并复验通过）。所以新开 `help-robustness`：它 **MODIFY** 已归档的 `help-surface` 能力。派单前先确认 `openspec/changes/archive/2026-10-15-cli-help/` 已在，否则先报我。

## 三条（都来自 V38 的观察表，按优先级）

1. **O1（最实质）非 UTF-8 locale 下排版失真**：`LC_ALL=C`（或未设 `LANG`/`LC_*`）时英文面 202 行越 100 格、中文面 35 行越界。根因是渲染器算显示宽度时依赖 locale（宽字符/CJK 的宽度判定随 locale 变）。**要求**：宽度计算与 locale 无关（自己实现/查表，不依赖 `wcwidth` 的 locale 行为），并给出**红侧**：`LC_ALL=C` 与 `LC_ALL=C.UTF-8`（或 `en_US.UTF-8`）下渲染同一页，**逐字节相同**且都在 100 格内；把宽度计算改回 locale 依赖 → 红。
2. **O2 合同文字不准**：spec/design 说「不进帮助面的唯一例外是 `__panel-data`」，而 dispatcher 实际还有 `__inbox-write`。**要求**：把两处（或实际存在的全部内部命令）写准，并让「内部命令不进帮助面」这条**可证伪**——列一个封闭清单，清单外出现内部命令名 → 红。
3. **O6 可达性断言缺口**：「菜单点名每一个分组」这条断言随文本类一起被移走了，于是「任何命令 ≤3 步可达」这层**结构**没有断言。**要求**：加一条**逻辑类**断言（不是措辞）：从命令清单出发，每个命令都能由「入口 → 组页 → 命令页」三级路径到达；删掉某个组页入口 → 红并点名那个组的命令。

## 边界

- 只碰帮助面（`scripts/strings/*`、`lib/cmd-help.sh`、`tests/help-surface.sh`、`routes.sh` 里属于帮助走查的部分）与该 change 的 delta（`openspec/changes/cli-help/`，若已归档则改 `openspec/specs/help-surface/spec.md` 的对应 requirement 并说明）；**不碰**别处。
- **不许削弱**：Walk A 的强度、承诺探针、控制臂、既有翻转一条不动；D170 的收窄照旧（措辞/排版由评审把关，不新加文本类断言——O1 加的是**行为**断言「同一输入在不同 locale 下输出相同」，不是措辞）。
- 与在飞任务串行：`smoke.sh` 与两张 tsv 此刻归 P264（门禁瘦身）；交付前 `git merge main`，冲突按双方保留，语义冲突停下报我。
- 合并前逐条看「本次相对 main 的删除行」（P261 的教训）。
- 不合并、不推送；做完 `team notify pm`；随后由未参与实现的席位独立复验。

## 验收（贴真实输出）

```bash
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/help-surface.sh --all
bash skills/teamsmith/tests/routes.sh
LC_ALL=C bash skills/teamsmith/tests/help-surface.sh --select layout   # 与 UTF-8 下逐字节对照
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```

4. **O7（V36 的观察，同类）CLI 拒绝语里还剩黑话**：`team config set` 在只读键上的拒绝语写「`TEAM_X` 是只读键，控制台不改它」（`cmd-config.sh:929` 一带）——「只读键」正是用户点名的词。**要求**：改成普通话（例如「这个键只能改项目配置文件 `.pi/team/config.sh`，控制台不能改」），并**同批检查同一族的其他拒绝语**（`refuse` 类键的提示）；判据是**行为**（拒绝仍发生、退出码不变、提示里含配置文件路径），措辞由评审把关。

## 追加两条（P277 交叉勾选时发现的证据缺口，2026-10-15）

- **G4（缺断言）**：`cli-help` 的 1.4 要求「未知占位符判红」，但**没有任何断言**盯着它（渲染器确实只解析已声明的占位符，行为在，红侧不在）。本任务补：在帮助面夹具里加一条「模板/清单里出现未声明的占位符 → 渲染器判红并点名」，配「破坏 → 红 → 还原 → 绿」。
- **G3（缺 rc 记录）**：`cli-help` 8.1 点名的 `spec-refs.sh --check` 在作者报告与复验记录里都**没有 rc**。本任务交付时把它连同 `openspec validate --all --strict` 一起跑一遍并贴 rc（这是本任务的验收行，不是补历史记录）。

## 本阶段只写方案（PM 2026-10-15 追加）

`cli-help` 已归档，`help-surface` 现在在 `openspec/specs/help-surface/spec.md`。本任务**先写方案**：产出 `openspec/changes/help-robustness/{proposal.md,design.md,tasks.md}` + 对 `help-surface` 的 MODIFIED delta（三条观察 + G3/G4 两条）。**PM 复核方案通过后再派 apply**（协议硬规矩：提案未复核不得进实现）。方案里要写清：三条观察各自的行为合同与红侧、以及「措辞/排版不设门禁断言」这条（D170）在本次不变量里怎么体现。
