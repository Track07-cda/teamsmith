# P156 · 小修：`26-c` 的纯文本对比把**机器读数**也当内容比，于是会抖

```
task:   P156
agent:  dev
issue:
change: -
specs:  -
phase:  apply
anchor: none (infra) — 只改一条断言的归一化口径与其红侧
deltas: -
grant:  skills/teamsmith/tests/smoke.sh · skills/teamsmith/tests/** · docs/team/reports/P156-<agent>.md · docs/team/reports/P156-<agent>/**
deps:   现场：2026-10-01 我在 main 上跑 FAST，`26-c` 两条断言红 ✗（PM 的捕获日志 `/tmp/fast-full3.log` 第 2130–2131 行）；
        两次独立 FAST 都是同两条 ✗（另有 dev-bob 的树 ✓3384 ✗0 绿 ✓ —— 说明它**取决于跑的那一刻机器读数** ✓）
status: wip
budget: 小
priority: 中高（真门禁会因此假红，且**每次全量都会**踩）
```

## 现场（原始行）

```
✗ 26-c 纯文本：重定向的 --once 与 --print 内容不一致（ESC=0，时间戳已归一）：4c4 < RAM 3.9G ｜ swap 63.0G …
✗ 26-c 纯文本：TEAM_MONITOR_UI=text 与 --print 内容不一致（ESC=0，时间戳已归一）：4c4 < RAM 3.9G ｜ swap 63.0G …
```

代码：`skills/teamsmith/tests/smoke.sh:9766-9771`（`p10_norm` 已经把**时间戳**归一 ✓，但**没有**归一 `RAM`/`swap` 这类**实时读数** ✗）。
机制：`--print` 与 `--once` 是**两次独立采样** ✗；机器内存/交换在两次之间会变 ✓ → 差异行永远是那一行 ✗。

## 要做的

1. **只归一"实时读数"**：把内存/交换/负载/CPU 这类**每次采样都会变**的字段值替换成占位（如 `RAM <n>G` → `RAM <n>G` 保留形状、数值用 `·`）✓；
   **结构、顺序、字段名、单位、分隔符照旧逐字节比** ✓（不许把整个对比削弱成"随便都算相等" ✗）。
2. **红侧**：造两段**真实不同**的纯文本（例如字段名不同 ✓ 或行数不同 ✓ 或一段里有 ESC ✗）→ 必须**仍然红** ✓；
   再造两段只有实时读数不同的输入 → 必须**绿** ✓（这就是今天那两条的还原 ✓）。两条都要留原始输出 ✓。
3. **不要动** `26-m`（真 pane 渲染）与其它段落 ✓；报告里点名你**没有**跑什么 ✓。
4. 门禁：`--select 26-c` ✓（多跑几次以证明不再抖 ✓）+ `openspec validate --all --strict` ✓ + FAST ✓。
