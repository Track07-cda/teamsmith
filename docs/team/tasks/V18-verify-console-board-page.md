# V18 · verify: console-board-page（P18 三批 apply 的独立验证）

```
task:   V18
agent:  verify
issue:  
change: console-board-page
specs:  panel 全部 ADDED/MODIFIED/REMOVED 条目（openspec/changes/console-board-page/specs/panel/spec.md）
phase:  verify       # 你与 propose(dev)/apply(dev3)都无关
deps:   P18          # 三批全部合并进 main，门禁绿
status: todo
budget: 一个工作块；超出就交 PARTIAL 报告
```

> 本地模式：不 push，任务分支留在 `.worktrees/verify`（从 main 切）。验证对象是 **main 已合并后的树**。

## Context

console-board-page 已三批落地主线：B1 有界帧（页脚钉底+吃满，旧三页同修）、B2 kanban 看板页、B3 只读
markdown 详情。PM 对每批做过复验（reviews/P18.md ×3 PASS，含一条抖动复跑记录）。按管线还差你的
**独立验证**，PASS 且用户确认后 PM 归档。

材料：change 目录 `openspec/changes/console-board-page/`；交付报告 `docs/team/reports/P18-dev3.md`；
面板规格 `openspec/specs/panel/spec.md` 的 delta 在 change 里。

## 要验证的（scenario 级对账 + 主动攻击）

1. 四条 ADDED + 一条 MODIFIED requirement 的**每个 scenario** 实跑取证（pty 夹具/快照/`--print --width/--height`
   都在，照 V17 的纪律：命令→输出，不靠读代码推断）。
2. **有界帧红线**：`--height 40` 与 60x8 两端的帧高恰好等于 pane、页脚是最后一行——并做**真树翻转**
   （改 layout.ts 让它回去按内容高度渲染 → 对应断言红 → 还原并验证逐字节干净）。
3. kanban：六车道顺序、空列渲染、焦点跨刷新按 id 跟踪、99 列/59 列降级形态。
4. 详情：三族文件发现、越界 id/路径拒绝、128KiB 截断标记、Esc/q 返回不收起。
5. **性能红线**：`bash skills/teamsmith/tests/panel-cpu.sh` 实测 <1% 单核（apply 侧标过 unverified，你要给出
   真实读数）；详情打开的首帧 ≤1s。
6. CPU/内存长跑毛边：连拍/翻页/开详情 50 次的内存曲线无单调爬升（V16 的 F-V16-3 口径）。

## Boundaries

- 只产 `docs/team/reports/V18-verify.md` + `V18-verify/` 证物；不改 `skills/**`、`openspec/**`、账本。
- 发现分级：bad（违反规格）/ finding（留痕）；不许顺手修。

## Acceptance

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict && TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
# + 上述每条验证的命令与输出进报告；翻转实录进证物
```

## Report

`docs/team/reports/V18-verify.md`，明确判定 PASS / FAIL + findings 清单。
