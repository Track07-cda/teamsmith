# tests/frames · 输入框判据的真实帧样本

这里的文件是 **`tmux capture-pane -p` 的原样输出**（守卫看到的就是它），给纯函数夹具
（`_team_box_rows_of_frame` / `_team_box_geometry`）当输入 —— 这样「真实现场 → 判据」这条链
不必开 tmux 就能在门禁里复跑，端到端（真 pane）与纯帧也共用同一份实现。

两类文件分得很清：前七份是**真 pi 实拍**（来源逐字写在下表）；`p78-*.txt` 八份是 **P80 的合成帧**、
`p86-f1-*.txt` 三份是 **P86 的合成帧** —— 「裁切型 TUI」的模型，**不是** pi 输出、没有真 pi 出处（P80 的
八份构造与 `docs/team/reports/P78-verify/pkg/lib.sh` 的 `p78_build_frames` 逐字节相同，`cmp` 可验；P86 的
三份与 P84 复验时自造的 `f1.txt`/`f1b.txt`/`f1c.txt` 逐字节相同）。

帧文件不能带注释（多一行就多一行 pane），来源与光标行写在下面这张表里。

| 文件 | 来源 | 光标行（1-based） | 现场 |
|---|---|---|---|
| `pi-0.87.0-project-trust-prompt.txt` | 真 pi **0.87.0**（`--no-session --session-dir <tmp>`，私有 tmux socket，pane 120×30），在一个 git 仓库里实拍 —— 仓库里有 `.pi/skills/teamsmith`（team init 装的项目资源）且**没有**已保存的信任决定 | `16`（弹窗自己的下边界那条整行 ─） | **Pi 的项目信任弹窗**（覆盖层，不是输入框）：第 1 行整行 ─、第 3 行问题、第 4 行 cwd、第 8–12 行选项、第 14 行导航提示、第 16 行弹窗下边界 —— 弹窗里一个字的输入都没有 |
| `pi-0.87.0-one-line-draft.txt` | 真 pi **0.87.0**（`--no-session --session-dir <tmp>`，私有 tmux socket，pane 120×30）在 P61 现场实拍；来源 `docs/team/reports/P61-dev3/logs/15b-one-line-draft-frame.log`（逐字节 `cmp` 相同） | `26`（框内唯一内容行，光标停在草稿上） | 输入框 = 第 25 行整行 ─ / 第 26 行 `HUMAN-ONE-LINE-DRAFT` / 第 27 行整行 ─；0.87.0 **把框自带状态行画在下边框下面**（第 28 行 cwd、第 29 行 `0.0%/1.0M … (deepseek) deepseek-flash • max`、第 30 行 `mc: …`），所以边框邻行就是草稿本身（P67 的核心现场） |
| `pi-0.87.0-draft-half-sentence.txt` | 真 pi **0.87.0**，同一批 P61 场景的另一份单行草稿实拍；来源 `docs/team/reports/P61-dev3/logs/10c-real-draft-box.log`（逐字节 `cmp` 相同） | `26` | 与上一份同形状，草稿文字 `DRAFT-p61-half-sentence`；同一次场景的空框对照是 `pi-0.87.0-empty-box.txt` |
| `pi-0.87.0-empty-box.txt` | 真 pi **0.87.0**，同一批 P61 场景的**空闲空框**对照；来源 `docs/team/reports/P61-dev3/logs/10c-real-empty-box.log`（逐字节 `cmp` 相同） | `26`（框内唯一内容行是空的） | 第 25/27 行整行 ─ 之间只有一行空白 —— 判据必须是 `EMPTY`（与 0.85.1 的状态行排除互为对照） |
| `pi-0.85.1-update-banner.txt` | 真 pi 0.85.1（`--no-session --session-dir <tmp>`，私有 tmux socket，pane 120×30）空闲 25s 后实拍；**1–9 行是 pi 的启动输出（`[Skills]`/`[Extensions]` 等与本判据无关）已置空，行号与实拍一致** | `26`（框内第一个内容行） | 两个更新横幅（`Package Updates Available` + `Update Available`）画在输入框上方；pane 第 11/16/18/22 行是横幅的 DynamicBorder，24/29 行是输入框的上下边框 —— 全部同形等宽（360 字节 = 120 个 `─`） |
| `p78-draft-rule-below-cursor.txt` | **合成帧**（P80：裁切型 TUI 模型，非 pi 实拍） | `2`（框内空行，光标停在它上面） | 草稿在光标下方画了自己的等宽 rule：rule / 空行(光标) / rule / ` draft text below my own rule` / rule / footer。P80 前几何 `[1 3]`、框读空 → 就绪门放行（P74 的 F1）；P80 后 `[1 5]`，框线行与草稿文字都留在框内 → `idle-read=NOT-EMPTY` |
| `p78-draft-rule-only.txt` | **合成帧**（P80，非 pi 实拍） | `2` | 光标下方的草稿**只有一条 rule**（rule / 空行(光标) / rule / rule / footer）。这一份与「空框正下方紧贴一条对话区 rule」是**同一串字节**（sha256 `e463c80c…f5053a6`，见文末）—— P80 取保守读法 `[1 4]` → `NOT-EMPTY` |
| `p78-wider-rule-below-cursor.txt` | **合成帧**（P80，非 pi 实拍） | `2` | 草稿的 rule 比框宽（140 > 120 字节列；裁切型 TUI 里长分隔线被裁到 pane 宽）：宽行**不能**与上边框配对 → 留在框内 `[1 5]`，判定与 P80 前一致（`NOT-EMPTY`） |
| `p78-spinner-row-below-cursor.txt` | **合成帧**（P80，非 pi 实拍） | `2` | 光标下方是 spinner 形状行（`── ⠋ Blanching… 0s ─…`）—— 下边框候选**只认整行 ─**，spinner 行是内容：`[1 5]`，判定不变 |
| `p78-cursor-mid-draft.txt` | **合成帧**（P80，非 pi 实拍） | `3`（三行草稿的第二行） | 光标在三行草稿中间、下边框在三行之下：三行草稿全部留在框内 `[1 5]`，判定不变 |
| `p78-draft-rule-below-cursor-line.txt` | **合成帧**（P80，非 pi 实拍） | `2`（` half a sentence`） | 光标下方有草稿自己的 rule、rule 下面还有 ` more draft`：P80 后框里读出 rule 行 + ` more draft`，所以 payload `half a sentence` 是 `extra-text`（P80 前截断的框正好等于它 → `only-ours`） |
| `p78-conversation-rule-below-box.txt` | **合成帧**（P80，非 pi 实拍） | `2`（空框内） | 空框的下边框**紧贴**着又一条整行 rule（模拟对话区的 rule）：P80 把框扩到最低候选 → 框变大、判 `NOT-EMPTY`（**这是记录在案的代价**，`references/troubleshooting.md` §3） |
| `p78-draft-rule-blank-region.txt` | **合成帧**（P80，非 pi 实拍） | `2` | 草稿 rule 与真下边框之间只有空行 —— 用来证伪「中间有非空行才扩框」的备选规则（那个规则在这里仍读 `EMPTY`）；P80 的规则不受区域内容影响：`[1 5]`、`NOT-EMPTY` |
| `p86-f1-mixed-width-disjoint-box.txt` | **合成帧**（P86；与 P84 复验自造的 `f1.txt` 逐字节相同） | `2`（` HUMAN DRAFT LINE`） | P84 的 F1 安全回归：光标框 `[1 3]`（100 列）下方另有一对**不同宽度**（120 列）自成配对的规则行（5/7 行）—— 只取「最低候选」时新框 `[5 7]` **整个落在光标下方**、读空 → 就绪门放行。P86 准入条件把 5/7 这一对判为不合格（配到的上边框 5 不在光标之上），回落到最近的合格候选 `[1 3]` → `NOT-EMPTY` |
| `p86-f1-spinner-top-disjoint-box.txt` | **合成帧**（P86；与 P84 的 `f1b.txt` 逐字节相同） | `2` | 同上的变体：下方那一对的**上边框是 spinner 形状行**（tier2 配对），下边框 7 行宽 120 列。P86 同样拒绝（配到的上边框 5 行不在光标之上）→ `[1 3]`、`NOT-EMPTY` |
| `p86-f1-narrower-width-disjoint-box.txt` | **合成帧**（P86；与 P84 的 `f1c.txt` 逐字节相同） | `2` | 同上的变体：光标框 120 列，下方那一对**更窄**（80 列，5/7 行）。P86 拒绝 7 行、5 行本就不配对（上方没有 80 列规则行），回落到 3 行 → `[1 3]`、`NOT-EMPTY` |

