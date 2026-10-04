# P75 · `team status` 的尾部现场来源：成片空行把画面吃光（P65 的 F1）

```
task:   P75
agent:  dev3
issue:
change: -                        # 无 change：P65 的 F1 收尾（读取器对"尾文件"来源做尾空行裁剪）
specs:  -
phase:  apply
anchor: none (infra) — 修正读取器对既有文件来源的呈现，不改契约（若你论证它是契约面，写清理由并改走 change）
deltas: -
grant:  skills/teamsmith/scripts/lib/cmd-status.sh · skills/teamsmith/tests/smoke.sh（append-only）· skills/teamsmith/references/troubleshooting.md（一句，若需）
deps:   P65 的 F1（`reviews/P65.md`）· P55（same 面）
status: todo
budget: 小
```

> 本地模式：不 push。

## 现场（P65 实测）

`team status <ID>` 的**第三层来源**是 `state/dispatch-<agent>-tail.txt`；当 `TEAM_AGENT_SCENE_LINES=3` 时，
它打印"**来源在但没有画面内容**"——因为 tmux 的 capture **末尾是成片空行**，
读取器按字面取"最后 N 行"就只剩空行。默认 40 不受影响（行数够多）。

## 要做的

1. **读取器对该来源做尾空行裁剪**（或其他等效做法：取"最后 N 行**非空**行"），使 `SCENE_LINES=3`
   也能给出有内容的画面，并且**声明要说清**（"最后 N 行（去尾空行）"之类的可读措辞）；
2. **边界**：① 只有空行 → 明确说"来源里没有可读内容"（不是静默空块）；② 行数不足 N → 给现有的全部；
   ③ **不许**改死 pane 现场（第一层）与 `dispatch-<agent>-pane-dead.txt`（第二层）的既有语义；
3. **可证伪**：造一个尾部带 5 行空行的 tail 文件 + `TEAM_AGENT_SCENE_LINES=3` → 改前"没有画面内容"（红侧）、
   改后有 3 行内容（绿侧）；只有空行的文件 → 明确"没有可读内容"；
4. **零回归**：`smoke` FAST + 全量（当前 main 可能有**已知**红 `12b-j`（P73）——点名区分）。

## Acceptance

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
```
