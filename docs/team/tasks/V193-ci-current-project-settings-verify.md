---
id: V193
title: 独立验证新版设置页的双语、保存与读屏检查
agent: dev2
category: verify
phase: verify
change: -
specs: panel#Selected settings editors preserve owning-command choices and writes
deltas: -
branch: task/V193-ci-current-project-settings-verify
---

# V193 · 只验 §28 / §38 已受影响的行为

作者 dev；候选 `f3a99344`，冻结检出见线程（`45f32d5c` 只交报告）。独立核真实差异、P492 报告及 V191 原件。复用 P491 的固定镜像/CI 布局，在本席位私有输出目录保存实际脚本、日志、tmux 画面与实码，不用当前项目 Pulse、配置或用户模型。按现有入口一次 `smoke.sh --keep --select 28,38 </dev/null`，如入口需要其它格式以现有 help 为准；自动前导实录，不能用 FAST 跳过 pty。若某项失败保留原件、精确归因，先不自行修复或重复整组，只建议接下来需要补哪条。已有 CLI schema 覆盖只读核仍在，不为证明未改另跑；不跑其它段或整套/远端 CI。

核对：正常双语与删除两种真实可见标签分别点名两语言、滚轮故意改坏能检出；当前 UI 可操作而非只匹配词：危险项确认前零写、最终授权同指纹一笔写一条审计；模型运行规则保存一次、取消和指纹冲突不覆盖；两处零读取的真实 argv；10/1/3 与 45/33/30/25 四档可见/隐藏、焦点、边框填高，窄屏返回、滚轮隔离，以及独立 CLI 键/组不改变用途分组或增加操作行。读屏未识别要明确失败，不当错误行数。报告写清各项是实跑、原样继承还是未取得；P491 的 §10 已验，不再跑。合并后同一人只核相关文件变化，如重叠同文件 §10 已合入、局部互不干涉，核对应块无需重跑。

交 `docs/team/reports/V193-dev2.md` 和原始位置，后台启动后当轮结束；不改候选、标签、npm 包或远端，只提交报告。