复现命令（P59，与 design §1 逐字一致；重跑必须得到**同一份字节**）：

```sh
rm -rf /tmp/trust-repro && mkdir -p /tmp/trust-repro/{sock,sess} /tmp/trust-repro/proj/.pi/skills/teamsmith
cd /tmp/trust-repro/proj && git init -q -b main && printf '# x\n' > README.md && git add -A && git commit -qm init
env -u TMUX -u TMUX_PANE TMUX_TMPDIR=/tmp/trust-repro/sock tmux new-session -d -s trustrepro -x 120 -y 30 \
  -c /tmp/trust-repro/proj "HOME=$HOME pi --no-session --session-dir /tmp/trust-repro/sess"
sleep 8
env -u TMUX -u TMUX_PANE TMUX_TMPDIR=/tmp/trust-repro/sock tmux capture-pane -p -t trustrepro
env -u TMUX -u TMUX_PANE TMUX_TMPDIR=/tmp/trust-repro/sock tmux display-message -p -t trustrepro '#{cursor_y}'
```

判据（P59）：这份帧是**覆盖层**，不是草稿。

```sh
bash skills/teamsmith/tests/pm-box-real.sh --frame skills/teamsmith/tests/frames/pi-0.87.0-project-trust-prompt.txt --cursor 16
#   → overlay=trust-prompt（rc 0）
M24_OVERLAY_DETECT=0 bash skills/teamsmith/tests/pm-box-real.sh \
  --frame skills/teamsmith/tests/frames/pi-0.87.0-project-trust-prompt.txt --cursor 16
#   → idle-read=NOT-EMPTY（rc 1）—— 关掉覆盖层判据，同一份帧退回老判定（可见红侧）
```

