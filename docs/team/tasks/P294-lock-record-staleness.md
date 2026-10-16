# P294 · 门禁锁记录在**新持有者接手**时必须重写（已合并代码的缺陷）

task: P294
agent: dev3
phase: apply
category: code
change: -
anchor: none (infra) — 门禁资源的可归因性；`gate-lock-hygiene` 已归档，故按规矩**新开**而不是改归档目录
deltas: -
branch: task/P294-lock-record-staleness
deps: P281（已并入，含 `gate_lock_*` 的记录读写）｜现场见 `docs/team/DECISIONS.md` D191

## 现场（PM 实测，读的是内核事实）

```
/proc/locks        ：锁文件 inode 33995889 由 pid 160298 持有；pid 2247100 在等
lock.holder（记录）：pid=599698  started=…  agent=dev3  expected=9581  …   ← 599698 已不存在
```

**缺陷**：新持有者接手时（正常排队接手，以及「原持有者已死 → 可接管」那条路径）**没有重写记录**，于是等待者读到的是**已死的持有者**，看不到「是谁、还要多久」——而可归因正是那条变更的目的。

## 要做什么

1. **接手即重写**：任何一次成功获取锁的路径，都要把记录重写成**当前**持有者的那一份（`kind/agent/worktree/started/expected/bound/sections/heartbeat` 全字段）。
2. **死 pid 可见**：读取侧发现记录里的 pid **已不存在**（或 `starttime` 不匹配 = pid 复用）时，**必须把它标出来**（一行「记录的持有者已不在；当前持锁者未知/正在接手」之类），不许让等待者把它当成当前持有者。
3. **红侧**：① 造「陈旧记录 + 新持有者」的现场 → 接手后记录**必须指向当前持有者**；② 造「记录指向死 pid」→ 读取侧**必须点名**；③ 回归：正常单层运行的排队语义、嵌套运行的预算约束、`kind=nested/top` 与等待者归因**不许回退**。
4. **写集**：只动门禁锁那几个文件（`lib/gate-lock.sh` / `tests/lib/section-guard.sh` / `smoke.sh` 的锁块）——**交付前 `git merge main`**，与在飞的其他测试面写者串行。
5. **交付验收只跑闭包选段**（这次的教训：你的全量运行让别人的选段排队两小时）；全量留给合并/归档。

## 验收（贴真实输出）

```bash
bash skills/teamsmith/tests/section-select.sh --paths $(git diff --name-only main...HEAD | tr '\n' ' ')
bash skills/teamsmith/tests/smoke.sh --select <上面打印的段号>
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```
