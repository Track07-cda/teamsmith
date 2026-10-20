# P326 · apply（behavior-focused-ci）：CI 判已交付的行为

status: DELIVERED（含 V70 后的定点返修）—— A/B/C/D 全部落地并有定点证据；C4 那次运行按 45 分钟预算被实际停止且**现场形状错了**（worktree 挂载），它的读数不作数；V70 之后按 PM 裁定只做差异（§7：11c 可靠匹配、探针一次 run 一条整体退出码、CI 入口有了真实承接者、文字勘误），本轮**没有**再跑容器/floor/probe/36 整段；第三次收口只做四件被点名的差异（11c 的判定/耗尽/前提、workflow-entry 的正向确认与吞错、退役无对象的旧豁免、注释搬正）
time: 2026-10-20
branch: `task/P326-behavior-focused-ci`（本仓 local 模式，分支留在本地，不推远端）
tip: `4068e287`（报告提交；实现 tip `295e966a`。此前先后是 `f14be42b`、`af58b620`，原始实现 `762cd654`）

## 结论（先给答案，再给过程）

PM 六条条件的逐条判定，每条后面是判它的命令或读数。

1. **墙钟上限（C4 ≤ 45 分钟）—— 未成立，机制按约定停手。** 容器 `029915307b75`（`modest_driscoll`，镜像
   `localhost/teamsmith-gate:local`）从 06:49:20Z 跑到 **07:34:18Z 被 `podman stop` 收口**，实际

   - 墙钟 **2699 s（44 分 59 秒）**，退出码 **143**（SIGTERM，不是「跑完」）；
   - 选中的 **133** 个段里完成 **96** 个（累计段内用时 2601 s），账本合计 `✓3839 ✗6 SKIP15`；
   - 未跑完的 37 个段里有重段；按已完成段的均值线性外推，整批在这台机器上约 **62 分钟**（133/96 × 2699 s）；
   - 单段成本极不均衡：**§11c 单段 1018 s（占 39%）**，§33 157 s，§12b-h0c 86 s，§12b-pi 84 s，§26 83 s，
     其余 91 个段合计 1273 s。
   - 选中的 133 = 地板 128 段去掉 `0g`（它的 patterns 只声明 `tests/lib/section-guard.sh`，本批路径没点到它）
     **加上**被路径点到的 `0e 0f 0h 0i 36`；完全没选的 2 个是 **`0g` 与 `61b`**。
   - 这 12 条红的归因分成三桶写在 §C4：**行为失败 1 条**（§0d 找不到 git 树，因为 `/work` 是 worktree 指针、容器里
     gitdir 不在挂载面上）+ **11 条「嵌套 run 期望 rc=0」的下游断言** + **未完成 37 段**；没有第二条独立病因。

   按条件原文（「C4 超过 45 分钟 → 机制停手」），结论是**停手**：这不是一个「再跑久一点就好」的读数，而是
   「地板在普通推送上不便宜」的事实 —— 45 分钟预算在这台机器上连**今天就在跑的全套**都放不下（§61b 单段
   CI 记 4946 s），地板本身没比全套更贵，但也没有便宜到 45 分钟以内。要不要缩小地板（把 `11c`、`33` 这类重段
   明确声明成自检/里程碑段）、还是把预算改回「按 `--paths` 只跑改动 + 少量地板」，是 **PM 的裁定**，不是这一行
   能自己决定的（见 §未观测边界/待裁定）。

2. **反向判据（每个 self-check 键自选 + 删键回地板 + 三种腐烂红）—— 做到。** 七个声明的键各自用它自己的
   patterns 造一次路径输入，七次都把该段选回来；从声明行删掉 `61b`、删掉 `0e`，那一段各自回到地板；不存在的 key /
   重复 key / 点名前导段三种腐烂都被 `--check` 判红并点名（§A、E3–E5 的原始输出）。

3. **缺行与空行 —— 做到。** 整行删掉 → 地板 = 全部 135 段（安全方向）；行在但为空 → `--floor` 拒绝（rc=2）并点名
   「行在但没点名任何段」，`--check` 同时判红；每个段都被点名 → 同样拒绝并点名「没有产品基线段」。**「行在但为空 →
   只跑前导段」这条静默变窄不存在**（§A、E6）。

4. **守卫净零 —— 做到。** 没有新增检查器 / 预算表 / 调度器 / 第二个非阻塞步：`--check` ⑧ 是表头声明的**静态**牙
   （替掉「哪几段算自检」过去靠人记），`--floor` 复用既有的 `--paths` 代码路径（`claim_paths` 从 `do_paths` 提出，
   两个模式共用一份实现），`perf.sh` 仍只有 `exit 0/3` 且只出参考读数。探针的嵌套 run **29 → 24**（合并 5 处
   同树同状态的调用），断言调用点两侧都是 **185**（一条没删，运行期多一条新增的 §19 收口行断言）。

5. **不改断言 —— 做到。** `smoke.sh` 的披露行（`decision=` / 运行与未跑的段数 / 未跑清单 / `== 选段结果 ==` /
   不打印「smoke 全绿」）一行没动，C4 的尾部就是这套披露原文；`needs` 的反例对证明红只来自真实破坏：把 §17 的
   `needs` 里的 `15b` 去掉，§17 当场死在 `M51_AGENT: unbound variable`（15b 建的假项目树不在）。

6. **`--floor` 与 `--select` 互斥 / 空地板 `die` / `--paths` 语义逐字不变 —— 做到。** `--floor --select 58` →
   `--select 与 --floor 不同用`，rc=2；空地板 rc=2 并点名；`--paths` 单独用仍是 `NONE`/`RUN`/`FULL` 三态。

   **更正（C4 收口后核对发现）**：§36 在 C4 里**没有被跑到**（它在 37 个未完成段里，见 §C4 桶 3），所以我不能拿 C4
   说它绿。它的证据只有两处：(a) 宿主上 `--select 36` 的定点运行（`✓119 ✗1 SKIP3`，那 1 条红是既有 §58 lint 红，
   见 B1）；(b) 纯逻辑的 E3/E7（`--paths` 三态、`--floor` 的并集与闭包）。

### V70 后的定点返修改变了什么（详见 §7）

- **11c 的 1018 s → 13 s**：轮询不再把 CLI 输出接给 `grep -q`（`pipefail` 下 SIGPIPE 能让命中被判成没命中），
  改成整份输出落变量 + bash 自己匹配；界没变、15 条产品断言没动、这条续跑行为仍在地板里。
- **一次真实 nest run 只留一条整体退出码断言**（同一 `$?` 不再冒充三段结果）；断言调用点 185 → 182。
- **CI 入口有了承接者**：`tests/workflow-entry.sh` 执行工作流自己的 `run:` 块，验三条已成立过的行为；
  §36 的 36⑨ 调它，`gates.yml` 与它一起映射到 §36 —— `--paths .github/workflows/gates.yml` 从 `FULL` 变成 `RUN`。
  未知路径/无有效基点的 `FULL` 兜底一字未改，`.github/**` 没有豁免。
- **文字勘误**：SKILL.md 最后一句 performance red lines、delta 的 Migration（四条 premise 场景 + 点名承接者）。

### 两件 PM 必须知道的事（不是本 change 造成的）

**B1. `smoke.sh --select 36` 在本树与基线提交上一样红（既有红，与 A/B/C/D 无关）。**
`skills/teamsmith/tests/signal-gate.sh` 第 410/411 行把 `kill $(pgrep -f "$1")` / `kill $(pidof sleep)` 当**夹具文本**
写着（P321 的 `ef5f374c` 引入），而 `signal-lint.pl` 的规则正是「`kill` 的参数里有命令替换 → 红」，并且明确拒绝给
`tests/**` 开豁免。于是 §58 的「lint 真树」从 P321 落地起就红，进而 §36 里所有读「`--select 58` 退出 0」的断言跟着红。
`signal-gate.sh` 在任务书的「不许碰」清单里（P318 第 1 轮正在改），所以本任务只报告不动手：

```
BLOCKED: skills/teamsmith/tests/signal-gate.sh:410/411 —— 那两行夹具文本要么改成 pid 形态
（`kill $(cat /tmp/recorded.pid)` 之类的记录型写法），要么由 signal-lint 给出可审计的「夹具文本」判据；
P318（或 P321 的后续）改它，本任务不碰。连带效果：§36 的定点运行在本树上不可能全绿。
```

**B2. C4 的 12 条红是**在容器里挂载一棵 git worktree**的工件，不是产品红。** 我把 `$REPO` 挂成 `/work:ro`，而
worktree 的 `/work/.git` 是一个指针文件（`gitdir: $HOME/…/.git/worktrees/dev`），容器里看不到那个目录：

```
$ podman exec 029915307b75 bash -c 'ls -l /work/.git; head -1 /work/.git; git -C /work rev-parse --show-toplevel'
-rw-rw-r-- 1 <user> <user> 85 /work/.git
gitdir: $HOME/Documents/.../pm-skills/.git/worktrees/dev
fatal: not a git repository: $HOME/Documents/.../pm-skills/.git/worktrees/dev
```

后果是「需要真 git 工作树」与「嵌套跑一次门禁」的段失败：`0d`（冲突标记守卫，段内自己报「找不到受检的 git 工作树」）
1 条、`0i` 3 条、`34c` 2 条、`34d` 6 条 —— 前 6 条进了账本（`✗6`），后 6 条来自收口时正在跑的 `34d`，没来得及
打出它自己的账本行。**这不是 C4 的目的**（C4 测的是地板要跑多久、披露长什么样），把它当产品红
会误导复验；要在真容器里跑这类段，检出必须是**真克隆**而不是 worktree（发布清单 §1 就是这么做的）。本轮没有为此追加
运行（PM 07:30Z 的指令：不延长、不重跑）。

## 改动面（七个实现提交 + 本报告）

