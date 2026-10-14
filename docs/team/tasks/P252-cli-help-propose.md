# P252 · `team help` 与每个命令的帮助页：默认英文、可切语言、给不懂这个项目的人看的

task: P252
agent: dev
phase: propose
category: analysis
change: cli-help
specs: help-surface
deltas: help-surface
branch: task/P252-cli-help-propose
deps: 用户 2026-10-14 的三条要求（见下）

## 用户的原话（这是本变更的唯一需求来源）

> 我看 `team --help` 里描述的语言风格太难懂了，而且需要默认是英文，且支持多语言。`--help` 菜单出来的也很乱，不好看。
>
> 你要确保的是对这个项目的实际内容和原理不懂的用户能够通过 `--help` 了解各种功能的作用和含义，避免过于简化的描述。

## 现状（PM 2026-10-14 实测，你复核一遍）

- `team help` 是一段 98 行的中文 heredoc（`scripts/lib/cmd-project.sh` 的 `team_cmd_help`），风格是**源头压缩式**的：用 `→` 串起一长串动作、把前置条件塞进括号、概念不解释（例如 bootstrap 那段：「一条命令把项目初始化到可派单状态：写配置 + 文档骨架 + AGENTS 段落 + 把 skill 装进项目 .pi/skills/ → 建 agent worktree → 起巡检窗口 → 打印下一步清单；幂等，可反复跑」）。对不懂本项目的人，读完不知道 **PM/席位/worktree/brief/change/门禁/账本/pulse/knock** 各是什么、为什么要它们。
- **没有任何按命令的帮助页**：`team <cmd> --help` 会退回全局那 98 行（`team reply --help` 的这条 nit 在 V27 复验里记过）。用户想查「`team config` 到底有哪些子命令、每个参数什么意思」只能滚全局页。
- **没有语言层**：CLI 全是中文硬编码（`scripts/lib` 里 5477 行含中文），而 README 与 `references/**` 是英文——同一项目两种语言没有机制区分。面板早就有先例：`scripts/panel/src/strings/{en,zh}.ts`。
- **布局**：组标题用 `── xxx ───…`，选项说明换行顶到第 19 列、没有悬挂缩进，长段落与选项混排；`--help` 里同一命令的参数说明与行为说明没有分开。
- **已有的诚实性守卫（你要保住它）**：`tests/routes.sh` 的 Walk A 会把 `team help` 里的**每一条用法行**喂给解析器（必须被接受），Walk B 校验 schema 注释点名的命令都有承诺探针，还有一条「把树改坏必须红」的翻转；门禁段 `§51 · 用法诚实性` 跑它。**改帮助文本必须让 §51 继续绿**，不许用删用法行/放宽解析器的方式。

## 你要产出的东西

一个 OpenSpec change（新能力 `help-surface`，或按你的判断落在既有能力上——但要在 proposal 里说明理由）：`openspec/changes/cli-help/{proposal.md,design.md,tasks.md}` + `specs/help-surface/spec.md`。至少覆盖：

1. **读者与深度**（用户要求的核心）：帮助文本的**目标读者**是「知道要管一个项目、但不懂 teamsmith 内部模型的人」。要为以下概念各给一句**可读的定义**（不是行话）：PM 与 worker 席位、工作树（worktree）与任务分支、任务书（brief）与它的 `category:`、变更（change）与规格（spec/OpenSpec）、门禁（gate）与「为什么绿是证据」、账本（ledger）与「谁写的」、pulse 巡检与 knock 叫醒、`--yes` 与授权边界。**深度**要能回答「这命令是干什么用的、什么时候用它、它读什么写什么、有什么副作用、能不能撤」，而不是只列旗标。
2. **每个命令一个自己的页**：`team <cmd> --help` 必须只讲该命令（用途 / 何时用 / 参数逐个解释 / 例子 / 触碰哪些文件与状态 / 有没有会启动进程或写账本这类副作用 / 是否要 `--yes`），并且**未知子命令的 `--help` 要有明确行为**（报错点名还是退回父页，你定但要有据）。`team help` 保留分组总览，但它要**能读到每个命令的一页**（例如 `team help <cmd>` 等价于 `team <cmd> --help`，两者行为要一致并写进 delta）。
3. **默认英文 + 多语言**：默认语言 = **en**；语言选择机制（建议 `TEAM_LANG`，值 `en`/`zh`，落在 `.pi/team/config.sh` 或环境变量——你评估两者并给理由）；**缺键必须可见**（某个语言缺一条键 → 打印时点名缺失的键并以可读回退，另有一条可跑的检查：把语言表里删一条键 → 红并点名）；帮助文本与 `references/**`、README 的语言关系要写清（哪些是英文、哪些可翻译、谁是谁的真源）。
4. **布局规范**：宽度与换行规则（例如默认 100 列、超宽自动折行且**悬挂缩进**）、组标题与命令行的对齐、参数与说明的列、例子块、以及「同一页内不许出现 `→` 串成的动作链、一个句子只说一件事」这类**可检查**的写作规则（能用夹具查的尽量写成夹具：行宽、缩进、禁止形态、空组）。
5. **诚实性沿用**：每条用法行仍必须被解析器接受（`routes.sh` Walk A）；帮助里的**每条承诺**要么有夹具兑现（§51 的既有口径），要么从文本里去掉——不许出现「文档说能、实际没做」的句子。新增/改写的承诺要在 proposal 里列成清单（哪几条进了 §51 的探针清单）。
6. **红侧**：至少给① `--help` 缺一条命令 → 红；② 中文表缺一条键 → 红并点名；③ 帮助里写一条解析器不接受的形式 → §51 红；④ 帮助里写一条没有夹具兑现的承诺 → §51 红；⑤ 布局规则（行宽/缩进/禁止 `→` 链）被违反 → 红。
7. **不变量**：命令名、旗标名、退出码、机器出口（`--print`/`--json`）**一个字节都不改**；本变更只动帮助文本、语言层与它们的夹具。

## 边界

- 只写提案（proposal/design/tasks/delta）；apply 与 verify 另行换人。
- 现有 `§51`/`routes.sh` 的**强度不许降**（可以为了新文本更新清单，但要在 design 里逐条说明为什么不是削弱）。
- 别在本批试图把 `scripts/lib` 里 5477 行中文全部翻译（那是另一个量级的工程）：**本变更的范围就是帮助面**（`team help`、每个命令的页、以及帮助里用到的概念词）。其余消息的迁移写成 design 的「未决/后续」一节，给一条能分步推进的路线（例如先错误信息里最常被读到的少数几条）。

## 验收（本阶段）

```bash
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/routes.sh            # §51 的诚实性走查（改帮助文本前先跑一遍基线）
bash skills/teamsmith/tests/section-select.sh --paths $(git diff --name-only main...HEAD | tr '\n' ' ')
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```

做完 `team notify pm`；PM 复核后派 apply 与独立复验。
