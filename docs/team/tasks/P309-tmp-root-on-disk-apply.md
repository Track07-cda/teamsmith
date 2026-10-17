# P309 · 临时根落磁盘：apply（一个解析函数 + 地板绑定 + 迁移/回滚）

task: P309
agent: dev2
phase: apply
category: code
change: tmp-root-on-disk
specs: verification
deltas: -
branch: task/P309-tmp-root-on-disk-apply
deps: P306（提案已 ACCEPTED 并入 main，准入条件见 `docs/team/reviews/tmp-root-on-disk-proposal.md`）

## 范围（合同以 `openspec/changes/tmp-root-on-disk/` 为准）

1. **一个解析函数**：`TEAM_TMP_ROOT` → `TMPDIR` → 平台默认（Linux 上 `/var/tmp/teamsmith-<ns>`，否则 `/tmp`）；**只此一处实现**，夹具 / `tmp-hygiene.sh` / 门禁 / 容器挂载都调它。`TMPDIR` 优先于契约键，**且 pin 被覆盖时要打印出来**（提案里已有这条，别丢）。
2. **余量地板绑定选定的根**：字节与 inode 两条腿都检查**选定根**，报错文案**点名那个根**（今天它硬编码写「临时根 /tmp」）。
3. **迁移与回滚**：默认变化进 CHANGELOG（含升级说明）；`TEAM_TMP_ROOT=/tmp` 可回退。
4. **红侧三条**：① 解析改成各处自算 → 必须红；② 地板检查指回固定 `/tmp` → 必须红（选定根空、`/tmp` 满时不许拒绝）；③ 选定根不可写 → **具名失败 + 修法**，**不许静默退回 `/tmp`**。另加第四条：`TMPDIR` 与 `TEAM_TMP_ROOT` 冲突时**必须打印**用了哪个（提案场景 2）。
5. **不变量**：夹具的隔离/清理/年龄判据不变；门禁判定口径不变；容器里仍是我们自己的根。

## 验收

```bash
bash skills/teamsmith/tests/tmp-hygiene.sh --self-test
bash skills/teamsmith/tests/section-select.sh --paths $(git diff --name-only main...HEAD | tr '\n' ' ')
bash skills/teamsmith/tests/smoke.sh --select <上面打印的段号>
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```
交付后写报告、notify pm；**独立复验换人**（自造「根不可写」「两根都不设」「`TMPDIR` 与契约冲突」三种现场）。