复现命令（M45）：

```sh
bash skills/teamsmith/tests/pm-box-real.sh --idle-secs 25   # 真 pi 打印原始帧 + 守卫判定
```

判据：这份帧的框文本必须是**空**（`_team_box_rows_of_frame 26` 只剩提示行；P67 起
`team_input_box_text` 把边框邻行按内容读，**只有**「光标不在其上且文本匹配实测状态行形状」的那一行
才排除 —— ` deepseek-flash  Deepseek  max` 命中形状且光标在第 26 行，所以排除）。修 M45 前，几何会把
第 11 行（横幅的 DynamicBorder）当成框的上边框（`geometry=[11 29]`）→ 框文本 = 横幅文字 + 框自己的
上边框 → `BUSY`、`RETRACT=failed`。

判据（P67：边框邻行按内容读 —— 0.87.0 的单行草稿正是这一行）：

```sh
bash skills/teamsmith/tests/pm-box-real.sh --frame skills/teamsmith/tests/frames/pi-0.87.0-one-line-draft.txt --cursor 26
#   → box_text=[HUMAN-ONE-LINE-DRAFT]、idle-read=NOT-EMPTY（rc 1）—— 边框邻行是草稿
bash skills/teamsmith/tests/pm-box-real.sh --frame skills/teamsmith/tests/frames/pi-0.87.0-empty-box.txt --cursor 26
#   → box_text=[]、idle-read=EMPTY（rc 0）
M24_SHADOW_CHROME=1 bash skills/teamsmith/tests/pm-box-real.sh \
  --frame skills/teamsmith/tests/frames/pi-0.87.0-one-line-draft.txt --cursor 26
#   → box_text=[]、idle-read=EMPTY（rc 0）—— 谓词影子成「一律 chrome」= 老的槽位排除，红侧可见
```

## P80：下边框取「最低的合格候选」（`p78-*.txt` 合成帧）