```
  762cd654 docs(release): P326 name the existing release-record file
  77babbc5 test(gate): P326 scope the merged run's assertions to their own section's lines
  7068e8ee docs(openspec): P326 tick the applied tasks of behavior-focused-ci
  e3838052 ci(gates): P326 run the product floor plus the push's changed paths
  3a1be4d4 docs(skill): P326 stop describing the retired performance red lines
  75446a97 test(gate): P326 merge same-tree probe runs and drop 58's stale closure
  7f1e2361 feat(gate): P326 declare the gate self-checks and answer floor ∪ changed paths

```

## A · 声明行、地板与 `--check` 的牙（纯逻辑，不跑套件）

```
=== E1 --check（真树） ===
ok: 映射表 key 唯一（135 行）
ok: 段 ↔ 行一一对应（源码 135 段 / 表 135 行）
ok: needs 声明全部存在且指向更早的段（107 条）
SKIP（条件不满足）: 行 19 的字面模式在检出里不存在（检出形状 internal，机器生成面（工具在本机生成、不进仓库））：.pi/skills
ok: 字面模式（640 条）里 639 条在位；1 条检出前提按缺失跳过（跳过不等于检查过）
ok: 豁免类（docs/*）没有任何行声明
ok: 前导段声明有效（0 0b 0c 0d）
ok: 段正文点名的真实路径 token 都被各自的行覆盖（528 个 token 检查过；0 个豁免类 token 不参与）
ok: 账本归属（ledger-scan 60）声明有效：9/9 个账本样例被它覆盖
ok: gate-self-check 行有效（7 个 key：各自命中一行、无重复、不含前导段）
== 选段自检 ==  ok 9  bad 0  SKIP 1
rc=0

=== E2 --floor 的 key 集合 = 全部段 − 声明行点名的段 ===
all=135  self=7  floor=128
61b 不在地板里（被声明，正确）
地板里缺少的未声明段：[]（应为空）

=== E3 声明行每个 key：用它自己的 patterns 造路径输入 → 必须把该段选回来 ===
0e   ok   ← --paths skills/teamsmith/tests/smoke.sh
0f   ok   ← --paths skills/teamsmith/tests/smoke.sh
0g   ok   ← --paths skills/teamsmith/tests/lib/section-guard.sh
0h   ok   ← --paths skills/teamsmith/tests/smoke.sh
0i   ok   ← --paths skills/teamsmith/tests/smoke.sh
36   ok   ← --paths skills/teamsmith/tests/smoke.sh
61b  ok   ← --paths skills/teamsmith/tests/task-model-routing.sh

=== E4 从声明行删一个 key → 那一段回到地板（61b 与 0e 各试一次） ===
删掉 61b  → 它回到地板
  该副本 --check rc=0（0 = 删一个 key 本身不是腐烂）
删掉 0e   → 它回到地板
  该副本 --check rc=0（0 = 删一个 key 本身不是腐烂）

=== E5 --check 三种腐烂：不存在的 key / 重复 key / 点名前导段 ===
[unknown] rc=1
bad: gate-self-check 行点名了不存在的段：no-such-seg（拼错/陈旧的 key 会静静地换掉普通入口）
[dup] rc=1
bad: gate-self-check 行重复点名：36
[prologue] rc=1
bad: gate-self-check 行点名了前导段：0b（前导段永远跑，不是可声明的自检段）

=== E6 空行/空地板/整行删除 ===
[empty-line] --floor rc=2：section-select: --floor：空地板 —— gate-self-check 行（/var/tmp/p326-pure.vZXjYC/empty-line.tsv:17）在但没点名任何段；空行不许退化成「只跑前导段」
[all-named] --floor rc=2：section-select: --floor：空地板 —— 135 个段全被 gate-self-check 行点名，没有产品基线段可跑
[no-line] --floor keys=135（应为 135 = 每个段都在地板里）
[empty-line] --check rc=1：bad: gate-self-check 行在但没有点名任何段（空声明，/var/tmp/p326-pure.vZXjYC/empty-line.tsv:17）—— --floor 会拒绝空地板
== 选段自检 ==  ok 8  bad 1  SKIP 1

=== E7 --floor 的定点回答 ===
0 0b 0c 0d 34b 34c 34d 36 ← 含 36 与其 needs 闭包
61 61b ← 含 61b（它的源被改）与 61（产品前门）
decision=FULL
section-select: --select 与 --floor 不同用
rc=2
decision=RUN
sections=135
keys=5
decision=RUN
sections=135
keys=128

```

## 路径形状：换行 / 双引号+反斜杠 / 空格（`git diff -z` → bash 数组 → 既有 `--paths`）

```
=== E8 路径形状（含换行 / 双引号+反斜杠 / 空格）：git diff -z → 数组 → 选择器 ===
数组元素数=3（应为 3）
  [1] bytes:  s k i l l s / t e a m s m i t h  / t e s t s / p 3 2 6 l i n e  b r e a k \n s e c o n d . s h 
  [2] bytes:  s k i l l s / t e a m s m i t h  / t e s t s / p 3 2 6 s p a c  e n a m e . s h 
  [3] bytes:  s k i l l s / t e a m s m i t h  / t e s t s / p 3 2 6 - q u o t  e " a n d \ b a c k s l a s h .  s h 
decision=RUN
  ok   选段答案里逐字节出现 b'skills/teamsmith/tests/p326 line break\nsecond.sh'
  ok   选段答案里逐字节出现 b'skills/teamsmith/tests/p326 space name.sh'
  ok   选段答案里逐字节出现 b'skills/teamsmith/tests/p326-quote"and\\backslash.sh'
逐字节不等数=0（应为 0）
byte-exact rc=0
逐行读法拿到 3 个条目（NUL 数组是 3）；但字节变了（C 转义 + 引号）：
  第 1 条："skills/teamsmith/tests/p326 line break\nsecond.sh"
decision=FULL
（期望 FULL：逐行读法拿到的不是树里真实存在的字节串 —— 行数没少，字节错了）
选中这些路径的 key（--floor 下应含 40 = 整棵 tests 树的声明行）：
0 0b 0c 0d 18 40 

```

对照（逐行读的写法）：同一批路径改用 `git diff --name-only` 的默认列表逐行读，第一条拿到的是
`"skills/teamsmith/tests/p326 line break\nsecond.sh"`（带引号、`\n` 是两个**字面**字符），选择器对它答 `decision=FULL`。
行数没少、字节错了 —— 这就是整链只走 NUL 分隔 + 数组 + 既有参数接口的理由。

## B · 工作流：宿主侧 NUL 链 → 容器命令参数（docker 用桩，逐字节核对 argv）

```
=== E10 工作流的 run 块（宿主侧 NUL 链 → 容器命令参数）：docker 用桩记录 argv ===
--- 抽取的 run 块行数：43 ---
changed paths: 3 (NUL-separated; passed as the suite's own arguments)
  $'skills/teamsmith/tests/p326 line break\nsecond.sh'
  skills/teamsmith/tests/p326\ space\ name.sh
  skills/teamsmith/tests/p326-quote\"and\\backslash.sh
STUB docker 22 args
run 块 rc=0
::warning::changed-path base is unresolvable (base=<none>) — running the full suite
STUB docker 18 args
无基点 run 块 rc=0
有基点：docker 参数个数 = 22 （argv[0] = run ）
  image = teamsmith-gates:ci
  容器命令里有 --floor = True ；有 --paths "$@" = True
  套件参数（git diff -z → 数组 → argv，逐字节）：
    b'skills/teamsmith/tests/p326 line break\nsecond.sh'
    b'skills/teamsmith/tests/p326 space name.sh'
    b'skills/teamsmith/tests/p326-quote"and\\backslash.sh'
无基点：docker 参数个数 = 18
  容器命令 = bash skills/teamsmith/tests/smoke.sh --keep </dev/null
  命令里没有 --floor（退回全套）= True
```

## C1 · `needs` 的反例对（同一棵树上只改表里那一行）

```

=== C1-0 真树：58 行已经是 needs=- ===
needs=[-]
decision=RUN
sections=135
keys=5
== 选段自检 ==  ok 9  bad 0  SKIP 1

=== C1-A 无闭包（真树）：smoke.sh --select 58 ===
rc=1 墙钟=22s
58 的收口行： ✓12 ✗1 SKIP1 

=== C1-A' 对照树（row 58 needs=13c，闭包在）：同一份套件、同一份 FAST 设置 ===
副本 needs=[13c]
decision=RUN
sections=135
keys=13
rc=1 墙钟=73s
58 的收口行： ✓12 ✗1 SKIP1 
两次收口行逐字相同：yes；退出码相同：yes
闭包多跑的段数：运行 5/135 段 vs 运行 13/135 段

=== C1-B 反例（needs 机制本身有牙）：§17 去掉 15b → 红；加回 → 绿 ===
带 15b：rc=0 · #9 15b · 必需依赖：doctor 三态 + paths + dispatch 预检 · 参考 用时 19s · ✓25 ✗0 SKIP0 · ticks 25 #10 17 · 迁移指南与 doctor 指引（M7.1） · 参考 用时 21s · ✓32 ✗0 SKIP0 · ticks 32 
副本 17 needs=[-]
decision=RUN
sections=135
keys=5
去掉 15b：rc=1
✗ 行数：4
#1 0 · 临时仓库 · 参考 用时 0s · ✓3 ✗0 SKIP0 · ticks 3
#2 0b · skill 可被 pi 解析器加载 · 参考 用时 0s · ✓2 ✗0 SKIP0 · ticks 2
#3 0c · 静态检查（函数结尾的 set -e 陷阱） · 参考 用时 1s · ✓9 ✗0 SKIP0 · ticks 9
#4 0d · 冲突标记守卫（受版本控制的文件里不许有冲突标记） · 参考 用时 0s · ✓9 ✗0 SKIP0 · ticks 9
--- 去掉 15b 的尾部 ---

== #5 17 · 迁移指南与 doctor 指引（M7.1） == 2026-10-20T06:03:43+00:00
/var/tmp/p326-c1.N9vhgX/tmp/teamsmith-select.cx-8c0fb36a.2678689.sh: line 1680: M51_AGENT: unbound variable
  · 临时根（结束）：/var/tmp/p326-c1.N9vhgX/tmp/teamsmith-smoke-cx-8c0fb36a.0vbixn（520 KB · 196 文件 · source=tmpdir）

== 选段：这次没跑的段 == 130 个键
0e 0f 0g 0h 0i 1 1b 1c 2 3 4 4b 4c 5 3b 6 6b 6c 6d 6e 6f 6g 6h 6i 6j 6k 7 7b 8 9 10 10b 10c 11 11b 11b2 11b3 11b4 11c 11d 11e 11e2 11f 11g 11h 11i 11j 14b 15b 15c 12 13 13b 13c 12b 12b-h0 12b-h0b 12b-h0d 12b-h0c 12b-pi 12b-pi2 12b-pi3 14 14c 54 14d 18 18b 18c 19 20 21 22 23 24 25 26 27 28 29 30 31 31c 32 33 12e 12f 12g 12h 12i 12j 12k 34 34b 34c 34d 35 36 37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 51b 51c 52 53 57 58 15 55 56 59 60 61 61b 62 63 64 65
  选段运行不是全套门禁（交付 / 复验 / 归档仍跑整套）；引用它的报告必须点名没跑的段


```

