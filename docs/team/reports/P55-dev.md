# P55 交付报告 · agent:dev · apply `agent-pane-survivability`

- 任务：`docs/team/tasks/P55-pane-survivability-apply.md`（apply 阶段）
- change：`agent-pane-survivability`（deltas：`specs/dispatch/spec.md` + `specs/watchdog/spec.md` 全量）
- 分支：`task/P55-pane-survivability-apply`（local 模式：不 push，分支留在 `.worktrees/dev` 等 PM 合并）
- 工作树：本 worktree（`.worktrees/dev`）
- 交付命令：`bash skills/teamsmith/tests/fixtures/p55/flip-p49.sh` +
  `bash skills/teamsmith/tests/smoke.sh </dev/null` + `openspec validate --all --strict`

## 一、现状复现（探针事实，P49 探针包 + 本任务开工前的三个补测）

本机能完整复现事故链（探针包：`docs/team/reports/P49/probe-pane-survivability.sh` + `.log`）：

1. **不留遗体**：tmux 默认 `remain-on-exit=off`，agent 进程被 kill（含 SIGKILL）→ pane 死 →
   窗口跟着消失，`list-windows` 里席位直接不见；2026-09-22 事故的「死因不明」直接原因就是现场没了
   （探针 P1/P6：`kill-window` 才真的带走遗体，留着它就必须先开选项）。
2. **对遗体按键不报错**：`send-keys` 对死 pane 返回 0，文字落进虚空（探针 P5）——
   这就是「PM 说已送达、worker 永远没收到」的机制。
3. **尸体冒充活 CLI**：遗体 pane 的 `pane_current_command` 仍可读成 CLI 名，
   旧 say 守卫（「前台是 shell 才不算活着」）会把它当活座位（探针 P5 同包）。
4. **消息通道是耐久的**：`docs/team/inbox/<agent>.md` 追加 + `team say` 既有
   offline→收件箱兜底 —— 所以修法是**换证据源**（判 pane_dead）而不是发明新兜底。

本任务开工前的三个补测（全部写进实现）：

- **argv 形式实测**：`tmux respawn-pane -k -t <win> bash -lc <script> <prompt-path>` 可行 ——
  harness 串不经 shell 重解析，多行提示词/任意文本安全（探针日志 §49-62）。
- **窗口索引陷阱**：本机 tmux.conf 让窗口索引从 1 开始（非默认 0）——所有定位一律用窗口名
  （`$SESSION:<agent>`），不用数字索引。
- **死因分类**：事故的直接死因是 **tmux 语义层**（pane 死 → 窗口消失 → 无现场）叠加
  **调度逻辑层**（send-keys 对遗体返回 0 → 假送达）；不是 Pi 本体、不是输入路径守卫的 bug ——
  输入路径守卫对遗体会探测失败（画面不变），但兜底文案是「投递未确认」，不会点名「座位已死」，
  且白白探测十几秒。修法 therefore 落在 tmux 留存 + 调度判据两处。

## 二、实现（对照 design D1–D8）

| 决策 | 落点 |
|---|---|
| D1 占位持窗 → 设选项 → **读回** → respawn 交窗 | `cmd-agents.sh` 建窗点（dispatch/resume 共用）；argv 形式 respawn |
| D2 只有 dispatch/resume 的窗设选项；PM/pulse 绝不设（PM 死=窗消失=pulse 重建）；draft 保持原样 | 建窗点单点生效；smoke §40① 断言 PM 窗读回为空 |
| D3 死 pane 是座位状况：四态 `running/exited/dead/absent`，running 的证明规则不动 | `team_seat_condition`（cmd-status.sh 末尾段，唯一读取器） |
| D4 say 对死 pane 不按一个键，消息落收件箱，输出点名已死+证据 | `team_cmd_say` 死 pane 分支（在 send_guarded 之前换道） |
| D5 复用=复用：dispatch/--fresh/resume 三条路，先抓遗体落盘 `state/dispatch-<agent>-pane-dead.txt` 再杀窗，输出点名「上一个 pane 已死」 | dispatch 复用分支；`team_agent_capture_corpse` |
| D6 roster 四态行（▲+证据）+图例；status 席位段+现场块（来源+时间）；机器块加 `pane`/`pane_exit` 不动 `state` 词表；digest [6] 段；doctor 一行 warn | cmd-status.sh 末尾段 + cmd-watch.sh `team_panel_agents_json` |
| D7 读面只读：roster/status/digest/doctor/__panel-data 对 state 指纹零变化 | smoke §40④ 指纹断言 |
| D8 文档：protocol §8f 一句 + troubleshooting §11b 一节 + delta 指针 | 见提交 6b90819 |

