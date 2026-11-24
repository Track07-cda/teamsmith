---
id: P491
title: 恢复复验记录检查的路径边界
agent: dev2
category: code
phase: opsx-apply
change: -
specs: verification#Delegated reviews record their actual executor and narrow ledger authority
deltas: -
branch: task/P491-ci-review-home-path-assertion
---

# P491 · 恢复复验记录检查的路径边界

读独立诊断 `docs/team/reports/V191-verify.md`，GitHub run 45318204605 的日志与已保存制品位置见本席位线程。已发布的 0.4.8 标签与 npm 包保持不变。

V191 确定 §10 两处误报：CI HOME=/tmp、复验在 /var/tmp；旧断言找普通子串，把合法 /var/tmp 当作家目录。只改 `skills/teamsmith/tests/smoke.sh` §10 对应检查，按实际路径边界准确区分，不改产品净化、不通过换 HOME 或豁免整条路径规避。保留真正 HOME 替换、兄弟路径保留、故意关掉净化能报错和恢复判据。作者只做静态范围/语法核对，实际原场景由非作者一次验证；不跑整套。

交 `docs/team/reports/P491-dev2.md`（真实命令、结果、覆盖和未运行范围），仅本地提交，不推送、不发布、不中断其他任务。