**读法**：无闭包 20 s / keys=5 / `✓12 ✗1 SKIP1`；带闭包 72 s / keys=13 / `✓12 ✗1 SKIP1` —— 收口行与退出码逐字相同，
闭包对 §58 的判定没有任何贡献（省下 52 s 与 8 个段）。那条 ✗ 是既有红（见 B1）。

## C1-S1 · 既有红的来源（两侧同一份 lint）

```
=== signal-lint 本树（真树）
  RED  skills/teamsmith/tests/signal-gate.sh:410  kill @CMD@
  RED  skills/teamsmith/tests/signal-gate.sh:411  kill @CMD@
signal-lint：2 条按名字/谓词选进程的调用（扫描 121 个脚本；历史豁免另算 0 条）
rc=0

=== signal-lint 基线 4eabb0f5（独立克隆）
  RED  skills/teamsmith/tests/signal-gate.sh:410  kill @CMD@
  RED  skills/teamsmith/tests/signal-gate.sh:411  kill @CMD@
signal-lint：2 条按名字/谓词选进程的调用（扫描 121 个脚本；历史豁免另算 0 条）

```

## C2/C3 · 合并后的探针：base / mine 同脚本对照

同一份 `checkout-shape-probe.sh`（各自树里那份）、同一组 FAST 环境、各跑一次，逐条 `bad:` 比对：

```
=== 两边 bad 行的集合差（mine 独有 / base 独有）===
--- 只在 mine 出现（= 我的改动引入的红）---
bad: ⑩ 内部树 + 清单文件都在 → --select 31,58 退出 0（§58 那一条）
bad: ⑩ 影子：放宽成「任何缺失即跳过」后 §58 仍红（/var/tmp/p326-probe.KfKTHq/tmp-mine/.teamsmith-p148-shape-probe.3588496/nest-teeth10-shadow.log）—— 红的原因可能不是逐条判据
bad: ⑤b 混合形状 --select 19,31,58 退出 0（§19 那一条）
bad: ⑤b 混合形状 --select 31,58 退出 0（§31 那一条）
bad: ⑤b 混合形状 --select 31,58 退出 0（§58 那一条）
bad: ⑨ 内部树 + 清单文件都在 → --select 31,58 退出 0（照旧判定）
--- 只在 base 出现（= 我的改动消掉的红）---
bad: ⑩ 内部树 + 清单文件都在 → --select 58 退出 0（照旧判定）
bad: ⑩ 影子：放宽成「任何缺失即跳过」后 §58 仍红（/var/tmp/p326-probe.KfKTHq/tmp-base/.teamsmith-p148-shape-probe.2371407/nest-teeth10-shadow.log）—— 红的原因可能不是逐条判据
bad: ⑤b 混合形状 --select 58 退出 0
--- 两边都有（= 既有红）---
bad: ⑩ 产品面：lint 照跑（不是把 58 整条记成跳过）（[
bad: ⑩ 产品面：--select 58 的红数为 0
bad: ⑩ 产品面树 --select 58 退出 0（豁免清单不再假红）
bad: ⑩ 内部树 + 清单文件都在 → signal-lint 照旧逐条核对（LEGACY 打印）（[
bad: ⑤b 混合形状：signal-lint 判定照旧执行（[
=== mine 现场里的 §58 lint 日志（既有红的来源）===
--- nest-hy-19-31-58.log 的 ✗/SKIP 行 ---
  SKIP（条件不满足） 58 lint 真树：仓库脚本/夹具没有按名字或模式选进程（豁免清单） —— 检出形状 internal：豁免清单注册的路径逐条不在（冻结的证据层） docs/team/reports/*/pkg/** 在检出里不存在（跳过不是通过）
  ✗ 58 lint 真树判红（见 /var/tmp/p326-probe.KfKTHq/tmp-mine/.teamsmith-p148-shape-probe.3588496/nest-tmp/teamsmith-smoke-hy-bea811e0.y6VN9A/p159-lint.log）
  ✓ 58 lint --selftest：双向夹具全部符合预期
--- nest-po10.log 的 ✗/SKIP 行 ---
  SKIP（条件不满足） 58 lint 真树：仓库脚本/夹具没有按名字或模式选进程（豁免清单） —— 检出形状 product-only：豁免清单注册的路径逐条不在（冻结的证据层） docs/team/reports/*/pkg/** 在检出里不存在（跳过不是通过）
  ✗ 58 lint 真树判红（见 /var/tmp/p326-probe.KfKTHq/tmp-mine/.teamsmith-p148-shape-probe.3588496/nest-tmp/teamsmith-smoke-po10-7e2be115.wDPGmL/p159-lint.log）
  ✓ 58 lint --selftest：双向夹具全部符合预期
--- 58 段自己打的 RED 明细（若有）---
  ✓ 58：signal-lint 豁免清单存在
        RED  skills/teamsmith/tests/signal-gate.sh:410  kill @CMD@
        RED  skills/teamsmith/tests/signal-gate.sh:411  kill @CMD@
=== done ===

```

**读法**：base 8 红 / mine 11 红，红的原因**只有一个**——B1 的 §58 lint 红。两侧**共同**的 5 条是读 §58 判定的断言。
mine 侧「只在 mine 出现」的 6 条里，**5 条是合并 run 的退出码断言**（`⑤b --select 19,31,58（§19 那一条）`、
`⑤b --select 31,58（§31 / §58 各一条）`、`⑨ --select 31,58 退出 0`、`⑩ --select 31,58（§58 那一条）`）：§58 的既有红
就在这一次 run 里，于是读这个 rc 的每条都跟着红 —— 这正是任务书 3.3 规定的「退出码换成这一次 run 的退出码」；base
侧对应的那几条本来也是同一原因红，只是名字还写着单段选（`--select 58`）。第 6 条 `⑩ 影子：… §58 仍红` 两侧都在
（`comm` 只因断言文案里带了各自 run-dir 的路径而算成两条）：它要证「放宽跳过判据后 §58 仍然红」，而 §58 现在因这条
无关的红**总是**红，影子因此失去信息 —— 既有红的第二个受害者，不是合并带来的。

**行级断言没有任何一条因为合并变红**：`⑤b 混合形状：产品文件里的裸 tmux 调用照旧判红并点名`、`pkill -f 照旧判红
并点名 file:line`、`⑤b --select 19：十条断言变成前提 SKIP`（计数口径修好后 10/10）、`⑤c 十条相位前提全部照旧判定`、
`⑨ 空内部目录：§18 照旧红并点名 SCOPE.md` 两侧都是 ✓。断言调用点 185 = 185，嵌套 run 29 → 24。

## C4 · 钉死镜像里的整体运行（到点收口，未跑完）—— 三桶归因

原始读数（容器 `029915307b75`，`localhost/teamsmith-gate:local`，挂载 `$REPO:/work:ro`）：

```
tip=762cd654 status=0 行
start=2026-10-20T06:49:20+00:00 loadavg=11.75 12.84 14.12 cores=32
end=2026-10-20T07:34:19+00:00
C4 rc=143 墙钟=2699s（07:34:18Z 用 `podman stop --time 10` 收口；不是跑完）
披露：== 选段 == decision=RUN · 运行 133/135 段 · 未跑 2 段
完成 96/133 段，累计段内用时 2601s，账本合计 ✓3839 ✗6 SKIP15
```

用时前 12（其余 91 段合计 1273 s）：

```
1018s  11c    ✓15 ✗0 SKIP0      ← §C4-2 单独拆读
 157s  33     ✓1  ✗0 SKIP0
  86s  12b-h0c ✓113 ✗0 SKIP2
  84s  12b-pi ✓103 ✗0 SKIP0
  83s  26     ✓143 ✗0 SKIP0
  67s  34     ✓36  ✗0 SKIP0
  56s  34c    ✓24  ✗2 SKIP0
  51s  0e     ✓22  ✗0 SKIP0
  44s  28     ✓166 ✗0 SKIP0
  39s  11b    ✓57  ✗0 SKIP0
  37s  12b    ✓87  ✗0 SKIP0
  34s  6h     ✓51  ✗0 SKIP0
```

### 桶 1 · 行为失败：**只有一条**，而且它是挂载形状，不是产品行为

**§0d 冲突标记守卫：`✗ 找不到受检的 git 工作树（/work/skills/teamsmith 不在仓库里？TEAM_SMOKE_MARKER_ROOT=<root>
可显式指定）`**。三条互相独立的证据：

