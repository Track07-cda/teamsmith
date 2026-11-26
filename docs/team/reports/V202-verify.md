# V202 · 独立验证看板连续方向键

agent: verify   status: PASS（候选与合并版定点）   time: 2026-11-26T02:02:36Z

branch: `task/V202-panel-board-batched-keys-verify`   PR/MR: -

**P509 候选 `f6182e925c5480e41e5d403d906c6ce6a3cf2500` 定点通过。** 在同一份看板数据、同样的 160×32 终端中，一条命令连发三次 ↑，旧版停在 `M51 Other`，新版到 `M39 Second`。随后一条命令连发两次 ↓ 并按 Enter，打开的是最后一张卡片 `M51`，不是起点 `M39` 或中途的 `M48`。宽屏车道窗口和同号卡片刷新后的焦点也通过实测。**合并版 `c0d2cfd9` 已短核通过：四份文件与候选逐字节一致，仍到 `M39 Second`。** 其余动作沿用候选实测，未在合并版重复运行。

## 交付与实测

| 检查 | 回执与原件 |
|---|---|
| 正式复验 | `docs/team/reviews/P509.md`、`docs/team/reviews/P509-verify.log`；候选时执行者 `verify`，冻结检出干净，用时 7 秒、排队 0 秒，原生判定 PASS；当时日志与候选私有 `frames/run.log` 逐字节相同。PM 已保存候选记录两份原件；这两个正式路径现记录下文的合并版短核。 |
| 同批键后立即打开 | `send 6: Down Down Enter`；`frames/enter.txt` 显示 `M51 · fixture brief`，未出现 `M39` 或 `M48` 的详情标题。退出后唯一光标为 `M51 Other`，`x=3 y=7`。 |
| 宽屏窗口跟随 | 已完成栏首窗为 `D40…D16`，从窗底的 `D16` 一次发送 `Down Down Up`；新窗口是 `D38…D14`、唯一光标在 `D15`（`x=83 y=28`），边沿标记 `↑2`、`↓13`。隔壁已放弃栏仍显示 `X40…X16`。见 `frames/window-{before,after}.txt`。 |
| 同号行、刷新与新断言 | 从原 `scn_board` 取相同 `BOARD.md` 行序，真实读取和写入只在私有项目。`dup-1`/`dup-2` 分别唯一选中 `M39 第一条`/`M39 第二条`；真实 `board assign M39 reviewer` 只给第二条补新更新时间（`2026-11-26T01:57:15Z`），再发 `r` 后第二条从第 5 屏行移到第 4 屏行，唯一光标跟随。Enter 显示 `Board body M39 proof`；退出后还在第二条。一条 `Down Down` 按顺序从第二条经第一条到 `M48 第三条`，最终只在第三条显示光标（第 6 屏行）。见 `frames/dup-*.txt`、`frames/board-{before,after}.json`。 |

原件保留于 `/var/tmp/v202.x5UGhS/`：`input/` 输入、`old/` 的 P505 旧帧及日志副本、`run.sh`/`check.py`、`frames/` 的新帧和两段终端原始流（`tty.raw`、`board-tty.raw`）。同一短运行共用一个私有 tmux 服务，先用 P505 的数据读者，后在同一窗格换到真实看板和详情读者；其它数据块仍用原测试读者。通过 `/proc` 及 tmux 回执核对了两个 pane 进程的 Node、启动参数、目录、160×32 尺寸和同一个专用 socket。命令参数含 `--no-pulse`，两个项目状态目录均在私有根。结束后对该 socket 执行 `has-session`，`rc=1`、`no server running`。

## 改前／改后证据

旧版的 `panel.js` 与 `git show 862733ea:skills/teamsmith/scripts/panel/panel.js` 字节相同；`862733ea` 到修复前 `1ba30d6c` 的 `skills/teamsmith` 无差异。P505 原 `run.log`、输入和指定帧均用 `cmp` 核对副本；`old/trace.jsonl` 的第 13 次发送为 `Up Up Up`，旧终端一次收到 `1b5b411b5b411b5b41`，记录三次相同的 `Outside → Other`。本轮只读取旧记录，没有重新运行旧版或 Node 追踪。旧版逐次发键的保存帧为 `M51 Other → M48 Neighbor → M39 Second`，证明三张都可逐步选中。

同一个画面判定函数要求全屏只有一个光标，且用 ID 与完整标题辨认同号卡片。新旧均从 `M39 Outside x=3 y=8` 出发，三次 ↑ 由同一条 `send-keys` 命令发出，键间无延时；下一次正常刷新后的帧用同样的判定。

```text
旧 862733ea: send 13: Up Up Up; send rc=0
旧首次变化 / 下一次刷新: M51 Other x=3 y=7 / y=7
P505 saved frame assertion rc=1 (wanted M39 Second, got M51 Other)
新 f6182e92: send 5: Up Up Up; send rc=0
新首次变化 / 下一次刷新: M39 Second x=3 y=5 / y=5
V202 candidate frame assertion rc=0
```

