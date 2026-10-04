# M74 · settings-choice-editors 重做后的独立验证（verify 阶段）

```
task:   M74
agent:  dev
issue:
change: settings-choice-editors      # 重做 apply 已合并（M68）；apply 作者 = dev2 → 验证必须换人（D31）
specs:  panel#The console offers the schema's choice set wherever there is one, and degrades visibly / panel#The console writes a project setting only through team config set, after validation
phase:  verify
anchor: change
deltas: panel
grant:  docs/team/reports/M74-dev.md · docs/team/reports/M74-dev/**（只写报告与证据，不改实现）
deps:   M65（修订提案）· M68（重做 apply，已合并）· M59/M60（你读过原件，知道基线）
status: todo
budget: 一个工作块（只写复验证据与报告，不改实现）
```

> 本地模式：不 push。**为什么是你**：M68 的 apply 是 dev2；你做过 M60（原件交互的 verify），
> 最清楚"旧交互应该变成什么样"——正好验证重做是否真的落地、且没弄坏旧语义。

## 要对抗性验证的六条（每条给可复现命令 + 原始输出）

1. **直写 argv 序列（用户决定②）**：accept 一个选项 → 恰好 `config set … --dry-run` → `config set … --yes --fingerprint …`，
   **无确认帧、无写编辑器**，审计 +1。自己用 argv 记录 wrapper 证（别只读帧）。
2. **交互路径零读取（M1）**：打开选择器、移动、accept、打开自由输入——**按键与回答帧之间不得出现**
   `config list`/`__panel-data` 调用（编辑器由已读的 settings 块构建）；settle 后的重读**在后台**且回执帧不等它。
3. **危险值例外（用户决定④）**：来自**选项**的危险值，第一次 accept 只出示警告（契约不变、无 --yes、无审计），
   第二次 accept 才带 danger allowance 写入。
4. **「其他」路径（用户决定③）**：自由输入仍打开写编辑器 + 校验 + 确认；非法值不写且草稿保留。
5. **读取一遍且等价（M2）**：`team config list --json` 的输出与**独立解析器**（你自己写一个小脚本按契约格式解析）
   逐字节/逐字段一致；并复测它报告的耗时级别（设计说 3.4s→~0.2s，验证不是回退）。
6. **旧语义没丢**：refuse 类仍拒写（exit 5）并点名手改路径；restart 类的回执**不谎称已生效**；
   冲突（CAS 指纹）拒写且不覆盖；bundle 与 src 同步（build 两次幂等）。

## 已知噪声（别误判）

- 新 pty 夹具（panel-p21 choices，110 条）在 **load≈11** 时会系统性失败（PM 实测：load 11 → ✓48 ✗89 计数稳定；
  load ~2 → ✓110 ✗0 ×2）。**遇到大面积红先看 load**；负载下请单独重跑该段并在报告里写清两次的输出与当时 loadavg。
  （"夹具负载容限"已另立待办，不在本任务修。）
- `team config list --json` 在"席位模型 override 为空"时会产出**非法 JSON**（pre-existing，main 上也是）——
  若你撞上，**另记 finding**，别算进本 change（也不许顺手修）。

## Acceptance

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
bash skills/teamsmith/tests/smoke.sh </dev/null
bash skills/teamsmith/tests/panel-choices.sh
bash skills/teamsmith/tests/panel-flip-m54.sh F-B F-C W-A W-B
node skills/teamsmith/tests/panel-strings.mjs
```

## Boundaries

- **不改实现**（`scripts/**`、`extension/**`、`tests/**` 一律不改）；缺陷 → 写清楚交回 PM。
- 变异只在临时副本里做，还原后 `git status --porcelain` 干净。
- 不 push；不改 `docs/team/**` 里 PM 的文件。
