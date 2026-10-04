# M60 · settings-choice-editors 独立验证（verify 阶段）

```
task:    M60
agent:   dev
branch:  task/M60-settings-choice-editors（local 模式：不 push；分支留在 .worktrees/dev）
change:  settings-choice-editors（phase: verify；apply = dev3 的 M55/78fc880，与本验证无 apply 关系，D31 成立）
deps:    M54（propose，已合并）· M55（apply，已合并）
status:  PASS（四条对抗性验证全过 + 验收命令全绿；1 次负载级联已按任务书纪律定性，见 §6）
```

证据目录：`docs/team/reports/M60-dev/`（`probe-enum.sh` + `frames/` 17 份原始帧 + `logs-*.txt` 运行实录）。
**本任务不改实现**：`scripts/**`、`extension/**`、`tests/**` 零改动（`git status --porcelain` 全树只剩本报告目录，
见 §8）；所有需要"临时改 schema"的验证都在 `/tmp` 的 scratch 副本上做。

## 判定总表

| 任务书验证项 | 方法（对抗性增量） | 结果 |
|---|---|---|
| 1 反硬编码 | **自己的探针**：`TEAM_M60_PROBE`（三值、默认居中）+ 给既有 enum 追加 `quad` + 去掉 constraints | PASS（✓44，§1） |
| 2 读=写、闸门非恒真 | 全量走查 + **收紧校验器**的自有翻转（F-D 是改建议列，我改校验器，方向相反） | PASS（§2） |
| 3 模型词表是项目的 | scratch HOME 用**本机真实在册 provider 名单**+ghost 模型；真机目录 399 模型对照 | PASS（§3） |
| 4 写入路径没绕开 | writer 函数逐字节对照 + argv 实记 + write/conflict 重跑 + unset 实测 | PASS（§4） |

---

## 1. 反硬编码判据（本 change 的核心卖点）——PASS

**探针 `probe-enum.sh`（✓44 ✗0，实录 `logs-probe-enum.txt`）与 M55 夹具的差异即对抗性增量**：
夹具的键是 `TEAM_ZZZ_MODE`（两值、默认在头）；我的键是
`TEAM_M60_PROBE|apply|enum|north,south,west|plain|south`——**三个值、默认值居中**，
第一次把「默认条目置顶」与「constraints 原序」两条排序规则分开观测；并追加夹具没覆盖的另一半：
**给既有 enum（TEAM_MONITOR_UI）的 constraints 加一个新值 `quad`**。bundle 自始至终是提交的那份
（`panel.js` sha256 与 `git rev-parse HEAD:...panel.js` 逐字节相等，运行前后各验一次）。

① 新增 enum 键 → 控制台零代码给出选项（`frames/02-probe-picker.txt`）：

```
│  选择 TEAM_M60_PROBE 的值 · TEAM_M60_PROBE
│ › 保持未设（取消 = 不写、不留审计）
│   south · 默认
│   north
│   west
```

顺序与 delta 规格的条目构造规则一致：当前 → **默认置顶** → 去重后的 values 原序
（south 居中所以置顶，其后 north、west 仍按声明序；封闭域无自由输入项）。
若实现把「constraints 顺序」硬编码成条目序，这一帧会是 north 在最前——观测推翻了它。

② 给既有 enum 追加 `quad` → 同一 bundle 的选择器末尾出现它，且 scratch 校验器接受、真树校验器拒绝
（值域确实来自各自 schema 行，不是常量）：

```
✓ auto 默认置顶 → tui → text → quad（新值在尾，零重建）（frames/11-ui-picker.txt）
✓ scratch 校验器接受新值 quad（读=写，rc=0）
✓ 真树校验器拒绝 quad（rc=4：值域确实来自各自的 schema 行，不是常量）
```

③ 去掉该键的 constraints → 同一 bundle 可见退回自由输入并写明原因
（`frames/15-noconstraints-editor.txt`）：

```
enum 这种 kind 没有选项集；写入仍由命令校验（Enter 打开自由输入）
╭─ TEAM_M60_PROBE ────…
│ > west
```