P80 之前下边框取光标下方**最近**的整行 ─；草稿自己在光标下方画一条等宽框线（粘贴的 Markdown
分隔线/表格边框，裁切型 TUI 可达）就成了下边框，框被定位得**太小**，框线以下的草稿落在框外 →
脏框判空 → 就绪门放行、payload 打进人的草稿（P74 的 F1；V9-A4/A5/A8/A10 缺陷类的另一端）。
P80 起下边框 = 光标下方**最低的**合格整行 rule（上边框 HIGHEST 的镜像）；上表八份合成帧就是
它的形状表。

- **合成，不是实拍**：这八份是「裁切型 TUI」的模型，构造与
  `docs/team/reports/P78-verify/pkg/lib.sh` 的 `p78_build_frames` 逐字节相同（`cmp` 可验）；
  它们没有真 pi 出处，门禁按合成帧对待，真实现场仍由前五份真帧守着。
- **判据只有一份实现**：候选顺序由 `_team_box_bottom_candidate_order` 决定；影子成升序（= 旧的
  「最近优先」）就是红侧：`p78-draft-rule-below-cursor.txt` 的 `[1 5]` 退回 `[1 3]`、判定退回
  `EMPTY`。FAST 段 `12b-h0d` 两个方向都跑，并逐帧断言。
- **不分离的歧义**：`p78-draft-rule-only.txt`（「草稿只有一条 rule」）与「空框正下方一条 rule」
  是同一串字节（sha256 `e463c80c…f5053a6`）；一条规则必须同时服务两种读法，P80 取保守的那个
  （内容 → BUSY）。代价写在 `references/troubleshooting.md` §3。
- **已存真帧不动**：五份真帧在 P80 前后判定与几何逐一相同（`[25 27]`/`[25 27]`/`[25 27]`/
  `[24 29]`/无框 overlay），两份布局的最低整行 rule 都是框自己的下边框 —— 镜像代价在已测布局上
  不可达。

## P86：下边框候选的**准入条件** —— 定位出的框必须包含光标行（`p86-f1-*.txt` 合成帧）

P80 的「最低候选」带来一个安全回归（P84 复验的 F1）：规格只钉了「上边框是下边框之上**最高**的合格行」，
旧顺序下（下边框紧贴光标下方）这**隐含**了「框含光标」；改成最低候选后，配对可以**整个落在光标下方** ——
混宽度帧里下方另有一对自成配对的规则行，新框与光标框**不相交** → 框读空 → 就绪门放行 → payload 打进人的
草稿（生产路径同样）。requirements 里「框只会变大 / 不许 BUSY→EMPTY」那句在混宽度帧上是**假的**，P86 把它
换成准入条件。

- **规则**：下边框候选**必须**满足「配到的上边框**严格在光标行之上**」（⇒ **框包含光标行**）；不满足的候选
  **跳过**，继续在**更近**的候选里找；全都不满足 → 既有的 unknown-shape 路径（不新造行为）。配对规则
  （tier1 等宽 / tier2 spinner）、横幅排除、两遍回退、上边框取最高，全部照旧。
- **准入也只有一个决策点**：`_team_box_top_border_max_row`（返回光标行上一行）。红侧不靠产品开关：测试
  进程把它影子成一个极大的行号（= 不设准入条件）即可**逐字**复现 P80 在 `p86-f1-*.txt` 上的 `EMPTY`
  （与候选顺序影子 `_team_box_bottom_candidate_order` 同一模式）。
- **单调性 = 可机读的断言，不是一句论证**：**已存帧上**（5 真帧 + 8 份 p78 + 3 份 p86）逐帧对比
  准入前/后 → 没有 BUSY→EMPTY；并且定位出的框**总是包含光标行**（`geometry=[t b]` ⇒ `t < cy < b`）。
  FAST 段 `46` 用影子把两侧都跑一遍并断言（发现式语料：新增帧不声明光标行就红）。
