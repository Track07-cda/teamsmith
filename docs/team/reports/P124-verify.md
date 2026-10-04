# P124 · `panel-board-cards` 独立验证 — verify

- **任务**：`docs/team/tasks/P124-panel-board-verify.md`（phase: verify）｜**change**: `panel-board-cards`
  （propose = P121 dev2 → apply = P123 dev3；本次**换人**独立验证）
- **验证对象与时间线**：§1–§9 是已落 main 的首轮基线 `a517aa39` 的原始记录（当时 `git diff main -- skills/` 为空、判定 PARTIAL）；**§10 是 PM 合并 P127/P125/P128 后最终 main tip `b08af2c659e87457a82c59600bb0e2622a39c1d0` 的复跑结论**。为避免把我的旧工作树当成新 tip，§10 在该 tip 的独立干净检出上运行；临时检出已删除，原始日志留在本分支。
- **分支**：`task/P124-p124`（**local 模式**：不 push，分支留在本地 worktree，PM 复验后本地合并）
- **最终结论（§10）**：**独立行为验证 PASS，最终全量门禁 PASS**（`✓3769 ✗0`；旧 §38-f 假红已解除）；§1–§9 的 `PARTIAL / BLOCKED` 仅为首轮历史状态，不代表最终判定。OpenSpec 勾选及归档仍归 PM：本 tip 的任务账本 **12/18**，不可把本报告单独当作归档授权。
- **复现**（全部命令在本 worktree 根下）：

  ```bash
  bash docs/team/reports/P124-verify/pkg/run.sh            # 10 20 30 40 50 60（默认，本次约 93 秒）
  bash docs/team/reports/P124-verify/pkg/run.sh 70         # 零回归门禁（长作业，共享锁排队）
  ```

- **包整跑**：`== P124 验证包汇总 == ok=135 finding=0 bad=0 skip=0`（`pkg/logs/run-summary.log`；最终脚本 + 帧/pty/conf 原始证据均已落在 `pkg/logs/`）。
- **`openspec/changes/panel-board-cards/` 未归档**（本验证是归档前置；归档按流程由 PM 在用户确认后做）。

---

## 1. 哪些是「我自己的证据」，哪些是「引用」

| 任务书条目 | 我的判据（本包自己写、自己跑） | 结果 | 原始输出 |
|---|---|---|---|
| ① 降级序 190/120/99/59，标题最后一个被截 | `pkg/10-degrade.sh`：自造长标题板 + 自写 `card_check.py`（显示宽度、前缀、行边界度量）；`panel.js --snapshot` 四档 | 52 ok / 0 finding | `pkg/logs/run-10.log` + `pkg/logs/frames/degrade-{190,120,99,59}.txt` |
| ① demoted 对在键位带（agent→phase→整对） | `pkg/10-degrade.sh` §10b：自扫 9 档宽度的键位带右端 + 单调性判据 | 同上 | 同上 |
| ② 真 pty 按 `c`、写 conf、重启持久、显式展开粘住 | `pkg/pty-fold.py`（**本包自写**的真 pty 驱动，不经过 tmux）+ `pkg/20-fold-pty.sh` | 30 ok / 0 finding | `pkg/logs/run-20.log` + `pkg/logs/pty/` |
| ③ 空车道默认折叠两个方向 | `pkg/30-empty.sh`：默认 vs `boardEmptyFold=0` vs 两表同名 | 15 ok / 0 finding | `pkg/logs/run-30.log` + `pkg/logs/frames/empty-*.txt` |
| ④ 机器出口不受折叠影响（字段级） | `pkg/40-machine.sh`：`--print` 归一化 diff + 自写 `json_same.py` 去 timestamp 逐字段比 | 7 ok / 0 finding | `pkg/logs/run-40.log` |
| ⑤ 有界帧与成本（长历史） | `pkg/50-bounded.sh`：200 张 done、`frame_stats.py` 行数/宽度/尾行 + 可见/隐藏可复算量 + 3×成本采样 | 13 ok / 0 finding | `pkg/logs/run-50.log` + `pkg/logs/frames/hist-*.txt` |
| ⑥ 对抗：自造两个红侧 + 复跑作者两条翻转 | `pkg/60-adversarial.sh`：自造突变 M1/M2（临时 src 树重建 bundle）+ `panel-flip-p123.sh F-MACHINE F-EMPTY` | 18 ok / 0 finding（红侧按预期红） | `pkg/logs/run-60.log` + `pkg/logs/flips-p123-machine-empty.log` |
| ⑦ 零回归 | `pkg/70-regression.sh`：openspec + FAST + `--select 26,27,28` + panel-* 独立套件 + 全量 | **前四项绿；全量 `✓3743 ✗2`，PARTIAL**（见 §7） | `pkg/logs/gates-*.log` |
| ⑧ 报告归属 | 本节 + §2.8 | — | 本文件 |

