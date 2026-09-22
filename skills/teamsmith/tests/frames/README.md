# tests/frames · 输入框判据的真实帧样本

这里的文件是 **`tmux capture-pane -p` 的原样输出**（守卫看到的就是它），给纯函数夹具
（`_team_box_rows_of_frame` / `_team_box_geometry`）当输入 —— 这样「真实现场 → 判据」这条链
不必开 tmux 就能在门禁里复跑，端到端（真 pane）与纯帧也共用同一份实现。

帧文件不能带注释（多一行就多一行 pane），来源与光标行写在下面这张表里。

| 文件 | 来源 | 光标行（1-based） | 现场 |
|---|---|---|---|
| `pi-0.87.0-project-trust-prompt.txt` | 真 pi **0.87.0**（`--no-session --session-dir <tmp>`，私有 tmux socket，pane 120×30），在一个 git 仓库里实拍 —— 仓库里有 `.pi/skills/teamsmith`（team init 装的项目资源）且**没有**已保存的信任决定 | `16`（弹窗自己的下边界那条整行 ─） | **Pi 的项目信任弹窗**（覆盖层，不是输入框）：第 1 行整行 ─、第 3 行问题、第 4 行 cwd、第 8–12 行选项、第 14 行导航提示、第 16 行弹窗下边界 —— 弹窗里一个字的输入都没有 |
| `pi-0.85.1-update-banner.txt` | 真 pi 0.85.1（`--no-session --session-dir <tmp>`，私有 tmux socket，pane 120×30）空闲 25s 后实拍；**1–9 行是 pi 的启动输出（`[Skills]`/`[Extensions]` 等与本判据无关）已置空，行号与实拍一致** | `26`（框内第一个内容行） | 两个更新横幅（`Package Updates Available` + `Update Available`）画在输入框上方；pane 第 11/16/18/22 行是横幅的 DynamicBorder，24/29 行是输入框的上下边框 —— 全部同形等宽（360 字节 = 120 个 `─`） |

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

判据：这份帧的框文本必须是**空**（`_team_box_rows_of_frame 26` 只剩提示行；`team_input_box_text`
里 `OFFSET==1` 的提示行被排除）。修 M45 前，几何会把第 11 行（横幅的 DynamicBorder）当成框的上边框
（`geometry=[11 29]`）→ 框文本 = 横幅文字 + 框自己的上边框 → `BUSY`、`RETRACT=failed`。
