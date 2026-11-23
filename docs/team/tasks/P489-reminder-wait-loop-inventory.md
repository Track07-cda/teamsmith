---
id: P489
title: 补齐提醒测试既有等待的两处清单记录
agent: dev-bob
category: code
phase: opsx-apply
change: -
specs: verification#Every wait in the gate is bounded and attributes at its cap
deltas: -
branch: task/P489-reminder-wait-loop-inventory
---

# P489 · 只修现有清单与源码不一致

V186 真实发布自检 RED 214/3，报告 `0d3deddb` 与原生 RED 留存；三个失败同因。P486 已接受的提醒测试退出等待在 `skills/teamsmith/tests/remind-tool-real.sh`，现有扫描器识别第 37/39 行的内外两层，清单 `skills/teamsmith/tests/loop-inventory.tsv` 少两项，导致干净及故意改坏后还原都被判错。只在该 TSV 登记这两个实际循环，保留它们真正的上限/退出依据及精确源码行；既有扫描结果是证据，不直接改预期数量。不改循环、提醒功能、清理、扫描器、套件、阈值、OpenSpec、历史记录或应用版发布包。若某层不适用现有 `cap=` 字面量，使用已支持的 `bound=` 并说明其结构上界，不自行加机制。

作者只看静态扫描的 88 条与两行说明、写集和 `git diff --check`，不执行 §0e（由 V186 非作者统一定点验证）、其它测试、提醒、模型或全量。`docs/team/reports/P489-dev-bob.md` 写精确 SHA、真实命令与结果、未验证范围，做本地提交；不推送、不发布。