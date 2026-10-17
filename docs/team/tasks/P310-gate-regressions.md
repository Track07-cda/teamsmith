# P310 · P288 引入的两处门禁回归（socket 超长 / 嵌套 review 排到自己祖先）

task: P310
agent: dev3
phase: apply
category: code
change: -
anchor: none (infra) — 门禁基建回归；来源 P288 的 `6f1ed69d`
deltas: -
branch: task/P310-gate-regressions
deps: P288/P305（已并入）｜P297 的报告（`docs/team/reports/P297-dev3.md` 的 §两条回归）

## 两件（都已由你复现，我做时要重跑确认）

**① §0i ✗3：私有 socket 路径超 AF_UNIX 上限。** `tmp-root.sh:178` 把临时根名改成 `teamsmith-<kind>-<ns>.XXXXXX`；§0i 的夹具给嵌套门禁套一层 `TMPDIR=$TMP/case-<name>`，于是 socket 到 **126 字节 > 107** → 隔离前置硬停 exit 2 → 三条用例拿不到收尾指纹（`✓2 ✗3`）。
**改法**：socket 路径不能靠临时根的长度，改为**在临时根之外**取一个短目录（例如 `$TMPDIR/.s/<短哈希>` 或 `/tmp/.tm-<pid>` 这类**固定短前缀 + 唯一后缀**），并给一条断言钉住「socket 路径 ≤ 107 字节」；**红侧**：把 socket 放回临时根下 → 必须红并点名长度。

**② §10：嵌套 review 排到自己祖先后面。** `6f1ed69d` 让「已由祖先持有锁」不再靠可继承的环境标记（那是 F4 的正确修法），但 `cmd-review.sh:1099` 仍靠那个标记走「不排队」→ 嵌套 review 于是**排在祖先前头**（永久等待）→ 段预算 60s 超时。
**改法**：`cmd-review.sh` 改成用 **P281 已有的「沿进程树 + starttime 证明祖辈持有锁」**那条判据（`gate_lock_*` 里已有实现），**不再看环境标记**；**红侧**：① 把判据改回看标记 → 嵌套现场必须复现排队超时；② 造一个「祖辈并未持锁」的普通运行 → 必须照常排队（不许因为「有祖先」就跳过排队）。

## 硬约束

- **不许**放宽 F4（写权不可继承）——修的是「读判断」，不是把标记恢复成可继承。
- 两处都要**新增断言**（socket 长度上界、嵌套不排队但非祖辈仍排队）。
- 交付验收：`--select 0i`、`--select 10` 各自绿；`--select 34,34b,34c,34d`（P288 的面）不回退；报「测试状态」在前。

## 验收

```bash
bash skills/teamsmith/tests/smoke.sh --select 0i
bash skills/teamsmith/tests/smoke.sh --select 10
bash skills/teamsmith/tests/smoke.sh --select 34,34b,34c,34d
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```
