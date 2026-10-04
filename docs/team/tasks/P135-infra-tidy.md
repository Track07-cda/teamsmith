# P135 · infra tidy：CI 镜像确定性 + `close` 清分支 + 镜像补 `iproute2` + 一行合并食谱 fallback

```
task:   P135
agent:  dev
issue:
change: -                        # 无 change：四件小修（anchor: none (infra)）
specs:  -
phase:  apply
anchor: none (infra) — 只修构建确定性、状态清理、镜像依赖与一行文档
deltas: -
grant:  ci/** · .github/workflows/gates.yml · skills/teamsmith/scripts/lib/cmd-agents.sh · skills/teamsmith/references/workflows.md · skills/teamsmith/tests/** · docs/team/reports/P135-dev.md · docs/team/reports/P135-dev/**
deps:   D62（两个工具坑 ✓）· D63（镜像缺 iproute2 ✓）· D65（<cep-project> 的 0007(1) 建议 ✓）· P130（`.github/workflows/gates.yml` 刚改过 ✓ 顺手 ✓）
status: todo
budget: 一个工作块
priority: 中（都小 ✓ 但都会反复咬人 ✓）
```

> 本地模式：不 push main ✓；**CI 不是判据**（D54 ✓）—— 推送时带 `[skip ci]` ✓（本任务会碰 `ci/**`，不 skip 就会烧额度 ✗）。

## 四件（每件都要**可证伪**）

1. **CI 镜像的 `ETXTBSY`（P103）** ✗：`esbuild` 的 install 脚本与 `npm ci` 竞争 ✓ → 改成**确定性** ✅：
   `npm ci --ignore-scripts` ✓ + **显式**跑该包的 install ✓（或等价确定做法 ✓）。
   **不动** 任何 pin（node/bun/pi/openspec/tmux ✓）；**不许** `continue-on-error` 掩盖 ✗。
   证据：本地**真构建一次**（`distrobox-host-exec podman build -f ci/Containerfile …` ✓ 或你在容器里能跑的方式 ✓）
   并证明镜像里 `pi`/`openspec`/`bun`/`node` 都在 ✓（列举命令与版本 ✓）。
2. **`team close` 不清 `state/<agent>.env: branch=`** ✗（D62-a）：关任务后该行仍写着上一个任务的分支 ✓ →
   下一次给该席位派单时**分支守卫读到陈旧记录** ✗ 而拒单 ✓（PM 今晚实测 ✓）。
   修：`close` 顺手清 `branch=` ✓（`task=` 已经清了 ✓）。
   证据：造一个带 `branch=` 的状态文件 ✓ → `close` 后该行**空/删** ✓（红侧：改回不清 → 断言红 ✓）。
3. **`ci/Containerfile` 缺 `iproute2`** ✗（D63）：`ss` 不在 → 镜像里的**隔离自检会可见降级** ✓
   （verify 今晚不得不派生镜像才跑全 ✓）。加进包列表 ✓。
   证据：构建后镜像里 `ss -V` 可用 ✓（或 `command -v ss` ✓）+ 相关夹具在该镜像里**不再 SKIP** ✓（列举前后 ✓）。
4. **合并食谱加一行可判定 fallback** ✓（<cep-project> 的 0007(1) ✓）：`references/workflows.md` 的 `--pr` 食谱里补：
   `# 若 forge 合并 403（缺 Contents: write）：本地 squash + push + 评论 + 关 PR` ✓
   （**中文允许** ✓ —— workflows.md 是中文文档 ✓；但**不要**断言任何项目的凭据状态 ✗ ✓）。
   证据：那一行在文件里 ✓ + `references` 的文档检查段仍绿 ✓。

## 门禁

`openspec validate --all --strict` ✓ + 相关段落 ✓ + **FAST 全绿** ✓（**不需要**全量 ✓ 你判断 ✓）。
