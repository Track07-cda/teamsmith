# P291 · 给工具加一条「打断席位长回合」的正式入口

task: P291
agent: -
phase: propose
category: analysis
change: seat-interrupt-entry
anchor: none (infra) — 席位生命周期的可见性与可控性
deltas: -
branch: task/P291-seat-interrupt-entry
deps: 2026-10-15 的两次实测（`docs/team/DECISIONS.md` D188）

## 现象（实测两次）

两个席位各自卡在**一个极长的单回合**里：**18 小时**与 **16 小时**没有提交、没有改动工作树里的文件，窗口一直是 `Working`，并反复跑同一组命令；PM 用 `team say` 发的两条消息（其一是**已复现的根因**）**都没有被反应**。

**机制缺口**：投递给席位的消息要**等回合结束**才会被读到（监视通道把唤醒指针写进它的会话，回合不结束就不进上下文）。工具的席位生命周期入口只有 `resume`（给**停了**的席位）与 `teardown`，**没有「打断一个正在跑的长回合」**。PM 当天的处置是**手动结束进程再 `resume`**（已记入账本：这是绕过 CLI 的动作）。

## 要做什么

1. **正式入口**（名字你定，例如 `team interrupt <seat> [--message <文本>]`）：
   - 语义写清：**结束该席位的当前回合**（进程级），**保留**磁盘状态（未提交改动、会话文件、记录），随后（或由 `resume`）**重新进入同一会话**；
   - **必须有审计**：谁在什么时候打断了谁、理由（一句话）、以及打断前该会话的**最后落盘时间**与**未提交文件数**（事后可判断这次打断是否必要）；
   - **必须给被中断的席位留下可见的理由**（写进它的收件箱/线程：PM 为什么打断、它该先做什么），否则它续跑起来只会接着绕。
2. **判据**：打断是**可观测**的（记录 + 收件箱各一行），**不是静默杀进程**；`resume` 之后席位能读到那条理由（在它的阅读顺序里）。
3. **红侧**：① 正常在跑、且最近有落盘的席位**不许**被误打断（要一条「拒绝或要求 `--force` + 理由」的判据，反例可证伪）；② 打断后磁盘上的未提交改动**必须还在**（造一个未提交文件，打断后检查它仍在）；③ 打断记录缺理由 → 拒绝。
4. **不做**：不改 `resume` 的既有语义；不引入自动判断「卡住了」的启发式（谁来判断是 PM 的事，工具只提供动作与证据）；不动别的项目的席位（跨项目一律拒绝，与既有边界一致）。

## 边界

- 只写提案；apply 与 verify 另换人。
- 排期：todo。
- 与 `long-job-suspend` 的关系在 design 里写清：**长作业**有记录、有叫醒；**长回合**两者都没有——本变更是后者的入口，不重复前者的机制。

## 验收（本阶段）

```bash
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/spec-refs.sh --check
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```
