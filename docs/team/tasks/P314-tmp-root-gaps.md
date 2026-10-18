# P314 · 临时根那条的四个交付缺口（归档前置）

task: P314
agent: dev2
phase: apply
category: code
change: tmp-root-on-disk
specs: verification
deltas: -
branch: task/P314-tmp-root-gaps
deps: P312（勾选已并入；四项缺口见 `docs/team/reports/P312-dev2.md`）

## 四件（按你的清单，逐项修 + 红侧）

1. **3.4 `team doctor` 有副作用**：默认根不存在时它**把它建出来**，且「临时根余量」行不说「尚未创建」→ 与 delta 的 `never created by a read-only surface` 冲突。
   **改法**：doctor **只读**（不建目录）；行内写清「尚未创建」并给出「将由夹具/门禁在运行时创建」的说明。
   **红侧**：跑 doctor 前后对 `TEAM_TMP_ROOT`（或默认根）**存在性**与状态目录全树哈希做对照——建了目录/改了东西必须红。
2. **5.4 §40 的 band 过期**：仍是 20.00s，今天实测 28s（改动前树）/36s（本分支），**两次都超带**。
   **改法**：按**实测**重填（同一套系数规则），并在 provenance 里写明「P314 重测，改动前树 X s、本分支 Y s，负载 Z」。
   **红侧**：把 band 改回 20.00s → 该段必须**红并点名超带**。
3. **6.1 smoke 开跑行不印来源**：工作根与诊断确实走了解析器，但开跑行没有 `source=`。
   **改法**：开跑行打印解析出的根与来源（与夹具同一格式）；**红侧**：把打印去掉 → 必须红。
4. **6.2 文档残留**：`references/troubleshooting.md` §25（`:1166`、`:1195`）仍写 `${TMPDIR:-/tmp}` 与「15 GB tmpfs」，`references/migration…` 同样残留。
   **改法**：按新行为改写（默认 `/var/tmp/teamsmith-<ns>`、`source=` 语义、`TEAM_TMP_ROOT=/tmp` 的回退写清）；**红侧**：把任一残留串放回去 → 文档一致性检查必须红（用**稳定 token**，不是整句）。
5. **6.3 全量门禁**：交付前跑一次完整套件（你之前只跑了 112 段闭包）；既有红按 D198 只记录（**不要修**），新红必须归因或修。

## 验收

```bash
bash skills/teamsmith/tests/smoke.sh --select 40
bash skills/teamsmith/tests/tmp-hygiene.sh --self-test
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```
做完把清单里 **3.4 / 5.4 / 6.1 / 6.2 / 6.3** 五格勾上（带证据），notify pm；**复验换人**。
