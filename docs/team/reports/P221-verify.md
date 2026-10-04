# P221 · P217 executing / mentioning 独立复验

agent: verify   status: PASS   time: 2026-10-04
branch: `task/P221-verify`   PR/MR: -（local 模式）

## Deliverables

| Path | What |
|---|---|
| `docs/team/reports/P221-verify.md` | 独立复验记录 |
| `docs/team/reports/P221-verify/` | 独立脚本与原始日志；按 D94 忽略，仅留工作树 |

被验树：`1aba8e89`，包含实现 `085713e2`。仅改自己的报告与证据，不改产品实现。

## Verification evidence (must have actually been run)

### 容器 live 选段门禁（自己跑）

独立快照由 `git archive 1aba8e89` 解包，再 `git init` / commit 成普通仓库；没有把 worktree 的 `.git` 指针挂进容器。

```bash
PKG="$PWD/docs/team/reports/P221-verify"
distrobox-host-exec podman run --rm --pid=host --cgroups=enabled --userns=keep-id \
  -e HOME=/tmp -v "$PKG/.snapshot:/work" -w /work localhost/teamsmith-gate:local \
  bash -c 'git config --global --add safe.directory /work;
    openspec validate --all --strict &&
    env -u TEAM_SMOKE_FAST bash skills/teamsmith/tests/smoke.sh --select 41 </dev/null'
```

```text
Totals: 13 passed, 0 failed (13 items)
41 · pane 留存 · ✓96 ✗0 SKIP0
账本自查：6 段收口 · 增量 ✓158 ✗0 SKIP0 ｜ 结果行 ✓158 ✗0 —— 一致
== 选段结果 == ✓ 158 ✗ 0
exit=0
```

- 日志：`docs/team/reports/P221-verify/logs/gate.log`。
- `section-paths.tsv` 的 41 行 `needs=2`；本次实际执行 `0 / 0b / 0c / 0d / 2 / 41`，无前提级联。
- 非 FAST，§41 的 live 进程 / pane / dispatch / resume 断言确实运行，没有 SKIP。
- 没跑其余 119 个选段键；完整清单见日志头尾。本次不是全套门禁，不能据此声称全树全绿。

### 独立七形状与端到端（自己跑）

使用自己的 `p221-seat-engine`：bash 脚本打印就绪 PID，然后循环执行 `read -t 10`。它没有子进程，① 能明确区分“pane 自己执行 agent”与“仅子进程可作证”。没有复用 `p55-agent` 或 `flip-p217`。

```bash
set -o pipefail
PKG="$PWD/docs/team/reports/P221-verify"
distrobox-host-exec podman run --rm --pid=host --cgroups=enabled --userns=keep-id \
  -e HOME=/tmp -v "$PKG/.snapshot:/work:ro" -v "$PKG:/evidence" -w /work \
  localhost/teamsmith-gate:local bash /evidence/run-probe.sh \
  2>&1 | tee "$PKG/logs/probe.log"
```

| 形状 / 席位 | 实测进程树 | `status <ID>` | `resume --dry-run --agent <seat>` |
|---|---|---|---|
| ① `bash <agent>` / direct | pane 自己执行脚本，无子进程 | 在跑 | 不列可续跑；在跑 1 个 |
| ② `bash -lc <agent>` / last | bash 优化为①，同样无子进程 | 在跑 | 不列可续跑 |
| ③ `bash -lc '<agent> & wait'` / background | `bash -lc` 父 + agent 直接子进程 | 在跑 | 不列可续跑 |
| ④ `respawn-pane … bash -lc '<agent>; :'` / harness | `bash -lc` 父 + agent 直接子进程 | 在跑 | 不列可续跑 |
| ⑤ `bash --noprofile --norc -s <agent>` / mention | 父 shell 仅提到脚本路径，从 stdin 跑非 agent 循环；无 agent 子进程 | 已退出 | 列为可续跑 |
| ⑥ 不含 agent / unrelated | `bash --noprofile --norc`，无 agent 子进程 | 已退出 | 列为可续跑 |
| ⑦ 遗体 / corpse | remain-on-exit，`pane_dead=1`，status=7，pane PID 已不存在 | pane 已死 | 列为可续跑 |
| 额外真实 `team dispatch` / prod | 产品生成 harness，父 + agent 直接子进程，cwd 在该夹具 worktree | 在跑 | 不列可续跑 |

每一行都调用了真实 CLI 的 `status` 与 `resume --dry-run`，不是仅调底层函数；前后 pane PID/dead 未改变。判据严格匹配 `座位 <seat>：` 行，避免全局 roster / 图例干扰。各席位的完整双命令输出见 `logs/baseline-*-{status,resume}.log`；原始 argv/PPID/cwd 见 `logs/tree-*.log`。

```text
PROBE PASS baseline=8/8 shadows=2/2 restored=2/2
exit=0
```

### §41 与生产同形证明（自己跑 + 引用代码明确区分）