**引用（只作数据/交叉参考，不作判据）**：
- `skills/teamsmith/tests/panel-b3-stub.sh`：既有**确定性夹具数据源**（board/agent/activity 的固定 JSON）。我把它当输入板用
  （还自造了长标题/200 张历史两张板），判据全部由本包自己的脚本给。
- `skills/teamsmith/tests/panel-flip-p123.sh`：复跑其中**两条**（六选二，任务书要求）；它自己的红/绿判定与我的 M1/M2 是两套。
- `tests/panel-b3.sh` 与 `tests/lib/pty-wait.sh`：**读了**（理解作者夹具的形状与等待纪律），没有依赖它们给出**看板行为**结论；
  交互证据是本包自己的 `pty-fold.py`（真 pty、静默判定）。但 §7 的独立门禁故障诊断需要检查 `pty-wait.sh` 本身。
- 我没有引用 P123 报告里的任何数字作结论（PM 的 P123 review 也只是我定位题目的背景）。

**我的包没有做的事**：没有改实现、没有碰 `skills/**`（`git diff main -- skills/` 为空）；
本包 10–60 的交互证据不走 tmux（真 pty 直驱）；70c/70e 的 smoke 自行管理隔离 socket，
诊断复跑的真 tmux 只在一次性容器里执行。

---

## 2. 逐项验收（原始输出）

### 2.1（任务书 ①）降级序：四档出帧，标题是最后一个被截

夹具：`LNG1`（todo，焦点卡），标题 `ZSTART` + 40 个 CJK + `ZEND`（`agent=zagent`、`phase=zphase`），
其余车道空/占位；`panel.js --snapshot --page 4 --lang zh --theme dark`。每档原始帧前 4 行
（这里只去除行尾填充空格；完整帧逐字节留在 `pkg/logs/frames/degrade-{190,120,99,59}.txt`）：

```
$ bash docs/team/reports/P124-verify/pkg/run.sh 10        # pkg/logs/run-10.log

  ---- w=190 · 原始帧 1–4 行 ----
      teamsmith pulse · fixture  10:00:00  巡检 900s · 待命 off
        总览   工作   消息与日志  [看板]
      ╭─ ▾ 待办 1 ─────────────────────────────╮ ╭─ ▾ 进行 1 ─────────────────────────────╮ ▸ 待复验 0（已折叠） ▸ 完成 0（已折叠） ╭─ ▾ 阻塞 1 ─────────────────────────────╮ ▸ 已放弃 0（已折叠）
      │ › · LNG1 ZSTART甲乙丙丁戊己庚辛壬癸甲… │ │   ▸ LNG2 ZSTART甲乙丙丁戊己庚辛壬癸甲… │                                         │   ✗ LNG3 ZSTART甲乙丙丁戊己庚辛壬癸甲… │
  ---- w=120 · 原始帧 1–4 行 ----
      teamsmith pulse · fixture  10:00:00  巡检 900s · 待命 off
        总览   工作   消息与日志  [看板]
      ╭─ ▾ 待办 1 ──────╮ ╭─ ▾ 进行 1 ──────╮ ▸ 待复验 0（已折叠） ▸ 完成 0（已折叠） ╭─ ▾ 阻塞 1 ──────╮ ▸ 已放弃 0（已折叠）
      │ › · LNG1 ZSTAR… │ │   ▸ LNG2 ZSTAR… │                                         │   ✗ LNG3 ZSTAR… │
  ---- w=99 · 原始帧 1–4 行 ----
      teamsmith pulse · fixture  10:00:00  巡检 900s · 待命 off
        总览   工作   消息与日志  [看板]
       ▾ 待办 1
       › · LNG1 ZSTART甲乙丙丁戊己庚辛壬癸甲乙丙丁戊己庚辛壬癸甲乙丙丁戊己庚辛壬癸甲乙丙丁戊己庚辛壬癸…
  ---- w=59 · 原始帧 1–4 行 ----
      teamsmith pulse · fixture  10:00:00  巡检 900s · 待命 off
        总览   工作   消息与日志  [看板]
       ▾ 待办 1
       › · LNG1   ZSTART甲乙丙丁戊己庚辛壬癸甲乙丙丁戊己庚辛壬…
```

度量（`card_check.py` 的 INFO；行内宽 = 卡片行所在车道的内宽，单列档 = 帧宽）：

| 宽度 | 档位 | 行内宽 | id 前缀宽 | 可见标题宽 | 标题字段宽 | 截断 | 每档判定 |
|---|---|---|---|---|---|---|---|
| 190 | 双列 | 40 | 10 | 28 | 29 | 是 | 4/4 ok |
| 120 | 双列紧凑 | 17 | 10 | 5 | 6 | 是 | 4/4 ok |
| 99 | 单列 | 99 | 10 | 86 | 87 | 是 | 4/4 ok |
| 59 | 单列极简 | 59 | 12（id 填充 6 列） | 44 | 45 | 是 | 4/4 ok |

