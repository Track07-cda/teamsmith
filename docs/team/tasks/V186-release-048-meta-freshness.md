---
id: V186
title: 独立刷新 0.4.8 发布所需测试自检记录
agent: verify
category: verify
phase: verify
change: -
specs: verification
anchor: none (infra) — 0.4.8 发布的常规检查，不是 PM 提示词验证
branch: task/V186-release-048-meta-freshness
---

# V186 · 只执行既有发布前测试自检，不等文案

用户 2026-11-23 授权发布新版。项目最后一条元套件 GREEN 2026-11-13，超过发布所要求的 7 天；该次不是本版本的通过证据。你没有实施这些改动。PM 准备干净独立检出，路径和完整 SHA 见 `docs/team/threads/verify.md` 最后一条 V186。读 `docs/team/RELEASE-PUBLIC.md`、V161 的元套件做法、`skills/teamsmith/tests/meta-suite.sh`。在固定已有代码上以本席位 `team_bg_run` 执行一次 `TMPDIR=/var/tmp OPENSPEC_TELEMETRY=0 bash skills/teamsmith/tests/meta-suite.sh --snapshot=<固定完整SHA> </dev/null`，启动后结束回合并等通知，不轮询；原生执行可追加本项目共享常规历史，不手改 history、不伪造记录。记真实日期、冻结 SHA、逐段、总时长、退出码、实际保留位置。失败先归因、不盲重跑。除此不执行全量产品测试、模型、安装、发布、扫描用户环境或测提示词。

另只读列出新版本产品及测试差异与已有独立验证来源，特别是 V174 全量两项失败及之后的定点处理。说明剩下哪些发布检查必须用最终候选做，哪些已有证据能复用，有实质缺口明确写，不沿用上一版的单次授权充当本版“已经全量通过”。不建议重复已做项目，无新测试框架。计划最终候选仅新增已讨论的 PM 指导文字、发布版本和说明、以及账本；等待最终候选后由 PM 与你逐项比对本轮自检实际涉及的文件，只有证据可覆盖才复用，不称本轮在最终 SHA 上跑过。报告 `docs/team/reports/V186-verify.md`，本地提交，不推送、不装到实际项目、不发版。