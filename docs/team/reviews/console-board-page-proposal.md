# 提案评审 · console-board-page

```
change:  console-board-page
propose: P17（dev，分支 task/P17-propose-pulse-console-board-）
reviewer: PM
date:    2026-09-18
verdict: **ACCEPTED**
```

## 评审依据

- 需求覆盖：kanban 第四页（六车道/空列/id 键控焦点/点击进入）、只读 markdown 详情（三族文件发现、
  128KiB 上限、路径拒绝集）、有界帧红线（页脚钉最后一行、内容区吃满——含旧三页同修、--height 40 翻转）
  全部成文；用户两条原话 + 截图根因（内容高度 ≠ pane 高度）都在提案里。
- 规格：ADDED×4 / MODIFIED×1（base 5 场景保留 +2 新）/ REMOVED×1（改名 remove+add 配对）；
  开发者已做 D23 手检（MODIFIED/REMOVED 标题与 base 逐一对上）。
- 零新依赖（自写 markdown 子集渲染，守住 bundle 的 no-install 契约）；只读；BOARD.md 格式不变。
- validate 14/14 绿（我在分支上重跑确认）。

## nit（apply 时顺手修，不阻塞）

- proposal.md「Spec home」行写 ADDED×3/MODIFIED×2，与 delta 实际 ADDED×4/MODIFIED×1/REMOVED×1 不符——
  以 delta 为准，apply 交付前把 proposal 这行改对。

## 生效

ACCEPTED 起 apply 相可派（P18，归 dev3——与 propose 的 dev 分离）。
