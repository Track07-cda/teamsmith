# V45 · `help-robustness` 的**第三方定点补验**（席位缺陷的补救）

task: V45
agent: -
phase: verify
category: verify
change: help-robustness
specs: help-surface
deltas: -
branch: task/V45-help-robustness-thirdparty
deps: P278（apply，已并入 main）、V41（复验 PASS，**但与 P278 同一席位**——`docs/team/reviews/P278.md` 记录了这处纪律缺陷）

## 为什么有这条

本变更的 apply 与 verify 落在**同一个席位**（换会话但同席位），违反了「不许自己验自己的活」的字面规则。为补救，由**第三个席位**只重验**两个最高风险面**，不必重跑全部：

1. **locale 无关的宽度引擎**（`cmd-help.sh`）：`LC_ALL=C`、`LC_ALL=C.UTF-8`、以及一个**非 UTF-8** 的 locale 下渲染入口页/组页/命令页 → **逐字节比对**；行宽上界（正好等于 / 超过一格）；CJK 折行不破行。**红侧你自己造**（把宽度计数器换成 locale 相关实现 → 必须红并点名页与行）。
2. **入口闭集与可达性**：从真实命令集反向核每个命令**三步内可达**；`__` 内部入口既不出现也不可打印；**你自己塞一个假命令**进清单 → 可达性断言必须红并点名分组。

另：随机抽 ≥5 条 V41 已验绿的断言复跑（确认它的结论可复现），并确认 `routes.sh`/`help-surface.sh` 的断言消息零丢失。

## 交付

`docs/team/reviews/V45.md`（抬头含 `判定: **PASS**` / `判定: **FAIL**`；逐条命令 + rc；你自己造的红侧原始输出；写明运行模型）；不改候选、不合并、不推送；结论通知 PM。
