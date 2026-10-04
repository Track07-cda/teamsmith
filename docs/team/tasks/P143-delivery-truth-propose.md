# P143 · `delivery-truth` propose：降级通道的几何假 BUSY 不许卡住消息，notify 三处命名一致

```
task:   P143
agent:  verify                        # propose 只写 openspec/changes/**（不违反 D36）
issue:
change: delivery-truth
specs:  delivery-guard#An automated send never types into a non-empty input box
phase:  propose
anchor: change
deltas: delivery-guard,notify-and-inbox,panel
grant:  openspec/changes/delivery-truth/** · docs/team/reports/P143-verify.md · docs/team/reports/P143-verify/**
deps:   P138 的诊断（`docs/team/reports/P138-verify.md` + `pkg/` 可重跑配方 + 867 个证据文件）· PM 的独立复现（rev fe46eae6，见 reviews/P138.md）· 既有承诺：`delivery-guard` 的两条 requirement（自动投递不往非空框打字 · 投递以 pane 为准且排队要如实报）· 本地模式
status: done
budget: 一个提案
priority: 高（同行 PM 报了两遍 ✅ 今天仍在真 Pi 上复现 ✅ 且是**假绿**形状 ✅）
```

## 现场（今天复现，不是引用）

```
REV=fe46eae6（当前 main）· 真 Pi 容器场景 · say_rc=0 · second_say_rc=0
judge: second_received=0 backend=0 settled=2 settle_editors_empty=1 → FAIL second say stranded despite idle empty editor
```

**F1**：真 Pi settle 之后，输入框几何把**聊天区分隔线**配成"上边框" → 假 BUSY → 消息进队列 ✗，
而 `team say` **退出 0** 并承诺"有草稿／清空后自动投递" ✗ —— 框其实是空的，所以这句**永远不会兑现** ✗（每次重读同一帧还是 BUSY ✗）。
代码路径（P138 给的行号）：`_team_box_geometry` · `_team_box_rows_of_frame:220` · `_team_box_text_of_frame:335` · `team_tmux_deliver:672-705`。

**F2**：`notify <agent> --from <sender>` 实际写 `docs/team/inbox/<agent>.md` ✅、敲 PM ✅、outbox 声明 `--inbox-written pm` ✅ →
**三者指向的文件不一致** ✗（wake 里的全文路径会指到不存在的东西 ✗）。

## 要 propose 的（每条 requirement + scenario，可证伪，**红侧要真帧**）

1. **几何判据在真帧上成立** ✅：上边框/下边框的候选选择规则要能应对真实 Pi 的**聊天区**（分隔线、空行、状态行）
   —— 判据必须以**闭集形状**说话 ✅（P67/P78/P86 已有的"上边框=最高合格行/下边框=最低合格行 + 必须包含光标行"那一族 ✅），
   **不许**靠"再试一次" ✗ 或"看到 BUSY 就等" ✗ 蒙过去；
2. **卡住的队列项不许被承诺** ✅（本 change 的真价值）：一条队列项在**框读作空且 idle** 时仍长期 `queued` ✗ →
   必须**可见地**暴露（判据/日志/面板/`team say` 的输出 ✅ 具体形式你定 ✅），
   且"清空后自动投递"这类**承诺性文案只有在框读数可信时**才允许出现 ✗；
3. **F2 三处一致** ✅：耐久收件人文件 · outbox 的 `--inbox-written` 声明 · wake 里的全文路径，指向**同一个真实存在**的文件 ✅；
4. **不许放松守卫** ✅：真草稿仍必须**推迟**（不往非空框打字 ✅），这是 P63/P67 的核心 ✅ —— 要有红侧证明它还在 ✅；
5. **证据用 P138 的配方** ✅：真 Pi + 容器（`pkg/run-case.sh` + `judge-second.py` ✅）作为**红侧基准** ✅；
   合成帧可以辅助 ✅，但"真帧绿"必须自己跑出来 ✅（写明 Pi 版本与你实际跑的命令 ✅）。

**非目标**：不动 M6.5 存活判据 ✅ · 不加新 intent ✅ · 不跨机器 ✅ · 不重设 <peer-c> 原事故的归因 ✗（P138 已说明不能冒认 ✅）。

## 交付

`openspec/changes/delivery-truth/{proposal,design,tasks}.md` + `specs/{delivery-guard,notify-and-inbox,panel}/spec.md` ✅
+ `openspec validate --all --strict` ✅ + MODIFIED 不丢基线场景（给前后对照表 ✅）+ 每条 What flips 有红侧 ✅
+ 报告写清"哪些是我自己跑的、哪些引用 P138" ✅。
