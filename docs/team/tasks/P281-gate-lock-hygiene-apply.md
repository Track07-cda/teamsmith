# P281 · 门禁锁卫生：嵌套运行不排队 + 持有者记录 + 嵌套预算

task: P281
agent: dev-bob
phase: apply
category: code
change: gate-lock-hygiene
specs: verification
deltas: -
branch: task/P281-gate-lock-hygiene-apply
deps: P280（提案已 ACCEPTED 并入 main，见 `docs/team/reviews/gate-lock-hygiene-proposal.md`）

## 范围

实现已接受的 `openspec/changes/gate-lock-hygiene/`（1 MODIFIED + 2 ADDED），按 `tasks.md` 执行。PM 复核时的准入条件：

1. **不许去掉锁**；嵌套运行**只有在能证明祖辈持有锁时**才不排队（沿进程树走到 `<lock>.holder` / `<lock>.runs/*.run` 记的持有者 pid，且 starttime 仍是那一次）；证明不了 → 按顶层排队。
2. **三条红侧逐条跑**（§4）：① 造嵌套持有现场 → 等待者一行点名 `kind=nested` + 席位 + 工作树 + 已跑时长 + 上限；② 嵌套超预算（3s 期限 + 永不返回的段）→ 一行点名（段号 + id + 预算 + 实际）并离开现场、注册记录消失；③ 回归：单层运行的排队与「排到了再跑」语义不变。
3. **持有者记录**写 kind / 席位 / 工作树 / 开始 / 已跑 / 上限；等待者的超时文案要能归因（今天那条只写「持有者：smoke.sh」）。
4. **只对夹具自己注册过的 pid 发信号**（对应今天那次「按名字选进程」的事故）。
5. **写集串行**：`tests/smoke.sh`、`tests/section-*.tsv`、`tests/lib/*`、select 包装此刻也被 **P278（帮助面收尾）与 P276（孤儿可见性）** 改；交付前 `git merge main`，冲突按双方保留，语义冲突停下报我；**合并前逐条看「本次相对 main 的删除行」**。
6. **不新增措辞类断言**（D170）：说明行的判定用稳定短语 + 行为红侧。

## 验收（贴真实输出）

```bash
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/gate-lock.sh            # 本变更的夹具（若无此名，用你在 tasks.md 里定的入口）
bash skills/teamsmith/tests/section-select.sh --paths $(git diff --name-only main...HEAD | tr '\n' ' ')
bash skills/teamsmith/tests/smoke.sh --paths $(git diff --name-only main...HEAD | tr '\n' ' ')
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```

## 交付

`docs/team/reports/P281-dev-bob.md`（逐条 requirement 对照、命令与 rc、三条红侧前后证据、未做项）；不合并、不推送；做完 `team notify pm`；随后由未参与实现的席位独立复验。
