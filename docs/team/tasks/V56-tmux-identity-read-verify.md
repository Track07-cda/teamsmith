# V56 · tmux 身份作用域读侧（归因与自愈）+ doctor 只读行：独立复验

task: V56
agent: dev3
phase: verify
category: verify
change: tmux-identity-scope
specs: pm-lifecycle, verification
deltas: -
branch: task/V56-tmux-identity-read-verify
deps: P304（已交付，冻结 tip 见**收据文件** `reviews/V56/freeze-receipt.txt`）｜V48（写侧复验）｜P274（写侧 apply）

## 复验对象

读侧**归因**（冲突对里每个变量的继承值都等于 `tmux show-environment -g` 的值 → 按 cwd 解析、**stderr** 一行点名 + 给出清除命令、不再拒绝）、**不可归因路径逐字不变**（继续拒绝）、`team doctor` 一行**只读**残留报告。

## 必须自己做的（不许只复跑作者脚本）

1. **自己造泄漏现场**（私有 socket + 私有 fixture ✓ 不碰真实 server）：让共享 server 的**全局环境**带本项目身份 → 在本项目目录里跑一条会触发身份守卫的命令 → **必须自愈**（rc=0、stderr 一行点名全局环境、给出那条清除命令）；然后把同一个变量改成**显式外来**值（不等于全局环境）→ **必须拒绝且文案与改动前逐字相同**（这是安全边界，不许放宽）。
2. **红侧自己造**：① 把归因判据改成「只要值相同就归因」→ 上一条的不可归因现场必须红；② 把可归因路径改回「直接拒绝」→ 必须红（我们要求自愈）；③ 给 doctor 那行加**写盘** → 只读断言必须红。
3. **doctor 只读**：跑 doctor 前后对**状态目录全树哈希**——必须一字节不变；并核它**不连真实 server**（私有 socket 下也要能跑或具名跳过）。
4. **写侧不回退**：V48 已验的写侧绿面随机抽 ≥3 条重跑（建对象动词摘身份、本项目窗口仍带身份、只读动词保留身份）。
5. **文本面不设门禁**（D170）：若发现新增断言锁了**措辞**，记一条观察。
6. 计时类按 D192；容器里先 `mkdir -p` 再设 `TMPDIR`（D189）；`/tmp` 根数前后对比；受检 tip 以收据为准（D196）。

## 交付

`docs/team/reviews/V56.md`（抬头含 `判定: **PASS**` / `判定: **FAIL**`；逐条命令 + rc；你自己造的泄漏现场与三条红侧的原始输出；doctor 前后全树哈希；写明运行模型与 loadavg）；不改候选、不合并、不推送；结论通知 PM。
