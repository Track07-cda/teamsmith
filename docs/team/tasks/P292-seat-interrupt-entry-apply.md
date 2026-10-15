# P292 · 「打断席位长回合」入口：apply

task: P292
agent: dev3
phase: apply
category: code
change: seat-interrupt-entry
specs: boundary
deltas: -
branch: task/P292-seat-interrupt-entry-apply
deps: P291（提案已 ACCEPTED 并入 main，见 `docs/team/reviews/seat-interrupt-entry-proposal.md`）

## 范围与硬约束

合同以 `openspec/changes/seat-interrupt-entry/` 为准（两条要求、十个场景）。**我的准入条件**：

1. **对象证明链照写**：名册 → 记录里的窗口 → pane → pid → **身份与启动时刻**；链上任一步不成立就**拒绝、不发信号**。**不许**按名字、按父子、按进程组。
2. **`--print`/计划态一个信号都不发**；**被拒绝的打断不写审计行**；**审计**一行一打断、字段与打断前读数一致（`session_last`、`uncommitted` 必须是发信号**之前**读的）。
3. **理由必须写进席位的阅读顺序**（收件箱/线程），并保证续跑后它读得到。
4. **红侧逐条**（各给「破坏 → 红点名 → 还原 → 绿」）：① 计划态零信号；② 授权打断 → 审计一行且字段正确；③ 对象不再是那个进程 → 拒绝；④ 正在写盘的席位 → 拒绝并点名（`--force` + 理由可越过且审计记 `forced`）；⑤ 理由落在席位的阅读顺序；⑥ **工作树逐字节不变**（造一个未提交文件，打断后检查仍在）；⑦ 读命令不写任何东西；⑧ 跨项目/非本队席位 → 拒绝并给出该走的路。
5. **写集串行**：`tests/smoke.sh` 与两张 tsv 此刻归门禁锁那条变更与 tmux 身份那条；交付前 `git merge main`，冲突按双方保留，语义冲突停下报我；合并前逐条看「本次相对 main 的删除行」。
6. **不改**：`resume`/`teardown` 的既有语义、死因词表、名册/面板显示、`long-job-suspend` 的车道机制。
7. **文本类不设门禁**（D170）：说明行用语稳定短语 + 行为红侧。

## 验收（贴真实输出）

```bash
bash skills/teamsmith/tests/seat-interrupt.sh                 # 你自己的新夹具（无参数即全组）
bash skills/teamsmith/tests/seat-interrupt.sh --flip          # 逐条红侧
bash skills/teamsmith/tests/smoke.sh --select <选段闭包打印的段号>
bash skills/teamsmith/tests/section-select.sh --paths $(git diff --name-only main...HEAD | tr '\n' ' ')
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/spec-refs.sh --check
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```

## 交付

`docs/team/reports/P292-dev3.md`（逐条 scenario 对照、命令与 rc、八条红侧前后证据、未做项）；不合并、不推送；做完 `team notify pm`；随后由**没写过本变更**的席位独立复验（要自己造一个真在跑的长回合替身）。
