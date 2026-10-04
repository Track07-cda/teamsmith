# P19 · propose: 写信体验（光标编辑 + 剪贴板图片粘贴）与「线程」中文改名

```
task:   P19
agent:  dev-bob
issue:  
change: panel-ergonomics
specs:  panel
phase:  propose
deps:   -            # M41 已交付（面板文件不重叠，但要基于最新 main 起分支）
status: todo
budget: 一个工作块；只做 explore/propose，不写实现
```

> 本地模式：不 push，任务分支留在 `.worktrees/dev-bob`。

## Context（用户原话，两条）

1. 「线程的命名是不是有点容易混淆，让人觉得是某个进程的线程」
   —— 面板「消息与日志」页里的 `收件箱与线程` 块：`线程` 在中文语境里默认读成**进程线程**，与
   `docs/team/threads/<agent>.md`（PM ↔ agent 的往来记录）不是一个意思。
2. 「pulse 的写信需要优化，需要支持光标，最好能够像 pi 一样允许剪贴板里有图片时粘贴进图片的临时文件地址」
   —— 现在的写信框是 **append-only**：`compose.ts` 只有 `appendText()` 与 `backspace()`（永远从末尾），
   光标恒定在末行行尾（`cursorColumn()` 取最后一行宽度）。用户要的是**可在任意位置编辑**，以及
   **剪贴板有图片时粘贴出临时文件路径**（与 pi 的行为一致，pi 的实现可参考：
   `~/.bun/install/global/node_modules/@earendil-works/pi-coding-agent/dist/utils/clipboard-image.js`
   —— Wayland `wl-paste --list-types` → 选首选 MIME → 取字节；X11 `xclip -selection clipboard -t TARGETS -o`；
   WSL PowerShell 兜底）。

## Deliverables（propose 阶段：只产出 openspec/changes/panel-compose-ergonomics/）

1. `proposal.md`：为什么、改什么、影响面（面板写信框 + 面板字符串 + 文档措辞）。
2. `design.md`：
   - **光标模型**：codepoint 索引（CJK/emoji 安全）、插入/删除发生在光标处、左右/Home/End 导航、
     软换行与显式换行下的**光标列渲染**（必须与 `tmux display -p '#{cursor_x}'` 的既有契约一致——
     panel-b3 现在就在测这个）、提交/粘贴/拒收路径不变;
   - **图片粘贴**：触发键（建议 `Ctrl-V`，与 pi 一致；同时保留普通文本粘贴路径）、探测顺序
     （Wayland → X11）、临时文件命名与位置（建议 `$TMPDIR/teamsmith-paste-<uuid>.<ext>`）、
     在光标处插入路径文本、无图片/无工具时**静默回退为文本粘贴**且不破坏草稿、
     **可测试性钩子**（例如 PATH 里的 fake `wl-paste`/`xclip`，或 env 指定探测命令——写死方案，别留开放项）;
   - **改名**：中文 UI `线程` → **`往来记录`**（块标题 `收件箱与往来`、行 `收件箱 N 条 · 往来 M 条 · {age}`、
     空态 `（没有收件箱/往来记录）`）；`scripts/lib/cmd-docs.sh` / `cmd-project.sh` 的提示文案、
     `templates/threads-README.md` 同步；**目录名 `threads/`、命令 `team thread` 与英文 term 不变**。
3. `specs/panel/spec.md`（delta）：给写信/编辑器与消息页加**可证伪的 scenario**（WHEN/THEN），
   至少覆盖：光标插入/删除/CJK 安全、换行处的光标列、图片粘贴成功路径、无图片回退、无剪贴板工具回退、
   改名后的字符串。
4. `tasks.md`：apply 阶段的任务拆分（含测试与翻转）。

## Boundaries

- **只写提案，不写实现**（explore/propose 阶段），不要动 `skills/**` 的实现文件。
- 不改变写信框的**既有语义**：草稿守卫、`draft-send.sh`、提交/拒收、standby 原因提示都保持；
  只加编辑能力与粘贴能力。
- 面板性能契约不变（<1% 单核、首帧 <2s）；不要把剪贴板探测放到渲染热路径上（只在按键时触发）。
- 规格写作遵守 `skills/teamsmith/references/openspec.md`（requirement/scenario/占位文本的约定）。

