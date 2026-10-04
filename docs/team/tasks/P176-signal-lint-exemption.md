# P176 · 产品面检出里 `signal-lint` 的豁免清单仍指着内部面文件 → 假红（P148 只处理了 M28 那张清单）

```
task:   P176
agent:  dev
issue:
change: product-checkout-gate
specs:  verification#A gate that cannot judge says so
phase:  apply
anchor: change
deltas: verification
grant:  skills/teamsmith/tests/** · openspec/changes/product-checkout-gate/** · docs/team/reports/P176-dev.md · docs/team/reports/P176-dev/**
deps:   **P170 的独立验证 F2** ✓（`docs/team/reports/P170-dev.md`，含原始输出 `logs/product-fast.tail.txt` ✓）· P148 已合并在 main ✓ · **与 P173 同一 change、同一 delta** ✗ → **P173 先落地** ✓（单写者守卫会拦 ✓）
status: wip
budget: 小到中
priority: 高（它让**公开面 FAST 仍红 1 条** ✗ → 公开仓 CI 与 `release-check --with-gates` 都不会绿 ✓）
```

## 现场（验证者实测，可复跑）

```
✗ 58 lint 真树判红（见 …/p159-lint.log）
    ✗ signal-lint: baseline —— docs/team/reports/M35-dev2/pkg/lib.sh：清单里的文件不在了（删文件就同时删豁免行）
```
对**生成器的真实导出**直接跑 `perl skills/teamsmith/tests/signal-lint.pl` → **rc=1** ✓（同一条 ✓）；同一 lint 在**内部检出**上 rc=0 ✓（那条是 LEGACY 豁免 ✓）。

## 要做的

1. **让 `signal-lint` 的豁免清单也走"声明的内部前提"** ✅：清单里指向**内部开发面**的条目（`docs/team/**` ✓ 等），
   在产品面检出里**按缺失可见跳过并点名** ✓，**不许**判红 ✗ —— 与 M28 那张清单**同一契约** ✓（`product-checkout-gate` 的 requirement ✓），
   不许另立一套 ✗。
2. **反向（必须仍然有牙）** ✅：清单里指向**产品面**的文件缺失（例如把 `skills/**` 里的某个文件删掉 ✓）→ **必须红** ✓
   （那是真问题 ✓，不是内部前提 ✓）；影子：把"内部面缺失即跳过"放宽成"任何缺失即跳过" ✗ → 该用例必须红 ✓。
3. **两棵树都要绿** ✅：产品面检出 `--select 58` ✓ 与内部检出 `--select 58` ✓ 都绿 ✓（内部那条 LEGACY 豁免照旧 ✓）。
4. **门禁**：`openspec validate --all --strict` ✓ + **容器内** `--select 58`（产品面树与内部树各一次 ✓）+ 容器内 FAST ✓；
   报告点名"哪些自己跑、哪些引用 P170" ✓；**复验换人** ✓（与 P173 一起复验 ✓ → P177）。
