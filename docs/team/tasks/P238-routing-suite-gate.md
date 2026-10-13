# P238 · 路由测试进闸门 + 组自足 + 选段归属（三个坑一起）

task: P238
agent: dev-bob
phase: apply
category: infra
change: -
anchor: none (infra) — 门禁登记、夹具自足与选段归属修复，不改产品契约行为
branch: task/P238-routing-suite-gate
deps: task-model-routing 已并入 main（S1+S2+S3，V19/V21/V23 PASS）；P237/V24 在飞（同改 `smoke.sh`，若它先落地请从它的 tip 起手）

## 三个坑（全部由 PM 在合并后手工跑前门时实测）

**坑 1（假红，最要紧）：`pm` 组不自足。** 单独 `bash skills/teamsmith/tests/task-model-routing.sh --select pm` → **74 通过 / 29 红**，最早的红是 `pm-partial-publication-record`，诊断 `common.sh:2584: …/.pi/team/state/.pm-launch-test-nonce: No such file or directory` → 夹具的 state 目录不存在。该目录由 **`boundary` 组**在 `task-model-routing.sh:694` 的 `mkdir -p "$STATE"` 创建（`routing_reader_matrix`，只在 boundary 组里跑），所以 `pm` 组依赖兄弟组先跑过。PM 已实测：S1 的 tip `8bea13e`、S2 的 tip `611f72d4`、S3 的 tip `2fc9ea5` **三处同样 29 红**——不是哪个切片引入的，是一开始就有的设计缺口；三轮独立复验跑的是默认 13 组全量（boundary 在前），所以它一直没被发现。
**要求**：让**每一组单独可跑**（自己准备自己需要的一切前置：state 目录、夹具仓库、记录文件），并在报告里给出**逐组单独跑**的证据（13 组各一行 rc 与 RESULT；`pm` 必须 103/0）。凡是确实要跨组共享的前置，改成每组的 setup 步骤，或显式声明依赖并在缺前置时**报错点名**而不是连锁红。

**坑 2：整套路由测试没有任何门禁段在跑它。** `tests/task-model-routing.sh`（1001 行 + 5 个 `tests/lib/model-routing-*` 夹具）不被 `smoke.sh` 或选段表调用；设计里的说法是「前门 = `routing/<group>` + 相应 smoke 段」，也就是靠人手工跑。PM 实测 13 组全量约 **18 分钟**，`--flip` 变异套件更久（同批前门作业跑了 29+ 分钟仍在跑）。
**要求**：把它登记成门禁的一部分，让人不做手工也能被咬住；成本要可见、要有依据。建议（你可以给更省或更严的方案，但必须写清依据）：新增一个**独立门禁段**承接整套前门，并且**在 FAST 里只跑路由行为的核心组**（`dispatch, limits, transaction, preview, resume, config, pm` 一类），完整组与 `--flip` 在**非 FAST**（live）里跑——判据是「全量门禁能咬住路由回归，FAST 的成本不失控」，两档都要真的能红。段号、选段表、预算表（`section-paths.tsv` / `section-budgets.tsv`）一并登记；预算行要有实测依据（跑一次记段用时）。

**坑 3：选段归属错了。** `section-paths.tsv` 里若段用 `skills/teamsmith/tests/*` 这类通配，选段器会把**新增的测试文件**归到无关段（本次合并后 `section-select.sh` 给出 55/56/59/14d，它们都不跑路由入口），于是「改了路由测试 → 选段结果不含路由段」。
**要求**：修掉这类通配归属（按文件精确登记，或给路由段显式登记其夹具文件），并证明：改一个路由测试文件 → 选段结果**包含**路由段。

## 边界

- 只碰 `skills/teamsmith/tests/`（`smoke.sh`、`task-model-routing.sh`、`tests/lib/model-routing-*`、两张 tsv）与必要的夹具说明；**不碰**产品代码（`scripts/lib/**`、`extension/**`、`panel/**`、`templates/**`、`references/**`）。
- 不改既有断言的强度：坑 1 修的是前置准备，不许用「跳过缺前置的用例」换绿；新增的 skip 必须有名字与理由。
- 不删 `--flip` 的既有臂；不合并、不推送；做完 `team notify pm`。

## 验收命令（报告里贴真实输出）

```bash
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
# 坑 1：逐组单独跑（13 行，pm 必须 103/0）
for g in policy machine init config upgrade dispatch resume transaction limits preview sid-readers pm boundary; do
  out=$(bash skills/teamsmith/tests/task-model-routing.sh --select "$g" 2>&1); printf '%-12s rc=%s %s\n' "$g" "$?" "$(printf '%s' "$out" | tail -1)"
done
# 坑 2：新段在 FAST 与非 FAST 各跑一次（贴段用时与结果）
bash skills/teamsmith/tests/smoke.sh --select <新段号>
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh --select <新段号>
# 坑 3：选段归属
bash skills/teamsmith/tests/section-select.sh --paths skills/teamsmith/tests/task-model-routing.sh skills/teamsmith/tests/lib/model-routing-boundary.sh
bash skills/teamsmith/tests/section-select.sh --check
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```

**红侧**：把坑 1 的修复还原（删掉 `pm` 组自己的 setup）→ 该组单独跑必须再红；把路由段从选段登记里去掉 → 坑 3 的选段检查必须不再包含它；新段的两档都要有过一次真实变红（例如临时让某个路由断言失败）的证据。

## 交付

`docs/team/reports/P238-dev-bob.md`（三个坑各自的前后证据、逐组单独跑表、新段两档实测、选段归属前后对照、预算依据、未做项）；证据包按 D94 放仓外；之后由未写过本任务的席位独立复验。
