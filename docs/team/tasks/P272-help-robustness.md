# P272 · 帮助面的三条收尾（V38 的观察 O1 / O2 / O6）

task: P272
agent: dev2
phase: apply
category: code
change: cli-help
specs: help-surface
deltas: help-surface
branch: task/P272-help-robustness
deps: P260（已并入 main）；独立复验 V38 的观察表（`docs/team/reviews/V38.md` §0）

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
