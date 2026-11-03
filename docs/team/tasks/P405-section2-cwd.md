---
id: P405
title: §2 init 段自己确保工作目录，不再依赖上一段留下的副作用
agent: dev2
category: code
phase: apply
change: -
specs: -
anchor: none (infra) — 修的是夹具段的隐式顺序依赖，不改产品契约
deltas: -
branch: task/P405-section2-cwd
---

# P405 · 少选一段就假红

## 现象（V127 实测，PM 复核过代码）

`bash skills/teamsmith/tests/smoke.sh --select 0b,1b,6,17,18,18b,19,39` 在这棵树上**必假红**：

- 选段经路径展开把 §2 拉进来，却没把 §1c 拉进来；
- §1b 结束时工作目录在 `$TMP/bootrepo`；
- 唯一把 cwd 挪回 `$REPO` 的是 §1c 结尾那句 `cd "$REPO"`（`smoke.sh:2658`）；
- 于是 §2 的 `team init` 在 bootrepo 里跑（rc=0，配置/看板都写进了 bootrepo），停在 `$REPO` 的断言全红，随后身份隔离自检判 `team 认错项目`，**整套中止**；
- 加上 `1c` 后同一棵树 ✓378 ✗0。

代价：任何人照抄一条不含 `1c` 的选段命令都会得到一片假红，并可能把它误判成产品回归（V127 就是这么撞上的）。

## 要做的（窄，且是减法）

1. 让 §2 在开头**自己**确保工作目录是 `$REPO`，不再依赖 §1c 留下的副作用。写法与 §1c 里那句一致，且注释写明"§2 曾经依赖 §1c 的 cd，少选一段就假红"。
2. 同样检查 §2 之后**依赖 cwd** 的段落里还有没有同类隐式依赖（只修你确认为真的，不要全面重构）。
3. **不许**新增段、不许新增守卫、不许把这层依赖改成"检测到选段不完整就跳过"——跳过会让真回归变成静默。

## 红侧（必须给）

- 不带 `1c`：`bash skills/teamsmith/tests/smoke.sh --select 0b,1b,6,17,18,18b,19,39 </dev/null` 修前红、修后 **✓378 ✗0**（数字可能因你用别的树而略差，贴实际）；
- 带 `1c`：`--select 0b,1b,1c,6,17,18,18b,19,39` 修前修后都绿（证明不是靠 `1c` 才绿）；
- 把新加的那行 `cd` 删掉，第一条必须回到红（证明断言真的咬住这条依赖）。

## 验收（自己跑，贴 rc 与输出尾）

- 上面三条命令
- `bash skills/teamsmith/tests/section-select.sh --check`
- `section-select.sh --check`、`ledger-ban.sh --names-file .pi/team/forbidden-names.txt`、`git diff --check`
- 报告 `docs/team/reports/P405-dev2.md`，提交推分支，通知 PM。

## 边界

- 只改 `skills/teamsmith/tests/smoke.sh`（§2 开头与同类 cwd 依赖处）。
- 不跑全量 smoke、不合并/归档/发布。
