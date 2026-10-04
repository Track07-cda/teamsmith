# pm-skills · 任务板

> PM 维护；agent 只读。状态：`todo` / `wip` / `review`(已交付待复验) / `done` / `blocked` / `dropped`
> 工具：`team task <ID> --title ...` 建行 ｜ `team board set <ID> <状态>` 改状态 ｜ `team board ls`

| ID | 任务 | Agent | 分支 | 依赖 | 状态 |
|---|---|---|---|---|---|
| — | （还没有任务：`team task T1.1 --title "第一个任务" --agent dev`） | - | - | - | dropped |
| T1.1 | smoke 快慢分层：给门禁一个 60 秒内的快模式 | dev | - | - | done |
| V1.1 | 对抗性复核：文档一致性不变量与 review --dir 只读性 | verify | - | - | dropped |
| M3.0 | Agent adapter layer: any TUI agent | dev | - | - | done |
| V3.0 | Adversarial verification: agent adapter layer | verify | - | - | done |
| M3.2 | Adapter hardening: V3.0 findings F1/F4/F5/F6/F7/F8 | dev | - | - | done |
| M3.3 | Monitor hardening: V3.0 findings F2 (OOM) / F3 (control chars) | dev2 | - | M3.0 | done |
| M3.4 | Flip stale expectations in the V3.0 verification package | dev2 | - | M3.2 | done |
| M4.1 | English for the remaining reference docs + SCOPE.md | dev | - | - | done |
| V4.0 | Adversarial verification: core lifecycle | verify | - | - | done |
| M2.5 | PM memory manual (references/memory.md) | dev | - | - | done |
| M4.3 | Make the two stuck-worker paths visible (queued until V4.0 lands) | dev | - | M4.1 | done |
| M5.1 | magic-context + OpenSpec as required dependencies (doctor fails without them) | dev | - | - | done |
| M5.2 | Adopt OpenSpec: specs + change workflow + gates | dev2 | - | - | done |
| M6.1 | State honesty: durable task record, board writes, close claims | dev | - | V4.0 | done |
| M6.2 | Review evidence integrity: branch guard, dirty/ignored/timeout/no-gates/--strong/revision | dev2 | - | V4.0 | done |
| M6.3 | Dispatch/notify/boundary: branch match, PM inbox, real recipients, empty-target guard | dev | - | V4.0 | done |
| M6.4 | Digest/version/meeting: upstream-aware, id parsing, SIGPIPE, reload claim, TTL | dev2 | - | V4.0 | done |
| M6.5 | False PM liveness (breaks up + own gate) and honest TIMEOUT attribution | dev | - | M6.2 | done |
| M6.3 | Dispatch/notify/boundary + F30 wrapper proof + OpenSpec protocol guidance | dev | - | M6.5 | done |
| M4.3 | Signal honesty: stuck agents, wedged panes, draft reports, squash noise, false settles | dev | - | M6.3 | done |
| M5.3 | Spec falsifiability lint (openspec validate does not check scenarios) | dev2 | - | M5.2 | done |
| M7.1 | Migration and upgrade guide + doctor pointer | dev | - | v1.22.0 | done |
| M7.2 | Watchdog single-tick jitter root cause | dev2 | - | v1.22.0 | done |
| M7.3 | English-only invariant as a suite assertion + installer duplicate-symlink fix | dev | - | M7.1 | done |
| M7.5 | Dispatch startup-verification flake (B3): diagnose and make deterministic | dev | - | M7.3 | done |
| M8.1 | PM side adapts too: any TUI agent CLI (default Pi byte-identical) | dev | - | v1.24.0 | done |
| M8.2 | Worker-side bare-name resolution + exit evidence (silent failure with a success line) | dev2 | - | v1.25.0 | done |
| M9.1 | OpenSpec guidance = process management (explore→PM→propose→dev→verify→user→archive) | dev | - | v1.26.0 | done |
| E1 | explore: spec backfill (M6–M8 behaviors missing from openspec/specs) | dev2 | - | v1.27.0 | done |
| P1 | propose: spec-delta-gate (C0, gate-time MODIFIED-delta check) | dev2 | - | E1 | done |
| M9.2 | done evidence must understand pipeline phases (explore/propose/verify/archive) | dev2 | - | v1.27.0 | done |
| P2 | apply: spec-delta-gate (C0 checker in spec-lint + smoke + doc) | dev | - | spec-delta-gate | dropped |
| V1 | verify: spec-delta-gate — differential vs openspec archive (adversarial) | verify | - | P2 | done |
| M9.4 | pending verification must not outlive the board's decision | dev2 | - | M9.2 | done |
| P2.1 | apply rework: close V1 findings F1–F5 (differential parity) | dev | - | V1 | dropped |
| V1.1 | re-verify spec-delta-gate after F1–F5 rework (own matrix as the net) | verify | - | P2.1 | dropped |
| V2 | re-verify spec-delta-gate after F1–F5 rework (verifier's own matrix as the net) | verify | - | P2.1 | done |
| E2 | explore: scope and split for C1 launch-and-adapter-evidence | dev2 | - | E1 | done |
| P2.2 | apply rework 2: close F-V2-1 (symlinked delta spec.md invisible to the gate) | dev | - | V2 | dropped |
| P3 | propose: launch-and-adapter-evidence (C1) | dev2 | - | launch-and-adapter-evidence | done |
| P2.3 | apply rework 3: escaping symlink must be a named refusal (premise was measured false) | dev | - | P2.2 | dropped |
| V3 | re-verify spec-delta-gate after P2.2+P2.3 (links; judge the D17 dispute independently) | verify | - | P2.3 | dropped |
| M9.3 | dispatch must not stack a second task on one agent (D16 tool half) | dev2 | - | M9.4 | done |
| E3 | explore: human draft entry + deferred delivery while the PM is typing (D20) | dev2 | - | D20 | done |
| P2.4 | apply rework 4: close F-V3-1 (symlinked change dir) + realpath generalization | dev | - | V3 | dropped |
| P5 | propose: deferred-delivery-and-draft-entry (D20 option B) | dev2 | - | deferred-delivery-and-draft-entry | done |
| V4 | final verify: spec-delta-gate after P2.4 (exit criterion: zero reachable disagreements) | verify | - | P2.4 | dropped |
| M9.7 | kill the two smoke timing flakes (bounded polling) | dev2 | - | v1.30.0 | done |
| P2.5 | apply rework 5: contain walk roots + enumerate dot change dirs (F-V4-A/B) | dev | - | V4 | dropped |
| P7 | propose: rename-watchdog-to-pulse (D22; alias period; spec strategy a/b) | dev2 | - | rename-watchdog-to-pulse | done |
| V5 | final verify: spec-delta-gate after P2.5 (decides the archive question) | verify | - | P2.5 | done |
| M9.5 | verify-task record binds the reviewed revision, not the verifier branch | dev | - | v1.31.0 | done |
| M9.6 | done evidence requires a committed report (zero-commit hole) | dev2 | - | v1.31.0 | done |
| P4 | apply: launch-and-adapter-evidence (C1 补账：adapter 引擎 + PM 存活证据进规格库) | dev | - | launch-and-adapter-evidence | done |
| E4 | explore: pulse 面板的 TUI 重写（D19 第一步：选型/分发/布局/降级） | dev2 | - | D19 | done |
| V6 | verify: launch-and-adapter-evidence（补账三层验证 + 交付诚实性裁决） | verify | - | P4 | done |
| P9 | propose: pulse-tui-panel（Ink+TSX 单文件新前端，monitor.mjs 留作数据层） | dev2 | - | pulse-tui-panel | done |
| P6 | apply: deferred-delivery-and-draft-entry（输入框守卫 + 延后队列 + 草稿窗口） | dev | - | deferred-delivery-and-draft-entry | done |
| M9.8 | watchdog 的唤醒计数 = digest 的可行动列表（同源同过滤） | dev2 | - | v1.33.0 | done |
| V7 | verify: deferred-delivery-and-draft-entry（E3 七条攻击面 + 多行草稿投递） | verify | - | P6 | done |
| V8 | verify: P6 rework——六条 finding 关闭确认 + F3b 二值裁决 + 新表面攻击 | verify | - | P6 | done |
| V9 | verify: P6 rework 2 收口（N1 真实 Pi 确认 + 残余行裁决 + 新表面攻击） | verify | - | P6 | done |
| M10 | apply: drop-spec-lint（删除自研规格检查器，门禁回归 validate+smoke） | dev2 | - | drop-spec-lint | done |
| P8 | apply: rename watchdog → pulse（代码先行；规格增量归档前由 PM 刷新） | dev2 | - | rename-watchdog-to-pulse | done |
| V10 | verify: 收口裁决（残余行逐行判 + 收敛判据） | verify | - | P6 | done |
| P10 | apply: pulse-tui-panel（Ink 面板重写） | dev | - | pulse-tui-panel | done |
| M11 | bootstrap 把 PM 窗口名固定写成 pm + doctor 漂移报警 | dev | - | - | done |
| M12 | 修 smoke PM 适配器段抖动（V9-E1：量出来→修→翻转证据） | dev | - | - | done |
| E6 | explore: pulse 控制台化 + 输入框状态数据通道（Pi 扩展 API 可行性实测） | dev2 | - | - | done |
| P11 | propose: pulse-console 实施提案（设计已定稿，E6 可行性已接受） | dev2 | - | pulse-console | done |
| P12 | apply: pulse-console B1（数据装配异步化+缓存化） | dev | - | pulse-console | done |
| P13 | apply: pulse-console B2（消息入口+三个动作） | dev | - | pulse-console | done |
| P14 | apply: pulse-console B3（三页+设置+鼠标+i18n+响应式+q 收起） | dev | - | pulse-console | done |
| V15 | verify: pulse-console 整变更对照设计定稿 | verify | - | pulse-console | done |
| M14 | 派单模型解析：配置压过名册旧记录（用户的 k3-256k 规则实测没生效） | dev2 | - | - | done |
| M16 | 沟通纪律：代号必须随身带人话名字（PM 汇报/CLI 输出） | dev2 | - | - | done |
| V16 | verify: pulse-console 收尾（包钉更新 + 全量 0 bad + 新表面攻击） | verify | - | pulse-console | done |
| M17 | 打字未发送的收回纪律：不留字在用户框里（用户实测） | dev2 | - | - | done |
| M18 | cmd-status.sh:463 team_watchdog_state_text 未定义（P8 改名漏网） | dev3 | - | - | done |
| M19 | PM 启动指引缺口：pulse 没在跑要明说拉起来（SKILL.md + AGENTS 模板） | dev3 | - | - | done |
| M20 | 门禁计时断言假红：27-d 取多次中位 + 26-m 同族复查 | dev2 | - | - | done |
| M21 | 控制台收尾：英文设置浮层键列窄 + F-V16-4/5 写实然 + F-V16-6 升级条目 | dev3 | - | - | done |
| M22 | 移除 skills/pi-team 兼容软链（用户拍板提前结束别名期） | dev2 | - | - | done |
| E7 | explore: teamsmith 拆成日常 skill + 初始化 skill 的边界与代价 | dev | - | - | done |
| E8 | explore: harness 能力探测 + 后台任务完成通知插件（pi 扩展形态） | verify | - | - | done |
| M23 | smoke 并发互相卡死：夹具改私有 tmux socket 或全量门禁互斥 | dev2 | - | - | done |
| M24 | PM 空闲时空框仍 draft-race + 收回零成功：投递守卫误判调查 | dev2 | - | - | done |
| V16.1 | flip 包补丁静默落空：破环补丁必须落空即红 + 重钉到 M21 后的 bundle | verify | - | - | done |
| M25 | 复验基建：TEAM_REVIEW_* 覆盖项泄漏进门禁环境 + 后台窗口跑 review 必挂 6i | dev2 | - | - | done |
| P15 | propose: split-teamsmith-init-skill（E7 轻拆形态，用户拍板直接拆） | dev | - | - | done |
| P16 | apply: split-teamsmith-init-skill（提案已 ACCEPTED） | dev3 | - | - | done |
| V17 | verify: split-teamsmith-init-skill（P16 apply 的独立验证） | verify | - | - | done |
| M26 | doctor/init 探测 harness 与后台任务包 + 推荐文案（E8 P1） | dev3 | - | - | done |
| M27 | 自写 team-bg.ts：团队后台任务车道（E8 P2，用户拍板自写） | dev2 | - | - | done |
| M29 | init/doctor UX：插件只报已装+推荐只限必需；名册改最小起点 | dev3 | - | - | done |
| M30 | draft-race 误判第五起：chars 折叠精确匹配在真实 payload 上失手 + 守卫缺诊断日志 | dev2 | - | - | done |
| P17 | propose: pulse-console 条目详情查看器（board/条目 → 渲染 markdown 详情） | dev | - | - | done |
| P18 | apply: console-board-page（看板页+markdown 详情+有界帧；提案已 ACCEPTED） | dev3 | - | - | done |
| M28 | tmux 接触型测试进 podman 容器 + 裸 tmux 调用 lint | dev2 | - | - | done |
| V18 | verify: console-board-page（P18 三批 apply 的独立验证） | verify | - | - | done |
| M31 | 容器镜像补 procps + digest 警告未入账的复验/报告记录 | dev2 | - | - | done |
| M32 | smoke 的 tty 敏感探针自 detach stdin（PM 在 tmux 窗口直接跑门禁必绿） | dev2 | - | - | done |
| M33 | 调查：smoke 运行中 $TMP 写入瞬时 ENOENT（bg6 的 50 红，串行复跑不复现） | dev2 | - | - | done |
| P18.1 | --title | fix: 两栏排版共享预算饿死右栏（用户实机发现） | - | --agent | done |
| M34 | work 页看板卡：活跃态置顶（用户拍板） | dev3 | - | - | done |
| M35 | smoke 抖动清查：attempts state=idle（两连）与 M25-② 对照组（一见） | dev2 | - | - | done |
| M36 | tmux 破坏性调用闸门：PATH 包装器记录+拒绝打默认 server 的 kill（默认 server 死亡事故第 5 次） | dev | - | - | done |
| M38 | public-release-prep：打包与发布准备（准备工作，不发布） | dev-bob | - | - | done |
| M37 | worker 存活探测：看 pane 进程树而不是 pane_current_command（假「停了」告警） | verify | - | - | done |
| M39 | 6k④ 夹具竞态：断言前要有界等到窗口成型 + 失败信息带现场 | verify | - | - | done |
| M40 | 身份一律以运行时目录为准：TEAM_* 环境变量不许静默赢过 cwd | dev3 | - | - | done |
| M41 | shim socket 解析复刻 tmux 的 TMUX_TMPDIR 回退（第 6 次默认 server 死亡实证） | dev2 | - | - | done |
| P19 | propose: 写信光标+图片粘贴+线程改名 | dev-bob | - | - | done |
| P20 | apply: panel-ergonomics（六批） | dev2 | - | - | done |
| M43 | inbox 唤醒重放：42 条假新消息投递两次 | dev | - | - | done |
| M44 | 门禁守卫：跟踪文件不许有冲突标记 | verify | - | - | done |
| P21 | propose: 控制台配置项目设置 | dev-bob | - | - | done |
| M45 | pi 更新横幅把输入框判据读成 BUSY | dev2 | - | - | done |
| P22 | apply: console-project-settings（四批） | verify | - | - | done |
| M46 | 投递降级要可见（扩展 skip setup 静默丢快路径） | dev3 | - | - | done |
| M47 | CI 可移植性：48 条红分类与修复 | dev2 | - | - | done |
| M48 | 看板重复 ID：聚焦卡死 + board add 不设防 | dev3 | - | - | done |
| M49 | 项目设置 key 的 i18n 标签 | verify | - | - | done |
| M50 | 读操作性能：消灭每文件子进程扇出（digest 89s→） | dev | - | - | done |
| P23 | change 为中心：一任务一 change + B 锚点（propose） | dev-bob | - | - | done |
| P24 | change 纪律 apply（B1/B3-B7；B2 待 M48/49/50） | dev-bob | - | - | done |
| P25 | 收件箱投递韧性：假缩容/重扫收敛/过期不唤醒（propose） | dev2 | - | - | done |
| P26 | 门禁资源纪律：复验超时不含排队 + 性能断言负载前提（propose） | verify | - | - | done |
| P27 | 门禁资源纪律 apply（排队记账 + 负载前提） | verify | - | - | done |
| P28 | 收件箱投递韧性 apply（offset/证据/过期门/账本 + 生产者裁切） | dev2 | - | - | done |
| M51 | 门禁夹具环境假设：镜像缺 /usr/bin/time + 35e 核数依赖 | verify | - | - | done |
| M50a | M50 收尾：写报告与证据（实现已就绪） | dev2 | - | - | done |
| M50b | M50 合并 main：三处冲突按语义解决 + 合并结果跑门禁 | dev2 | - | - | done |
| M52 | inotify 配额耗尽：唤醒降级可见 + 轮询兜底 + 夹具可分辨（propose） | verify | - | - | done |
| M53 | watch-degradation apply（记录/兜底/doctor 余量/门禁前提） | dev2 | - | - | done |
| M54 | 设置视图：有选择就给选择（schema 驱动，bool/enum/model/数值） | dev-bob | - | - | done |
| M55 | 设置选项 apply（choices 字段 + 选择器 + suggest 列） | dev3 | - | - | done |
| M56 | watch-degradation 独立验证（含界面首帧红是否环境所致） | verify | - | - | done |
| M57 | 性能测试与全量门禁拆分（perf-suite-split，propose） | dev-bob | - | - | done |
| M58 | perf-suite-split apply（正确性门禁去性能判定 + 独立性能套件） | dev2 | - | - | done |
| M59 | pty 夹具健壮性：稳定帧等待 + 清理按键状态确认 + 失败自带现场 | dev3 | - | - | done |
| M60 | settings-choice-editors 独立验证（反硬编码 / 读=校验 / 模型词汇 / 写入路径） | dev | - | - | done |
| M61 | 规格回填 2026-09：六条已落地的跨任务规则写进契约 | dev-bob | - | - | done |
| M62 | spec-backfill 证据核对（apply：逐行核对 + 两条翻转） | dev-bob | - | - | done |
| M64 | perf-suite-split 独立验证（正确性门禁不判性能 / 套件自述 / 守卫双向 / CI 两结论） | verify | - | - | done |
| M63 | 授权模型重做：按目标归属判定 + argv 一次性授权（方案 2） | dev-bob | - | - | done |
| M65 | 设置选择重做：先测延迟根因再改交互（选中直写 / 其他才手动） | dev2 | - | - | done |
| M66 | perf.sh：--in-container 校验钉死信号，宿主直跑可见拒绝（M64 F2） | dev | - | - | done |
| M67 | 授权模型重做 apply（判定按目标 + argv token + 夹具/翻转） | dev-bob | - | - | done |
| M69 | perf.sh：--in-container 要求镜像自带标识文件（F2 复验逃逸） | dev | - | - | done |
| M70 | spec-backfill 独立验证（含 boundary 与 M67 后现实的逐字核对） | dev2 | - | - | done |
| M71 | 回填 delta 修订：移除 boundary 三行（归 tmux-gate-grant-redesign） | dev-bob | - | - | done |
| M73 | perf.sh：标识文件不得是挂载点 + 信任边界成文（M64 F2 第三轮） | dev | - | - | done |
| M68 | 设置选择重做 apply（直写交互 + 交互路径不等读 + 读一遍） | dev2 | - | - | done |
| M74 | settings-choice-editors 重做独立验证（直写 argv / 零读取 / 危险值例外 / 读一遍等价） | dev | - | - | done |
| P29 | 设置视图：按功能分组 + 重启类颜色 + 滚轮（propose） | dev-bob | - | - | done |
| M75 | tmux 闸门重做独立验证（按目标判定 / 环境零授权 / token 两态 / 夹具纪律） | dev3 | - | - | done |
| P30 | 设置视图 apply（第 10 列 group + 功能域分组 + 行级 class + 滚轮） | dev-bob | - | - | done |
| P31 | 设置视图分组独立验证（单一真源/功能域/词+tone/滚轮/基线未动） | dev2 | - | - | done |
| P32 | 设置视图修订：标题可辨识 + 用满窗口高度 | dev-bob | - | - | done |
| P33 | team_bg_run 结果带原始命令（超长缩略，按码点切） | dev2 | - | - | done |
| P34 | scope 收窄为 Pi-only（契约 + init 检测 + 接缝标注，propose） | dev3 | - | - | done |
| P35 | README 示例 pin 对齐 + 纳入版本一致性检查 | dev | - | - | done |
| P36 | PM 会话交接：--fresh-pm + init 交接段 + 同 cwd 活会话提示 | dev2 | - | - | done |
| P37 | 安装形态对齐 openspec：npm 全局 CLI + 项目内 init 装 skill（propose） | dev2 | - | - | done |
| P38 | dispatch 守卫：apply 任务不得派给 verify 席位（propose） | dev3 | - | - | done |
| P39 | pi-only-scope apply（宣称面 Pi-only + 接缝 frozen 标注） | dev3 | - | - | done |
| P40 | npm CLI + team init 装 .pi/skills（apply，等 P39） | dev2 | - | - | done |
| P41 | pi-only-scope 独立验证（禁语/措辞/问卷/四键/两版渲染） | dev | - | - | done |
| P42 | settings-view-groups 独立验证（含 P32 修订面） | dev | - | - | done |
| P43 | 门禁指纹假红 + 记录可见性 + --json 空 override（propose） | dev-bob | - | - | done |
| P44 | pty 夹具负载前提（忙机不许假红）propose | dev3 | - | - | done |
| P45 | change-centric-discipline B2 apply（digest 归组 + 面板 token） | dev2 | - | - | done |
| P46 | 名册写入路径 + 路线真诚性检查（propose，等席位） | dev | - | - | done |
| P47 | ledger-and-gate-noise apply（指纹/记录可见性/JSON） | dev-bob | - | - | done |
| P48 | pty 负载前提 apply（前提行/延长/归因/实验守卫） | dev3 | - | - | done |
| P49 | 席位窗口无声消失：死 pane 留现场（propose，等席位） | verify | - | - | done |
| P50 | 测试不许漏 /tmp（夹具回收 + 占用可见）propose | - | - | - | done |
| P51 | npm 变更独立验证 | dev | - | - | done |
| P52 | pty 负载前提独立验证 | dev2 | - | - | done |
| P53 | test-tmp-hygiene apply（临时根拥有者/回收/sweep/doctor） | dev3 | - | - | done |
| P54 | ledger-and-gate-noise 独立验证 | verify | - | - | done |
| P55 | agent-pane-survivability apply（pane 现场 + 四态） | dev | - | - | done |
| P56 | 门禁段落自述/超时/现场（propose） | dev-bob | - | - | done |
| P57 | 信任弹窗不许把夹具判红（propose） | - | - | - | done |
| P58 | F1 尾单：pm 行同源 + R5 文字 | dev-bob | - | - | done |
| P59 | trust-prompt apply（覆盖层判定 + 信任提示行） | dev-bob | - | - | done |
| P60 | test-tmp-hygiene 独立验证 | verify | - | - | done |
| P61 | trust-prompt 独立验证 | dev3 | - | - | done |
| P62 | 夹具等数据态（propose） | dev-bob | - | - | done |
| P63 | 单行草稿被读成空框（高优先级 propose） | dev3 | - | - | done |
| P64 | container-tmux 临时根合规（小） | - | - | - | done |
| P66 | 排队超时要大声失败（小） | dev-bob | - | - | done |
| P67 | 单行草稿 apply（高优先级） | dev3 | - | - | done |
| P68 | 夹具等数据态 apply（含 CI 红的修法） | dev-bob | - | - | done |
| P69 | change-centric 独立验证 | verify | - | - | done |
| P65 | agent-pane 独立验证 | dev2 | - | - | done |
| P70 | 门禁段落自述 apply | dev2 | - | - | done |
| P71 | 唤醒重复投递：投递要幂等（propose） | verify | - | - | done |
| P72 | 手工 notify 的 sender 记成 pm（propose） | verify | - | - | done |
| P73 | 审计日志毒化隔离扫描（propose） | dev | - | - | done |
| P74 | 单行草稿独立验证 | dev2 | - | - | done |
| P75 | 尾部现场尾空行裁剪（小） | dev3 | - | - | done |
| P76 | 合并前查未入账记录 | dev-bob | - | - | done |
| P77 | 审计日志排除 apply | dev2 | - | - | done |
| P78 | 下边框候选选择（propose） | verify | - | - | done |
| P79 | digest 段号重复修正（小） | dev | - | - | done |
| P80 | 下边框最低候选 apply | dev3 | - | - | done |
| P81 | 唤醒幂等 apply | dev2 | - | - | done |
| P82 | sender 归属 apply | dev-bob | - | - | done |
| P83 | 审计排除独立验证 | dev3 | - | - | done |
| P84 | 下边框独立验证 | dev | - | - | done |
| P85 | 夹具等数据态独立验证 | verify | - | - | done |
| P86 | F1 修复：框必须含光标 | dev3 | - | - | done |
| P87 | bg 排除改确切路径 | dev3 | - | - | done |
| P88 | infra 修正确认（P75/P79） | verify | - | - | done |
| P89 | 唤醒幂等独立验证 | dev | - | - | done |
| P90 | 下边框重验（换人） | dev2 | - | - | done |
| P91 | 合并后核对（D49） | dev-bob | - | - | done |
| P92 | 审计排除重验（换人） | verify | - | - | done |
| P93 | sender 归属独立验证 | dev3 | - | - | done |
| P94 | SCENE_LINES=0 边界（极小） | dev2 | - | - | done |
| P95 | post-merge 基准细化（低） | dev-bob | - | - | done |
| P96 | 合并流程两检查复核 | verify | - | - | done |
| P97 | 门禁分段预算（propose） | dev3 | - | - | done |
| P98 | 门禁分段预算 apply（优先） | dev3 | - | - | done |
| P99 | 名册写入 apply | dev | - | - | done |
| P100 | infra 两件确认（P66/P94） | verify | - | - | done |
| P101 | 席位死因分类 + 通报（propose） | verify | - | - | done |
| P102 | 模型 id 形状（model 段可含 /）propose | dev | - | - | done |
| P103 | CI 镜像 ETXTBSY（infra apply） | dev-bob | - | - | done |
| P104 | 名册写入/用法诚实性 独立验证 | dev-bob | - | - | done |
| P105 | 名册返工（空白名/记录同源） | dev | - | - | done |
| P106 | 夹具尊重 TEAM_TMP_KEEP（infra apply） | dev-bob | - | - | done |
| P107 | 名册返工后的换人重验 | verify | - | - | done |
| P108 | 门禁段落账目 独立验证 | dev-bob | - | - | done |
| P109 | 巡逻误报：wip 报告不唤醒 PM | dev-bob | - | - | done |
| P110 | 门禁段落账目返工（F2/F1） | dev2 | - | - | done |
| P111 | 门禁段落账目 复验（P110 后） | dev3 | - | - | done |
| P112 | 门禁分段预算 独立验证 | dev2 | - | - | done |
| P113 | 席位死因分类 + 通报 apply | dev3 | - | - | done |
| P114 | 模型 id 形状 apply | dev | - | - | done |
| P115 | §36 嵌套跑断言假红（infra apply） | dev-bob | - | - | done |
| P116 | 模型 id 形状 独立验证 | verify | - | - | done |
| P117 | 选段返工（副本可解析 + needs 闭包） | dev | - | - | done |
| P118 | 席位死因 独立验证 | dev2 | - | - | done |
| P119 | 门禁分段预算 复验（P117 后） | verify | - | - | done |
| P120 | §36⑦ 深 TMPDIR 环境假红（infra apply） | dev-bob | - | - | done |
| P121 | 看板显示层（卡片标题 + 车道折叠）propose | dev2 | - | - | done |
| P122 | tmp-hygiene：归属证据 + 拒绝不阻塞 + tmux 残留可见 | dev-bob | - | - | done |
| P123 | 看板显示层 apply（卡片标题 + 车道折叠） | dev3 | - | - | done |
| P124 | 看板显示层 独立验证 | verify | - | - | done |
| P125 | 看板折叠 宽度自适应（宽屏省列/窄屏省行） | dev3 | - | - | done |
| P126 | 模型窗口解析认 :思考档 后缀（修 09-21 痛点） | dev-bob | - | - | done |
| P127 | 等待引擎长帧假缺（pipefail + grep -q SIGPIPE） | dev | - | - | done |
| P128 | 窄档折叠行左对齐卡片列 | dev2 | - | - | done |
| P129 | P127 独立复验（含 26 处守卫语义） | dev3 | - | - | done |
| P130 | CI 省额度：paths-ignore + 只构建一次镜像 | dev | - | - | done |
| P131 | 破坏性调用记录长保留（propose） | dev3 | - | - | done |
| P132 | 破坏性记录长保留（apply） | dev2 | - | - | done |
| P133 | 破坏性记录长保留 独立验证 | verify | - | - | done |
| P134 | 会议机制：发现性+收尾+投递安全+规格（propose） | dev3 | - | - | done |
| P135 | infra tidy：镜像确定性 + close 清分支 + iproute2 + 一行 fallback | dev | - | - | done |
| P136 | 派单摩擦与幂等（propose） | dev2 | - | - | done |
| P137 | references 反面清单（常见被拒与修法） | dev-bob | - | - | done |
| P138 | <cep-project> 报告复现：team say 脏工作树投递 | verify | - | - | done |
| P139 | meeting-liveness apply（发现性/收尾/投递安全/身份/标识） | dev3 | - | - | done |
| P140 | dispatch-friction apply | dev2 | - | - | done |
| P141 | 容量地板补磁盘腿（propose） | dev-bob | - | - | done |
| P142 | 14b 判据按主题判（harness 语境豁免） | dev | - | - | done |
| P143 | 投递真相：几何假 BUSY 卡消息 + notify 命名一致（propose） | verify | - | - | done |
| P144 | capacity-floor-disk apply（磁盘腿 + schema 注册） | dev-bob | - | - | done |
| P145 | spec 理据自洽（公开可读，先量后议） | dev2 | - | - | done |
| P146 | 公开树也要能诚实跑门禁（propose） | - | - | - | done |
| P147 | delivery-truth apply（真帧几何 + 阻碍如实 + notify 同名） | - | - | - | done |
| P148 | product-checkout-gate apply（公开树可见 SKIP + 两向有牙） | - | - | - | done |
| P149 | dispatch-friction 独立验证 | verify | - | - | done |
| P150 | spec 理据自洽 apply（四处重写 + id 键 + 走查） | - | - | - | done |
| P151 | dispatch-friction 返工（修法可粘贴 + 一次列全 + 产出时点） | dev3 | - | - | done |
| P152 | 公开发布面独立验证（证伪我自己的脚本） | verify | - | - | done |
| P153 | meeting-liveness 独立验证 | verify | - | - | done |
| P154 | 只杀自己的 PID：pkill/killall 闸门 + 停作业入口 + lint | - | - | - | done |
| P155 | notify 身份：工作树外目录会不会记成 pm | dev2 | - | - | done |
| P156 | 26-c 纯文本对比要归一实时读数（假红） | - | - | - | done |
| P157 | delivery-truth 独立验证 | - | - | - | done |
| P158 | 门禁自证：树在跑动中被改 → 报无效而不是报红 | dev3 | - | - | done |
| P159 | safe-signal-discipline apply（模式拒 / pid 放行 / 记录保留 / lint） | - | - | - | done |
| P160 | meeting-liveness 返工（F1 账本 / F2 标识宽度 / F3 不许造 task） | - | - | - | done |
| P161 | 文档更正：巡检会自动续跑停了的席位 | - | - | - | done |
| P162 | 隔离前置：破坏性段开跑前必须证明私有 socket 生效，否则硬停 | - | - | - | done |
| P163 | delivery-truth 两条 finding：配方重置现场 + 钉版本与 1.0.0 真帧 | dev-bob | - | - | done |
| P164 | pgrep/pidof 要不要纳入信号闸门（propose） | verify | - | - | done |
| P165 | capacity-floor-disk 独立验证（补派） | - | - | - | done |
| P166 | safe-signal-discipline 独立验证 | - | - | - | done |
| P167 | signal-gate-pgrep apply（窄规则 + 真身路由 + 逐形态红侧） | dev-bob | - | - | done |
| P168 | 夹具排除后台作业账本 bg.log（假红） | - | - | - | done |
| P169 | safe-signal-discipline 返工：bg stop 边界 + 一致 fail-closed + 勾选 | - | - | - | done |
| P170 | product-checkout-gate 独立验证 | - | - | - | done |
| P171 | 夹具 state 守卫收窄到夹具自己的路径（活运行时下不可满足） | - | - | - | done |
| P172 | 巡检叫醒的去重键按类别而非计数（15 分钟噪声） | verify | - | - | done |
| P173 | 产品面检出里 §31 lint 被跳过（探针牙齿一红） | dev2 | - | - | done |
| P174 | pulse-nudge-key apply（类别集合去重 + 三条红侧） | dev | - | - | done |
| P175 | safe-signal-discipline 换人复验（P169 之后） | dev3 | - | - | done |
| P176 | signal-lint 豁免清单里的内部面（产品面假红） | dev | - | - | done |
| P177 | product-checkout-gate 换人复验 | verify | - | - | done |
| P178 | P162 隔离前置硬停的独立验证 | verify | - | - | done |
| P179 | dispatch-friction 换人复验（P151 之后） | - | - | - | done |
| P180 | P162 返工：隔离前置只看首参（-S/-L/命令链可绕过） | dev | - | - | done |
| P182 | meeting-liveness 换人复验（P160 之后） | dev | - | - | done |
| P183 | pulse-nudge-key 独立验证 | dev2 | - | - | done |
| P184 | spec-rationale-self-contained 独立验证 | - | - | - | done |
| P185 | spec-refs 返工：确切相等 + 畸形行不许丢弃 | dev | - | - | done |
| P186 | P180 隔离前置的独立验证（换人） | verify | - | - | done |
| P187 | safe-signal 返工：state/bg 目录自身也必须在项目内 | dev3 | - | - | done |
| P188 | 隔离前置返工：一份分类器 + 命令链 + 别名 + builtin command | dev3 | - | - | done |
| P189 | safe-signal-discipline 第三轮复验 | verify | - | - | done |
| P190 | P188 一份分类器的独立验证（换人） | dev2 | - | - | done |
| P192 | P192 · 重写 `pulse-nudge-key` 的 delta（归档基线已前进） | dev | - | - | done |
| P193 | P193 · 重写 `meeting-liveness` 的 delta（归档基线已前进） | dev | - | - | done |
| P191 | P191 · `spec-rationale-self-contained` 换人复验（P185 修了 F1/F2 之后） | verify | - | - | done |
| P194 | delivery-truth 独立验证（P163 之后） | verify | - | - | done |
| P195 | bg list 与 bg stop 同一条规则（读面不许说谎） | dev-bob | - | - | done |
| P196 | safe-signal-discipline 第四轮复验（P195 之后） | verify | - | - | done |
| P197 | 判据要数标记条数（同 ID 重复不许蒙混） | dev | - | - | done |
| P198 | delivery-truth delta 重写（MODIFIED 少基线场景） | dev | - | - | done |
| P199 | delivery-truth 再复验（P197 之后） | verify | - | - | done |
| P200 | 18c 退场引用断言钉在临时状态（归档后必红） | dev | - | - | done |
| P201 | 主检出里的席位线索不许静默记成 pm | dev2 | - | - | done |
| P202 | routes.sh 翻转②未兑现（变异可能没落地） | dev | - | - | done |
| P203 | 独立验证 P201（发送者身份） | verify | - | - | done |
| P204 | spec 同步：发送者身份的拒绝规则 | dev2 | - | - | done |
| P205 | sender-identity-refusal apply（实现与规范对齐） | dev | - | - | done |
| P206 | sender-identity-refusal 独立验证 | verify | - | - | done |
| P207 | 公开面加设计记录（导出+遮蔽+扫描+过滤历史） | - | - | - | done |
| P208 | sender-identity-refusal 收尾：按事实勾选 16 项清单（归档前置） | - | - | - | done |
| P209 | 归档前置要看清单：tasks.md 有未勾项时拒绝就绪 | dev2 | - | - | done |
| P210 | 席位存活判据：裸 shell 不算在跑 | dev3 | - | - | done |
| P211 | P211 · 看板裁决 `dropped` 的报告不该再算「待复验」 | - | - | - | done |
| P212 | P212 · 账本禁令检查进 FAST 门禁（D94 的机制） | - | - | - | wip |
| P213 | P211 的换人独立验证（dropped 不再算待复验） | verify | - | - | wip |
| P214 | 公开仓 CI 20 条红的定性（只读） | dev | - | - | wip |

## 当前里程碑

见 [ROADMAP.md](ROADMAP.md)。创建于 2026-09-14。

## 阻塞与风险

| # | 事项 | 影响 | 处理 |
|---|---|---|---|
| — | — | — | — |