- **边界（已实测，不是隐藏的例外）**：准入条件承诺的是「定出来的框一律含光标」，**不是**「任何帧都不会读成
  空框」。实测的边界形状：`rule(A) / 空行(光标) / rule(A) / 空行 / rule(B) / 文本 / rule(B) / footer`
  （A≠B）—— 下方那一对（5/7 行）在光标之上配不到任何规则行、被准入条件跳过，而第 3 行是**草稿自己画的**
  rule、自身可配对 → 回落到 `[1 3]` → 读空（P86 前取 `[5 7]`、判忙）。它把
  `p78-draft-rule-only.txt` 的字节二义（草稿＝一条 rule vs 空框正下方一条 rule）在混宽度上再走一格；写进
  design §8 与 `references/troubleshooting.md` §3 的「仍开着的洞」，交 PM 裁决。

复现（纯帧；gate 的帧探针另外打印 `geometry`）：

```sh
bash skills/teamsmith/tests/pm-box-real.sh --frame skills/teamsmith/tests/frames/p78-draft-rule-below-cursor.txt --cursor 2
#   → box_text 带草稿的 rule 行与 ` draft text below my own rule`、idle-read=NOT-EMPTY（rc 1）
bash skills/teamsmith/tests/pm-box-real.sh --frame skills/teamsmith/tests/frames/p78-conversation-rule-below-box.txt --cursor 2
#   → idle-read=NOT-EMPTY（rc 1）—— 记录在案的镜像代价：框下方的整行 rule 把框撑大、判忙
```

## P147：支持布局准入 —— Pi 0.99.2 的闭集编辑器矩形（两份新真帧）

`pi-0.99.2-empty-editor.txt` / `pi-0.99.2-human-draft.txt` 是 **P147 自己的容器跑出来的真帧**
（P138 的 Poda 配方 + 宿主 Pi 0.99.2，isolated HOME/session；见
`docs/team/reports/P147-dev/logs/tmux-delivery-truth-before-dirty/` 与 `...-draft-before-dirty/`）：

| 文件 | 光标行（1-based） | 记录下来的页脚 cwd | sha256 |
|---|---|---|---|
| `pi-0.99.2-empty-editor.txt` | 29 | `/tmp/p138.8HwUSx/proj/.worktrees/dev` | `61153ab21abac7bef005e7a16e75b87a7f5ff20b38c430c3310ac2f7531d526a` |
| `pi-0.99.2-human-draft.txt` | 29 | `/tmp/p138.yalHes/proj/.worktrees/dev` | `a0198a0f36d94e217b0a65b80c9afabb78bc454a70e916f3bc7a692c1161253f` |

两份都是 120×32 的整屏 capture，页脚两行 = `<cwd> (branch)` + `1.2%/128k (auto) … p138`；
对话区第 21 行还有一条整宽规则行（旧域把它当编辑器顶线 → 框 `[21 30]`、空编辑器被读成 BUSY →
`say` 退出 0 并承诺「清空后自动投递」而永不兑现 —— P147 的红）。

- **规则**（唯一决策点 `_team_box_layout_decision`，实现见 `scripts/lib/outbox.sh`）：末两行是 Pi 页脚
  （cwd 行 + 状态行闭集语法）；紧贴页脚上方的等宽整行 ─ 是下边框；光标上方**恰好一个**等宽整行
  ─ 能框出一个内部行不超过 `max(5, floor(R×0.3))`、每行字节数 ≤ 规则行字节数-3（terminal-cell 宽度的
  保守上界）且内部**没有**别的整宽规则行的矩形 → 收窄候选域；反之（0 个或多个矩形、底线缺失/太短、
  内容超宽、页脚 cwd 与 target 运行时 cwd 不符）→ `geometry-untrusted`：一个键都不发、held + 非零退出。
  没有 expect cwd（纯帧探针不带上下文）或页脚形状不成立 → 维持旧域（已存 0.85.1/0.87.0 帧的判定
  逐字不变）。
- **判据只有一份实现**：`team_input_box_text`（真 pane）、`team_box_frame_verdict`（纯帧）与门禁探针
  都走 `_team_box_layout_decision`；红侧 = 测试进程把它影子成 `none`，同一份真帧退回 `[21 30]`/BUSY。
- 判据/门禁：`bash skills/teamsmith/tests/delivery-truth.sh --section frames --mutations`
  （真帧 `[28 30]`/EMPTY、真草稿 `P143-HUMAN-DRAFT`/BUSY、全部既有帧判定保持、两条红侧）。
