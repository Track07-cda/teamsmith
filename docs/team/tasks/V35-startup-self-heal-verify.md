# V35 · 启动自愈（team up 自动升级）独立复验

task: V35
agent: verify
phase: verify
category: verify
change: startup-self-heal
specs: init-skill, pm-lifecycle
deltas: -
branch: task/V35-startup-self-heal-verify
deps: P261（apply 已交付，冻结 tip 见派单消息）

## 复验对象

`startup-self-heal` 的 apply：`team up` 在配置旧形状时自动迁移（值一个不改、写前打印计划、备份、审计）、PM 身份记录缺失时自动登记、不一致仍拒绝、版本提示只提示不安装（有界、缓存、静默失败、`--print` 不联网）。被检树：PM 冻结的独立 clone（tip 见派单消息）。

## 必须自己做的（不许只复跑作者脚本）

1. **迁移值一个不改**：自造一份 0.1.x 形状的配置（`TEAM_AGENT_MODELS` + `TEAM_DEFAULT_MODEL` + `TEAM_PM_MODEL`），`team up`（或 `--print`）→ 逐键 before/after 表里**每个模型值逐字节等于原值**，只改键的形状与名字；旧键消失、新键落盘；备份文件在且内容等于迁移前的配置。
2. **失败关闭**：形状定位不了（注释/多行/变量展开）、兜底类别撞名 → 一个字节都不写（配置、备份、审计都不动），且点名文件与障碍。各造一例。
3. **身份**：缺记录 → 登记并打印一行（model/resume_key/continued）；记录与当前解析不一致（改 PM 模型）→ 仍拒绝、打印两边值、点名后缀。
4. **版本提示**：桩 npm 分别答「有更新 / 相同 / 更旧 / 报错」→ 只有「有更新」打一行（含两边版本号 + 可粘贴命令 + 「工具从不自己安装」）；其余静默且 rc 与启动决策不变；TTL 内不重复联网（桩计数）；`TEAM_UPDATE_CHECK=0` 连联网都不发生；`--print` 不写缓存不联网但预告了会做什么。
5. **端到端**：迁移之后**派单真的按类别选中模型**（dispatch --print 里能看到解析结果），不是只看 `config list` 退出码 0。
6. **不削弱既有断言**：`config upgrade-models` 的手工入口语义不变（`upgrade`/`transaction`/`preview` 组仍绿）；逐条看 diff 有没有删断言换跳过。
7. 容器纪律：钉死容器 + 干净独立 clone；先看 `/tmp` 余量。任何「既有红」必须同命令对照 **v0.2.0（tag）**。

## 交付

`docs/team/reviews/V35.md`（抬头含 `判定: **PASS**` / `判定: **FAIL**`；逐条命令 + rc + 证据路径；写明运行模型）；证据包仓外；不改候选、不合并、不推送；结论按协议通知 PM。
