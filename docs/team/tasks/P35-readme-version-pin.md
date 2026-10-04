# P35 · README 的安装示例版本 pin 修好，并让它不再过期（版本一致性检查扩容）

```
task:   P35
agent:  dev
issue:
change: -
specs:  -
phase:  apply
anchor: none (infra) —— 文档里的版本 pin 与"版本一致性检查"（工具面；用户 2026-09-22 批准修复）
deps:   M38（版本一致性检查：四处 → 五处）· v1.42.0
status: todo
budget: 小（一个提交 + 一条断言）
```

> 本地模式：不 push。

## 问题（用户 2026-09-22 批准修）

`README.md` §Install 的两条示例 pin 写着 **`@v1.40.0`**，而仓库最新 tag 是 **v1.42.0**——
文档自己在撒谎（旁边那句"Latest tag: `git tag --sort=-v:refname | head -1`"救不了示例本身）。

## 要做

1. **改示例**：`README.md` 的 `pi install git:…@v1.40.0`（两条）→ **当前版本 `@v1.42.0`**；
   同节里出现的其它版本数字（若有）一并对齐（以 `package.json` 的 `version` 为准）。
2. **让它不再过期（机制，不是承诺）**：把 README 的这份 pin 纳入既有的**版本一致性检查**
   （M38 建的那处；先 `grep -rn "version" skills/teamsmith/tests/*.sh | grep -i consist` 找到它，
   它现在比对四个/五个位置）。要求：
   - 断言 **README 里 `git:git@github.com:Track07-cda/teamsmith@v<X.Y.Z>` 的 `<X.Y.Z>` 与
     `package.json` 的 version 相等**；不等 → 红并**点名两处**（README 行号 + package.json）；
   - **翻转**：把 README 的 pin 改成 v0.0.1 → 断言红（贴原始输出）→ 还原 → 绿。
3. **顺带**：`docs/team/PUBLISH.md`（发版清单）加一条"发版时同步 README 的示例 pin"，与上面那条检查互相印证。

## 边界

- 只碰 `README.md`、既有的版本一致性测试（`skills/teamsmith/tests/` 里那一处）、`docs/team/PUBLISH.md`；
- **不改**版本号本身、不动 `install.sh`、不动任何安装语义；
- 不 push；不改 `docs/team/` 里 PM 的台账（PUBLISH.md 除外——它就是要改的那份清单）。

## Acceptance

```sh
bash skills/teamsmith/tests/<版本一致性那个脚本>.sh    # 绿；把 README pin 改坏 → 红
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
```

## Deliverables

- 改动 + 翻转证据 + 报告 `docs/team/reports/P35-dev.md`（含改前/改后的 README 行、断言红/绿的原始输出）。