1. `.git` 是 worktree 指针，不是目录：`$REPO/.git` → `gitdir: $HOME/Documents/.../pm-skills/.git/worktrees/dev`；
2. 容器里那个 gitdir 不在挂载面上，所以 `podman exec … git -C /work rev-parse --show-toplevel` 直接
   `fatal: not a git repository: $HOME/Documents/.../pm-skills/.git/worktrees/dev`；
3. §0d 自己的红行就是它找不到工作树的那句话（上面）。

**其余 11 条红都是「期望某个嵌套 run 退出码 = 0」的下游断言**，逐条按场景里的嵌套日志归因（不是一概推给一个根）：

| 红行数 | 段 | 静态归因（证据文件在 `$HOME/.cache/p326-c4/tmp/teamsmith-smoke-work-*/`） |
|---|---|---|
| 1 | `0d` | 直接：容器里 `/work` 不是 git 仓库（证据 1–3） |
| 3 | `0i`（P310 socket 翻转夹具） | 它的 leg green 是「嵌套跑一次 `--select`（探针 4 段，前导含 §0d）→ 期望 rc=0」，实际 rc=1；`teamsmith-flip-p310sock-work-*​/green.log` 的 `== 选段结果 == ✓ 22 ✗ 1` 里那唯一一条 ✗ 就是 §0d。leg red 反而按预期工作（rc=2，点名 121 字节 > 107） |
| 2 | `34c` | `p287c_run` 嵌套跑 `smoke.sh --select 0b,0c`（前导含 §0d）→ rc=1，于是「嵌套运行正常跑完」红；红侧判据要求 `rc=0 且 平铺命中`，命中有（`teamsmith-smoke.NseXhR`）但 rc 那半塌了 → 「红侧没兑现（夹具失效）」 |
| 6 | `34d` ①②③④ | `clean-1/clean-2/pub/del-shadow/swap-shadow-rm/swap-shadow-mv/entry-shadow` 七个嵌套日志，每一个的 `== 选段结果 ==` 都只有一条 ✗，全是 §0d；于是它们「期望 rc=0」的 6 条断言全部塌 |

证据（场景目录里命中同一句红行的日志，共 11 个）：

```
p70-check/smoke.sh  p70-gg/smoke.sh  m73-install-copy/teamsmith/tests/smoke.sh  m98-skill/tests/smoke.sh
p287-id/del-shadow.log  p287-id/swap-shadow-rm.log  p287-id/swap-shadow-mv.log  p287-id/entry-shadow.log
p287-id/clean-1.log  p287-id/clean-2.log  p287-id/pub.log
```

**结论**：12 行红 = **1 个行为**（§0d 找不到 git 树）+ **11 条「嵌套 run 期望 rc=0」的下游断言**；整批里没有第二条
独立病因，也没有一条来自 A/B/C/D 的改动。**未观测**：真克隆形状下 §0d 是否绿，本轮没有实测（PM 已指定留到修复批次），
所以那句「容器形状不等于 CI 的 git clone，换真克隆这些红会消失」是**推断**，不是实测。

### 桶 2 · 其它红：**0 条**

我按 PM 的要求逐条看了，不是一概归因：上面 12 条全部落到桶 1 的同一条因果链上，没有剩下的。另外要点名一个**容易混**的
地方：本树宿主上的 §36 红来自 **§58 的既有 lint 红**（B1），而 C4 里 §58 **根本没被跑到**（桶 3），所以两个红不是同一个
来源 —— C4 的 12 条里没有一条是 §58。

### 桶 3 · 未完成（不是失败）

- 选中 **133** 段：完成 **96**，**未完成 37 段** —— 收口那一刻正在跑 `34d`，其余 36 段没开始：
  `14c 14d 15 34d 35 36 37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 51b 51c 52 53 54 55 56 57 58 59 60 61 62 63 64 65`
- 完全没被选中的 2 段：`0g`（它的 patterns 只声明 `tests/lib/section-guard.sh`，本批路径没点到）与 `61b`
  （patterns 只声明 `task-model-routing.sh`）。
- 因此 **§36 / §58 / §61 / §61b 在本轮都没有被测量**；「地板的总时长」只能按已完成段外推（≈62 分钟），**不是实测值**，
  报告里凡是用到这个数的地方都写着「外推」。

### §C4-2 · `11c` 的 1018 s：静态拆读（不重跑）

源码 `skills/teamsmith/tests/smoke.sh:6360` 起的 `section "11c · agent 续跑是 PM 的事（pulse 不碰）"`，它做的第一件事是
`$TEAM dispatch dev T1.1 …` 造出「有任务但 pi 已退出」的状态，然后**一行有界轮询**等 roster 认出来：

（`smoke.sh:6371–6373`）

```bash
R_WAIT=0; R_T0="$(date +%s)"
while [ "$R_WAIT" -lt 1500 ] && ! $TEAM roster 2>/dev/null | grep -qF "pi 已退出"; do sleep 0.2; R_WAIT=$((R_WAIT + 1)); done
```

**昂贵的就是这一行**，两个因素相乘：

- **界是 1500 次**，每次 = 一个完整的 `team roster` 子进程（读 config、问 git、扫 `state/*.env`、`tmux list-windows`）
  **加上** `sleep 0.2`；只算 sleep 就是 300 s，注释里那句「最多 5s」是陈旧文案（1500 × 0.2 本来就不是 5 s）。
- 实测这一次**耗尽了整圈**：日志原文 `现场（有界轮询 986s 内 roster 没看到「pi 已退出」）：窗口=[keep,keep,keep,keep,pm,…dev,] pane=[bash]`
  → 986 s ÷ 1500 次 ≈ **0.66 s/次**（0.2 s sleep + ≈0.46 s 的一次 roster）。1018 s 里 **986 s（97 %）** 就在这一行，
  其余约 32 s 是本段别的动作（`wait_window_gone dev 300`（`smoke.sh:6385`，上限 300 s）、`team watch --once`、`team resume`（要重派单并起假 pi）、
  两次 `tmux kill-window`、以及 15 条断言）。
- **这 986 s 一条判据也没换来**：断言读的是循环**之后**单独的一次 `$TEAM roster >"$TMP/roster-dead.log"`（`smoke.sh:6378`，`assert_has
  roster-dead.log "pi 已退出"`）；循环自己的结果只被用来打印上面那行「现场」。所以它是**纯等待**，而且等的那件事是
  下一个单次调用就能拿到的。
- **这里只报测量，不报结论（PM 2026-10-20T07:40:36Z 已把机制交独立席位静态核）**：一条能解释「1500 次都不命中、
  紧接着的单次调用却通过」的**假说**是 —— 套件顶层是 `set -uo pipefail`（`smoke.sh:16`），这条 pipeline 里
  `grep -qF` 一命中就退出、`team roster` 因此吃到 SIGPIPE，`pipefail` 于是把整条 pipeline 判成非 0，`!` 又把它翻回
  真 → 循环**在有字符串时也可能永远不命中**；循环之后那次 `$TEAM roster >"$TMP/roster-dead.log"` 不过管道，所以它通过。
  这条假说与本段的实际读数一致，但**没有在本轮被验证**（要验它得看 roster 早退时的退出码/SIGPIPE，属独立静态复核的
  范围）。所以：**只把界缩回注释量级不足以解释也不足以修**，那只是把等待缩短；根因在这条 pipeline 的判定方式上。
- 本段没有失败（`✓15 ✗0`）：读数是「慢 + 判定可能永不成立」，不是「断言错」。改动属于修复批次，本轮（产品冻结）
  不动；也不把这条必要的 agent 续跑行为改名成自检来绕开。

## D · 生效文档：7 处旧红线 → 0 处

同一条 `grep -nE '2000 ms|panel-cpu-premise|0/2/4/3|0/2/3/4|skips? visibly|premise factor|PREMISE_FACTOR|0\.75|0\.25'`
打三份文件，基线 `4eabb0f5` 命中 7 行、本树命中 2 行 —— 而这 2 行正是新文案里的**否定句**（`with no thresholds, no
premise factor` / `there is no threshold and no premise factor`）：

```
=== mine（762cd654）===
skills/teamsmith/SKILL.md:70:| Performance | `team perf [--host \| --container]` (**separate from correctness**: it only measures and prints reference readings — interactive first frame, frame assembly, steady-state pane CPU — and names the environment it measured in; the exit codes are `0` (a reading was taken) and `3` (setup failed, or the perf lock was unavailable), with no thresholds, no premise factor and no `2`/`4`; its own lock `TEAM_PERF_LOCK`, never the gate lock; default = the pinned `ci/Containerfile` image, `--host` is labelled **not the reference**) |
skills/teamsmith/references/protocol.md:786:together with the environment it was taken in, there is no threshold and no premise factor, and no number it prints

=== base（4eabb0f5）===
skills/teamsmith/SKILL.md:70:| Performance | `team perf [--host \| --container]` (**separate from correctness**: the wall-clock/CPU red lines — interactive first frame, frame assembly, steady-state pane CPU — with the unchanged thresholds (2000 ms / 2000 ms / < 1 %), premise factors (`0.75` / `0.25`), medians, visible `SKIP` and exit codes `0`/`2`/`4`/`3`; its own lock `TEAM_PERF_LOCK`, never the gate lock; default = the pinned `ci/Containerfile` image, `--host` is labelled **not the reference**) |
skills/teamsmith/SKILL.md:329:  prints why and reports a visible SKIP (its own exit status) instead of judging, as does the `panel-cpu-premise`
skills/teamsmith/references/protocol.md:785:(`bash skills/teamsmith/tests/perf.sh`, front door `team perf`): the thresholds (`2000 ms` / `2000 ms` / `< 1 %` of
skills/teamsmith/references/protocol.md:786:one core), the premise factors (`0.75` for the five-sample assembly median, `0.25` for the cold-start first frame
skills/teamsmith/references/protocol.md:787:and the sampled pane CPU, `TEAM_PANEL_CPU_PREMISE_FACTOR`) and the median-of-three/five rules are unchanged, every
skills/teamsmith/references/protocol.md:788:sample is printed, and above the premise the judgement **skips visibly** (exit `4` for a skip, `2` for a red, `0`
skills/teamsmith/tests/perf.sh:171:  # 上限到点留下可读的一句（性能套件的退出码是 0/2/3/4，拿不到锁 = 没结论 → exit 3）。


```

