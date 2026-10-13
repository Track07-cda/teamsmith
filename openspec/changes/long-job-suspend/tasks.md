# long-job-suspend · tasks（propose 阶段：全部未勾；apply 另派席位）

## 1. 输入冻结与排期

- [ ] 1.1 PM 记录提案接受与本 change 的输入基线 tip；确认 `task-model-routing` S1 对
  `scripts/lib/cmd-agents.sh`、S3 对 `templates/**` 与 `references/**` 的释放状态。未释放则按
  design 决策 8 分两刀派单：A 刀（扩展 + 独立测试入口）先行，B 刀（提示词/模板/文档/门禁登记）
  待释放；PM 在 apply 任务书里写明切片边界与输入 tip。
- [ ] 1.2 派单守卫核对：本 change 的三份 delta（dispatch / background-jobs / notify-and-inbox）
  各只有一份、无其他未完成任务在写同一 delta 文件；`notify-and-inbox` 的 MODIFIED 基线按派单时
  磁盘文本刷新（若期间有其他 change 归档碰到该 requirement）。

## 2. A 刀 · 车道侧（extension/team-bg.ts，无路由碰撞）

- [x] 2.1 重写 `team_bg_run` 的 description / promptGuidelines / 起作业回执文本与 `team_bg_wait` 的
  description：结束回合默认、完成叫醒为正常收割点、原地等例外三条（预算 + 阻塞 + 独占）、
  预算数字入文；不再出现「回合结束前必须收割」与「叫醒 = 损失」措辞。完成叫醒的合并消息继续
  点名每个 id 并指引收割（既有行为，钉住）。
- [x] 2.2 账本新增两类行：`start id=<id> pid=<pid>`（返回 id 前，与 `.job` 记录同点位）与
  `wait id=<id> outcome=<harvested|running|interrupted> waited_s=<s>`（每次 wait 返回，只量本调用）；
  `wake` / `settled-with-unharvested` / `spawn-error` / `stop` 行形状逐字节不变。
- [x] 2.3 新独立测试入口 `skills/teamsmith/tests/bg-ledger.sh`（遵循夹具隔离纪律：清继承 TEAM_*、
  断言 `team paths` 解析到夹具、跑后断言真账本未动）覆盖：`--select wording,ledger,suspend-shape,flip`。
  A 刀的两个扩展（2.1/2.2 与 3.1）的用例都跑在这个入口里 —— 因为它不碰 S1 拥有的 `smoke.sh`；
  B 刀再把这些用例折回 smoke §13/§13c 并登记 section-select 映射（见 4.3）。
  flip 组对独立 scratch 源码做真实破坏（措辞回退 / 删 `start` 行 / `waited_s` 记成作业年龄 /
  身份不验 / 改成读 notify 自己的 root）必须红，还原后绿。

## 3. A 刀 · 通知侧（extension/team-notify.ts，无路由碰撞）

- [x] 3.1 实现挂起判定：从**车道写记录的那个目录**读 `state/bg/*.job`，按车道的解析规则定位（显式
  `TEAM_STATE_DIR` 优先；否则「cwd 的 worktree 带 `.pi/team/config.sh` → 它自己；`TEAM_ROOT`；
  最近的带 config 的祖先；git 主工作树」）—— **不许用 notify 自己的 root（`--git-common-dir`，落
  主工作树）顶替车道的目录**；逐条 `(pid, start-time)` 活体验证（与 `team bg list` 同一规则），
  验证不过不算在跑。完成 + 在跑非空 → `[auto·suspended]` + `awaiting=<id>[,…]`，省略 ⚠ 前缀、
  保留 `uncommitted=<n>`；未完成 + 在跑非空 → 保持 `[auto·interrupted]` + `awaiting=`；其余形状
  逐字节不变。判定的任何失败（目录不可读、记录畸形、/proc 读不到）一律退回非挂起。
- [x] 3.2 A 刀阶段：3.1 的用例先在 2.3 的独立入口里实现（S11 形状 worktree 侧记录算数 + 主根诱饵；
  显式 `TEAM_STATE_DIR` 里的记录算数 + notify 自己 root 下的诱饵不算）；B 刀再折回 smoke §13 并
  登记 section-select 映射（4.3）。用例主体：完成 + 活记录 → suspended；死 pid / 指纹不符（复用）→
  不挂起；中断 + 活记录 → interrupted + awaiting。
  含红侧：把身份验证删掉 / 改成读 notify 自己的 root（主工作树）→ 对应用例必须红。

## 4. B 刀 · 提示词与文档面（待 S1/S3 释放）