## Acceptance (must actually be run)

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
PATH="$HOME/.bun/bin:$PATH" openspec show panel-compose-ergonomics --json | head -40
```
报告里贴输出，并说明「为什么这些 scenario 能在 apply 阶段被证伪」。

## Report

`docs/team/reports/P19-dev-bob.md`。

---

## 追加要求（用户 15:5x）：键位**继承 pi 的 keymap**，并支持多行编辑

pi（`@earendil-works/pi-tui` 的 `tui.editor.*`）实际默认键位，写信框应对齐：

| 动作 | 键 |
|---|---|
| 左右移动 | `←` `→`，`ctrl+b` `ctrl+f` |
| 上下移动（多行） | `↑` `↓`（`pageUp/pageDown` 可选） |
| 按词移动 | `alt+←` / `ctrl+←` / `alt+b`；`alt+→` / `ctrl+→` / `alt+f` |
| **行首** | `Home`、`ctrl+a` |
| **行尾** | `End`、`ctrl+e` |
| 退格 | `backspace` |
| 前向删除 | `delete`、`ctrl+d` |
| 删词 | `ctrl+w`、`alt+backspace`（前向可选） |
| 删到行首 | `ctrl+u` |
| 删到行尾 | `ctrl+k` |
| **插入换行（多行编辑）** | `ctrl+j`（必做）；`shift+enter` 在终端支持时同义 |
| 提交 | `enter`（**保持现状不变**） |
| 可选 | `ctrl+y`/`alt+y`（yank）、`ctrl+-`（undo）——做不了就在 design 里说明取舍 |

**必须写进 design 的终端现实**（否则 scenario 无法证伪）：

- `ctrl+j` 在终端里就是 LF（`\n`），与「粘贴里的换行」同字符——现在 `compose.ts` 把单个 `\n` 当 Enter 提交；
  新设计必须区分「按键产生的 LF」与「粘贴文本里的 LF」（bracketed paste 已有 `pasteBody` 解析可复用），
  并用 **pty 测试**证明 `ctrl+j` 真的插入了换行而 `enter` 仍然提交；
- `shift+enter` 依赖扩展键盘协议（面板已经在探 `client_termfeatures`/`extended-keys`）——
  写清「拿不到时退化为 `ctrl+j`」，不要留下"看起来能用"的空档；
- 多行草稿落到 `draft-send.sh` / 草稿守卫 / standby 原因提示时的**归一化**（换行怎么进文件、怎么进 tmux 投递）
  必须明确，不能破坏既有契约。

---

## 追加要求 ②（用户 16:1x）：工作页看板卡也要能进条目详情；并收敛 change 范围

用户原话：「从工作页面的 board 也可以进入具体条目的详细内容」。

- 工作页（page 1）的 board 卡片行要与看板页一致的**可聚焦**语义：↑/↓（或既有 focus 键）选中行，
  Enter/点击打开**同一个**只读 markdown 详情页（任务书/报告/复验记录，复用 P18 的能力）；
- 返回必须回到**来处**（从工作页进 → Esc/q 回工作页；从看板页进 → 回看板页），
  不能把用户丢到另一个页面；
- 复用既有边界：路径边界校验、128KiB 上限、文件缺失/不可渲染的降级、帧有界（页脚钉底）；
- 空 board / 降级布局下不得出现"可聚焦但打不开"的死项。

**change 范围收敛**：本 change 现在覆盖四块（写信光标编辑、pi 键位与多行、剪贴板图片粘贴、面板中文改名、
工作页详情入口）——请把 change id 改为 **`panel-ergonomics`**（目录改名 + proposal/design/tasks 内引用同步），
标题与影响面按四块重写；delta 里的 requirement 保持「一条 requirement 一个行为主题」的粒度。

**键位冲突的裁决（PM 拍板，写进 design）**：写信框现有 `C-e` = 交给 `$EDITOR` 续写；
用户要求继承 pi keymap 的 `ctrl+e` = **行尾**。裁决：**`C-e` 取 pi 语义（行尾）**，
外部编辑器改绑 **`C-o`**（Open editor），并在 design 里写明这是对既有键位的迁移、提示文案（zh/en）同步更新。
