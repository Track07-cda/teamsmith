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

修复后定点：P489 作者 dev-bob，冻结 `7ee3db91b6b6852d06a1661b650aa08d2923df04`（`53471f5b` 只加作者报告），干净检出见 V186 线程。原 RED 已收取且必须保留，单独用本席位后台在冻结修复源执行 `TMPDIR=/var/tmp OPENSPEC_TELEMETRY=0 TEAM_META=1 bash skills/teamsmith/tests/smoke.sh --select 0e --snapshot=7ee3db91b6b6852d06a1661b650aa08d2923df04 </dev/null`（如该组合 CLI 入口拒绝，先核 CLI 的真实旗标再执行，不运行其它段）。核干净 88/88、故意加错会报错、还原能通过，得到实际 rc 并明确不是元套件 GREEN。只读核两条记录的截止与固定输入依据，把 P489 候选证据补入原报告。通过交 PM，暂不重跑完整元套件，等 PM 把 P489 合入并冻结真正发布内容后再在那一份上运行一次。不要改清单、减项、做产品全量或覆盖前轮原件。

最终发布候选：PM 已接受 `1e148f87` 的 P489 定点，已合入两行。最终冻结源和完整 SHA 见本席位最后 V186 线程。用原生 `meta-suite.sh --snapshot=<该SHA>` 在该检出一次全跑，以项目原生历史写真实 GREEN 或 RED；不复跑上一轮基线，也不另跑 §0e。保留退出、6 段及前导的计数和新旧原件，合并版 §0e 也是 P489 的最终证据。非执行间隙只读核 V174→最终的原提醒事件与 G2 调用链，尤其 P486 改动是否影响事件观察；写实际路径与缺口，不先执行产品全量或事件样本。当前 0.4.8 的组合验收选择未确认，不擅自标绿。