④ 还原与干净：scratch CLI / 夹具项目 / scratch HOME 全在 `/tmp`，真树一个字节没动；
探针收尾断言 `panel.js` sha256 全程不变、仍 == HEAD blob、`skills/teamsmith/` 工作树干净（全 ✓）。

## 2. "读给出的值 = 校验器接受的值"——PASS

**全量走查**（验收命令 `bash skills/teamsmith/tests/panel-choices.sh`，✓35 ✗0，
实录 `logs-panel-choices.txt`）：real 树 86 条 options 作业逐值喂 `team config set <KEY> <value>
--dry-run` 全被接受（0 或 7=danger）、108 个 schema 键的静态一致性（values/min/max/known）全过、
每个键的 `choices.empty` = 校验器对 `''` 的判定、走查后契约 sha 不变。

**"选项里有、写入却拒绝"的构造尝试**（实录 `logs-token-vocab.txt`）：唯一存在的组合是
token 类（pairlist/winlist）的**词表**语义——`values` 是裸模型名，裸写被拒（rc=4 并点名组合规则），
按视图组合规则写则接受：

```
✗ TEAM_AGENT_MODELS=deepseek/deepseek-flash 不合法：只接受 seat=provider/model 空格分隔（…没有 =）   rc=4
ok: TEAM_AGENT_MODELS=dev=deepseek/deepseek-flash（dry-run…）                                          rc=0
✗ TEAM_MODEL_LIMITS=deepseek/deepseek-flash 不合法：只接受 pattern=N 空格分隔                          rc=4
ok: TEAM_MODEL_LIMITS=deepseek/deepseek-flash=1（dry-run…）                                            rc=0
```

这是 D1/D3 裁定的设计（pairlist 在控制台不组合、路由到席位块；winlist/pattern 选择器把 `<model>=`
种进编辑器），走查按同一组合规则走——不是静默过滤。除此之外未能构造出任何"读给了、写入拒绝"的组合。

**一致性闸门非恒真（自有翻转，与 F-D 方向相反）**：F-D 是把建议列改成 30（数据错）；我把
**校验器**收紧（scratch 树 `TEAM_PULSE_INTERVAL` 的 constraints `60,`→`1200,`，建议列不动）
——读（建议值 300/900）与写（最小 1200）错位，闸门必须红。实测（实录 `logs-flip-tighten.txt`）：

```
✗ 走查（real）：schema 与 choices 的静态一致性有 2 条问题
✗ 走查（real）：TEAM_PULSE_INTERVAL 的选项 [300]（组合成 [300]）被校验器拒绝（rc=4）：…超出范围：最小 1200
✗ 走查（real）：TEAM_PULSE_INTERVAL 的选项 [900]（组合成 [900]）被校验器拒绝（rc=4）：…超出范围：最小 1200
== 结果 ==  ✓ 3  ✗ 3   rc_red=1
（恢复 scratch 的 schema 行后重跑）== 结果 ==  ✓ 5  ✗ 0   rc_green=0
```

静态比对与逐值 dry-run 两层都红、点名键与值——闸门不是恒真仪式。夹具自带的 F-D（改建议列）
与 F-A（去掉 pm 解析）也在本次全量运行中各自红→绿（`logs-panel-choices.txt` 的 flip 段）。

## 3. 模型词汇表是本项目的，不是机器的——PASS

**探针 E 段**（scratch HOME 的目录 = 本机真实在册的 6 个 provider + 已下线的 sub2api，各带一个
`m60-ghost`；项目侧席位模型**故意与目录同 provider、不同 model**：`xai/m60-seat`、
`zai-coding-cn/m60-record`、`kimi-coding/m60-pm`）——若实现按「provider 黑名单」过滤，这三个项目模型
会误死；若实现读目录，ghost 会漏出。实测（`frames/12-model-picker.txt`）：

```
│ › deepseek/deepseek-flash · 当前
│   xai/m60-seat
│   zai-coding-cn/m60-record
│   kimi-coding/m60-pm
│   …（自由输入）
```