实现期实测抓到并修掉的三个真 bug（都有提交）：

1. **空字段串列**：`list-panes -F '#{pane_dead} #{pane_dead_signal} …'` 空格分隔时，被 kill 的 pane
   `pane_dead_status` 为空 → 字段左移 → signal 读到时间戳。改 `|` 分隔（63dab9b）。
2. **tmux 的死讯通知行**：`[Pane is dead (status 1, signal 9)…]` 被画在遗体画面中部，
   `tail -n N` 只会拿到空行+通知行、丢掉真正的末行 → 捕获时按行丢弃该通知（63dab9b）。
   这同时实证了 spec 那句「visible screen alone can lose the last line」。
3. **读回失败短路重试契约**（FAST 门禁的 M4.3 B1 楔死窗夹具抓到的回归）：我初版在读回失败时
   `return 1`，把「首发+重试共 2 次 new-window、失败诊断、失败路径杀窗」的既有契约短路成 1 次。
   改为本轮作废、窗口留给下一轮重用分支/失败路径杀（154cff6）。

## 三、验收对照（brief 逐条）

> §40 = `skills/teamsmith/tests/smoke.sh` 的新段「40 · pane 留存」（FULL 模式运行；FAST 段表已含 fast_skip 行）。

1. **dispatch/resume 建窗即 on（设置先于启动），PM/pulse 不改动** —— §40①：
   读回 `on`；PM 窗（fixture 会话的 `pm`）窗口级读回为空（D2）。pulse 窗 fixture 不建，
   代码面：建窗点是 dispatch/resume 唯一入口（清点文件逐点佐证）。
2. **kill 后遗体留 scrollback，pane_dead=1、退出证据 signal=9** —— §40②：轮询到
   `pane_dead=1`、`pane_dead_signal=9`、窗口仍在、`capture-pane -p -S -` 含 P55-MARK-5。
3. **say 不按一个键、消息落收件箱、输出点名已死+证据** —— §40③：rc=0；输出含
   `pane 已死（signal=9）`、不含「已确认送达」/`said to`；inbox 新增该消息行；
   `capture-pane -S - | cksum` 前后逐字节相等。
4. **roster 四态 + 机器面 pane/pane_exit + status 现场块（来源标注）** —— §40④：
   四席位夹具（p55live 在跑 / p55exit 已退出 / p55w ▲已死 signal=9 / p55none 无窗口）逐行断言 +
   图例行；`__panel-data --block agents` 用 python3 断 JSON（尸体 `state=exited`+`pane=dead`+
   `pane_exit=signal=9`，无窗席位无 `pane` 键，无条目弱证据报 running）；`status T9.55` 含
   座位行/来源/记录时间/恰好 2 行现场（`TEAM_AGENT_SCENE_LINES=2`）；活席位任务无现场块。
5. **close --keep-window 后不算异常退出、不进 pending stopped；未收尾死席位仍被点名** ——
   §40⑦ 与 ④ 对照：收尾前 digest `[6] 死 pane` 的 `!` 行 + doctor warn + pending `stopped=1`；
   `close T9.55 --status blocked --keep-window` 后 digest 改口「无登记任务」、doctor 无该行、
   pending `stopped=0`、roster 仍如实 ▲；teardown 后四态回到「无窗口」。