每档的 4 条判据（四档全绿，`run-10.log`）：卡片行带序号；**可见标题是完整标题的前缀**（证明 id 与标题之间、
标题之后都没有别的字段）；标题起始 `ZSTART` 没有被挤掉；截断时 `prefix + zone ≥ 行边界 − 2`（标题吃到边界，
没有字段在标题右侧）。每档另有 grep：卡片行不含 `zagent`/`zphase`。

键位带阶梯（自扫 9 档，`pkg/10b`）：

```
  w=190 键位带右端=full       w=160 full   w=140 full
  w=120 键位带右端=phase      w=110 none   w=99 none   w=80 none   w=70 none   w=59 none
  ok  阶梯单调下降（full → phase → none，从不回升、无 agent-only）
  ok  三段都观测到（有过 full、phase、none，不是单档特例）
```

190 列的键位带尾（焦点卡的 demoted 对右对齐，主 chip 一个不少）：

```
( m 写信 ) ( f 冲刷 ) ( s 待命 ) ( , 设置 ) · ←/→ 车道 · ↑/↓ 卡片 · c 折叠 · Enter 打开 · Tab/1-4 翻页 · q 收起        zagent · zphase
```

> 观察（不是缺陷）：≤70 列时键位带自身被宽度截断，`c 折叠` chip 落在截断之外（`q` 等 chip 同样如此）——
> 这是「键位带宽度有界」的既有行为；双语 chip 断言在 160 列（§2.2 末）。

### 2.2（任务书 ②）真 pty：`c` 的**写 conf** 那一半 + 跨进程持久 + 显式展开粘住

`pkg/pty-fold.py` 是**本包自写**的真 pty 驱动（python `pty.openpty` 直接跑真 bundle，无 tmux；
每次按键后只取**该动作之后的字节段**，重启段是完整首帧；等待用静默判定而非常量 sleep）。
场景：启动 → `c` → 杀进程重启 → `c`（显式展开）→ 再重启。关键原始输出（`pkg/logs/run-20.log`）：

```
  ok    首帧：待办展开且卡片 T1 在
  ok    按 c 后的新帧：折叠行一行带计数 1
  ok    按 c 后的新帧：该车道不再建卡片行（T1 消失）
  ok    按 c 后的新帧：焦点光标落在折叠行上（唯一光标）
  ok    c 立即落盘 boardFold=todo
  ok    重启后的首帧仍折叠（跨进程持久）
  ok    重启后的首帧仍不建卡片行
  ok    第二次 c 是显式展开（头带 ▾）
  ok    第二次 c 后卡片 T1 回来
  ok    显式展开落盘 boardShow=todo
  ok    显式展开后 boardFold 里没有 todo
  ok    第二次重启仍展开且卡片在
  ok    pty 写的 conf 驱动新渲染：折叠行在（= yes）
  ok    pty 写的 conf 驱动新渲染：单帧光标恰好一个（= 1）
  ok    pty 写的 conf 驱动新渲染：没有卡片行
```

段计数（自报数，`pkg/logs/pty/`）：`after-c1` 里 `T1` **0** 次、折叠行 `› ▸ 待办 1（已折叠）` 在；
重启段 `boot2` 同样 `T1` **0** 次；`after-c2`/`boot3` 里 `T1` 各 **1** 次（展开）。折叠后该车道卡片行 0 条。
原始落盘文件 `pkg/logs/pty/conf1.txt` 有 `boardFold=todo`，`conf2.txt` 有 `boardShow=todo` 且 `boardFold=` 为空。

空车道显式展开（点击车道头，再用另一张板让该车道长出一张卡，重启）：

```
  info  点击坐标 row=3 col=42（needle 在第 3 行第 41 列）
  ok    首帧：空车道默认折叠（一行带计数 0）
  ok    点击车道头后落盘 boardShow=review
  ok    点击后的新帧：该车道显式展开成盒子
  ok    板子长出卡（review=1）后重启：车道仍展开
  ok    板子长出卡后重启：卡 RV1 在展开的车道里
```

页脚 `c` 提示双语：

```
  ok    zh 页脚带 [c 折叠] chip
  ok    zh 空车道折叠行用 zh 字符串（已折叠）
  ok    en 页脚带 [c fold] chip
  ok    en 空车道折叠行用 en 字符串 (folded)
```

### 2.3（任务书 ③）空车道默认折叠：两个方向

```
  ok    默认：review 空车道是一行折叠（计数 0）
  ok    默认：done 空车道是一行折叠
  ok    默认：dropped 空车道是一行折叠
  ok    默认：review 不画盒子（没有展开头）
  ok    boardEmptyFold=0：review 展开成盒子（▾ 头）
  ok    boardEmptyFold=0：review 不再有折叠行
  ok    显式展开赢过空车道默认：review 仍展开
  ok    两表同名时显式隐藏赢：review 折叠
  ok    显式折叠非空车道：todo 折成一行
```

