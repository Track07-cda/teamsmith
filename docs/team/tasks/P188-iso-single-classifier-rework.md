# P188 · 隔离前置返工：**一份分类器**（同源 = 同一份代码）+ 命令链 + 别名 + `builtin command`

```
task:   P188
agent:  dev3
issue:
change: -
specs:  -
phase:  apply
anchor: none (infra) — 只改隔离前置的分类实现与其断言
deltas: -
grant:  skills/teamsmith/tests/** · skills/teamsmith/scripts/lib/** · docs/team/reports/P188-<agent>.md · docs/team/reports/P188-<agent>/**
deps:   P186 的独立验证（`docs/team/reports/P186-verify.md` ✓ 四条 + 真执行证据 ✓）· PM 评审 `docs/team/reviews/P186.md`（**裁定：根因是"写了第二套实现"** ✓）· P178/P180 的历史（同一条机制的两轮 ✓）· **铁律：破坏性实验一律在容器内** ✓
status: wip
budget: 一个工作块
priority: **最高**（唯一挡住"隔离静默失效 → 打到共享默认 socket"的机制 ✓，而它第三轮仍被绕过 ✓）
```

## 四条（照 P186）

### ① 一份实现（根因）✅
`skills/teamsmith/scripts/shim/tmux`（M36/M67 ✓）里的 argv 解析与分类**抽成共享函数** ✓ →
**运行时 shim 与套件包装器都调用它** ✓（`skills/teamsmith/tests/lib/tmux-iso.sh` 不许再有第二份分类逻辑 ✗）。
**可证伪**：改共享函数里的一处判定 ✓ → 两侧的判定**同时**变 ✓（影子：把共享函数改成恒"非破坏性" → 两侧的绕过用例**都必须红** ✓）。

### ② 命令链 ✅
一次 tmux 调用里用 tmux 自己的 `;` 分隔的**每个**动词都要扫 ✓（`tmux list-sessions ';' kill-server` ✓、`tmux -u list-sessions ';' kill-server` ✓）；
**任一是破坏性 → 整条判破坏性** ✓（硬停 ✓）。
**红侧**：F2 的三条形状 → 必须硬停 ✓；**真执行验证**：在容器里用自己的私有 socket 跑同一条链 → `has-session` **仍为 0** ✓（证明前置真的拦住了 ✓）。

### ③ 别名与包装 ✅
`killw`/`killp`（tmux 的合法缩写 ✓）→ **必须**被分类 ✓（与运行时 shim 一致 ✓）；
`builtin command tmux …` ✓ → 纳入 ✓（定义 `builtin()` 包装或在共享分类器层面覆盖 ✓ —— 选一种并说明 ✓）。
**红侧**：三种形态各一条 ✓ + 影子 ✓。

### ④ F4 的过时前提 ✅
`checkout-shape-probe.sh` 现在要求 `smoke.sh` 里**字面**存在 `tmux() {  # P162` ✗ → P180 之后它不在那里 ✓ →
改成证明"**包装器存在且与 shim 同源**" ✓（例如断言 `tmux_iso_install_suite_guards` 被调用 ✓ + 共享分类函数被引用 ✓ + 牙齿仍能咬 ✓）；
**不许**删掉这条检查换绿 ✗（它抓的正是"前提不在时牙齿会因别的原因通过" ✓）。

## 门禁

`openspec validate --all --strict` ✓ + 容器内 `--select 0h` ✓ + 容器内 `--select 31,36` ✓ + 容器内 FAST ✓；
报告点名"哪些自己跑、哪些引用 P186" ✓；**复验换人** ✓（第四轮 ✓）。
