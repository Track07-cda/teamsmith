# P275 · 启动自愈：文档只说真话（清单 5.2）

task: P275
agent: dev-bob
phase: apply
category: code
change: startup-self-heal
specs: init-skill
deltas: -
branch: task/P275-self-heal-docs
deps: P261（已并入 main）、P271（清单已勾 26/30，唯一缺口就是本条）

## 要做什么

清单 5.2（`openspec/changes/startup-self-heal/tasks.md:74`）是这次变更**唯一未勾的交付项**——它是「文档只说真话」的最小修正，不是可选项：四处还写着「只能走 `team config upgrade-models`」，而现在**启动事务（`team up`）也能做**这件事，文档说了假话。

改这四处（把「只能走手工事务」改成「启动事务或手工事务」）：

1. `skills/teamsmith-init/SKILL.md`
2. `skills/teamsmith-init/references/bootstrap.md`
3. `skills/teamsmith/references/config.md`
4. `skills/teamsmith/references/workflows.md`

外加：`skills/teamsmith/references/migration.md` 的 §5b 与升级步骤同步（形状表结构写清楚：迁移表一行一条 `from`/`to`/transform、`TEAM_CONFIG_VERSION` 的含义与「高于已知版本直接拒绝」这条）。**完整重写留给 P255**——本条只做「不说假话 + 不误导」的最小修正。

## 判据（可证伪）

- `grep -rn 'upgrade-models' skills/teamsmith*/` 里**不再有**「只能走手工事务」这类句子（残留的旧话要么改对、要么删）；
- 四条路径各自给出 `before → after` 的 diff（只贴相关几行）；
- **不改**：帮助面（`cmd-help.sh`/`strings/*`，P260 已并入）、`references/protocol.md` 的 §4b、`cmd-config.sh` 的行为；
- 与在飞任务串行：`tests/smoke.sh` 与两张 tsv 此刻归 P264/P274；本条**只动文档**，不碰它们；交付前 `git merge main`。

## 验收（贴真实输出）

```bash
grep -rn 'upgrade-models' skills/teamsmith*/ | head -20
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/spec-refs.sh --check
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```

交付后**自己把清单 5.2 勾上并补证据指针**（本条的交付物就是它），写 `docs/team/reports/P275-dev-bob.md`，notify pm。