§18（英文正文不变量，`references/**` 的正文必须全英文）：

```

[1m== 选段结果 ==[0m  ✓ 48  ✗ 0
[33mFAST 模式：跳过 0 个真进程段落（）——完整门禁请不带 TEAM_SMOKE_FAST 重跑[0m
  [2m·[0m 临时根（结束）：/var/tmp/p326-long.Jyb4W6/tmp18/teamsmith-smoke-pm_skills-deb708fe.zm4rZi（9.4 MB · 442 文件 · source=tmpdir）

[1m== 选段：这次没跑的段 ==[0m 130 个键
0e 0f 0g 0h 0i 1 1b 1c 2 3 4 4b 4c 5 3b 6 6b 6c 6d 6e 6f 6g 6h 6i 6j 6k 7 7b 8 9 10 10b 10c 11 11b 11b2 11b3 11b4 11c 11d 11e 11e2 11f 11g 11h 11i 11j 14b 15b 15c 12 13 13b 13c 12b 12b-h0 12b-h0b 12b-h0d 12b-h0c 12b-pi 12b-pi2 12b-pi3 14 14c 54 14d 17 18b 18c 19 20 21 22 23 24 25 26 27 28 29 30 31 31c 32 33 12e 12f 12g 12h 12i 12j 12k 34 34b 34c 34d 35 36 37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 51b 51c 52 53 57 58 15 55 56 59 60 61 61b 62 63 64 65
  选段运行不是全套门禁（交付 / 复验 / 归档仍跑整套）；引用它的报告必须点名没跑的段
```

## V70 后的定点返修（2026-10-20，PM 明授；只做差异）

基线：先 `git merge main`（`f9d34e57`，含 P318 的 §58 修复与 P331），无冲突、无 rebase/reset。返修前 tip
`af58b620` → 返修后 `173b4cd5`。

### 7.1 · 11c：判定、耗尽与前提

三处改动，都在这条断言自己的因果链上：

**(a) 判定不再经过不可靠的管道，也认退出码。** 原来把 CLI 输出直接接给 `grep -q`（`pipefail` 下读端命中就关管、
写端 SIGPIPE 能被读成非 0，再被 `!` 翻成「没等到」）；现在整份输出落到变量，**命中要求这次调用自己退出 0 且输出里有
那句话** —— 退出码非零时哪怕串出现也不算读到。

**(b) 耗尽不静默。** 1500 轮用尽时打印现场（轮数、roster 末次退出码、窗口表、pane 命令）并**单独判一条红**
（`§11c 夹具前提：… 后面的崩溃态断言因此没有前提`），产品断言照旧另算。界仍是 `R_MAX=1500` 轮 × 0.2 s，
15 条产品断言一个字没动，这段仍在地板里。

**(c) 最后那条「PM 启动失败」的前提是真的准备出来的，不是等出来的。** 这一条推翻了我上一轮写在报告里的
"starting: 标记竞态"假说 —— 加上前提断言后第一次跑就点名了真因：

```
✗ §11c 前提：up --agents 之前 PM 状态是「running:1677517」—— 不是 idle/unknown，最后那条启动失败断言没有前提
```

机制：§11b 用 `pi-sleep`（`sleep 600`）把 PM 拉起来，跑完不收回；§11c 走到 `up --agents` 时窗口里是个**活进程**，
`team up` 于是走 `running:` 分支、打「PM 在运行」，那句「启动失败」本来就不该出现。**C4 那次是 ✓，只因为那段跑了
1018 s，600 s 的 sleep 已经到期** —— 这条断言以前是「靠段落慢」绿的，13 s 只是让它现了原形。

修法是 fixtures 自己的口径：`make_pm_idle`（§11b 定义，等的是 `team_pm_state` 真报 `idle:*`，不是赌一次 sleep）
把窗口还原成确定性空 shell，然后把「此刻确实是 idle」断成**自己的一条前提断言**；前提不成立就红在前提上并点名状态，
产品断言一个字不放宽，也没有任何一处靠加长 sleep 换绿。

**本轮 11c 的四次读数**（`--select 11c`，宿主，私有 TMPDIR/锁；每次都是修完之后跑、失败就改再跑）：

| # | tip | 墙钟/段用时 | 结果 | 说明 |
|---|---|---|---|---|
| 1 | `5ac2885a` | 20 s / 13 s | 8✓ 8✗ | `needs` 只写 `4` → `wait_window_gone: command not found`，此后全塌 |
| 2 | `173b4cd5` | 104 s / 13 s | 14✓ 1✗ | 补 `needs=4,11b`；末条「PM 启动失败」红（真因未明） |
| 3 | `34e5c711` | 159 s / 57 s | 14✓ 2✗ | 加上前提断言 → 直接点名 `running:1677517`（前提不成立） |
| 4 | `f14be42b` | 119 s / 22 s | **16✓ 0✗** | 用 `make_pm_idle` 准备前提 + 前提断言绿 + 产品断言绿；整次选段 `✓ 342 ✗ 0` |

第 4 次的 11c 段内全文：

```
== #12 11c · agent 续跑是 PM 的事（pulse 不碰） == 2026-10-20T08:12:43+00:00
  ✓ roster 能区分「窗口在但 pi 已退出」（有界轮询，不是赌一次 sleep）
  ✓ agent 没在跑时 say 落收件箱并返回 0
  ✓ 说明消息进了收件箱（而不是打进 shell）
  ✓ 读命令之后 state/ 一个字节没变（F28）
  ✓ 崩溃 agent 的任务记录还在
  ✓ digest 仍把崩溃 agent 算成待办
  ✓ 死窗口释放模型槽位（RUNNING=0）
  ✓ pulse 不续跑 agent（窗口仍不在）
  ✓ pulse 输出里没有 agent 续跑动作
  ✓ resume --dry-run 能识别待续跑任务
  ✓ resume（PM 工具）退出码 0
  ✓ resume 重新派单
  ✓ resume 后 dev 窗口回来了
  ✓ §11c 前提：up --agents 之前 PM 是 idle（窗口是空 shell、无在飞标记 → up 会真的尝试启动）
  ✓ up --agents 才会续跑 agent
  ✓ （假 pi 秒退：up 同时也如实报了 PM 没起来）
#12 11c · agent 续跑是 PM 的事（pulse 不碰） · 参考 用时 22s · ✓16 ✗0 SKIP0 · ticks 16
```

段的收口行与整次选段：

```
== 选段 == decision=RUN · 运行 12/135 段 · 未跑 123 段
#12 11c · agent 续跑是 PM 的事（pulse 不碰） · 参考 用时 22s · ✓16 ✗0 SKIP0 · ticks 16
== 选段结果 ==  ✓ 342  ✗ 0
```

**关于 1018 s 与 13/22 s**：两者都是**段账本自己的用时**，但环境不同 —— C4 那次在钉死容器里（`loadavg 11.75`，且
那 1018 s 里有 986 s 卡在一条永远不认账的轮询上），这几次在宿主。所以它们**不是一个提速比**，也不作为因果证据；
有判据价值的只有一件事：轮询现在第一轮就认账，并且它认的账是「退出 0 且串在」。

#### 7.1b · 取证缺口（如实：这条是 PM 追加要求之后我没做到的）

PM 在 **08:07:13Z** 要求「下一次已批准的 11c 唯一运行请用现有 `--keep`，并保留 `up-agents.log` 及对应 PM 状态文件直到
复核收口；不为取证额外跑一次」。已批准的第四次运行是在 **08:12:43Z** 开始的 —— 指令到达时我正在等这次作业返回，读到时
它已经跑完，**没有带 `--keep`**；而这次是**绿的**，所以套件按自己的规则删掉了现场：

```
· 临时根（结束）：/var/tmp/p326-11c4/tmp/teamsmith-smoke-pm_skills-deb708fe.zUpf0q（1.8 MB · 556 文件 · source=tmpdir）
$ ls /var/tmp/p326-11c4/tmp/     # 现在只剩 node-compile-cache 与 smoke.lock
```

于是 `up-agents.log` 与那一刻的 PM 状态文件都**不在**了。按同一条指令，我**没有**为取证再跑一次、也没有造新的采集手段。

现在能独立回读的、都还在（我自己存的段日志，不在被删的现场里）：

| 文件 | 里面有什么 |
|---|---|
| `/var/tmp/p326-11c4/run.log` | 第四次（`f14be42b`）整次选段的原始 stdout：16 条断言逐行、`✓ §11c 前提：up --agents 之前 PM 是 idle…`、`#12 11c … ✓16 ✗0`、`== 选段结果 == ✓ 342 ✗ 0` |
| `/var/tmp/p326-11c3/run.log` | 第三次（`34e5c711`）—— 前提断言**红**在 `running:1677517` 的那一行（真因的第一手证据） |
| `/var/tmp/p326-11c2/run.log` | 第二次（`173b4cd5`）—— `14✓ 1✗` 与那条 `up --agents` 红 |

下一次以 `--keep` 跑 §11c 时（独立席位或 PM 最终的固定树入口），要回读的两件东西在这里：

```
<--keep 的现场根>/up-agents.log                      # up --agents 的整份 stdout（「续跑 dev」与有没有「PM 启动失败」）
<--keep 的现场根>/repo/.pi/team/state/pm.pid.starting # 那一刻的在飞启动标记（有/无、内容、年龄）
<--keep 的现场根>/repo/.pi/team/state/                # 同目录下的 dev.env 等席位记录
```

