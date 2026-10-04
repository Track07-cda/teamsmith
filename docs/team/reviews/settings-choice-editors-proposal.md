# settings-choice-editors · PM proposal review

time: 2026-09-21T04:4x:00Z · reviewer: pm · verdict: **ACCEPTED**

```
change:  settings-choice-editors
owner:   dev-bob（propose）
tip:     494a482（task/M54-schema-bool-enum-model）
```

## Commands run

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict    → Totals: 18 passed, 0 failed
$ git -C .worktrees/dev-bob status --porcelain | wc -l            → 0
# delta 完整性（MODIFIED 不得悄悄删掉 base 的 scenario）：
memory-and-deps「A seat's model is read and written as a seat …」  base 7 → delta 8，被删 = 无（+1：known 集带 pm 席位模型）
panel「The console writes a project setting only through team config set …」 base 7 → delta 7，被删 = 无
```

## Findings

1. **用户的原话被正确翻译成契约 — PASS。** `panel` 新增一条 requirement（+10 scenario）：
   `bool` 从**两个带标签的条目**里选；`enum` **只给 constraints 里的取值**；**新增一个 enum 键或枚举值无需改控制台**
   （这就是我要的反硬编码判据）；`model` 条目是**本项目的词汇表**、**绝不倒整个 Pi 目录**；
   数值键给建议值**且仍可自由输入**；path 键标注存在性并只提供命令真正接受的"清空"；
   **没有可选集合的键打开自由输入并写明原因**；**未设键以一个条目开头，而不是空白框**；
   pairlist 行**路由到座位块**；选择器**鼠标完整**且取消不写任何东西。
2. **选择集只有一个来源 — PASS。** `--json` 新增 `choices`（每键一个对象，形状见 D1：
   `{source, values, min, max, empty, note}`），由 schema 行派生；并钉住一条强不变量：
   **"读给出的值与校验器拒绝的值不一致" = 门禁失败** —— 这条把"选项"和"写入校验"焊在一起，非常对。
3. **数值建议值进了 schema（D2）— PASS。** 新增**可选的第 9 列 `suggest`**，无建议的行保持 8 列（读者两形状都认）——
   比我任务书里"另立一张表"的选项更好：建议值随键一起演化，不会漂。
4. **模型词汇表 = 项目数据（D5）— PASS。** `known` 只由本项目的配置/席位/记录推出并包含 `pm` 席位；
   场景里明写"**绝不来自机器目录**" —— 这正是 `sub2api` 那个已下线 provider 给的教训。
5. **写入路径没动（D6）— PASS。** 仍是 `team config set` 唯一写入者、两步确认、CAS 指纹、危险值二次确认、
   审计可从视图与 CLI 两处读；`panel` 那条 MODIFIED 保持 7 条 scenario 一条不删。
6. **可证伪性齐（D8）— PASS。** 一致性夹具 + 双向翻转（新增 enum 键→零改动给选项；去掉 constraints→**可见地**退回自由文本）。

## 一处 PM 裁定：`unset` 不在本 change，但必须留痕

我的任务书写的是「未设键…提供显式的『恢复默认（unset）』选项」。作者**实测**后指出：
写入者**没有 unset**（`team_config_set_in_file` 只写；唯一的删除是 `set-agent-model <seat> -`），
于是设计改成：未设键的首个条目是**"保持未设"（取消即不写、不留审计）**；已设键把默认值作为**普通的一次写入**提供，
并**明说这是写入**；真正的 unset 是手改 `config.sh`（行内提示）。
**我接受这个版本**（诚实 > 假装），并把 **F1：`team config unset`** 登记为后续项（新增写操作 = 校验/CAS/审计/危险值/文档都要动，
不该塞进这个 change）。若用户想在本轮就拿到"回到未设"，我会单独派一个小 change。