原始帧（`pkg/logs/frames/empty-default.txt` / `empty-off.txt`，160 列）：

```
默认：     ╭─ ▾ 待办 1 ───────────────────╮ … ▸ 待复验 0（已折叠） ▸ 完成 0（已折叠） …
           │ › · T1 待办一张卡             │
off：      ╭─ ▾ 待复验 0 ──────────╮ … 盒子里是 dim 空标记 ·
```

### 2.4（任务书 ④）机器出口不受折叠影响（字段级，不是 cmp）

conf A = `boardFold=todo` + `boardShow=review` + `boardEmptyFold=0`（人类帧会大变样）；conf B = 无折叠键。

```
  ok    夹具 sanity：conf A 真的有折叠键
  ok    --print 两种 conf 的归一化输出逐字节相同（时间戳已归一化，raw 也相同）
  ok    --print 机读帧仍按默认折叠空车道（不看 conf）
  ok    --print 机读帧渲染 todo 卡片（不看 conf 的 boardFold=todo）
  ok    --print 帧里没有折叠键的原文
  info  --json 顶层键（A=activity,panel）
  ok    --json 去 timestamp 后逐字段相同（sha 不同内容同）
```

`--print` 归一化（`[0-9]{2}:[0-9]{2}:[0-9]{2}` → `TT`）后 `diff` 无输出；`--json` 由 `json_same.py` 递归去掉
`timestamp` 键后深度相等。机读帧仍渲染**默认**折叠态（`▸ 待复验 0（已折叠）`）且渲染 board（`LNG…`，机读布局
把窄车道里的 id 截断是既有形状）。

### 2.5（任务书 ⑤）长历史下的有界帧与成本

夹具：200 张 done + 各 1 张 todo/wip，`--snapshot --width 190 --height 32`。

```
  ok    帧行数 == 高度（32 行）
  ok    没有一行超过宽度（max=190 width=190）
  ok    底部页脚是最后一行（( m 写信 ) …）
  ok    未折叠：可见窗口是累计计数（↑175 之类）
  ok    可复算量：可见 + 隐藏 == 200（25 + 175）（= 200）
  ok    可复算量：可见窗口 ≤ 帧高（25 ≤ 32）（= yes）
  ok    帧行数 == 高度（32 行）[boardFold=done]
  ok    没有一行超过宽度（max=190 width=190）
  ok    底部页脚是最后一行
  ok    折叠 done：一行折叠行带计数 200
  ok    折叠 done：整个帧里 0 条卡片行（H 系列命中次数）（= 0）
  ok    折叠 done：没有边计数 ↑N（折叠行不建边计数）
```

可复算量：未折叠 `可见 25 + ↑175 = 200`（同一帧可数、可复算）；折叠后同一几何仍是 32 行、宽 ≤190、
`H###` 卡片行 0 条、无 `↑N` 边计数。

成本采样（墙钟毫秒/次，含 node 启动；机器读数，只记录不设阈值）：

```
    open: 183 183 163 ms（3 次）
    fold: 158 155 155 ms（3 次）
```

### 2.6（任务书 ⑥）对抗证据见 §3。

### 2.7（任务书 ⑦）零回归门禁见 §7。

### 2.8（任务书 ⑧）报告归属

本文件；§1 表已写清「本包自证 / 引用」。原始证据都在 `docs/team/reports/P124-verify/pkg/logs/`（帧、pty 段、
门禁日志）与 `pkg/run.sh` 可复跑。

---

## 3. 对抗（Flip evidence：红 → 绿，两个红侧都是本包自造）

### 3.1 突变 M1（本包自造）：把 agent 放回卡片行 → 降级序断言必须红

在**临时 src 树**里给 `layout.ts` 的 `cardLine` 插回 `seg(card.agent)` 并用 bun 重建 mutant bundle
（`pkg/mut-agent-card.py`；提交的 `panel.js` 全程不动）。同一组 `card_check.py` 判据：

```
绿侧（提交 bundle）：0 红
$ （commit 的 panel.js）190 列 → │ › · LNG1 ZSTART甲乙丙丁戊己庚辛壬癸甲… │
红侧（M1 突变）：
  red-side  FIND  标题是整行最后一个字段   可见=[zagent ZSTART甲乙丙丁戊己庚]
  red-side  FIND  标题起始 ZSTART 被挤掉了
  red-side  FIND  标题是整行最后一个字段   可见=[zagen]        （120 列）
  red-side  FIND  标题起始 ZSTART 被挤掉了
  ok    M1 绿侧（提交 bundle）同一组降级序断言 0 红（= 0）
  ok    M1 红侧（突变）降级序断言变红：4 条
```