输入 SHA-256 `8b8c7b74a0fc56a60808678c48e6f3b700be2b0980c73c2dc6c1eb697f9d08a5`；实际执行的新 bundle SHA-256 `215a8f9106745664a44e21251c6b0c1c266fe3637e9c8142a8a0de9a2ed9d8be`，从冻结源直接运行，不重建。

## OpenSpec 对照与边界

| 维度 | 本次结论 | 依据 |
|---|---|---|
| 完整性 | 任务书指定的定点范围已覆盖 | 着眼于 `panel#The board page is a kanban over the board's states` 的方向键、Enter、选中行与可见范围；无新 change 或 delta。 |
| 正确性 | 通过 | 同输入同断言旧失败、新通过；真实终端确认了批量移动、立即打开、宽屏跟随和刷新保焦。 |
| 一致性 | 在源码检查的范围内相符 | `App.tsx:929–972` 仍使用已画看板的车道顺序、原行身份及折叠判定；只在键间立即更新同一行引用。`openBoardFocused`（`:1014`）读同一引用。`layout.ts:1045–1047` 仍把当帧的行身份交给鼠标动作，`App.tsx:1799/1846` 仍用动作携带的行定位，不按新焦点重解坐标。生产 `layout.ts`、规格及原数据读者无差异。 |

源差异确认原 `panel-b3.sh` 的 `dup-1`、`dup-2`、实际写入后 `dup-refresh`、详情与返回断言均保留，只把返回后的两次单独 ↓ 换为一批 `keys Down Down` 到第三条。本次在私有运行中重放该片段的操作与断言，未执行整个 B3、窄屏、鼠标或折叠；鼠标与折叠仅核源码。工作页、标签候选 P497/V196、P503、OpenSpec 全量结构检查、重建和全套测试均未运行；不把本次判定外推到这些范围。检查项内无必须返工的问题，未作发版判定。

## 实际命令与提交边界

```text
$ TMPDIR=/var/tmp/v202.x5UGhS/tmp TEAM_GATES='bash /var/tmp/v202.x5UGhS/run.sh' bash skills/teamsmith/scripts/team review P509 --dir /var/tmp/p509-review-f6182e92.d2TU2D --branch f6182e925c5480e41e5d403d906c6ce6a3cf2500
✓ 门禁输出：docs/team/reviews/P509-verify.log（PASS，7s）
✓ 复验记录：docs/team/reviews/P509.md（PASS）
rc=0（后台作业 v202-p509-panel 已收取；P509-verify.log 含 `V202 all assigned real pane assertions passed`）
```

`bash -n` 私有驱动、候选 `git diff --check`、新日志 `cmp` 及冻结检出的干净核对均为 `rc=0`。

Ledger ban(验证席位工作树,报告已暂存):

```text
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: scope=published files=3142 hits=0 names=ok user=resolved
ledger rc=0
```

## 合并版短核 · 2026-11-26T02:02:21Z

在 PM 提供的干净固定检出 `/var/tmp/p509-merged-c0d2cfd9.BPUVzs` 上运行，对照候选 `f6182e92` 的 Git 文件内容逐一与合并版实际文件 `cmp`。`panel/README.md`、`panel/panel.js`、`panel/src/App.tsx`、`tests/panel-b3.sh` 四份均一致，完整 SHA-256 在 `P509-verify.log`。实际 Node 进程参数指向该检出的 `panel.js`，SHA-256 仍是 `215a8f9106745664a44e21251c6b0c1c266fe3637e9c8142a8a0de9a2ed9d8be`；输入与候选及 P505 的原数据副本 `cmp` 均为 `rc=0`。

```text
$ TMPDIR=/var/tmp/v202-merged.GeH51G/tmp TEAM_GATES='bash /var/tmp/v202-merged.GeH51G/run.sh' bash skills/teamsmith/scripts/team review P509 --dir /var/tmp/p509-merged-c0d2cfd9.BPUVzs --branch c0d2cfd9d4e76639d72d2b999d19eb866a366baa
✓ 门禁输出：docs/team/reviews/P509-verify.log（PASS，2s）
✓ 复验记录：docs/team/reviews/P509.md（PASS）
rc=0（后台作业 v202-p509-merged 已收取）

# 正式日志的实景读数
burst-outside: M39 Outside x=3 y=8
send 5: Up Up Up
send rc=0
burst-up-first: M39 Second x=3 y=5
burst-up-next-tick: M39 Second x=3 y=5
merged three-key assertion rc=0
```

同一 160×32 私有 tmux 中一次发送三键；两张帧均只有一个光标，且在第二条 `M39` 上。结束后专用 socket 的 `has-session` 返回 `rc=1`、`no server running`。本轮不重跑候选其它动作、旧版、构建或整套测试。正式记录与日志副本、输入、启动脚本和画面原件在 `/var/tmp/v202-merged.GeH51G/`，`sha256sum -c SHA256SUMS` 九项通过。候选原件仍在 `/var/tmp/v202.x5UGhS/`；两处均保留，未改 V196。

本分支只提交本报告，不推送或合并。待 PM 接收合并版证据与两轮原件。