（`pm.pid.starting` 是 `team_pm_starting_file` 的落点 —— 见 `scripts/lib/common.sh`。前提断言已经把 `team_pm_state` 的
读数直接打印进段日志，所以「那一刻是 idle 还是 running」不必只靠现场文件。）

### 7.2 · 探针：一次真实 run 只留一条整体退出码断言

- ⑤b 的 `--select 19,31,58` 原先用同一个 `$P_HY_RC` 分别冒充 §19、§31、§58 三段的结果（3 条断言）；
  现在只有**一条**「这一次 run 的退出 0」，三段的判定各读自己那几行（§19 的 SKIP 计数与 `✗0` 收口行、
  §31 的 `M28 真树` 行、§58 的 `signal-lint 判定` 行）。
- ⑨/⑩ 共用同一次 `--select 31,58`：整体退出码只在 ⑨ 断言一次，⑩ 不再重复。
- 整次 run 的失败**仍然**被那一条兜住（没有照抄「把 5 条全删」）。断言调用点：185 → **182**。

### 7.3 · CI 入口有了真实承接者（并补上了「没有段读它」这个缺口）

新增 `skills/teamsmith/tests/workflow-entry.sh`：它执行工作流**自己的** `run:` 块（`docker` 换成记录 argv 的桩），
不做 YAML 再解析、不建矩阵。只验 C4 里已经真跑过的三条：

| 行为 | 断言 |
|---|---|
| 有效基点 + 特殊文件名 | 3 条（换行 / 空格 / 引号+反斜杠）逐字节到达容器参数（`cmp` 比 NUL 流）；命令里是 `--floor --paths "$@"` |
| 基点不可解析（空 / 全零 / 不在仓里） | 每条都 `::warning::` + `--floor` 不在**且正向确认执行完整入口**（命令里有 `openspec validate --all --strict` + `bash skills/teamsmith/tests/smoke.sh --keep`）—— 只查「缺 `--floor`」时一条空命令也能过 |
| 底层执行失败（stub rc=5） | 这一步照旧非 0（失败没被吞） |

```
✓ workflow-entry ①：有效基点时这一步退出 0
  ✓ workflow-entry ①：容器命令带 `--floor` 与 `--paths "$@"`（不是全套、也不会丢路径）
  ✓ workflow-entry ①：3 条特殊文件名（换行 / 空格 / 引号+反斜杠）逐字节到达容器参数（cmp 一致）
  ✓ workflow-entry ②：基点不可解析（空）→ ::warning:: + 退回全套（命令里没有 --floor）
  ✓ workflow-entry ②：基点不可解析（0000000000000000000000000000000000000000）→ ::warning:: + 退回全套（命令里没有 --floor）
  ✓ workflow-entry ②：基点不可解析（no-such-sha-3632869）→ ::warning:: + 退回全套（命令里没有 --floor）
  ✓ workflow-entry ③：容器执行失败（stub rc=5）→ 这一步非 0（rc=5），失败没被吞
== workflow-entry == ok 7 bad 0 skip 0
```

**翻转证据**（在工作流的**磁盘副本**上破坏，原文件不动）：

| 破坏 | 结果 |
|---|---|
| 容器命令去掉 `--paths "$@"` | rc=1，`✗ workflow-entry ①：容器命令不是 --floor --paths 形状` |
| 退回全套那一支也带上 `--floor` | rc=1，3 条 `✗ … 基点不可解析（空/全零/no-such-sha）没有按约定退回全套` |
| 把这一步的失败吞掉（`fi \|\| true`） | rc=1，`✗ workflow-entry ③：容器执行失败后这一步仍退 0（失败被吞了）` |
| 把回退分支的命令换成 `true`（空命令） | rc=1，`✗ … 没有正向确认退回完整入口（rc=0，入口在=0，命令：… && true）` —— 这正是旧写法会放过的那一种 |

```
[cmd-loses-paths]
    ✗ workflow-entry ①：容器命令不是 --floor --paths 形状（实际：mkdir -p "$TMPDIR" && openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh --floor --keep </dev/null）
  == workflow-entry == ok 6 bad 1 skip 0
[failure-swallowed]
    ✗ workflow-entry ③：容器执行失败后这一步仍退 0（失败被吞了）
  == workflow-entry == ok 6 bad 1 skip 0
[fallback-keeps-floor]
    ✗ workflow-entry ②：基点不可解析（空）没有按约定退回全套（rc=0，命令：mkdir -p "$TMPDIR" && openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh --floor --keep </dev/null）
    ✗ workflow-entry ②：基点不可解析（0000000000000000000000000000000000000000）没有按约定退回全套（rc=0，命令：mkdir -p "$TMPDIR" && openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh --floor --keep </dev/null）
    ✗ workflow-entry ②：基点不可解析（no-such-sha-2432893）没有按约定退回全套（rc=0，命令：mkdir -p "$TMPDIR" && openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh --floor --keep </dev/null）
  == workflow-entry == ok 4 bad 3 skip 0
```

接入与映射：
- **看的是哪棵树**（V71 的承接缺口，本轮修掉）：36⑨ 的条件与 `--tree` 原先都指向本段自建的夹具项目 `$REPO`，而那棵
  空项目顶层没有 CI 源码 —— 所以在门禁里这条检查**只能**退化成一个 skip，只有手工 `--tree` 才真跑。现在两处都改成
  `$CHECKOUT_REPO_ROOT`（产品面检出），`workflow-entry.sh` 自己把 CI 定义拷进它的临时仓库，因此不需要往夹具里放任何
  东西；检出确实没有 CI 源码时仍如实 skip。证据：下面 §36 的读数里 `36⑨` 是 **✓ 执行**（ok 7 bad 0），不是 SKIP。

- §36 新增 36⑨ 调用它；产品面检出不含 CI 源码时按既有缺前提语义 `cond_skip`（不计通过），没有伪造通过。
- `section-paths.tsv` 的 36 行 patterns 追加 `skills/teamsmith/tests/workflow-entry.sh` 与 `.github/workflows/gates.yml`：

```
$ bash skills/teamsmith/tests/section-select.sh --paths .github/workflows/gates.yml
decision=RUN
sections=135
keys=5
```

  返修前同一条路径答 `decision=FULL`（未声明 → 全套，含 §61b）。现在它归 §36，`--floor --paths .github/workflows/gates.yml`
  也不再是 FULL。
- `--paths` / `--floor --paths` 的未知路径与无有效基点 `FULL` 兜底**一字未改**；`.github/**` 没有加豁免；`FULL` 没有改成 floor。
- **净零**：这条新入口检查替代的正是 7.2 删掉的那 3 条重复的整批退出码检查。

### 7.3b · 退役那条无对象的旧豁免记录（PM 明授）

`skills/teamsmith/tests/signal-lint-legacy.txt` 里最后一条记录指向 `docs/team/reports/M35-dev2/pkg/lib.sh`，那份证据文件在
main 上已经不存在，于是 `signal-lint.pl` 每轮报 `baseline 过期`。本轮只做 PM 授权的那一件事：**删掉这一条记录**，
不改 lint 规则、不添豁免、不恢复证据文件；清单里留一段带日期的说明（为什么现在是空清单）。

**这条记录的对象为什么不在**（V71 核出的事实，替换掉我先前的猜测）：它**注册那天就没有对象** —— 现行 main 的历史里
这份证据包从未存在过，只在更早的旧历史（`938e5ea2`）里出现过。所以这不是某次删夹具删出来的，也与 P330 无关：
P330 的实现提交 `a62ab6bb` 只删 `skills/teamsmith/tests/**`，碰不到 `docs/team/reports/**`。退役这条登记仍然成立
（lint 规则未放宽、扫描面不变）。

使用方先确认过：`signal-lint.pl` 读它做 sha/条数核对；`smoke.sh` §58 断言它存在、逐条核对面与在册；`checkout-shape-probe.sh`
在 scratch 副本里重写它（`sed '/^[^#]/d'` + 追加一条）—— 三处都不要求它非空。

原 lint 与自检（真树）：

```
$ perl skills/teamsmith/tests/signal-lint.pl
signal-lint：干净（扫描 90 个脚本；pid 精确形态全部干净）

$ perl skills/teamsmith/tests/signal-lint.pl --selftest
✓ signal-lint --selftest：29 个夹具 + 豁免机制全部符合预期（该红的红、该净的净）

$ # 清单为空时整张扫描面照旧判（临时根里种一条 pkill -f）
按名字/模式选进程（pkill/killall）：名字不是身份
signal-lint：1 条按名字/谓词选进程的调用（扫描 1 个脚本；历史豁免另算 0 条）
```

**一处要 PM 知道的后果**（已交 PM 裁定，P333 归 dev3）：空清单 → `checkout_registered_paths_absent` 返回 0 → §58 会打印一条「证据层缺席」的 `prereq_skip` 行。**它不是切断**：`prereq_skip` 只计数与实际打印，紧随其后的 `perl signal-lint.pl` 判红/判绿是无条件执行的（PM 2026-10-20T08:34:49Z 更正了我先前把它当成「主判定被跳过」的读法）—— 所以空清单**没有**藏起任何判定，问题只在那行提示本身：文案说「豁免清单登记的路径逐条不在」，而登记是**空集**，提示在描述一件没有发生的事。修法（空清单才算可裁决、只有「至少一条且都不在」才跳过）已立 P333，写集是 §58 自己的条件与注释，`checkout_registered_paths_absent` 与 §19 不动。本轮**没有**为了消掉它去改 lint 规则或补豁免。

### 7.3c · `--select 36` 的两次读数（本轮唯一跑到的整段）

按裁定只跑 `--select 36`。**第一次**（`0b7e1ffe`）36⑨ 已经真跑起来了，但它同时把我自己引入的一处红翻了出来 ——
新写的注释里点了夹具项目顶层的一个文件名，选择器的「未声明路径」规则把它读成「段 36 读取了没声明的路径」，于是
36① 与 36⑧ 一起红（同一个 token 的级联）：

