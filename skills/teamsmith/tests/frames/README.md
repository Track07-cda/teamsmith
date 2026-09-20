# tests/frames · 输入框判据的真实帧样本

这里的文件是 **`tmux capture-pane -p` 的原样输出**（守卫看到的就是它），给纯函数夹具
（`_team_box_rows_of_frame` / `_team_box_geometry`）当输入 —— 这样「真实现场 → 判据」这条链
不必开 tmux 就能在门禁里复跑，端到端（真 pane）与纯帧也共用同一份实现。

帧文件不能带注释（多一行就多一行 pane），来源与光标行写在下面这张表里。

| 文件 | 来源 | 光标行（1-based） | 现场 |
|---|---|---|---|
| `pi-0.85.1-update-banner.txt` | 真 pi 0.85.1（`--no-session --session-dir <tmp>`，私有 tmux socket，pane 120×30）空闲 25s 后实拍；**1–9 行是 pi 的启动输出（`[Skills]`/`[Extensions]` 等与本判据无关）已置空，行号与实拍一致** | `26`（框内第一个内容行） | 两个更新横幅（`Package Updates Available` + `Update Available`）画在输入框上方；pane 第 11/16/18/22 行是横幅的 DynamicBorder，24/29 行是输入框的上下边框 —— 全部同形等宽（360 字节 = 120 个 `─`） |

复现命令（M45）：

```sh
bash skills/teamsmith/tests/pm-box-real.sh --idle-secs 25   # 真 pi 打印原始帧 + 守卫判定
```

判据：这份帧的框文本必须是**空**（`_team_box_rows_of_frame 26` 只剩提示行；`team_input_box_text`
里 `OFFSET==1` 的提示行被排除）。修 M45 前，几何会把第 11 行（横幅的 DynamicBorder）当成框的上边框
（`geometry=[11 29]`）→ 框文本 = 横幅文字 + 框自己的上边框 → `BUSY`、`RETRACT=failed`。
