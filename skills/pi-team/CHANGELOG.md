# pi-team 变更史

> 版本号单一来源：`scripts/lib/common.sh` 的 `TEAM_VERSION`（`SKILL.md` 的 `metadata.version` 必须一致，
> `team version --check` 会检查）。**更新怎么拿到**：`scripts/**` 每次调用现读盘（零操作）；
> `SKILL.md`/`references/**`/`templates/**`/`extension/**` 在 Pi 里输入 `/reload`（或 `/pi-team-reload`）即生效；
> 判断自己是不是旧的：`team mark-loaded`（开局记一次）→ `team version --check`。

## v1.11.0 · 2026-09-11

**收窄到"不包装已有工具"（用户原则）**
- **删除** `team merge` / `team pr`（连"打印食谱"也算包装）：合并与开 PR 由 PM 直接用 git/gh/glab/tea/网页；
  步骤写进 `SKILL.md`、`references/workflows.md`、`references/protocol.md §8h`
- **删除** `team gh` / `team gl` 透传与 `scripts/lib/forge.sh`（token 只作为项目配置；PM 自己注入）
- `team review <ID>` 现在**要求 `--dir <PM 准备的独立 checkout>`**：skill 只跑门禁 + 写证据，不碰 git
- `team add-agent` / `bootstrap` 默认**只打印** `git worktree add` 命令（git 归 PM）；
  想让它代建加 `--create` / `--create-worktrees`；`dispatch` 不再代建 worktree
- `team close <ID>` 也彻底不碰 git（不再 `--delete-branch`；只在输出里提示 PM 自己跑 switch/删分支）
- 保留（这些不是已有工具的包装）：任务书/看板/线程/报告/收件箱/digest、派单与提示词、
  看门狗与巡检、容量守卫、监视器、跨项目会议、版本与更新

## v1.10.0 · 2026-09-11

**分工变更：git 与 forge 写操作归 PM，skill 不再代做**
- `team merge <ID>` / `team pr <ID>` 由"执行合并/建 PR"改成**打印可复制粘贴的食谱**：
  - `merge`：在主工作树 squash 合并（含 lockfile 用 `--theirs` 的处理提示）→ push → `board set done`
    → 删分支（可选）；给了 `--pr N` 时按 **forge-first** 排序（先合 PR，再 `fetch + merge --ff-only`）
  - `pr`：push 分支 + 建 PR/MR 的命令
- `team dispatch` 不再自动建/切分支：只**检查**工作树（不在保护分支上、不脏），否则拒绝并给出该跑的 git 命令
- `team close` 只动 BOARD/窗口/状态，不再切/删分支（只提示）
- 删除 forge 写操作（`forge_open_pr` / `forge_merge_pr` / `forge_pr_record_and_close`）；
  `team gh` / `team gl` 变成**只读透传**，写命令直接拒绝并指路食谱
- **forge 无关**：`TEAM_VCS=local|github|gitlab|other`；非 GitHub/GitLab 可用 `TEAM_PR_CMD` /
  `TEAM_MERGE_PR_CMD` 写命令模板（占位符 `{branch} {base} {title} {pr} {body}`），skill 只负责渲染
- 任务书文件名：非 ASCII（中文）标题的 slug 退化为 `task`，不再出现 `T1.1-.md`

## v1.9.0 · 2026-09-11

**更新分发与版本自检（新）**
- `team mark-loaded`：把本会话加载的 skill 版本 + 指纹（SKILL.md+extension 哈希）记进 `.pi/team/state/pm-loaded.env`
- `team version [--check]`：磁盘代码版本 / SKILL.md 版本 / CHANGELOG 版本 / 本会话加载版本 + 结论与生效方式
- `team changelog [--since X]`、`team reload [--done]`
- 扩展新增命令 `/pi-team-reload` 与工具 `reload_skills`：PM/agent 可自助刷新 skill（等价 `/reload`）
- `digest` / `doctor` 增加"skill 版本 vs 本会话"提示行
- 依据（读 Pi 实现确认）：`/reload` 会重新发现 skills 并重建 system prompt（`available_skills`），
  同时清扩展模块缓存并重新解析 CLI 传入的 `--skill`/`-e` 路径 → 文档与扩展都能热更新；
  `scripts/**` 本来就每次现读盘

