# P267 · PM 关键结论先发布：apply（把这条义务写进技能）

task: P267
agent: dev2
phase: apply
category: code
change: pm-reply-discipline
specs: key-replies
deltas: -
branch: task/P267-reply-discipline-apply
deps: P257（提案已 ACCEPTED 并并入 main；change 目录在 main 上）

## 范围

实现已接受的 `openspec/changes/pm-reply-discipline/`：proposal、design、tasks、delta（`key-replies` 一条 MODIFIED + 一条 ADDED）。合同以 change 目录为准。要点：

1. **三处表面**：`templates/pm-prompt.md.tmpl`（在 `## Talking to the user` 小节加一段简短可执行的规则：什么时候发——里程碑落地 / 做出裁定 / 请你决策之前；怎么发——`team reply post --from pm --title '<一行标题>' --stdin < <文件>`，正文是完整那份；发完再在对话里发同一份；同一批可合并成一条；只发结论不发过程噪音）、`references/protocol.md` §4b（从「当你有一个值得留存的答复时」改成**常设义务**）、`SKILL.md` 命令表给 `reply` 一行「给用户的关键结论」。
2. **门禁**（`tests/key-replies.sh` 新 `guide` 组）：行为探针（示例命令对拍真解析器、变异红侧）+ 最小语义锚点（义务的存在、指向 `team reply post`），**断言的是「义务的存在」不是「一字不差的措辞」**（D170）。破坏性对照：从模板删掉那段 → 断言红并点名；示例命令写成不存在的旗标 → 红。
3. **不改** `team reply` 的 CLI 行为、存储、面板渲染；不碰 `section-paths.tsv`（P264 的面）。

## 边界

- 与在飞任务串行：`tests/key-replies.sh` 此刻归你（本任务）；`templates/`、`references/protocol.md`、`SKILL.md` 此刻归 P261/P260 的部分在飞——交付前 `git merge main`，冲突按双方保留，语义冲突停下报我。
- 不合并、不推送；做完 `team notify pm`。

## 验收（贴真实输出）

```bash
bash skills/teamsmith/tests/key-replies.sh --select guide
bash skills/teamsmith/tests/key-replies.sh --all
bash skills/teamsmith/tests/smoke.sh --select 62
bash skills/teamsmith/tests/spec-refs.sh --check
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```

## 交付

`docs/team/reports/P267-dev2.md`（逐条对照、命令与 rc、破坏性对照前后证据、未做项）；之后由未参与实现的席位独立复验。