- **引用代码**：`smoke.sh:16480` 左右的 `p55live` 用 `new-window … bash -lc '<agent>; :'`；`cmd-agents.sh:1288–1299` 的生产启动先持窗并读回 remain-on-exit，再 `respawn-pane … bash -lc "$inner" "$prompt"`。`inner` 包含 agent 前的 spawn、agent 后的退出事件和尾屏采集，末尾 `exec bash`。
- **自己跑的证明**：用自己的 engine 逐字复刻 §41 的 `new-window` 形状（fixture）；另起要求④的 `respawn-pane`（harness）；再通过真实 `team dispatch prod T221.8 … --branch task/T221.8-prod` 运行产品生成的 harness。`production-dispatch.log` 的启动校验是 `proof=spawn pid=2569154`。
- `check-tree.py` 独立解析实测 ps/PPID，不只比较启动字符串：fixture 的 pane=2569280、agent 子=2569286；harness 的 pane=2568742、agent 子=2568748；生产 dispatch 同样是 `bash -lc` 父 + agent 直接子进程。三者均通过拓扑断言。
- **差异如实保留**：夹具使用 new-window、cwd=项目根、agent 后只有 `:`；生产使用 respawn-pane、cwd=本席位 worktree，包含身份前缀、spawn/exit 文件、shim、尾屏与提示词 argv[0]。它们不是完整命令逐字一致；但与存活判据有关的父子关系同形，且后续语句都阻止最后一条命令的 exec 优化。cwd 两种都属于同一夹具项目。

```text
TREE PASS seat=fixture own=1 direct-agent-children=1
TREE PASS seat=prod own=1 direct-agent-children=1
TOPOLOGY PASS fixture(new-window) == harness(respawn) == production(dispatch): bash -lc parent + direct agent child
```

## Flip evidence

影子只改 `P221-verify/.scratch/variants/` 内的产品副本，原快照挂载只读；两条影子都对同一批活进程重跑全部八行双 CLI 检查。

1. **放宽为“提到就算执行”**：将 `team_agent_alive_in_pane` 的 pane-self 调用从 `team_proc_executing_bin` 换成 `team_proc_cmdline_is_bin`。⑤ 从已退出 / 可续跑翻为在跑 / 不可续跑；另外七行仍通过，⑥ 没有被无条件判活。
2. **收紧为仅直接子进程**：只禁用 pane-self execution 分支，保留原子进程扫描。① 从在跑 / 不可续跑翻为已退出 / 可续跑；② 因 exec 优化与①同形，也红。③④和真实生产 dispatch 仍绿，说明没有把所有活进程一概判停。
3. **恢复**：重新调用只读原快照 CLI，①与⑤再次同时通过；实际 agent 的 PID 从影子前到恢复后都未改变。

```text
FAIL variant=broad seat=mention expect=stopped actual=running pid=2568745
SHADOW-ACCEPTED variant=broad red=1 targets= mention
FAIL variant=children seat=direct expect=running actual=stopped pid=2568716
FAIL variant=children seat=last expect=running actual=stopped pid=2568721
SHADOW-ACCEPTED variant=children red=2 targets= direct last
PASS variant=restored seat=direct expect=running actual=running pid=2568716 read-only=unchanged
PASS variant=restored seat=mention expect=stopped actual=stopped pid=2568745 read-only=unchanged
```

两种错误对实际 `resume --dry-run` 的影响也已量出：broad/mention 印“没有需要续跑的 agent（在跑 1 个）”；children/direct 印“direct 可续跑：T221.1”。影子验收器仅当红侧精确命中预定席位且其余绿侧保持时 exit=0；因此总脚本成功表示洞被抓住，不表示被破坏的产品通过了断言。

## Decisions and deviations

- 任务书要求选段 live 门禁；按此执行，不把历史全套结果冒充本次结果。**没有运行全套 smoke 或原作者的 flip-p217**；七形状、双 CLI、拓扑、影子和 live §41 都由我本次运行。未引用原作者/PM 的通过结论作为验证证据。
- 两次验证脚本自错已纠正并留痕：首次把 status 全局图例的“在跑”误归给停跑席位；第二次假设 children 影子仅①红，实际②因 exec 优化也必须红。原始输出保留 `logs/attempt1-validator-error/` 与 `logs/attempt2-shadow-expectation/`，最终完整重跑通过，不将这两次错归为产品缺陷。
- 按 D94，只有本报告入 git，脚本/日志留 ignored 证据包。可重建的快照和夹具副本收尾删除，README 保存完整重建命令。
- Verdict: **PASS（P221 范围）**。没有发现需返工的产品问题。选段结论不外推到未跑的 119 个键；本次没有实际 respawn 一个正在工作的共享席位，仅在隔离夹具运行真实 dispatch 并观察 dry-run。

## Suggested next steps

- PM 可复跑证据包 `README.md` 中的命令，并核对本报告后完成 P221 收尾。本地分支留待 PM 合并；无 push/MR、无共享席位改动。
