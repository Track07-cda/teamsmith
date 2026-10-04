# P173 · `product-checkout-gate` 返工：产品面检出里 §31 的 lint 被跳过 → 植入的裸 tmux 变更调用没被抓住

```
task:   P173
agent:  dev2
issue:
change: product-checkout-gate
specs:  verification#A gate that cannot judge says so
phase:  apply
anchor: change
deltas: verification
grant:  skills/teamsmith/tests/** · openspec/changes/product-checkout-gate/** · docs/team/reports/P173-<agent>.md · docs/team/reports/P173-<agent>/**
deps:   合并 `feat(teamsmith): P148 …`（在 main ✓）· P148 自己的探针 `tests/checkout-shape-probe.sh:380-389`（"牙齿一" ✓）· **现场（PM 2026-10-02 实测）**：在**钉死容器**里对冻结克隆（tip `4d7a278f`）跑**全量** → `✗ 36⑧ 产品面检出探针有失败（1 条）` ✓ + `bad: ⑨ 产品面树里出现裸 tmux 变更调用，§31 仍然绿（跳过把产品问题吞了）` ✓
status: wip
budget: 一个工作块
priority: **高**（它让 main 在容器里全量必红 ✓ → 也挡住 `product-checkout-gate` 归档 ✓ 与发布里程碑 ✓）
```

## 现场（**容器里**，全量；FAST 下不出现 ✗）

```
✗ 36⑧ 产品面检出探针有失败（1 条）
    bad: ⑨ 产品面树里出现裸 tmux 变更调用，§31 仍然绿（跳过把产品问题吞了）
#96 36 · 选段与分段账本自检 · ✓109 ✗1
```
探针（`checkout-shape-probe.sh:380-389` ✓）做的事：在**产品面树**的 `skills/teamsmith/tests/tmp-hygiene.sh` 末尾追加一行 `tmux kill-server` ✓ →
跑嵌套的 `--select 31` ✓ → 期望**非 0**（§31 的 tmux 隔离 lint 判红并点名该文件 ✓）→ 实测**退出 0** ✗ = **产品文件里的真问题被"前提跳过"吞掉** ✗。

**这正好是本 change 要防的形状** ✗（"跳过不是通过"✓）：§31 的 lint 是**产品检查** ✓，不该因为"产品面检出缺内部开发面"而被跳过 ✗。


## ⚠ 根因更正（P170 的独立验证实测，**推翻我上面的猜测**）

**我原先猜"§31 走了跳过路径"是错的** ✗ —— 真根因在 **M28 lint 的 wrapper 归属规则** ✓（`logs/f1-f2-brackets.log` 的括号表 ✓）：

| 树 | P162 的 `tmux()` 包装（`smoke.sh:583`） | 往 `tmp-hygiene.sh` 追加裸 `tmux kill-server` 后 M28 的判定 |
|---|---|---|
| `b57e2df3`（dev2 的证据 tip，早于 P162） | 无 | **RED** ✓（`RED tmp-hygiene.sh:1188 tmux kill-server`） |
| `251c5e45`（P148 合并提交，含 wrapper） | 有 | **ok** ✗ |
| `4d7a278f`（现行 main） | 有 | **ok** ✗ |

机制：lint 的"同目录互认"把 `smoke.sh` 里那个 `tmux()` **函数**当成了整个 `skills/teamsmith/tests/` 目录下名为 `tmux` 的隔离证明 ✓ →
于是**别的脚本**里的裸 `tmux kill-server` 也判 ok ✗。而 `tmux()` 包装只存在于 **`smoke.sh` 自己的 shell** 里 ✓，不会惠及其它脚本 ✓ ——
所以**探针的期望在语义上是对的** ✓，要修的是 **lint 的归属规则** ✓（按"哪个文件里定义的 wrapper 只护哪个文件 / 只护它自己 spawn 的调用"✓），
**不是**把 §31 的跳过逻辑改掉 ✗（那条我写错了 ✓）。
**另外**：这解释了为什么此前两边各自绿 ✓ —— dev2 的证据跑在**没有 wrapper** 的树上 ✓，我的 P148 复验只跑 `--select 0c,0e,0h`（**不含 §36**）✗ → 内部 FAST 从合并那天起就是红的 ✗。
**要求**：修 lint 归属 ✓ + 探针的"牙齿一"在**含 P162 wrapper 的树**上必须红并点名 ✓ + 影子（把归属规则改回"同目录互认"）必须让该用例红 ✓。

## 要做的

1. **先定位** ✅：在**容器**里复现 ✓（`--keep` 留下现场 ✓），找出 §31 为何在**产品面检出**里走了跳过路径 ✓（把它的前提判据逐条列出来 ✓、给代码行 ✓）；
   同时说明**为什么宿主上（或 FAST 下）没暴露** ✓（这就是 CI 与本地不一致的那一类 ✓）。
2. **修** ✅：**产品检查不许因内部前提缺失而跳过** ✓ —— §31 的 tmux 隔离 lint 必须**照跑** ✓（它的输入是产品文件 ✓，与内部开发面无关 ✓）；
   若它确实依赖某个**产品**前提（例如 `perl` ✓），那前提缺失要**红**（工具缺失不是"跳过"✓）或按既有语汇**可见跳过并点名** ✓ —— 但**不得**把"植入的真问题"变成绿 ✗。
3. **红侧（必须三条）**：
   ① 探针的"牙齿一"（`tmux kill-server` 植入产品文件 → §31 判红并点名 `tmp-hygiene.sh` ✓）**在容器里必须过** ✓（当前是它红 ✓）；
   ② 影子：把 §31 的 lint 改成恒绿 → 该牙齿**必须红** ✓（证明牙齿有牙 ✓）；
   ③ 反向：**产品面检出**里 §31 正常时**必须绿** ✓（不许为了让它红而把整段改成恒红 ✗）。
4. **不许**用"把 §31 从产品面检出里排除"来绕过 ✗（那等于承认产品检查可以跳过 ✗）。
5. **门禁**：`openspec validate --all --strict` ✓ + **容器内** `--select 31,36` ✓ + **容器内一次全量** ✓（这是它唯一能暴露的地方 ✓）；
   报告点名"哪些自己跑、哪些引用" ✓；**复验换人** ✓。
