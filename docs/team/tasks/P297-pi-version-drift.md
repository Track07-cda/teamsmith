# P297 · 生产路径探针钉住了 Pi 的旧版本帧（段 42 的 9 条红）

task: P297
agent: -
phase: apply
category: code
change: -
anchor: none (infra) — 门禁夹具与已装 Pi 的版本漂移；不改产品行为
deltas: -
branch: task/P297-pi-version-drift
deps: 无（独立于在飞两条；但写集与它们重叠 → **等 P288/P292 落地再派**）

## 现场（PM 实测）

- `smoke.sh --select 42` 在 **v0.2.0 那棵树**上同样红：**✓150 ✗9**，9 条全在 `P67 生产路径`，形态是 `input_box_state=UNKNOWN` / `delivery_verdict=NOPANE` / 「dev 窗口画的正是 0.87.0 单行草稿帧」这类。
- 夹具里钉的是 **`pi-0.87.0-*` 的录制帧**（`smoke.sh:7990` 起：`pi-0.87.0-one-line-draft.txt`、`pi-0.87.0-empty-box.txt`、`pi-0.85.1-update…`），而**本机装的 Pi 是 1.2.0**。
- 结论：**这 9 条是环境漂移红**（夹具钉住了旧版本的真实帧），**不是任何一次合并引入的**（v0.2.0 上同红），也不是产品缺陷。

## 要做什么（二选一，把理由写进报告）

**A. 版本感知 + 具名跳过**：探针启动时探测 `pi --version`；与录制帧的版本一致时才跑真帧断言，**不一致时具名 `SKIP`**（写明「录制帧是 0.87.0，当前装的是 X」），**并把当前版本打进结果行**。
**B. 重录为当前版本**：为 1.2.0 重录那几张帧并更新钉住的数值——**代价**：下次 Pi 一升级就再红一次（这正是今天发生的事）。

**我倾向 A**（今天已经证明「钉死外部工具的版本」会周期性制造假红），但**B 也有道理**（生产路径的形状变化本身是值得被发现的信号）——所以：**你可以选 A 并额外在版本变化时打印一行 `OBSERVE:`**（可见但不红），这样两边都拿到。

## 判据

1. **版本一致时**：真帧断言照旧跑（不许为了省事把真帧断言删掉或改成只看有无输出）。
2. **版本不一致时**：**具名可见跳过**（`SKIP` 计数 + 一行原因 + 当前版本），**不是静默通过、也不是假红**。
3. **红侧**：① 把版本探测改回「永远当一致」→ 在 1.2.0 上必须红并点名（这正是今天的现场）；② 把版本不一致改成静默跳过 → 必须红（我们要的是**可见**跳过）；③ 人为把版本号改成一个不存在的值 → 仍然具名跳过且打印该值。
4. **不许**删掉 `P67/P80` 生产路径这一组（它存在是有价值的——它抓过真事故）。
5. 验收：`smoke.sh --select 42` 在**两种版本情形**下各跑一次（用桩 `pi` 伪造版本号即可）并贴结果；`/tmp` 根数前后对比。

## 验收命令

```bash
bash skills/teamsmith/tests/section-select.sh --paths skills/teamsmith/tests/smoke.sh
bash skills/teamsmith/tests/smoke.sh --select 42
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```
