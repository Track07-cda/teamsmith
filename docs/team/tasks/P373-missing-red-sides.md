# P373 · 补上六条「从没被改坏过」的红侧（契约必须能红）

task: P373
agent: dev
phase: apply
category: code
change: turn-notice-in-pm-inbox
specs: notify-and-inbox#A turn-end notification appends one inbox line and knocks once
anchor: none (infra) — 红侧
deltas: -
branch: task/P373-missing-red-sides

## 依据（P371 的发现，`docs/team/reports/P371-dev3.md` §3）

`turn-notice-in-pm-inbox/tasks.md` 的红侧总表 R1–R12 里，真正在案的「破坏实现 → 断言红 → 还原」只有 6 行；
**R1、R3、R5、R7、R12 五行的断言在跑，但从没有人把它改坏过一次**；R8 只做了「不写账本」那一半。
`notice-fulltext-and-asks` 那边还欠 `4.6`（文案不撒谎那条的 R8）与 `4.5`（死默认）。

**一条断言从没被改坏过，等于没人知道它会红。**

## 要做的（六件，各自独立，别合成一次）

| # | 清单项 | 改坏什么 → 哪条必须红 |
|---|---|---|
| 1 | `turn-notice` 1.1.2 | 让同 run 的三个事件各起一行（不合并）→ `--select 13` 的 F17 断言（`×3` + `notify.log` 三条）必须红 |
| 2 | `turn-notice` 1.4.3 | ① 把 `__notify-settle` 从内部命令白名单删掉 → help-surface 的覆盖断言红；② 把 `pm.md` 设成只读 → 必须打印 `pointer=failed` 且仍落账 |
| 3 | `turn-notice` 1.5.3 R1/R8 | 删掉那一次 `__notify-settle` 调用 → `pm.md` 无指针行 → 夹具红；把某个分支的指针写入拿掉 → 对应那条红 |
| 4 | `turn-notice` 1.7.2 R12 | 回到「按文件席位取记录」→ `team inbox pm --detail` 对一条 `×N` 指针行报缺口 → 那条红 |
| 5 | `notice-fulltext` 4.5 | 删掉 `common.sh:1125` 那个没有 shell 读者的死默认（`${TEAM_INBOX_MAX_CHARS:-150}`）—— **删它，不是留它**；删后所有读它的地方仍走扩展/config |
| 6 | `notice-fulltext` 4.6 R8 | 把文案改回「降低它就能降噪」→ §14b/§18 的「文案不撒谎」断言必须红 |

每件都要：**改坏 → 贴红行原文 → 还原 → 贴绿**。红侧在 `/var/tmp` 的私有副本里做，**不改 main 的产品代码**
（第 5 件例外：删死默认是真实改动，走正常提交）。

## 交付

报告 `docs/team/reports/P373-dev.md`：六件的「改坏点在哪个文件哪一行 / 红的是哪条断言原文 / 还原后绿」。
**不要自己勾清单**——把哪几项现在可以勾写进报告，由 PM 勾。

## 边界

写集：`skills/teamsmith/scripts/lib/common.sh`（只第 5 件那一行）、必要时 `tests/smoke.sh`（若某条红侧需要有界等待）、报告。
不改产品其它面、不加段、不改判据语义。