**合并顺序修正（CEP 实测，重要）**
- `team merge --pr N` 改为 **forge-first**：先让 forge 合 PR/MR（历史保留真合并提交与 PR 链接），
  成功后 `git fetch && merge --ff-only` 快进本地保护分支；失败才回落到本地 squash+push+留言+关 PR
- 失败提示不再甩锅权限：打印 forge 的真实错误，并按内容区分「不可合并（冲突/已被推进）」与「权限」

**`team say` 投递校验（CEP 实测）**
- 发送后比对 pane 内容指纹确认送达；没动静就补发 Enter、再整条重发一次；仍未确认 → 明确报"投递未确认"
  并写明消息已落收件箱 + 手工兜底命令（不再假报成功）
- agent 没在跑（窗口不在 / pi 已退出）时不再硬失败：消息落收件箱 + 提示 `team resume --agent`
- 新增 `--no-verify` 跳过校验

**跨项目会议**
- 新增 `meeting peer <slug> <项目>:<session>`（事后登记 session）与 `meeting knock <slug>`（重敲最后一条）
- 敲门失败输出五步排查清单（全局开关 / 对方 session / session 是否存在 / PM 窗口是否在跑 pi / 边界守卫）

## v1.8.0 · 2026-09-11

- **跨项目会议模式**（peer 交流，不是指令通道）：`meeting open/say/read/list/inbox/propose/agree/close`
  - 共享区 `~/.pi/team/meetings/<slug>/`（两个项目之外）；transcript 是唯一真相，先落盘再（可选）敲门
  - `intent` 白名单 `info|question|report|proposal|request` —— 机制里没有 command/order
  - `--as-user` 仅人类终端可用；共识需双方各自 `agree`；TTL 72h、每边 20 条上限；close 后冻结
  - 跨 session 打字默认一律拒绝，唯一例外＝已登记会议的敲门
- 修复：新建 tmux 窗口瞬间 `pane_pid` 可能是 tmux 自己（`[tmux: server]`）→ 窗口被误判"忙"、PM 拉不起来

## v1.7.3 · 2026-09-11

- `forge_gitlab_api` 按调用自动选 Content-Type（`--data-urlencode` → 表单头），修 GitLab 开不出 MR
- 派单解析 `pi` 绝对路径 + 校验存在性（修 `pi: command not found` 竞态）
- `team_render` 不再走 sed 并关掉 bash 5.2+ 的 `patsub_replacement`（修 `TEAM_GATES="a && b"` 被写成 `{{GATES}}{{GATES}}`）
- 非任务交付物不再被当待复验；`team resume` 支持位置参数

## v1.7.2 · 2026-09-11

- **BOARD 的 done 只在「merge + push 都成功」后写**；任何失败都还原状态并给恢复步骤
- `--pr` 自动带 `--push`；`--prefer-theirs <path>` 解决 lockfile 冲突；merge 前校验分支存在

## v1.7.1 · 2026-09-11

- merge 失败列出未合并文件（UU/AA/…）+ `--no-renames`
- BOARD 解析按表头名定位（容忍手工加列）；`board set` 只改状态列
- 「待复验」收紧为真任务报告；结项报告进「忽略的非任务报告」
- 翻转证据（修复前红→修复后绿 / 破坏实现→守门测试失败）写进任务书/报告模板与派单提示词

## v1.7.0 · 2026-09-11

- 容量口径：zram 不当额度（硬线＝MemAvailable + 磁盘 swap 空闲；zram 只警告）
- 分支模型：`TEAM_BRANCH_MODE=task`（默认，一任务一分支）
- 门禁硬超时 `TEAM_REVIEW_TIMEOUT`（超时判 `TIMEOUT`→FAIL）；`review --strong`
- 模型并发限额支持通配（默认 `kimi-coding/k3=2 openai-codex/*=1`）