### 3.2 突变 M2（本包自造）：折叠分支失效 → 折叠车道仍建卡片行，计数断言必须红

```
  ok    M2 绿侧（提交 bundle）：折叠 done 后 0 条卡片行（= 0）
  ok    M2 红侧（突变）：折叠 done 后仍有 25 条卡片行 —— 计数断言必红
  info  M2 红侧帧行数=32（高度 32）
```

### 3.3 复跑作者 `panel-flip-p123.sh` 的两条（F-MACHINE / F-EMPTY）

```
$ BUN=~/.bun/bin/bun bash skills/teamsmith/tests/panel-flip-p123.sh F-MACHINE F-EMPTY
== F-MACHINE：机读帧读 panel.conf 的折叠键 ==
  ✓ F-MACHINE：提交的 bundle 上同一组检查绿
  ✓ F-MACHINE：突变之后变红（1 条； ✗ 机读帧读了面板 conf 的折叠键）
== F-EMPTY：空车道默认折叠关掉 ==
  ✓ F-EMPTY：提交的 bundle 上同一组检查绿
  ✓ F-EMPTY：突变之后变红（1 条； ✗ 空车道没有按默认折叠）
  ✓ 翻转全程没有碰提交的 panel.js（sha256 不变）
== 结果 ==  ✓ 5  ✗ 0
```

（作者其余四条未复跑：F-ORDER/F-CARDS 与我的 M1/M2 是同类突变；F-WIDTH 属宽度再分配，已由
§2.1 的阶梯与 §2.5 的折叠帧覆盖；F-PERSIST 的真 tmux 落地由 §2.2 的本包 pty 驱动覆盖同一承诺。）

---

## 4. 未验证 / 已知风险（明说）

- **未验**：真实用户终端的字体/CJK 宽度差异（沿 `width.ts` 既有口径）；真机上远大于 200 张的看板（夹具 200 张，
  有界帧机制由 §2.5 钉住）；`--print` 机读布局里窄车道 id 截断（`LNG…`）是**既有**形状，非本次改动。
- **没有发现 `panel-board-cards` 实现缺陷**；但独立全量 gate 在看板之外的旧设置视图 §38-f 红 2 条，
  其中一个已锁定为夹具缺陷，另一个仍需排查；这阻断了门禁全绿结论（§7）。
  `openspec/changes/panel-board-cards/` 仍未归档（本验证是归档前置，归档需 PM + 用户确认）。
- 我的验证包只写 `docs/team/reports/P124-verify.md` 与 `docs/team/reports/P124-verify/**`；`git diff main -- skills/` 为空。

## 5. 决定与偏差

- **执行偏差**：无（严格按任务书 8 条跑命令；全量虽可选，我判断需要并跑了，不能抹去失败）。
  另补了两项任务书未点名的 delta 检查：`agent → phase → 整对` 阶梯与空车道点击展开后粘住，均绿。
- **看板实现返工项 0；既有测试夹具返工项 ≥1**（§7）；≤70 列键位带自身截断、机读帧 id 截断为既有行为。

## 6. Suggested next steps

- **BLOCKED:** PM 将 `skills/teamsmith/tests/lib/pty-wait.sh` 的 `pipefail + grep -q` 假缺标记问题交给
  有实现路径授权的 agent 修复并加长帧红/绿守卫；同时排查 `panel-p21.sh settings` 在全量 §38-f
  出现的 `want_count` 为空 / 120×30 缩窗帧不完整（两者与内部红计数的逐项归属还不清楚）。
  **我没有跨授权目录改这些文件**。
- **BLOCKED:** PM 核对 `openspec/changes/panel-board-cards/tasks.md` 的 18 个 `[ ]`：已落地的项由有
  OpenSpec 路径授权的 owner 按证据标 `[x]`；`5.1` 要求「六条 flip 全复跑」但 P124 brief 只授权
  「自造两条 + 作者六选二」，这条范围冲突须由 PM 定性/补派，不能由我擅改 brief 或勾选。
- 修复/归因后 PM 在独立 worktree 复跑失败选段及全量门禁，再决定 P124 是否 PASS；未绿不得归档。
  用户确认后才由 PM 归档 `panel-board-cards`。

---

## 7. 零回归门禁：前四组绿，全量 **红 2**（阻断交付）

实际运行的是 `pkg/70-regression.sh`（后台作业 `p124-gates`，**已 harvest**，脚本本身 exit 0
仅表示收集结束；`finding=2` 不等于门禁通过）。所有门禁 stdin 为 `/dev/null`；smoke 自己管理隔离 socket，
**没有在 smoke 外额外包 tmux shim**；非 FAST 两次排共享 `/tmp/teamsmith-smoke.lock`。

