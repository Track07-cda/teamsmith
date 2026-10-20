# P331 · 控制台粘贴图片「没有文件落地」：先复现，再判产品 / 夹具

task: P331
agent: dev2
phase: apply
category: code
change: -
specs: panel#`C-v` pastes a clipboard image as a temporary file path
deltas: -
branch: task/P331-panel-paste-file

## 这件事从哪来

`tests/panel-b2.sh` 的 `clipboard` 场景在 `dc7da324`（P318 动手之前）就是红的，P318 原样留了那三条断言没有改：

```
✗ B4 TMPDIR 里恰好一个 teamsmith-paste-*.png（期望 [1]，实际 [0]）
✗ B4 文件内容就是剪贴板的 8 字节（期望 [PNGDATA8]，实际 []）
✗ B4 X11 回退：文件内容 XCLIPDATA（期望 [XCLIPDATA]，实际 []）
```

三次 `wl-paste` 探测成功、路径「插进草稿」也成功，但**没有任何文件落地**，所以「路径插在插入点」那条是空洞绿（插进去的是空路径）。纯模型夹具 9/9 全绿，说明 `pasteFilePath` 的纯逻辑没问题。

这条之所以这么久没人看见：`panel-b2.sh` **不在任何门禁段里**（P318 已实测），所以它红着也没人知道。

> **这条有规格**：`openspec/specs/panel/spec.md` 的 `C-v pastes a clipboard image as a temporary file path`
> 明写「图像字节写进 `${TMPDIR:-/tmp}/teamsmith-paste-<uuid>.<ext>`，路径插在插入点」，两个 scenario 断言的就是
> 那三条红里的内容（TMPDIR 里恰好一个文件、内容是 8 字节、X11 回退同形）。所以这不是「没承诺的角落」，
> 而是**一条被承诺的行为，它的载体从不运行**。

P318 给了一个**假说、不是结论**：控制台从 `cache.snapshot().data?.capacity?.temp_root` 取临时根（`scripts/panel/src/main.tsx:817`），而 `capacity` 块在 `team_panel_capacity_json`（`scripts/lib/cmd-watch.sh:834-871`）里降级时会打印 JSON 但返回非 0，条件是需要 `capacity.log` 里有 `RAM 可用 NMB` 行；夹具是全新 `team init` 项目，没有那份日志。

## 你要回答的第一个问题（先别改代码）

**在真实环境里，粘贴图片到底会不会落地？** 用你自己的、真实启动的控制台（私 tmux server、私 state 目录、你的临时根），造一个**新建的**项目（`team init`），在真实终端里粘一张真图片，看：
1. 草稿里插入的是什么（路径是否为空）；
2. 那个路径对应的文件是否真的在盘上、内容是否就是剪贴板字节；
3. `team panel` 的 capacity 块在**没有** `capacity.log` 的项目里返回什么（退出码与 JSON 都要）。

这三条就是判据，不要用「应该」「大概」。

## 然后二选一

- **产品缺陷**：真环境里也不落地 → 修产品（最小改法），并给一条会红的产品面断言（不是夹具自证）。修法要能回答「新建项目为什么可以没有 capacity.log」。
- **夹具缺陷**：真环境里能落地（说明是夹具把项目造成了一个产品不需要满足的形状）→ 修夹具，把「新建项目没有 capacity.log」这件事在夹具里显式造出来并注明理由，**不许**为了让断言变绿而放宽它。

报告里必须写明你选了哪个、依据是哪一条实测。

## 边界

- 不许为了让场景变绿而删除或放宽那三条断言；它们是 P20 事故（剪贴板探测顺序）的墓碑。
- 不接门禁（`smoke.sh` / `section-paths.tsv` 归 P326），不改 `panel-b2` 的其它场景。
- 真终端与真剪贴板优先；如果这台机器上 `wl-paste`/`xclip` 都不可用，如实写「无法复现」，并给你用替身时**替身与真实差在哪**。
- 你签字的那条改动要有红侧：把修复退回去 → 同一条断言必须红。

## 验收

```bash
bash skills/teamsmith/tests/section-select.sh --paths <你改的路径…>   # 取段号
bash skills/teamsmith/tests/smoke.sh --select <段号>
bash skills/teamsmith/tests/panel-b2.sh clipboard          # 该场景必须 ✗0，除非你判定是产品缺陷且已修
openspec validate --all --strict
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```
