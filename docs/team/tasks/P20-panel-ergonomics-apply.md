# P20 · apply: `panel-ergonomics`（写信光标/pi 键位/多行/图片粘贴/工作页详情/改名）

```
task:   P20
agent:  dev2
issue:  
change: panel-ergonomics
specs:  panel, memory-and-deps
phase:  apply
deps:   -            # 提案已由 PM 验收：docs/team/reviews/panel-ergonomics-proposal.md（在 main 上）
status: todo
budget: 分批推进（B1…B6），每批一个提交；超出就交 PARTIAL 报告
```

> 本地模式：不 push，任务分支留在 `.worktrees/dev2`。

## 前置（先读，别跳）

1. `openspec/changes/panel-ergonomics/`（proposal / design / tasks / specs）——**tasks.md 的 B1…B6 就是实施计划**，
   每批的「项 · 夹具 · 翻转」都在里面；design 的 11 条决策是你的实现口径（尤其 2/3/4/6/7/8/10）。
2. `docs/team/reviews/panel-ergonomics-proposal.md` —— PM 的验收记录，末尾「验收焦点」是复验时会重点打的六处。
3. 本 change 的 PM 裁决：**`C-e` = 行尾（pi 语义）**，外部编辑器改绑 **`C-o`**（含迁移 scenario：`C-e` 不得再启动编辑器）。

## Deliverables

按 tasks.md 分批实现并提交（每批：实现 + 该批 pty/单元夹具 + 重建 `panel.js` bundle + 该批自检）：

| 批次 | 内容 |
|---|---|
| B1 | 插入点光标模型（codepoint、宽字形、窗口化草稿、Ink `useCursor` 真实光标、`cursor_x/y` 契约） |
| B2 | pi 键位（`ctrl+a/e/b/f`、`alt+b/f` 等，**两种终端编码**）+ kill ring + undo |
| B3 | 多行编辑（`ctrl+j` 插换行、`enter` 仍提交、`shift+enter` 退化、standby 原因单行化）+ `C-e`→`C-o` 迁移 |
| B4 | 剪贴板图片粘贴（`C-v`、`wl-paste`→`xclip`、临时文件、有界、非渲染路径、文本回退） |
| B5 | 工作页 board 行可聚焦 + 进入详情 + **原地返回** + 降级无死项 + `pageUp/Down` 接管滚动 |
| B6 | 改名（zh 表 `往来`；`grep -c '线程' zh.ts` = 0；目录/命令/英文 term 不动）+ 最终 bundle |

## Boundaries

- **只做** `panel` 与 `memory-and-deps` 两个 capability 的 delta 所要求的行为；不改 CLI 语义、不改草稿/投递契约。
- **别碰 M40 的地盘**：身份解析/spawn/`extension/team-notify.ts`/`cmd-*.sh` 的 TEAM_* 逻辑（dev3 在做）；
  `smoke.sh` 里 M40 的 §32 段落也不要改——你的新段落追加在自己位置即可。
- 面板性能契约不变（<1% 单核、首帧 <2s）；剪贴板探测只在按键时跑，绝不进渲染/刷新路径。
- 测试纪律照旧（私有 tmux socket + 破坏性夹具进容器）；跑门禁前后 `tmux ls | head -3` 探活。

## Acceptance (must actually be run; put the output in the report)

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh </dev/null
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh      # 开发期快速回路
```
外加**六条验收焦点的手工实录**（贴输出/截图文本）：
1. `ctrl+j` 插换行而 `enter` 提交；粘贴里的换行仍是"一个草稿一条消息"；
2. `C-e` 到行尾（**不再启动编辑器**）、`C-o` 启动编辑器；
3. `C-v` 在 fake `wl-paste` 下写出 `teamsmith-paste-*.png` 并把路径插到光标处；无图/无工具静默回退；
4. 宽字形（CJK/emoji）单步移动、不被半删；`#{cursor_x}/#{cursor_y}` 与插入点一致（含换行/软换行）；
5. 工作页 `↓`→聚焦、`enter`→详情、`esc/q`→**回工作页**（看板页同理回看板页）；
6. 消息页 zh 渲染 `收件箱与往来` / `往来 N 条`，且 `grep -c '线程' zh.ts` = 0。

## Report

`docs/team/reports/P20-dev2.md`：按 requirement 的覆盖表 + 每批的翻转证据（red→green）+ 独立包路径。
