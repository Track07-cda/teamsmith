# P177 · `product-checkout-gate` **换人复验**（P170 FAIL → P173+P176 之后）

```
task:   P177
agent:  verify
issue:
change: product-checkout-gate
specs:  verification#A gate that cannot judge says so
phase:  verify
anchor: change
deltas: -
grant:  docs/team/reports/P177-<agent>.md · docs/team/reports/P177-<agent>/**
deps:   第一轮 `docs/team/reports/P170-dev.md`（FAIL：F1/F2 ✓，含括号表与两棵树的原始输出 ✓）· 返工 P173（lint 归属）+ P176（signal-lint 豁免）· **换人** ✓（D31）
status: wip
budget: 一次对抗性验证
priority: 高（它是 `product-checkout-gate` 归档的**唯一**前置 ✓，也挡着发布 ✓）
```

## 要独立证明或证伪的

1. **F1 真修好** ✅：**含 P162 wrapper 的树**上，往 `tmp-hygiene.sh` 追加裸 `tmux kill-server` → M28 **必须红并点名该文件** ✓；
   影子（把归属规则改回"同目录互认"）→ 该用例必须红 ✓；**反向**：`smoke.sh` 自己里的调用仍按 wrapper 语义判 ✓（不许把 wrapper 判据整体删掉 ✗）。
2. **F2 真修好** ✅（**PM 已更正口径** ✓）：判据是**门禁**（`--select 58` 在产品面树里）**rc=0** ✓ 且**可见跳过并点名**那份清单 ✓；
   **不是**「直接跑 `perl signal-lint.pl` 必须 rc=0」✗ —— 我原来写严了 ✗：那条 lint 是**内部测试助手** ✓（用户不会直接跑它 ✓），
   而 M28 的 `tmux-lint.pl` 在导出树里**行为完全相同**（我实测两者都报「清单里的文件不在了」✓）→ 两段是**同一契约、同一层次**（都在段落层收口 ✓）✓。
   **残余要如实写进报告** ✓：lint 二进制直接在产品树里跑仍会红 ✓（两条 lint 都是 ✓）。

   **反向**：清单里**产品面**文件缺失 → **必须红** ✓（自己造 ✓）。
3. **两棵树 FAST 都绿** ✅：**内部树** ✓ 与**产品面树**（用 `publish-public.sh` 真实导出 ✓）各跑一次 FAST ✓ —— 这是 P170 两条 FAIL 的直接反证 ✓。
4. **P148 的其余承诺不许破** ✅：可见跳过不计通过 ✓、产品真失败仍红 ✓、内部树不少跑（与基线逐段比 ✓）。
5. **门禁**：`openspec validate --all --strict` ✓ + 容器内两棵树的 FAST ✓；报告写清原始输出与**没有**测到什么 ✓。
