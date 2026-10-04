# P47 · ledger-and-gate-noise apply：指纹只由稳定状态构成 + 记录扫到 worktree + 空 override 与 JSON 契约

```
task:   P47
agent:  dev-bob
issue:
change: ledger-and-gate-noise            # 提案已验收：docs/team/reviews/ledger-and-gate-noise-proposal.md（ACCEPTED）
specs:  verification#The container self-test's host fingerprint is stable state, and only a real host change moves it / board-and-status#Unfinished work is visible as pending wrap-up / memory-and-deps#Every machine read is a JSON document, and an empty value is a value
phase:  apply
anchor: change
deltas: verification, board-and-status, memory-and-deps
grant:  tests/container-tmux.sh · scripts/lib/cmd-status.sh · scripts/lib/common.sh · scripts/lib/cmd-config.sh · tests/smoke.sh（append-only）· tests/config-cli.sh · tests/panel-choices.sh（仅回归核对，必要时补断言）
deps:   P43（propose，已合并）· D34/D37（事故与规矩）
status: todo
budget: 一个工作块（三批：① 指纹 ② 记录可见性 ③ 空 override/JSON）
overlap: ⚠️ **P40（dev2，npm 安装形态）同时在飞**且也会 append `tests/smoke.sh` 与碰 `scripts/lib/cmd-config.sh`：
         你的新段**加在文件末尾**、小步提交；合并冲突由 PM 解决，不要为了避让而改别人的段。
```

> 本地模式：不 push。**真源 = `openspec/changes/ledger-and-gate-noise/tasks.md`（1.1–1.4 / 2.1–2.3 / 3.1–3.5 / 4.x）
> 与 `design.md` D1–D4**——按它们做，别凭本简述发挥。

## 三批的要点（细节看 tasks.md）

1. **指纹**（`tests/container-tmux.sh:102` 重写 `host_tmux_fingerprint()`）：只由**真实 host 变化才会动的**事实构成
   ——**范围内每个 socket** 的磁盘身份 + 该 socket 上 **server 的会话表** +（有 server 应答时）**它的 pid**；
   **客户端/门禁 shim/`team` 命令/命令行里提到 tmux 的进程**都必须让它**逐字节不变**；范围外（别的项目的私有
   fixture server）**不得进入**；读取**只读、不得起 server**；不一致时**两个值都打印**并非零退出。
   另加 `--fingerprint-check`（两面粉丝：客户端风暴 → 不变；杀范围内 server → 变；真实会话变化 → 变）
   与 `smoke.sh` §31c 的接线。**isolation lint** 也要过（新夹具的 server 调用必须带隔离证明）。
2. **记录扫到 worktree**（`cmd-status.sh:497`）：主检出 + **每个 worktree**；worktree 的**复验记录**与
   **报告包内文件**都要点名（P36 那次的形状）；`smoke.sh` §7b/§37 补夹具。
3. **空 override 与 JSON**：`common.sh:1174` 的空 token 解析同"未设"回退；`cmd-config.sh` 的
   `IFS=$'\t' read` 站点（`:661` 等）改成**字段安全读**（前导 tab 不许被当分隔空白吃掉）；
   所有机器出口（`config list --json`/`change status --json`/`paths`/`monitor --json`/`__panel-data`）
   对**门禁练过的每种契约形状**必须**恰好一份可解析 JSON**（`python3 -m json.tool`），失败**点名命令与位置**；
   顺带核对 `models.known` 不再被来源标签污染。

## 必给的翻转（红→绿原始输出）

- 旧指纹函数 + 客户端风暴 → `DIFFER`；新函数 → 逐字节一致；
- 新函数 + 杀掉范围内 server → 值变；**真实会话变化 → 值也变**（前提是对的东西）；
- worktree 里的复验记录：改前 `grep -c` = 0，改后可点名；报告包内文件同样；
- `TEAM_AGENT_MODELS=dev=` 改前 `json.tool` 报 `Expecting value …`，改后可解析；
- 还原后 `git status --porcelain` 干净。

## Acceptance

```sh
bash skills/teamsmith/tests/container-tmux.sh --fingerprint-check
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
bash skills/teamsmith/tests/smoke.sh </dev/null          # 交付前全量
# 试归档（scratch 副本）
cp -r openspec /tmp/trial-p47 && (cd /tmp/trial-p47 && openspec archive -y ledger-and-gate-noise)
```

## Boundaries

- 只碰 `grant:` 列出的路径；**不改** change 的 delta 文本；矛盾 → `BLOCKED:` 交回 PM；
- 不 push；不改 `docs/team/**`（报告除外）。

## Deliverables

- 实现 + 四组翻转原始输出 + 试归档结果 + 报告 `docs/team/reports/P47-dev-bob.md`。
