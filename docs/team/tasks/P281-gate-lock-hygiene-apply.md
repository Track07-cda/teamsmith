# P281 · 门禁锁卫生：嵌套运行不排队 + 持有者记录 + 嵌套预算

task: P281
agent: dev-bob
phase: apply
category: code
change: gate-lock-hygiene
specs: verification
deltas: -
branch: task/P281-gate-lock-hygiene-apply
deps: P280（提案已 ACCEPTED 并入 main，见 `docs/team/reviews/gate-lock-hygiene-proposal.md`）

## 范围

实现已接受的 `openspec/changes/gate-lock-hygiene/`（1 MODIFIED + 2 ADDED），按 `tasks.md` 执行。PM 复核时的准入条件：

1. **不许去掉锁**；嵌套运行**只有在能证明祖辈持有锁时**才不排队（沿进程树走到 `<lock>.holder` / `<lock>.runs/*.run` 记的持有者 pid，且 starttime 仍是那一次）；证明不了 → 按顶层排队。
2. **三条红侧逐条跑**（§4）：① 造嵌套持有现场 → 等待者一行点名 `kind=nested` + 席位 + 工作树 + 已跑时长 + 上限；② 嵌套超预算（3s 期限 + 永不返回的段）→ 一行点名（段号 + id + 预算 + 实际）并离开现场、注册记录消失；③ 回归：单层运行的排队与「排到了再跑」语义不变。
3. **持有者记录**写 kind / 席位 / 工作树 / 开始 / 已跑 / 上限；等待者的超时文案要能归因（今天那条只写「持有者：smoke.sh」）。
4. **只对夹具自己注册过的 pid 发信号**（对应今天那次「按名字选进程」的事故）。
5. **写集串行**：`tests/smoke.sh`、`tests/section-*.tsv`、`tests/lib/*`、select 包装此刻也被 **P278（帮助面收尾）与 P276（孤儿可见性）** 改；交付前 `git merge main`，冲突按双方保留，语义冲突停下报我；**合并前逐条看「本次相对 main 的删除行」**。
6. **不新增措辞类断言**（D170）：说明行的判定用稳定短语 + 行为红侧。

## 验收（贴真实输出）

```bash
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/gate-lock.sh            # 本变更的夹具（若无此名，用你在 tasks.md 里定的入口）
bash skills/teamsmith/tests/section-select.sh --paths $(git diff --name-only main...HEAD | tr '\n' ' ')
bash skills/teamsmith/tests/smoke.sh --paths $(git diff --name-only main...HEAD | tr '\n' ' ')
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```

## 交付

`docs/team/reports/P281-dev-bob.md`（逐条 requirement 对照、命令与 rc、三条红侧前后证据、未做项）；不合并、不推送；做完 `team notify pm`；随后由未参与实现的席位独立复验。

## 返修轮次 1（2026-10-15，独立复验 V43 判 FAIL：四项，PM 全判「修」）

复验记录 `docs/team/reviews/V43.md`（受检 `aa45f90a`）。四项我都判**修**（F1/F3 是必修；F2/F4 是我的裁定），并给出方向：

1. **F1（必修，合同不符且有行为后果）**：持有者记录里写的 `heartbeat=` **全仓无人读**，嵌套运行只认环境变量 `SMOKE_ANCESTOR_HEARTBEAT`（`smoke.sh:470`、`section-guard.sh`）——环境一清（套件自己的夹具就这么干）就**无声**退回自己的表预算，于是嵌套运行能活过生它的那一段。**改法**：沿着**已证明的祖辈 pid** 去读 `<lock>.runs/<pid>.run` / `<lock>.holder` 的 `heartbeat=`（证明成功时手里就有那个 pid）；读不到时退回自己的表预算**但必须可见**（一行点名「没有可读的祖辈心跳，按本段预算 N s」）。红侧：持有者记录公布着可读心跳、而环境里没有那个变量 → 必须仍按祖辈预算设限期并点名。
2. **F2（我判：改工具，不改规格）**：`no_lock=1` 现在只写 stdout、不落记录，而规格与 design 都写「record」。**改法**：opt-out 路径也落一条 `<lock>.runs/<pid>.run`（含 `no_lock=1`）。红侧：走 `TEAM_SMOKE_NO_LOCK=1` 跑一次 → 记录里有那条 run 且带 `no_lock=1`。
3. **F3（必修，新引入的抖动红）**：§34⑦ 的期望值建在 1 秒宽的窗口上（候选树 3 跑 2 红，v0.2.0 无此断言且全绿）。**改法**：期望值改成**运行时算**（用记录里的 `started` 算 `remaining`），或把窗口放宽到覆盖真实启动抖动；**横幅仍是断言**（值可算，不许把整条断言删掉）。判据：同一条命令连跑 5 次全绿，且把 `remaining` 改错仍会红。
4. **F4（我判：修，这是信任边界）**：一个**继承了 `SMOKE_LOCK_MARKER`** 的后代能**覆写/删除真持有者的记录**（复验者的场景 G 里，记录换成了伪造者，而 flock 仍被真持有者握着）。**改法**（二者择一，你判断哪个更稳，design 里写明理由）：① 把 marker 从环境里移出（作为参数只交给本次运行，不进 `env`）；或 ② 「自述为持有者」再加一条**不可继承**的证明（例如写入前用 `flock -n` 试锁，或与记录里的 pid+starttime 对照）。红侧：继承 marker 的后代**不许**改写或删除真持有者的记录。

**回归**：四条红侧逐条跑出来（破坏 → 红点名 → 还原 → 绿）；只对登记过的 pid 发信号、单层排队语义、残余窗口可见三条**不许回退**；变更自带夹具与 §34/§34b 全绿（含 F3 的连跑 5 次）。改完 notify pm，我派 **V43 第二轮**（换一个没写过本变更的席位）。