```
== 选段 == decision=RUN · 运行 5/135 段 · 未跑 130 段
== #5 36 · 选段与分段账本自检（P98 · gate-runtime-budget） == 2026-10-20T08:44:27+00:00
  ✗ 36① --check 红：bad: 段 36 读了它没声明的路径：token AGENTS.md（源码行 18286）—— 补进该行的 patterns
  ✗ 36① 副本表未改就红（夹具本身有问题）
  ✗ 36① 变体树注入前就红了（夹具本身有问题）：bad: 段 36 读了它没声明的路径：token AGENTS.md（源码行 18286）—— 补进该行的 patterns
  ✓ 36③ 结果行用 == 选段结果 ==
  ✗ 36⑧ 产品面检出探针有失败（3 条）
  ✓ 36⑨ CI 入口：workflow-entry 三条行为全绿（ok 7 bad 0 skip 0）
#5 36 · 选段与分段账本自检（P98 · gate-runtime-budget） · 参考 用时 769s · ✓117 ✗4 SKIP3 · ticks 124
== 选段结果 ==  ✓ 140  ✗ 4
```

**第二次**（`295e966a`，注释改成不点任何路径 token，§36 的 patterns 一个没动）：整段绿，36⑧ 探针与 36⑨ 都真执行：

```
== 选段 == decision=RUN · 运行 5/135 段 · 未跑 130 段
== #5 36 · 选段与分段账本自检（P98 · gate-runtime-budget） == 2026-10-20T08:58:25+00:00
  ✓ 36① 变体树注入前是绿的（token 夹具的负面对照）
  ✓ 36③ 结果行用 == 选段结果 ==
  ✓ 36⑧ 产品面检出探针全绿（ok 144 bad 0 skip 0）
  ✓ 36⑨ CI 入口：workflow-entry 三条行为全绿（ok 7 bad 0 skip 0）
#5 36 · 选段与分段账本自检（P98 · gate-runtime-budget） · 参考 用时 773s · ✓121 ✗0 SKIP3 · ticks 124
== 选段结果 ==  ✓ 144  ✗ 0
```

3 条 SKIP 全部是同一件事：`.pi/skills`（机器生成面）在这棵检出里不存在 —— 既有的、按形状如实披露的跳过，不是本轮引入。

### 7.4 · 文字勘误

- `SKILL.md:305`（残留的「The **performance** red lines live in `tests/perf.sh`」）→ 读数语义。
- `section-paths.tsv`：上一轮把「36 行 patterns 追加两条路径」的说明**误写进了 58 行的 basis 列**；本轮只把它搬回 36 行，
  58 行只剩它自己的依据（`needs` 改 `-`）。
- delta 的 `**Migration**`：premise 场景退场数 `三` → **四**（over-premise 可见跳过 / 前提不是真回归的逃生门 /
  skipped fixture 不许报成通过 / 前提读数在真路径上仍是真的），并点名第三条的承接者
  `verification#A gate that cannot judge says so`（它在 base spec 已存在，`verification/spec.md:1437`）。