6. **完整门禁绿 + openspec validate 绿** —— 见末节输出尾段。
7. **翻转**：`skills/teamsmith/tests/fixtures/p55/flip-p49.sh`（rc=0）——
   leg0 未改全绿（27 条）；leg1 删掉留存（建窗换回旧一行）→ B1 红（kill 后窗口消失）；
   leg2 删 say 换道 → C2 红；leg3 roster 冒充在跑 → E1 红。证据：`flip/`（四条腿的逐断言 results）
   与 `flip-p49.log`（判定输出）。
8. **git status 干净** —— 见末节。

补充：正常退出语义不变（§40⑥）：fake agent `sleep 2` 自然 exit 0 → pane 活着（pane_dead=0）→
roster「已退出」而非 ▲ → `resume --agent` 正常续跑、恰好一个窗口。
旧 `.exit` 不误报为本轮退出（§40⑤：复用后 `.exit` 不存在 —— harness 每轮先 rm 再 respawn）。

## 四、消费方清点（任务 2.4）

`docs/team/reports/P55-dev/tmux-window-sites.txt`：对 `team_agent_live` /
`team_agent_window_exists` / `new-window` / `send-keys` / `kill-window` 的全部调用点逐个裁决。
结论：没有任何未修改的调用点会把遗体当活座位（running 判定全走 M6.5/M37 证明，遗体证明天然失败，
全部落入 not-running 的安全一侧）；notify 的敲门 target 永远是 PM 窗口且消息在按键前已落收件箱，
delta 所述「notify knock against that seat」的形状结构上不存在；outbox/draft/knock 对遗体走既有
守卫兜底（探测失败 → held/收件箱，不丢消息）——均在授权面外，未动。

## 五、门禁输出尾段（交付时刻，分支 tip）

完整门禁第二趟（第一趟抓到本任务的两个真问题 —— flip 夹具顶层隔离不满足 M28 lint 规则 D、
§40 python 把裸数组当 `{"agents":[…]}` 读 —— 修复后重跑）：

```
$ bash skills/teamsmith/tests/smoke.sh </dev/null          # FULL_RC=1
== 结果 ==  ✓ 2972  ✗ 1
== 40 · pane 留存：死 pane 是座位状况，不是活座位（P55 / agent-pane-survivability） ==
  （§40 共 93 ✓ 0 ✗，逐条输出：docs/team/reports/P55-dev/section40-full-gate.txt）
唯一 ✗：M28 容器里跑真 pi 体检失败（rc=1）—— 见下「预存环境失败」
```

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
Totals: 22 passed, 0 failed (22 items)        # rc=0
```

```
$ git status --porcelain
（空）
```

**预存环境失败（非本任务引入，证据三条）**：`M28 容器里跑真 pi 体检` + 其明细行 `M45 空闲空框` ——
① dev3 的 P53 交付完整门禁（P55 代码不存在）同一条同形失败（`/tmp/p53-evidence/final-full.log`：
✓2860 ✗1，即此条）；② dev-bob 的 P59 完整门禁（同样无 P55 代码）此条全绿（✓2896 ✗0）→ 随 pi.dev
版本检查时机飘动的环境型 flake；③ 该夹具 `tests/pm-box-real.sh` 不经过 dispatch/roster/status 等任何
P55 代码路径（grep 无调用）。

**翻转（rc=0）**：`docs/team/reports/P55-dev/flip-p49.log` + `flip/`（四腿逐断言 results）。

## 六、交付状态

- local 模式：未 push；分支 `task/P55-pane-survivability-apply` 留在 `.worktrees/dev`，等 PM 复验后本地合并。
- 未触碰授权面外文件；P53 红线遵守（cmd-status.sh 只动「文件末尾新加段」）。
- 已知边界：panel bundle（React）未动（design 决策：机器面加键，渲染器照旧）；`team ps` 不在 B3 授权面，
  死 pane 在 ps 里落进「未在跑」一侧（安全方向，清点文件有记录）。