选择器恰含 4 个项目模型（**pm 席位在内**）、零 ghost、零 sub2api；同一 HOME 下
`team config list --json` 也不含 ghost/sub2api，`known` 恰为这 4 个且 pm 的恰好一次
（`frames/13-read.json` 的 python 断言 ✓）。证明词表来源是**项目记录**，不是 provider 过滤、更不是目录。

**真机对照**（在本仓库真树上只读运行，实录 `logs-real-catalogue.txt` /
`logs-real-catalogue-compare.txt`）：

```
项目 known: ['deepseek/deepseek-flash', 'kimi-coding/k3-256k', 'openai-codex/gpt-5.6-terra:xhigh']
真实目录（~/.pi/agent/models-store.json，只取键名）: 6 providers / 399 个模型（openrouter 一家 380）
目录里有而 known 没有的 provider: ['openrouter', 'xai', 'zai-coding-cn']
目录 397 个模型不在 known —— 一个没混进来
已退休备份 models.json.bak-20260921-031641 仍带 sub2api → http://<internal>/v1（拒连端点，仅 baseUrl）
```

本机历史上那个端点已下线的 provider（sub2api）实证仍在备份里，而项目的读与选择器都不含它——
proposal 的动机判断成立，实现把它挡住了。

## 4. 写入路径没被绕开——PASS

**机器层：writer 一行未动**（`78fc880` 前后逐字节对照，实录 `logs-writer-untouched.txt`）：

```
SAME  team_config_validate_value / canonical_value / danger_reason
SAME  team_config_fingerprint / audit_write / write_checked（CAS+原子写）
SAME  team_config_pairlist_upsert / seat_state / team_cmd_config（调度体）
```

**视图层：写入仍走 `team config set`**（探针 B/C 段 + 既有场景重跑）：

- 选中 `west` 的两步写入，argv 实记（`frames/08-argv-write.log`）**恰好两条**：
  `config set TEAM_M60_PROBE west --actor panel --dry-run --fingerprint <64hex>` →
  `… --yes --fingerprint <64hex>`；契约写入、审计恰好 +1 行。
- 取消的编辑（dry-run 后 esc）：契约 sha 不变、审计不增、argv 里**只有 dry-run 没有 --yes**
  （`frames/10-cancel-argv.txt`）。
- **审计双读**：视图底部 `审计（最近）` 与 CLI `team config log 5` 显示同一条最新行
  （`frames/06-audit-footer.txt` / `07-cli-audit.txt`）：
  `2026-09-21T09:49:13Z result=ok actor=panel key=TEAM_M60_PROBE old='' new='west'`
- **危险值二次确认 / CAS 冲突**：重跑既有场景 `panel-p21.sh write conflict`
  （`logs-p21-write-conflict.txt` + 重跑 `logs-p21-write-rerun.txt`）：两次确认、非法值留草稿、
  danger 先警告再写、指纹冲突保对方字节、审计一行 `result=conflict`、restart 写入不谎报生效——全绿
  （第一次运行 write 段有 3 条红，定性为负载级联，见 §6）。
- **`unset` 没有被偷加**：`team config unset TEAM_PULSE_INTERVAL` →
  `✗ config: 未知子命令 unset（list|set|log|set-agent-model）`（rc=2）；源码 grep 无副作用语义外的
  `unset`。未设键首条目「保持未设（取消 = 不写、不留审计）」在探针 A/C 段实测：接受 = 取消，零写入、
  零审计、无临时文件。

## 5. 验收命令（逐字跑在本树 tip）

