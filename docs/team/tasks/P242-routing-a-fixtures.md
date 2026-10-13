# P242 · 让 210 条 A 类红按新合同转绿（夹具/期望更新，不许削弱断言）

task: P242
agent: dev-bob
phase: apply
category: code
change: task-model-routing
specs: dispatch
deltas: -
branch: task/P242-routing-a-fixtures
deps: **P238 必须先交付**（同一写集合：`skills/teamsmith/tests/smoke.sh`、`section-paths.tsv`、`section-budgets.tsv`、`tests/lib/**`）；V25 的分类报告 `docs/team/reports/V25-verify.md`

## 背景

合并 `task-model-routing` 后全量门禁 `✓4478 ✗224`（v0.1.2 是 `✓4653 ✗0`）。V25 逐条分类：**A=210（夹具/期望按新合同更新）、B=14（产品回归，B1 已修、B2+B3 在 P241）**。本任务修 **A 类**，依据是 V25 报告的 §3（A1–A9 聚类，含段号、条数、红的形态、修法归属与现场引用），**以那份报告为唯一清单来源**，不重做分类。

五个根因（条数按 V25）：

| 聚类 | 条数 | 要点 | 修法方向 |
|---|---|---|---|
| A2 | 162 | 夹具 brief 自己拼、缺**唯一** `category:` 头 → `dispatch` 预检拒绝（原文 `brief 必须唯一 category: header；显式 override 不豁免`）→ 整段级联（§41 69、§54 31、§22 16、§6g 14、§12h 13、§12g 7、§31c 6、§12i 4、§32 2） | 给每个夹具 helper/内联 brief 补一行合法 `category:`（用项目映射里真实存在的类别），**不要**给产品加豁免 |
| A1 | 18 | `dispatch --print` 不再落盘提示词（规格：preview 不得改动 launch state）→ §6f 断言读的是不再更新的旧文件 | 让该段用**一次真派单**（假 agent）落盘后断言，或改读 `--print` 的标准输出；不要动产品 |
| A3 | 14 | 同任务换模型必须 `--fresh`（M4.3 夹具按旧语义换模型） | 夹具改成带 `--fresh`（或改用同模型续跑），并在报告里点明这是新合同的意图 |
| A4 | 8 | 自定义模板必须绑定身份占位符；不合格模板不得提交窗口 | 夹具模板补全必需占位符；保留「坏模板被拒」的红侧用例 |
| A5 | 5 | patrol 的 PM 连续性与会话大小按 **committed assignment** 关联 | 夹具按新合同准备 assignment 记录后再断言 |
| A9 | 2 | **新加的路由测试库自身违约**：用裸 `tmux`，违反 M28 隔离合同（§31 1 条 + §36⑧ 探针） | 按 M28 的隔离方式（私有 `-L`/`TMUX_TMPDIR` + 闸门）改写，不许把 lint 放宽 |

## 硬要求

1. **不许削弱**：不得删断言、不得把断言换成跳过（除 V25 明确记为「现场敏感」且你给出理由的极少数）、不得改 lint 的判据来放行。夹具的合法输入变化要在报告里逐条说明理由（「为什么这是新合同要求的合法输入，而不是把测试改松」）。
2. **逐聚类给红绿对照**：每个聚类至少 1 条「改前红 → 改后绿」的原文；A9 额外给出「用裸 tmux 的变异 → 隔离 lint 必须红」。
3. **全量收口**：交付前在**钉死容器 + 干净 clone** 里跑一次**全量** `smoke.sh`，贴出 `== 结果 ==` 行。目标是 A 类清零：相对 v0.1.2 只剩 B 类（P241 修完即 0）与任何你新发现的、必须逐条归因的红。
4. **同命令对照**：任何「这条红是既有红」的说法都必须在 **v0.1.2（tag `v0.1.2`）** 上用**同一条命令**复跑并贴数字（PM 与 V25 都踩过「拿父 tip 或不同 `--select` 当基线」的坑）。
5. 不碰产品代码（`scripts/lib/**`、`extension/**`、`panel/**`、`references/**`、`templates/**`）——需要产品改动就 `BLOCKED:` 给 PM。不合并、不推送。

## 验收命令（贴真实输出）

```bash
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/section-select.sh --check
bash skills/teamsmith/tests/smoke.sh                      # 全量（容器 + 干净 clone）
bash skills/teamsmith/tests/task-model-routing.sh --select all
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```

## 交付

`docs/team/reports/P242-dev-bob.md`（逐聚类的条数与改动点、红绿对照、全量结果行与 v0.1.2 对照、未做/未归因项、合法输入变化的理由）；证据包按 D94 放仓外；之后由未写过本任务的席位独立复验（复验必须重跑**全量**，并抽查至少两个聚类是否真的按新合同而非按「跳过」转绿）。