| 命令 | 实际结果 | 证据 |
|---|---|---|
| `openspec validate --all --strict` | rc 0，14 passed / 0 failed | `pkg/logs/gates-openspec.log` |
| `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh` | rc 0，`✓3090 ✗0`（显式跳过 34 个真进程段） | `pkg/logs/gates-smoke-fast.log` |
| `bash skills/teamsmith/tests/smoke.sh --select 26,27,28` | rc 0，`✓370 ✗0`（真实面板段） | `pkg/logs/gates-smoke-panel.log` |
| `panel-snapshots.sh` / `panel-knobs.sh` / `panel-choices.sh` | rc 0，分别 `✓52/9/44 ✗0` | `pkg/logs/gates-panel-*.log` |
| `bash skills/teamsmith/tests/smoke.sh`（全量） | **rc 1，`✓3743 ✗2`，账本一致，§38-f 红** | `pkg/logs/gates-smoke-full.log` |

全量的红尾摘录（去 ANSI、裁剪超长路径；完整原始输出 `pkg/logs/gates-smoke-full.log:3656–3662,4213–4216`）：

```
  ✗ 38-f panel-p21.sh groups/settings/wheel 有失败
      ✗ 项目设置视图没有在预算内出现数据（marker=身份与账本布局）
      ✗ 缩到 120×30 之后没有画出完整的设置视图帧（-1 -1 -1 -1）
      ✗ 25 行：rows(13) + ↑(0) + ↓(102) = 命令报的键+席位（）（期望 []，实际 [115]）
      == 结果 ==  ✓ 89  ✗ 2  SKIP 0
  #97 38 · 设置选项 …… ✓21 ✗1 SKIP0
账本自查：113 段收口 · 增量 ✓3743 ✗2 SKIP2 ｜ 结果行 ✓3743 ✗2 —— 一致
== 结果 ==  ✓ 3743  ✗ 2
smoke 有失败项（--keep 保留现场）
```

**独立诊断（不改实现；真 tmux 仅在一次性容器里运行）**：

```bash
TEAM_TMUX_TIMEOUT=1200 bash skills/teamsmith/tests/container-tmux.sh -- \
  bash -c 'TEAM_P21_TRACE=1 TEAM_P21_KEEP=1 bash skills/teamsmith/tests/panel-p21.sh settings'
# pkg/logs/p21-settings-container.log：container rc=1；设置场景 ✓48 ✗5 SKIP0。
```

该容器跑法的失败数**不是**宿主全量的 2 条（不能混算），但同一个「设置视图缺 marker」能复现：
`wait 设置视图（marker=身份与账本布局） rounds=40 settled=0`，报「缺 marker、画面静止」，
紧接着夹具自己的 `cap_to view; assert_has view.txt 身份与账本布局` 却**通过**
（见该日志 7–30 行）；英文 marker 3 轮通过、中文长帧多次失败。源码路径：
`tests/lib/pty-wait.sh` 的 `_pty_has_all` / `_pty_report_missing` 用
`printf '%s\n' "$c" | grep -qF -- "$n"`，脚本启用 `set -uo pipefail`；长帧中 marker 在前面，
`grep -q` 提前关管道，写端 SIGPIPE 导致整条管道 rc 141，被当作**不存在**。
本包生成 120607 字节、marker 计数 1 的合成长帧做无 tmux 最小复现（`pkg/logs/pty-needle-pipefail.log`）：

```
frame bytes=120607 marker count=1
helper attempt 0 rc=1
helper attempt 1 rc=1
helper attempt 2 rc=1
helper attempt 3 rc=1
helper attempt 4 rc=1
helper attempt 5 rc=1
raw pipeline rc=141 (grep -qF hits marker, writer SIGPIPE)
here-string grep rc=0
```

这是**旧夹具的验证侧缺陷**，与本次看板实现无关；**没有**擅自改 `tests/lib/`（不在 grant 内）。
全量日志还出现 `120×30` 缩窗帧不完整、`25 行 want_count=空`；容器复跑的行数基准为 115 且
该段全绿，故**其余失败的归因未定**（smoke 只截取夹具若干 `✗` 行，不能将这些摘录强行逐项对应到
内部 `✗2` 的计数）。不能凭不同环境的重跑宣称「可忽略」，需要 PM 安排有授权的 agent 排查并让最终门禁绿。

**BLOCKED:** PM 派有 `skills/teamsmith/tests/lib/pty-wait.sh` 授权的 agent 修好管道判据并补长帧守卫，
核对 §38-f 的 `want_count`/缩窗红；再处理 §8 的未勾选任务账本/范围冲突；复验绿后才能解除 P124 的 PARTIAL。

---

## 8. OpenSpec 三维核对（补充：artifact 完备不等于 tasks 完成）

`PATH="$HOME/.bun/bin:$PATH" openspec status --change panel-board-cards --json` 报四种规划工件均为 `done`、
`isComplete=true`，**仅表示工件齐全**；`openspec instructions apply --change panel-board-cards --json` 的原始进度为：