| 命令 | 结果 |
|---|---|
| `PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict` | `Totals: 18 passed, 0 failed`（`change/settings-choice-editors ✓`），rc=0（`logs-openspec-validate.txt`） |
| `bash skills/teamsmith/tests/smoke.sh </dev/null`（全量） | `== 结果 == ✓ 2723 ✗ 0`，rc=0（§7） |
| `bash skills/teamsmith/tests/panel-choices.sh` | `== 结果 == ✓ 35 ✗ 0`（含走查 + catalogue + F-A/F-D 翻转），rc=0 |
| `bash skills/teamsmith/tests/panel-flip-m54.sh F-B` | `== 结果 == ✓ 4 ✗ 0`（断 choices 读取 → 红在预期点；恢复 → 绿且 bundle 逐字节一致），rc=0 |
| `bash skills/teamsmith/tests/panel-flip-m54.sh F-C` | `== 结果 == ✓ 4 ✗ 0`（目录泄漏 → 红在 sub2api；恢复 → 绿且 bundle 逐字节一致），rc=0 |

## 6. 已知噪声定性：write 段的 3 条红 = 负载级联，不是真失败

任务书预警过 §38-b pty 夹具在负载下会级联假红。本次 `panel-p21.sh write conflict` 第一次运行
（`logs-p21-write-conflict.txt`，当时 loadavg ≈ 5.4）write 段 3 条红：非法值回执/点名接受域/草稿保留
——同一段的「非法值契约不变」却是绿的（语义其实对了，只是帧没到）。**单独重跑同一段**
（`logs-p21-write-rerun.txt`，`bash tests/panel-p21.sh write`）：

```
== 结果 ==  ✓ 23  ✗ 0   EXIT=0
```

conflict 段在第一次运行已全绿（6/6）。两段合起来全绿覆盖；级联形态（同夹具、负向前提通过、
单独重跑全绿）与任务书描述一致，定性为夹具时序抖动，不算实现缺陷。M59（dev3）正在修这个机制本身。

## 7. 全量 smoke（`bash skills/teamsmith/tests/smoke.sh </dev/null`，非 FAST）

```
== 38 · 设置选项（M55：choices 读 / 一致性走查 / 选择器夹具） ==
  ✓ 38-a panel-choices.sh 全绿（ ✓ 35 ✗ 0；含一致性走查与 F-A/F-D 翻转）
  ✓ 38-b panel-p21.sh choices 全绿（ ✓ 74 ✗ 0）
== 结果 ==  ✓ 2723  ✗ 0
smoke 全绿        SMOKE_EXIT=0（运行 972.7s，实录 logs-smoke-full.txt）
```

38-b（pty 选择器夹具）这次在全量里真跑且全绿。机器当时很忙（§36 panel-cpu 前提测到 loadavg 9.00 over
the premise，按规则**可见 SKIP** 而不是报机器欠的红）——高负载下 38-b 仍绿，与 §6 的级联定性互证：
级联是概率性时序抖动，不是实现的稳定缺陷。

## 8. 边界与干净证明

- 本任务**只新增** `docs/team/reports/M60-dev.md` 与 `docs/team/reports/M60-dev/**`（我的证据目录）；
  `scripts/**`、`extension/**`、`tests/**`、`openspec/**` 零改动。所有"临时改 schema"都在 `/tmp`
  的 scratch 副本上做（probe-enum.sh 收尾断言 + 下方 git 状态双证）。
- 探针运行期间发现过一次**我自己**的残骸并清掉：探针首版路径 bug 在 `docs/docs/` 留了
  一个 frames 文件（09:44 那次失败运行），已 `rm -rf docs/docs`；与实现无关，如实记录。
- 复验时发现的 2 处探针自身断言 bug（顺序期望写反、多按一个 Esc 弹出了视图）已修正后全绿；
  两次失败都不是实现问题，帧证据与修正过程留在 `logs-probe-enum.txt`（首轮 40✓5✗ → 终轮 44✓0✗）。

```
$ git status --porcelain        # 交付前
?? docs/team/reports/M60-dev/
```

- 读取边界：机器目录只取了 provider 键名与模型计数（`logs-real-catalogue.txt`）；退休备份只取了
  sub2api 的 baseUrl 作历史证据——备份里同时有一个凭据，**没有**被读进任何证据文件。
- local 模式：不 push，分支留在 `.worktrees/dev`。
