---
id: P404
title: 给两处规格点名的声明面补上会变红的断言
agent: dev2
category: code
phase: apply
change: instruction-context-slimming
specs: init-skill
anchor: openspec/changes/instruction-context-slimming/specs/init-skill/spec.md
deltas: init-skill
branch: task/P404-declaration-guards
---

# P404 · 没有断言的"必须存在"是一句话

## 事实（V125 实测，PM 复述）

`instruction-context-slimming` 的规格点名两处声明面必须存在：

1. 双门禁分工——每次改动判正确性、发布前读一次性能，附可复制命令，正确性门禁里不留墙钟红线（现在在 `SKILL.md` 与 `references/protocol.md`）；
2. `SKILL.md` 的 `## Agent adapters` 小节、frontmatter `description`、深读表那一行，且所有非 Pi 提法保留冻结 seam 措辞。

V125 把"删掉双门禁那句"和"把 seam 措辞改成禁语"两个变异分别放到**改动前后**的树上，门禁都还是绿的——这两处**没有任何断言守着**。P403 里的内容是对的，但"规格要求它存在"目前不可证伪。

## 要做的（窄，且是净零）

1. 在**已有的**那个断言文件与段里加断言（不要新开段、不要新守卫层）：
   - `SKILL.md` 与 `references/protocol.md` 都含双门禁分工的实质句子（必须能在正确性门禁段落里断言"没有墙钟红线"这一点，而不是只查两个关键词在不在）；
   - `SKILL.md` 含 `## Agent adapters` 小节与深读表行，frontmatter `description` 非空，且每个非 Pi 提法都带冻结 seam 措辞。
2. **净零**：新增断言必须替换掉同文件里一条已被更强断言覆盖或已无意义的旧断言（在报告里点名替换了哪一条）；找不到可替换的，就在报告里写一句"为什么产品自己不能承载这条行为"——二选一，不许两头都不做。
3. 红侧必须给：删掉双门禁那句 → 红；改掉 seam 措辞 → 红；删掉 adapters 小节 → 红。三次都贴命令与输出，还原即绿。

## 验收（自己跑，贴 rc 与输出尾）

- `bash skills/teamsmith/tests/smoke.sh --select 19,39 </dev/null`
- `bash skills/teamsmith/tests/spec-refs.sh --check`、`section-select.sh --check`、`ledger-ban.sh --names-file .pi/team/forbidden-names.txt`、`git diff --check`
- `openspec validate --all --strict`（`~/.cache/openspec-1.8.0/node_modules/.bin/openspec`）
- 报告 `docs/team/reports/P404-dev2.md`，提交推分支，通知 PM。

## 边界

- 只改测试断言与（必要时）`section-paths.tsv` 那一行的声明；**不改** `SKILL.md`/`references/` 的正文措辞（它们已经对了）。
- 不跑全量 smoke、不合并/归档/发布。
- 本机 `openspec init --tools pi` 生成的 `.pi/skills/*` 是机器面，若缺失请重新生成而不是把它们提交进仓库。