- [x] 4.1 `cmd-agents.sh`：后台车道段整段重写为 design 决策 1 的口径；「Never stop mid-task」段列三种
  合法结束状态（交付 / 硬阻塞 / 挂起，挂起须点名 job id 且不写终稿不报 BLOCKED）；续跑行加
  「先查 `state/bg.log` 与 `team bg list` 再继续」。
  证据：提交 `adc7be0`（提示词三态）/ `12bf9c9`（注入夹具位置修正）；报告 `docs/team/reports/P237-dev.md` §4.1；
  smoke `--select 6,13,13c`（full）§13c 的 `The built-in Pi prompt carries the three states` 7 条与
  `The resume guidance points at the on-disk evidence` 4 条全绿（渲染原文在证据包 `P237-dev/accept/rendered-prompt.txt`）；
  红侧：把旧「Harvest every job … costs a turn」措辞还原进提示词 → 同一场景 5 条红并点名 worker prompt（`P237-dev/flips/flip2-*`）。
- [x] 4.2 `templates/AGENTS.section.md.tmpl` 纪律条同步三态一句话版；`references/protocol.md` 通知小节
  登记 `[auto·suspended]` 与 `awaiting=`；`references/workflows.md` §E2 规则 1 改为结束回合默认、
  规则 2 账本清单补 `start`/`wait`。核对 `templates/pm-prompt.md.tmpl` 与 `SKILL.md` 无需改并把
  核对证据写进报告。
  证据：提交 `84a3b6c`；报告 §4.2 与证据包 `P237-dev/accept/pm-template-check.log`（两文件不在 diff 里、
  既有车道口径行 79-80 / 20 / 58 仍在、退休措辞 0）；`One contract across the shipped surfaces` 26 条
  逐面钉住四面的三态与同一预算数字；红侧：AGENTS 模板删第三态 → 该场景点名「AGENTS template」（`flip1-*`）。
- [x] 4.3 一致性夹具（B 刀：把 2.3/3.2 的用例折进 smoke §13/§13c，一致性断言挂 §6 dispatch 或 §13c，
  并登记 section-select 映射表）：`--print` 渲染的
  工人提示词含三态与新车道口径、不含旧「harvest every job before your turn ends」；无 `{bg_ext}` 的
  自定义模板不注入车道段；AGENTS 模板 / protocol.md / workflows.md §E2 与提示词的三态措辞一致；
  PM 模板的既有口径行仍在。红侧：任一面缺第三态或回退旧措辞 → 红。
  证据：提交 `e5a8ff6`（§13c 折进 + 四场景断言）+ `12bf9c9`（注入夹具移回 §6 真派单段、绑身份占位符）；
  报告 §4.3；§13c 折进 `bg-ledger.sh --select wording,ledger,suspend-shape,owner-scope`（41 passed, 0 failed）
  并有 4 条按用例名的登记断言；`section-paths.tsv` §13c 行同步登记；
  红侧：无 `{bg_ext}` 也注入车道段 → 2 条红（`flip3-*`）、续跑行去掉 `state/bg.log` → 2 条红（`flip4-*`）。
- [x] 4.4 兜底夹具：挂起后死亡的席位命中既有巡检待办条款（「任务未完成 + 窗口不在」），不新增
  watchdog 条款；把夹具输出（pending 计数含该席位）写进报告。
  证据：提交 `e5a8ff6`；报告 §4.4；§13c·P237 §4.4 四条断言 + smoke 日志里打印的夹具输出
  （`待办 停了的 agent 1（dev=unknown）` 与 digest 建议点名 `dev 未在跑但仍有任务 P237FALLBACK`）；
  作业也结束后待办逐字不变（既有条款只看任务 + 窗口，不看车道）。

## 5. 独立验证与采纳

- [ ] 5.1 未写过本 change apply 的席位在独立 clone 复验：三份 delta 的全部场景 + 全部红侧；报告逐条
  命令 / rc / 证据路径。
- [ ] 5.2 wrap-up 按门禁纪律跑全量（容器、干净 clone、后台起 + 叫醒收割）；归档前 PM 复核
  MODIFIED 与基线逐场景对照无丢失。
- [ ] 5.3 PM 合并、用户确认、归档；共享技能软链接影响授权沿用既有程序（D107）。

## 6. 实现后运行的验收命令（本阶段未运行；登记用）

```bash
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/spec-refs.sh --check
bash skills/teamsmith/tests/bg-ledger.sh --select wording,ledger,suspend-shape,flip   # 新入口（2.3）
bash skills/teamsmith/tests/smoke.sh --select 13,13c,6                                  # 选段以 section-select 为准
bash skills/teamsmith/tests/section-select.sh --paths <apply 实际改动的路径>
git diff --check
```
