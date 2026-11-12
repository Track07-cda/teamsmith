---
id: P450
title: 修复默认配置下提醒工具不注入与失败无证据
agent: dev
category: code
phase: opsx-apply
change: agent-self-reminder
specs: agent-remind-tool
anchor: openspec/changes/agent-self-reminder/tasks.md
deltas: agent-remind-tool
branch: task/P450-remind-init-config
---

# P450 · 默认配置下提醒工具必须可用

## 缺陷证据

V158（dev3）真实模型验证：AC-02/AC-09 自主性本身通过，但 `templates/config.sh.tmpl` 的 `TEAM_SESSION` / `TEAM_PM_WINDOW` 带行尾注释，`scripts/remind-capability.mjs:configValue()` 把注释算进值，验证失败；`extension/team-remind.ts` 又静默 `catch { return false }`，doctor 只报 unknown。真实 `team init` 项目因此没有 `team_remind`。

阅读 `docs/team/reports/V158-dev3.md` 与 `/var/tmp/v158-lab/evidence/`，不要修改真实项目配置。

## 最小修复

1. `configValue()` 正确支持模板已有的 quoted value + 行尾注释：引号内的 `#` 属于值，引号后的空白 + `#` 是注释；未加引号时也只把空白后的 `#` 当注释。不要删除模板注释，不要要求用户迁移配置，不另造配置解析系统。
2. 注入前校验失败时写入可见的 `status=error` 能力证据和具体原因，doctor 能区分“未加载/无证据”和“加载了但配置校验失败”。不能继续静默返回 false，也不能把不匹配的配置当成通过。
3. 真实 Pi 夹具不再手写无注释配置来绕过生产形状：用 `team init` 生成配置，再只覆盖测试所需模型键；保留私有 HOME/tmux/项目隔离。
4. 不新增额度、权限位分析或配置键，不改提醒语义。

## 验收

- 带行尾注释的默认配置下工具注册/暴露成功；quoted `#`、未加引号值、真实 mismatched 配置各有行为断言。
- 恢复旧 `configValue()` 必须按名变红；删除 error 证据写入必须按名变红；修复后恢复绿。
- 配置确实不匹配时必须拒绝并留下 error 原因，不能伪装 ready。
- 跑 `remind-tool-real.mjs`、`remind-delivery.sh`、`state-authority.sh`、相关 doctor/init 选段、OpenSpec/spec-refs/section-select/账本禁令；不跑全量/夜间/61b。
- 作者不重复 V158 的长真实模型场景；交付后由原 verifier 用**未修改的 team init 配置**重跑 AC-02/AC-09。

## 交付

小步提交，`docs/team/reports/P450-dev.md` 先给结论，附红/绿/恢复、doctor error 证据、真实 init 夹具与未跑范围。通知 PM 后交 V158 复验；不合并、不归档、不发布。
