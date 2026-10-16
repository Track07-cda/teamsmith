# V52 · 打断入口收尾（探针配方 / 命令页声明 / 两份文档）：换人定点复检

task: V52
agent: dev2
phase: verify
category: verify
change: seat-interrupt-entry
specs: boundary
deltas: -
branch: task/V52-seat-interrupt-finishup-verify
deps: P292 收尾轮（已交付，冻结 tip 见派单消息）；背景：`docs/team/reviews/P295.md`（清单勾选翻出的三条缺口，其中一条是我复现过的主分支活红）

## 复验对象

P292 收尾加的四样：① `help-surface.sh` 里 `interrupt` 的**claims 探针配方**（把我发现的那条活红堵上）；② `commands.tsv` 的 `interrupt` 行声明（改成实现真正触碰的面与授权语义）；③ `references/troubleshooting.md` 新增「席位卡在长回合里」一节；④ `references/protocol.md` 对应小节。

## 必须自己做的（不许只复跑作者脚本）

1. **探针不是橡皮章**：把探针**指向一个真的会写状态的命令**（或人为让 `interrupt` 真的改动一处不该动的路径）→ 必须红并点名；再把探针改成「永远通过」→ 必须红（自证有牙）。
2. **命令页声明与实现一致**：核 `commands.tsv` 那行声明的面（`faces=`）与**实现真正写的东西**逐项对齐（自己读 `cmd-interrupt.sh` 的写点：审计文件、收件箱/线程、状态目录）；声明里多写或少写一项都必须能被发现（各造一例）。
3. **文档的每条命令真跑一遍**：`troubleshooting.md` 那一节里出现的命令/字段（`session_last`/`uncommitted`/`--force`/审计行格式/「只对一个 pid 发信号」等）**逐条对拍真行为**，任何「文档这么说、实际不是」→ 记 FAIL 并点名那一行。
4. **不回退**：`help-surface.sh --select claims` **✓ 全绿**（改前是 ✓82 ✗2，我复现过）；`seat-interrupt.sh --all`/`--flip` 与 `smoke.sh --select 51c` 各跑一次并贴结果；跑前跑后 `/tmp` 根数。
5. 计时类判据按 D192；容器里先 `mkdir -p` 再设 `TMPDIR`（D189）。

## 交付

`docs/team/reviews/V52.md`（抬头含 `判定: **PASS**` / `判定: **FAIL**`；逐条命令 + rc；你自己造的红侧原始输出；文档对拍结论单列一节；写明运行模型与 loadavg）；不改候选、不合并、不推送；结论通知 PM。