```
-scenario became the guard's planted-comparison and slow-but-correct scenarios; the three premise-`SKIP` scenarios
-retired with the premise; the knob-integrity scenario now pins the section-guard knobs the gate still has.
+scenario became the guard's planted-comparison and slow-but-correct scenarios; the **four** premise-`SKIP`
+scenarios (over-premise skips visibly, the premise is not an escape from a real regression, a skipped fixture is
+never reported as a passing one, the premise readings stay real on the real path) retired with the premise — the
+third of them, "a skipped fixture is never reported as a passing one", is carried on by
+`verification#A gate that cannot judge says so`, which is where that promise lives now; the knob-integrity
+scenario now pins the section-guard knobs the gate still has.
-| `tests/smoke.sh`, `tests/perf.sh`, `tests/skill-load.mjs` | To confirm the tooling works here: `team smoke` (end-to-end in a temp repo, never touches this project). **Fast mode**: `TEAM_SMOKE_FAST=1 team smoke` runs only sections that need no real tmux stage or agent process — good for day-to-day gates before dispatch/verification; it **does not cover** dispatch actually launching an agent, the non-Pi agent end-to-end segment, window/close behaviour, the pulse waking the PM, standby/monitor, real agent resume, cross-session guards, offline `say` delivery, or knock probing (those print `SKIP (FAST mode)`); run the full suite before changing those paths or cutting a release. The full run is the machine's **one** shared gate resource: it queues on `TEAM_SMOKE_LOCK` up to `TEAM_SMOKE_LOCK_WAIT`, and `team review` takes the same lock *before* its hard timeout (so the record's `queued`/`ran` are separate and a long queue is a loud `FAIL`, never a `TIMEOUT`). The **performance** red lines live in `tests/perf.sh` (`team perf`), not in the correctness gate: correctness on every change, performance separately and before a release |
+| `tests/smoke.sh`, `tests/perf.sh`, `tests/skill-load.mjs` | To confirm the tooling works here: `team smoke` (end-to-end in a temp repo, never touches this project). **Fast mode**: `TEAM_SMOKE_FAST=1 team smoke` runs only sections that need no real tmux stage or agent process — good for day-to-day gates before dispatch/verification; it **does not cover** dispatch actually launching an agent, the non-Pi agent end-to-end segment, window/close behaviour, the pulse waking the PM, standby/monitor, real agent resume, cross-session guards, offline `say` delivery, or knock probing (those print `SKIP (FAST mode)`); run the full suite before changing those paths or cutting a release. The full run is the machine's **one** shared gate resource: it queues on `TEAM_SMOKE_LOCK` up to `TEAM_SMOKE_LOCK_WAIT`, and `team review` takes the same lock *before* its hard timeout (so the record's `queued`/`ran` are separate and a long queue is a loud `FAIL`, never a `TIMEOUT`). The **performance** readings live in `tests/perf.sh` (`team perf`), not in the correctness gate (there are no performance red lines left to run there — the suite prints reference readings, names the environment it measured in, and cannot fail a run): correctness on every change, one performance reading before a release |
```

### 7.5 · 本轮**没有**跑的东西（不是通过）

- **§36 在本轮的唯一一次返修里跑了**（`--select 36` 共两次，见 §7.3c）：36⑧（探针 ok 144 bad 0）与 36⑨（workflow-entry
  ok 7 bad 0）都有本轮读数，整段 `✓121 ✗0 SKIP3`。此前的三次收口里它确实没跑，那几节的「未跑」记录保持原样。
- **没有**跑容器、`--floor` 整体、`checkout-shape-probe.sh` 整套、路由变异矩阵。原 C1/C2 已成立的证据按 PM 裁定复用。
- **11c 只跑了一次**（选段 `--select 11c`，附带 `needs: 4`）。
- 合并带来的一个**既有**红（本轮已退役，见 §7.3b）：`perl skills/teamsmith/tests/signal-lint.pl` 曾报「基线清单里的
  `docs/team/reports/M35-dev2/pkg/lib.sh` 不在了」。那条登记**注册时就没有对象**（现行 main 历史里该证据包从未存在，
  只在旧历史 `938e5ea2` 出现过），不是任何一次删夹具删出来的 —— P330 的 `a62ab6bb` 只删 `skills/teamsmith/tests/**`。
  §58 更早的那条红（`signal-gate.sh` 的 `kill $(…)` 夹具）已由 P318 修掉，是另一件事。

## 验收命令（5.2 的整套，全部 rc=0）

`openspec` 只装在钉死镜像里（宿主没有这个命令），所以它与试归档都在容器里跑：本树只读挂载给 validate，试归档在
`$HOME/.cache/p326-archive/tree` 的磁盘副本上（`--userns=keep-id` 让它可写；原件不动）。

```

=== accept-1 --check ===
ok: 映射表 key 唯一（135 行）
ok: 段 ↔ 行一一对应（源码 135 段 / 表 135 行）
ok: needs 声明全部存在且指向更早的段（107 条）
SKIP（条件不满足）: 行 19 的字面模式在检出里不存在（检出形状 internal，机器生成面（工具在本机生成、不进仓库））：.pi/skills
ok: 字面模式（640 条）里 639 条在位；1 条检出前提按缺失跳过（跳过不等于检查过）
ok: 豁免类（docs/*）没有任何行声明
ok: 前导段声明有效（0 0b 0c 0d）
ok: 段正文点名的真实路径 token 都被各自的行覆盖（528 个 token 检查过；0 个豁免类 token 不参与）
ok: 账本归属（ledger-scan 60）声明有效：9/9 个账本样例被它覆盖
ok: gate-self-check 行有效（7 个 key：各自命中一行、无重复、不含前导段）
== 选段自检 ==  ok 9  bad 0  SKIP 1
rc=0

=== accept-2 bash -n（三个改动过的套件文件 + perf.sh） ===
rc=0

=== accept-3 openspec validate --all --strict ===
/var/tmp/p326-accept.sh: line 17: openspec: command not found
rc=127

=== accept-4 spec-refs.sh --check ===
retired openspec/specs/verification/spec.md:371 docs/team/reviews/<ID>.md by behavior-focused-ci
retired openspec/specs/verification/spec.md:398 docs/team/PUBLISH.md by behavior-focused-ci
spec-refs: judged 111 reference(s) (49 distinct) in 12819 effective line(s); retired 2; undeclared 0; id families used [D,E,F,M,P,V] named [D,E,F,M,P,V]
rc=0

=== accept-5 ledger-ban（名单从 git common-dir 上一层） ===
ledger-ban: names：名单已配置（/home/<user>/Documents/syncthing/Work/Projects/pm-skills/.git/../.pi/team/forbidden-names.txt，命中即红）
ledger-ban: root=/home/<user>/Documents/syncthing/Work/Projects/pm-skills/.worktrees/dev scope=published files=1829 hits=0 names=ok user=resolved
rc=0

=== accept-6 git diff --check && git status --short ===
diff-check rc=0
status 行数=0

=== accept-7 磁盘副本试归档（不碰真树） ===
archive rc=127
/var/tmp/p326-accept.sh: line 34: openspec: command not found
归档后 validate rc=127
/var/tmp/p326-accept.sh: line 36: openspec: command not found
归档后 verification 的 requirement 标题（前三处改名应落地）：
222:### Requirement: The correctness gate judges correctness only
327:### Requirement: The performance suite is separate, self-describing and non-blocking
1079:### Requirement: A load experiment signals only the processes it started
1126:### Requirement: Every gate section accounts for itself, and a stuck section is named

=== done ===


=== 5.2-a 容器内 openspec validate --all --strict（本树只读挂载，CI 同一条命令） ===
✓ spec/notify-and-inbox
✓ spec/panel
✓ spec/pm-lifecycle
✓ spec/seat-visibility
✓ spec/verification
✓ spec/watchdog
✓ spec/writing-discipline
Totals: 20 passed, 0 failed (20 items)
rc=0

=== 5.2-b 磁盘副本 + 试归档（--rw 只给副本；原件不写） ===
容器 rc=0
Specs to update:
Applying changes to openspec/specs/verification/spec.md:
  + 3 added
  ~ 6 modified
  - 4 removed
Totals: + 3, ~ 6, - 4, → 0
Change 'behavior-focused-ci' archived as '2026-10-20-behavior-focused-ci'.
archive rc=0
Totals: 19 passed, 0 failed (19 items)
validate-after rc=0

=== 5.2-c 归档后 verification 的标题（红侧应换成成品标题） ===
9:### Requirement: Reviewing needs an independent checkout
26:### Requirement: A dirty or mismatched checkout is refused
47:### Requirement: Gates run under a hard timeout
192:### Requirement: The gate refuses tracked files that still hold conflict markers
222:### Requirement: CI runs the two gates separately and performance does not block
274:### Requirement: The two gates are discoverable, and the doctor names the next step
294:### Requirement: The container self-test's host fingerprint is stable state, and only a real host change moves it
339:### Requirement: A fixture's input-box judgement distinguishes an unexpected overlay
--- 归档前后：archived 目录 ---
2026-10-17-tmux-identity-scope
2026-10-18-tmp-root-on-disk
2026-10-20-behavior-focused-ci
--- 改动清单（原件 vs 副本，只看 openspec/）---
Only in $HOME/.cache/p326-archive/tree/openspec/changes/archive: 2026-10-20-behavior-focused-ci
Only in $HOME/Documents/syncthing/Work/Projects/pm-skills/.worktrees/dev/openspec/changes: behavior-focused-ci
Files $HOME/Documents/syncthing/Work/Projects/pm-skills/.worktrees/dev/openspec/specs/verification/spec.md and $HOME/.cache/p326-archive/tree/openspec/specs/verification/spec.md differ

=== done ===

```

## 返修后本轮实跑的轻量检查（全部 rc=0）

`openspec validate --all --strict` 在钉死镜像里跑（宿主没有这个命令）：**21 passed, 0 failed**；本树只读挂载。

```
$ bash skills/teamsmith/tests/section-select.sh --check
ok: 账本归属（ledger-scan 60）声明有效：9/9 个账本样例被它覆盖
ok: gate-self-check 行有效（7 个 key：各自命中一行、无重复、不含前导段）
== 选段自检 ==  ok 9  bad 0  SKIP 1

$ bash -n <4 个套件文件>
bash -n: rc=0（4/4）

$ bash skills/teamsmith/tests/spec-refs.sh --check
retired openspec/specs/verification/spec.md:398 docs/team/PUBLISH.md by behavior-focused-ci
spec-refs: judged 111 reference(s) (49 distinct) in 12869 effective line(s); retired 2; undeclared 0; id families used [D,E,F,M,P,V] named [D,E,F,M,P,V]

$ bash skills/teamsmith/tests/workflow-entry.sh
  ✓ workflow-entry ②：基点不可解析（no-such-sha-3770189）→ ::warning:: + 退回全套（命令里没有 --floor）
  ✓ workflow-entry ③：容器执行失败（stub rc=5）→ 这一步非 0（rc=5），失败没被吞
== workflow-entry == ok 7 bad 0 skip 0
```

`ledger-ban`（名单从 git common-dir 上一层）`hits=0`；`git diff --check` 干净；`git status --short` 为空。

## 最后一轮（V71 后）的轻量收口 —— 全部 rc=0

`openspec validate --all --strict` 在钉死镜像里跑（宿主没有这个命令）：**21 passed, 0 failed**；本树只读挂载。
`ledger-ban`：`hits=0 names=ok`。

```
$ bash skills/teamsmith/tests/section-select.sh --check
ok: gate-self-check 行有效（7 个 key：各自命中一行、无重复、不含前导段）
== 选段自检 ==  ok 9  bad 0  SKIP 1

$ bash -n ...
bash -n: rc=0（4/4）

$ bash skills/teamsmith/tests/spec-refs.sh --check
spec-refs: judged 111 reference(s) (49 distinct) in 12869 effective line(s); retired 2; undeclared 0; id families used [D,E,F,M,P,V] named [D,E,F,M,P,V]

$ bash skills/teamsmith/tests/workflow-entry.sh --tree "$PWD"
  ✓ workflow-entry ③：容器执行失败（stub rc=5）→ 这一步非 0（rc=5），失败没被吞
== workflow-entry == ok 7 bad 0 skip 0

$ git diff --check && git status --short
diff-check rc=0
```

## 未观测边界 / 待 PM 裁定

- **条件 1 未成立，需要裁定**：地板在普通推送上没被证明能塞进 45 分钟（本机 44 分 59 秒只跑完 96/133）。可选方向
  （都属于缩小地板，不是我能单方面决定的）：把 `11c`（1018 s）与 `33`（157 s）这类重段声明成自检/里程碑段；或把普通
  推送改成「只跑 `--paths` 命中的段 + 前导段」而把地板留给合并/发布；或把 45 分钟预算按 CI 实测重定。
- **真 GitHub CI 没跑过**：工作流的 NUL 链与两条容器命令是用 docker **桩**在宿主上执行的（argv 逐字节核对：
  `--floor --paths "$@"` 在、无基点时退回全套在），容器里跑的是**同一条**套件命令。`github.event.before` /
  `github.sha` 的真实取值、`fetch-depth: 0` 的实际拉取、`::warning::` 在 runner 上的呈现，都只有真推一次才能确认。
- **`.github/workflows/gates.yml` 自己没有任何一行 patterns 覆盖**（交独立审阅，PM 07:40:36Z）：`--floor --paths
  .github/workflows/gates.yml` 答 `decision=FULL`。所以「改工作流自己」的那种推送会跑全套（含 §61b 的 4946 s），
  60 分钟上限会吃掉它。这是规格要的安全方向（多跑），但**这一行没被授权**给它补 patterns（写集只授了表头一行与 58 的
  `needs`）。约束（PM 明确）：最小修正，**不能简单地给 `.github/**` 开豁免**，也**不能削弱「未知路径 → FULL」这条兜底**
  ——要的是「工作流这个路径本来该由哪一段负责」的答案，而不是让它变成不用跑。本轮不做，也不预设修法。
- **C4 的红是挂载形状的工件**（B2）：要在真容器里覆盖 `0d/0i/34c/34d`，检出必须是真克隆，不是 worktree。
- **本机不是 runner**：C4 的时长在本机量的（loadavg 11.75 / 32 核），与 CI 有系统性差异（P322 量过约 1.57 的比值），
  所以它是一个乐观方向存疑的读数，不能当作 runner 上的承诺。
- **§61b 未重跑**（C4 的未跑清单里点名它，它也是 `--floor` 明确不选的段）；性能读数未重测（引用 P316 / V65 / V66 的
  既成独立证据）。
- **§36 的定点运行**用 `TEAM_SMOKE_FAST=1`（§36 本身两种档都跑，探针的嵌套 run 固定 FAST）；**C4 在容器里是非 FAST，
  且 C4 没跑到 §36**（桶 3），所以 §36 的绿/红只由宿主那次定点运行与 §A 的纯逻辑证据支撑。
- **§36 的读数**：本轮最后一轮返修跑过两次 `--select 36`（§7.3c），36⑧ 与 36⑨ 都是真执行；更早几次收口没跑，那几节
  的记录保持原样。
- **那条过期豁免已退役**（§7.3b）：`docs/team/reports/M35-dev2/pkg/lib.sh` 这条登记**注册时就没有对象**（现行 main 里该
  证据包从未存在，只在旧历史 `938e5ea2` 出现），与 P330 无关（它的 `a62ab6bb` 只删 `skills/teamsmith/tests/**`）。
  退役后 `signal-lint.pl` 在真树上干净。
- **11c 的末条断言以前是「靠段落慢」绿的**（本轮已查清，不是抖动）：§11b 用 `pi-sleep`（`sleep 600`）把 PM
  拉起来不收回，快跑到 `up --agents` 时窗口里还是活进程 → `running:` 分支 → 那句「启动失败」本就不该出现；C4 那次
  ✓ 只因为那段跑了 1018 s，600 s 的 sleep 已到期。上一轮报告里写的「starting: 标记竞态」是**错的假说**，已由
  前提断言点名真因（`running:<pid>`）后推翻，修法与四次读数见 §7.1(c)。
- **§58 的豁免清单现在是空清单**（本轮退役了那条无对象的记录）：`checkout_registered_paths_absent` 对空清单返回 0，
  所以 §58 会打印一条「豁免清单登记的路径逐条不在」的 `prereq_skip` 行。它**只计数、不切断**，紧随的 lint 判定照常
  执行（PM 已更正这一点）；留在台账上的问题只是那行提示在描述一个空集。修法已立 P333（dev3），不在本轮写集里。
- **既有红的两侧对照**是本报告最强的证据，但它的结论是「不是我的」而不是「全绿」：§36 在本树上不可达全绿，直到
  B1 被 P318 修掉。
