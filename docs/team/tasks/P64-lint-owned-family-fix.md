# P64 · 小收尾：`container-tmux.sh` 的指纹检查临时根不在 owned 家族（P53 lint 逮到）

```
task:   P64
agent:  （等席位）
issue:
change: -                            # 无 change：这是既有夹具对 P53 新 lint 的合规修正（infra）
specs:  -
phase:  apply
anchor: none (infra) — 修正既有夹具的临时根命名以符合 P53 的 owned 家族规则，不改契约
deltas: -
grant:  skills/teamsmith/tests/container-tmux.sh
deps:   P53（lint 规则）· P61 的 F3（现场：`container-tmux.sh:159/215` 用 `fpcheck.XXXXXX`）
status: todo（等席位）
budget: 极小（一行级）
```

> 本地模式：不 push。

## 要做的

`tests/container-tmux.sh` 的指纹检查用 `mktemp -d "${TMPDIR:-/tmp}/fpcheck.XXXXXX"`——
名字不在 P53 的 owned 家族里，`tmp-hygiene.sh --lint` 报 finding（FAST/全量各 `✗1`，base 树同红）。

1. 改成经 `tests/lib/tmp-root.sh` 创建（或至少用 owned 家族名 `teamsmith-<kind>.XXXXXX`）；
2. 保持行为不变（指纹检查的四条腿仍绿）；
3. **红侧**：改回 `fpcheck.XXXXXX` → `--lint` 必须红并点行；
4. 验收：`bash skills/teamsmith/tests/tmp-hygiene.sh --lint` rc=0；`TEAM_SMOKE_FAST=1 … smoke.sh` 全绿
   （那条 `✗1` 必须消失）；`container-tmux.sh --fingerprint-check` 仍绿。
