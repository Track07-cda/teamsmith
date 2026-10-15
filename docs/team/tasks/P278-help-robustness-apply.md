# P278 · 帮助面收尾（宽度与 locale 解耦、入口清单、可达性、占位符红侧、拒绝语去黑话）：apply

task: P278
agent: dev
phase: apply
category: code
change: help-robustness
specs: help-surface
deltas: -
branch: task/P278-help-robustness-apply
deps: P272（提案已 ACCEPTED 并入 main，见 `docs/team/reviews/help-robustness-proposal.md`）

## 范围

实现已接受的 `openspec/changes/help-robustness/`（2 MODIFIED + 1 ADDED），按 `tasks.md` 的 0–7 节执行。PM 复核时把五个裁定点全部按推荐裁掉：

1. **归档已提交**（我在复核前补提交了那批归档）——**开工先 `git merge main`**，否则 MODIFIED 的基线不在你的树里。
2. **O7 收进本变更**：CLI 拒绝语里的行话（`cmd-config.sh` 的「只读键」等）改成普通话；同批检查同一族提示。**措辞由评审把关、不设门禁断言**（D170）；行为判据是「拒绝仍发生、退出码不变、提示里含配置文件路径」。
3. **§51 的路径登记补 `cmd-config.sh`**（真实的门禁覆盖缺口：改它不会重跑跑它的那段）。改完用 `section-select.sh --paths skills/teamsmith/scripts/lib/cmd-config.sh` 复核 §51 在选集里，并跑 `section-needs-audit.sh`。
4. **O6 的「卫生」半条收进来**：选段器对**未知/过期段名**必须拒绝（今天 `--select nosuchsection` 静默 rc=0、`✓0 ✗0`）——这是假绿口子，给红侧。
5. **O1 的宽度上界留在门禁**：它是宽度旋钮的定义（声明折到 N 格就必须折住），不是排版偏好。

## 不变量（apply 与 verify 都要核）

- 命令名/旗标名/退出码、`--print`/`--json` 字节、语言机制、面板：**一个不改**。
- **不恢复** `layout` 组；Walk A 的强度与解析器规则、承诺探针、控制臂、既有 10 条翻转：**一条不动**。
- 新要求只到**行为**（同输入在任何 locale 下逐字节相同、合法 UTF-8、行不超宽）；措辞、缩进阶梯、页面深度、小节顺序仍由评审把关。

## 红侧（逐条：破坏 → 指定用例红 → 还原 → 绿）

1. 把渲染器的宽度计算换回 locale 相关实现（`wcwidth`/`wc -L`/按字符索引展开）→ 非 UTF-8 locale 的逐字节比对与宽度用例必红；
2. 内部入口（`__panel-data`/`__inbox-write`）从封闭清单里放走一个 → 红；
3. 可达性断言（每个分组都被菜单点到）删掉 → 红；
4. 清单里塞一个未声明的占位符 → 渲染器判红并点名；
5. 选段器对未知段名不拒绝 → 红。

## 验收（贴真实输出）

```bash
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/help-surface.sh --all
bash skills/teamsmith/tests/routes.sh
bash skills/teamsmith/tests/config-cli.sh list validate roster
LC_ALL=C bash skills/teamsmith/tests/help-surface.sh --all      # 非 UTF-8 下同一条命令
bash skills/teamsmith/tests/section-select.sh --paths $(git diff --name-only main...HEAD | tr '\n' ' ')
bash skills/teamsmith/tests/smoke.sh --paths $(git diff --name-only main...HEAD | tr '\n' ' ')
bash skills/teamsmith/tests/spec-refs.sh --check
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```

## 交付

`docs/team/reports/P278-dev.md`（逐条 requirement 对照、命令与 rc（含 `spec-refs.sh --check` 的 rc，这是 G3 的补做）、五条红侧前后证据、未做项）；不合并、不推送；做完 `team notify pm`；随后由未参与实现的席位独立复验。