```
"progress": { "total": 18, "complete": 0, "remaining": 18 }
```

| 维度 | 判定 | 具体证据 / 留口 |
|---|---|---|
| 完整性 | **CRITICAL：任务账本 0/18 勾选**（不等于实现 0/18） | `openspec/changes/panel-board-cards/tasks.md` 的 1.1–5.1 全部 `[ ]`；主分支有代码、§2–3 看板行为全绿，但账本没有记录完成。要先按证据勾选或明确未完成项，再考虑归档。 |
| 正确性 | 三项 delta requirement 的本 brief 核心行为有自写帧/pty/机器口/红侧证据；**全量门禁未绿** | `panel` ADDED 折叠、MODIFIED 看板卡片、MODIFIED 鼠标：分别对应 §2.2–2.5、§2.1、§2.2 点击与 26/27/28 选段；§7 旧 settings 夹具红阻断最终放行。 |
| 一致性 | 本次覆盖的设计 D1–D8 未见偏离；其余场景没有逐条独立重跑 | `design.md` §1–4 的一行卡、键栏降级、单行折叠、conf 落盘及机读隔离由 §2–3 覆盖；看板外部契约仍依赖既有 panel-* 与全量修复后的复验。 |

`tasks.md` §5.1 还写「独立验证重跑全部六条作者 flip」，而 P124 brief 明确「本包自造两条红侧、作者六选二」；
我按 brief 跑了作者 F-MACHINE/F-EMPTY + 自造 M1/M2（§3），**没有**把 §5.1 偷标为完成。
这是规范工件与本次任务范围的可见冲突，交回 PM；本任务 grant 不含 `openspec/**`，不能代替 owner 改账本。

---

## 9. 首轮实现未被触碰的证据（历史基线）

```
$ git diff main -- skills/          # 首轮 a517aa39：空（当时本分支与 main 同步）
$ git status --porcelain -- skills/ # 首轮收发两次都空（见 pkg/logs 各分节收尾行）
```

---

## 10. §5.1 最终 tip 复跑（P127 + P125 + P128 均已合并）

**对象及隔离**：从 main 建独立干净检出，固定 `b08af2c659e87457a82c59600bb0e2622a39c1d0`；它的 `git status --porcelain` 为空，`panel.js` sha256 为 `3f13427dd4e840a2b2c47638675801eed8a0c755b1550bb1b967d50063684712`（`final-logs/final-manifest.txt`）。我的任务分支尚未更新到这个源码 tip，以下测试没有误用旧工作树 bundle。临时克隆已删；原始日志和检查脚本在本报告目录内。真 tmux 场景只在 `container-tmux.sh` 的隔离容器里运行；原工作树的 `skills/**` 未修改。

### 10.1 六条翻转的红、绿两侧 + 新折叠形态翻转

`final-logs/flip-p123.log` 是在最终 tip 直接运行作者脚本五条的完整 stdout：`F-ORDER F-CARDS F-MACHINE F-EMPTY F-WIDTH`，**✓11 ✗0、rc=0**。各条均同一组断言对提交的 bundle 判绿、对临时重建的 mutant 判红，提交 bundle SHA 未变。额外用 `TEAM_TMP_KEEP=1` 对 F-ORDER/F-EMPTY 取回原始红侧文件（`final-logs/F-{ORDER,EMPTY}-red.{raw,plain}.log`）；这是因为原脚本的 `grep` 对 F-ORDER 的 Unicode 帧只输出 `binary file matches`，不能把那句当作可读的红侧断言。

| Flip | 绿侧（提交 bundle） | 红侧（突变 bundle 的原始判据摘录） |
|---|---|---|
| F-ORDER | `提交的 bundle 上同一组检查绿` | `✗ 卡片行仍带 agent/phase：│ › · V14 verify 独立复验…`（`F-ORDER-red.plain.log`） |
| F-CARDS | 同上 | `✗ 折叠的 done 仍建了卡片行或没有三列小框` |
| F-PERSIST | 真 pty/b3 **✓28 ✗0**、`重启后 todo 仍折叠（显式状态持久…）` | `✗ c 立即把 boardFold=todo 写进 panel.conf`、`✗ 重启后 todo 仍折叠（显式状态持久…）`（rc=1） |
| F-MACHINE | 同上 | `✗ 机读帧读了面板 conf 的折叠键` |
| F-EMPTY | 同上 | `✗ 空车道没有按默认折叠`（`F-EMPTY-red.plain.log`） |
| F-WIDTH | 同上 | `✗ 折叠没有让出宽度（wip 盒 23 → 23）` |

F-PERSIST 是与作者脚本**相同的 settings.ts 双键去除突变**，但把触 tmux 的 b3 真场景放到 M28 容器：本包新写 `pkg/final-persist.sh`，对同一最终 tip 的原始 bundle 和 mutant **分别**跑原版 `panel-b3.sh fold`；前者 `final-logs/pty-fold-green.log` **✓28 ✗0、rc=0**，后者 `final-logs/pty-fold-persist-red.plain.log` **rc=1、同时点名上述写入与重启两条红**。没有在宿主直接运行作者 F-PERSIST 脚本的 tmux 分支，也没改生产脚本；重建/证据/rc 在 `final-logs/persist-*` 与 `final-logs/pty-fold-*`。这六条覆盖 §5.1 原先未跑齐的六个方向；绿红均在最终 tip 上对照，不沿用旧 a517 结论。

新增形态的作者两条 P125 翻转 `F-INPLACE/F-FRAME99`：`final-logs/flip-p125.log` **✓5 ✗0、rc=0**，分别让宽档退回原地一行、窄档错误画三列框，原 bundle 绿、mutant 分别红 3/2 条；P128 窄档列对齐 `F-COLUMN`：`final-logs/flip-p128.log` **✓3 ✗0、rc=0**，去掉卡片列缩进导致 mutant 红 3 条。这三条是被引用的作者测试；额外独立判据见下节。

### 10.2 真 pty 与独立窄档列判据

真 pty `panel-b3.sh fold`（M28 容器、提交 bundle）自己按 `c` → 保存 `boardFold=todo` → 真进程重启折叠仍在 → 再按 `c` 显式展开 `boardShow=todo`；还逐条覆盖宽档三列小框、空车道默认/关闭、车道头点击、折叠车道滚轮不穿透、展开车道滚轮。**28/0**，原始 28 行和收口在 `final-logs/pty-fold-green.log`；这个结果是本次亲自运行的现成 b3 夹具（非自写驱动），§2.2 旧轮自写 pty 的事实仍只适用于旧 tip。

我另外用最终 tip 的 `panel.js --snapshot` 独立渲染 **99/60/59** 三档，原始帧 `final-logs/column-{99,60,59}-{open,fold}.{raw,txt}`，以本包自写 `pkg/final-column.py` 核对对应卡片行与折叠行：

```text
# final-logs/column-verdict.log：1-based 显示列；每一宽档同位置原始行
99:  › · V14 独立复验…  →  › ▸ 待办 1（已折叠）
60:  › · V14 独立复验…  →  › ▸ 待办 1（已折叠）
59:  › · V14    独立复验…  →  › ▸ 待办 1（已折叠）
ok width=99: glyph column=4 cursor column=2; fold card absent; rows=32/32; footer last
ok width=60: glyph column=4 cursor column=2; fold card absent; rows=32/32; footer last
ok width=59: glyph column=4 cursor column=2; fold card absent; rows=32/32; footer last
```

也就是说：窄档原地**一行**，marker 与被替代卡片的状态字形同列、光标同列，折叠后卡片消失，页脚仍最后一行；这是我的帧和判据，不拿作者 P128 自测代替独立证据。

### 10.3 全量门禁及历史阻断闭合

```text
openspec validate --all --strict: Totals: 14 passed, 0 failed（rc=0）
panel-snapshots.sh: ✓52 ✗0（rc=0）
全量 TEAM_SMOKE_FAST=0 bash skills/teamsmith/tests/smoke.sh: 114 段、✓3769 ✗0 SKIP7（rc=0）
§38-f panel-p21.sh groups/settings/wheel: ✓102 ✗0 SKIP0（旧轮的两条假红不再出现）
```

原始日志：`final-logs/openspec-final.log`、`snapshots.log`、`smoke-full-final.log`，对应 `.rc`；`smoke-full-final.meta` 点名最终 tip 与共享锁。门禁 stdin 接 `/dev/null`，`TEAM_SMOKE_LOCK=/tmp/teamsmith-smoke.lock` 排队；smoke 自己在**短 `TMPDIR=/tmp/p124-final-gate.XXXXXX` 下建私有 tmux socket**。此前曾把 `TMPDIR` 设在很深的报告目录里，socket 报 `File name too long`，该次仅为**无效夹具尝试**，已终止我自己创建的门禁进程组，留 `smoke-full-invalid-longpath.log` 供排查；它**没有 rc/结果行，也没有计为门禁结论**。之后短目录的正式全量完整跑到 114 段，结果如上。

首轮 §7 的 `✓3743 ✗2` 是 a517 当时真实发生的红，P127 修复后必须用新 tip 重跑；本节给出实际重跑绿证据而非追溯改写历史。首轮 §8 所见 `tasks.md 0/18` 也已由 PM 在 main 上补至本 tip 的 **12/18**（`final-logs/final-manifest.txt`）；余下六项勾选及试归档是 PM 的账和用户确认门槛，**不由本 verify 代理填写或归档**。本轮未见实现 finding；独立行为与全量门禁判定 PASS，但本报告**不是归档授权**。
