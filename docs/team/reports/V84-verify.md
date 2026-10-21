# V84 · P344 的独立验收：两处夹具缺陷，与同族清扫的账

agent: verify · branch `task/V84-sigpipe-sweep-verify` · change: `-` · anchor: none (infra) — 夹具缺陷与同族判定
受检：`de497f52`（代码面 `899ab6f3`，另含 `240a70ef`）· 报告 `docs/team/reports/P344-dev3.md` · time: 2026-10-21T01:29Z

**第二轮（返修增量）判定：PASS** —— 任务书第二轮的三件全部成立，证据见 §7。
第一轮的 PARTIAL 保留在下面作为历史：其中 `§36③` 的死断言、`§36⑦` 的「会」理由、`outbox.sh` 六处漏账，这一轮
都已返修并已复验；**两处产品缺陷**（`common.sh:5234`、`cmd-status.sh:158`）与「面板 `cap()` 无害」的判断**未变**。

---

## 0. 第一轮记录（`de497f52`）

**判定：PARTIAL。**

- **两处夹具修复成立，可以收**：`§51 C2/tmp-root-mkdir` 不再由调用者的环境决定测哪一支，优先级被钉住，并且有牙
  （把产品优先级反过来 → 恰好那一条红并点名 `source=tmpdir`）；`§41 ④` 的等待改成「先落变量再匹配」，假失败不再
  可能，坏掉时是一条点名的红（变异树实测 `✗ P55 ④ 夹具前提`）。
- **同族清扫：方法站得住，账不闭合。** 判定标准（生产者会不会在读端退出后继续写）本身正确，我把三类「不会」的
  理由各实测了一类，都成立；但（a）三处「会、且已改」里只有 `§41 ④` 是真修，`§36③` / `§36⑦` 的「会」理由不成立
  （实测它们的生产者根本到不了 8192 B），其中 `§36③` 的红标检查**两个版本都是死断言**；（b）产品面的站点账只点了
  13 处，树上有 **19 处**，缺的 6 处全在 `outbox.sh`。
- **5 处 BLOCKED 里 2 处是产品缺陷（该修）、3 处面板夹具应改判「无害」**（我实测 `tmux capture-pane` 不吃 SIGPIPE）。

---

## 1. `§51` 真的不再依赖环境

### 1.1 新写法确实是「两条腿都自己给 + 断言点名哪条腿」

`routes.sh:1537-1549`（候选树）：

```diff
-  RC_EXTRA=("TEAM_TMP_ROOT=$d/explicit-root")
+  RC_EXTRA=("TMPDIR=$d/tmpdir-root" "TEAM_TMP_ROOT=$d/explicit-root")
   RC_CMD=(dispatch dev P1 "$b" --print)
-  rc_case tmp-root-mkdir '临时根不可用' '修法：mkdir -p ' 'apply:cmd' same clear
+  rc_case tmp-root-mkdir '临时根不可用：.*（source=tmpdir）' '修法：mkdir -p ' 'apply:cmd' same clear
```

`rc_team()` 把 `RC_EXTRA` 原样塞进 `env …`（`routes.sh:1125-1135`），所以两个源都由走查自己给；
拒绝行的 `source=` 由产品唯一的解析实现印出（拒绝行本体在 `cmd-agents.sh:1050`，另一处同格式在
`common.sh:4176`；顺序只在 `team_tmp_root_source` 里，`common.sh:4059-4063`：`TMPDIR` → `TEAM_TMP_ROOT` → 默认）。

### 1.2 两种环境各跑一次 `--select 51`：都绿

四次门禁运行都在候选树 `de497f52` 的独立克隆上（`git clone --shared`，树逐字节等于候选），各持门禁锁、串行：

```
G1  env -u TMPDIR            bash skills/teamsmith/tests/smoke.sh --select 51   →  rc=0
    运行根：…/teamsmith-smoke-cand-e6bcc777.HnTvYE（4 KB · 2 文件 · source=default）
    == 选段结果 ==  ✓ 26  ✗ 0            #5 51 · … · 用时 1056s · ✓3 ✗0
      ✓ 51 routes.sh 全绿（254 条断言，1 条可见跳过）
G2  TMPDIR=/var/tmp/v84/tdir bash skills/teamsmith/tests/smoke.sh --select 51   →  rc=0
    运行根：/var/tmp/v84/tdir/teamsmith-smoke-cand-e6bcc777.gnzgii（… source=tmpdir）
    == 选段结果 ==  ✓ 26  ✗ 0            #5 51 · … · 用时 1050s · ✓3 ✗0
      ✓ 51 routes.sh 全绿（254 条断言，1 条可见跳过）
```

`source=tmpdir` 是产品自己印的：**G2 走的确实是 `TMPDIR` 那条腿**，而 C2 走查（在 §51 的 254 条断言里）是绿的。
这一段之所以要 1000s：三条断言各是一整套嵌套夹具——`routes.sh`（254 条，含 11 条翻转子项）、`help-surface.sh`（128 条）、
名册/契约夹具（144 条）。

### 1.3 红侧两条：旧走查（P343 现场）与「优先级反过来」

私有副本 `/var/tmp/v84/mini`（候选的 `skills/` 整树拷贝，候选树不动），只换 `routes.sh`：

```
旧 routes.sh（75ead3e3），默认环境              == 结果 ==  ✓ 28  ✗ 0  SKIP 0   rc=0
旧 routes.sh，TMPDIR=/var/tmp/v84/tdir          ✗ C2/tmp-root-mkdir：拒绝命令没有拒绝（rc=0）
                                               == 结果 ==  ✓ 27  ✗ 1  SKIP 0   rc=1
新 routes.sh，TMPDIR=/var/tmp/v84/tdir          ✓ C2/tmp-root-mkdir：修法路线让阻塞项消失（mkdir -p …）
                                               == 结果 ==  ✓ 28  ✗ 0  SKIP 0   rc=0
```

P343 的红**就是**「环境里导出了 `TMPDIR`」这一支，改后同一环境绿；默认环境两版都绿 —— 与报告 §1 的形状一致。

产品优先级反过来（只改 `mini/scripts/lib/common.sh` 的 `team_tmp_root_source`，把 `TEAM_TMP_ROOT` 排在前面），
候选 `routes.sh` 在同一棵树上：

```
✗ C2/tmp-root-mkdir：拒绝输出里没有期望的阻塞项（临时根不可用：.*（source=tmpdir））：临时根不可用：…
== 结果 ==  ✓ 27  ✗ 1  SKIP 0
```

**红的是这一条，点名的是期望字符串 `source=tmpdir`** —— 优先级被钉住了，不是顺带绿。

## 2. `§41 ④` 的等待不再假失败

### 2.1 读代码：命中靠 bash 内建，不靠管道状态

`smoke.sh:19539-19555`（候选树）：

```bash
P55_W=0; P55_WMAX=200; P55_ROSTER=""; P55_RRC=0; P55_HIT=0; P55_T0="$(date +%s)"
while [ "$P55_W" -lt "$P55_WMAX" ]; do
  P55_ROSTER="$(P55_RENV bash "$SKILL_DIR/scripts/team" roster 2>/dev/null)"; P55_RRC=$?
  if [ "$P55_RRC" -eq 0 ]; then
    case "$P55_ROSTER" in *'在跑'*) P55_HIT=1; break ;; esac
  fi
  sleep 0.3; P55_W=$((P55_W + 1))
done
if [ "$P55_HIT" != 1 ]; then
  bad "P55 ④ 夹具前提：$P55_WMAX 轮（N s）内 roster 没报出「在跑」（末次退出码 …，末次输出末行：…）—— 四态断言因此没有前提"
fi
```

三点都成立：① 整份输出先落变量、连它自己的退出码（`P55_RRC`），匹配用 `case`（bash 内建，不起管道，无从 SIGPIPE）；
② CLI 非零退出不算命中（「崩了但打了半句」不算读到）；③ 上界 200×0.3 s ≈ 60 s **短于**被等对象的寿命（本段假 agent
`sleep 300`），耗尽是一条点名的红而不是静默。`smoke.sh` 是 `set -uo pipefail`（无 `-e`），所以 CLI 非零退出不会把
整段带走。

### 2.2 绿侧与红侧

```
G3  env -u TMPDIR bash skills/teamsmith/tests/smoke.sh --select 41   →  rc=0
    == 选段结果 ==  ✓ 154  ✗ 0     #6 41 · … · 用时 68s · ✓93 ✗0

G4  同一棵树 + 一处变异（`*'在跑'*) P55_HIT=1; break` → `*'在跑'*) :`，即「永不记录命中、永不 break」）
    bash skills/teamsmith/tests/smoke.sh --select 41                 →  rc=1
    ✗ P55 ④ 夹具前提：200 轮（143s）内 roster 没报出「在跑」（末次退出码 0，末次输出末行：session: teamsmith-smoke-2511918（attach: …））—— 四态断言因此没有前提
    == 选段结果 ==  ✓ 154  ✗ 1     #6 41 · … · 用时 212s · ✓93 ✗1
```

值得写下来的一点：**变异只坏「等待」，四态断言全都仍然绿**（它们自己再调一次 `roster`）。也就是说没有这条新加的
「夹具前提」红，坏掉的等待会安静地跑满上界而整段照旧绿 —— 这条红正是这段的判据，不是装饰。

## 3. 同族判定站得住吗

### 3.1 抽查：比要求的 6 条多（2 条「不会」+ 2 条「被改」+ 2 条 BLOCKED，三类「不会」各抽一条）

取材是候选树上的**原文行**（`git show 75ead3e3:<file> | sed -n '<line>p'` 取改前那一行），判定用的是
「读端退出后生产者会不会继续写」。

| 站点 | 报告判定 | 我的复核 | 结论 |
|---|---|---|---|
| `tests/delivery-truth.sh:435` `printf '%s' "$out" \| grep -q queued` | 不会（内建单写） | payload 实测 15 B；同类形态换 18892 B 立刻 `rc141=10/10` | 判定成立，**前提是负载**（见 3.2-A） |
| `tests/smoke.sh:4343` `{ sed … \|\| true; } \| grep -qE …`（`pm_wait_delta`） | 不会（状态被吸收） | 10 万行生产者：带 `\|\| true` `rc141=0/20`，去掉 `\|\| true` `rc141=20/20` | 判定成立，且这个对照直接证明「吸收」有效 |
| `tests/tmp-hygiene.sh:1441` `printf … \| grep -A1 -F … \| grep -qF …` | 不会（中间级 < 8192 B） | 输入 2074 B，中间级输出 2069 B → `rc141=0/20` | 判定成立 |
| `tests/smoke.sh:18187`（`§36③`，**被改**） | 会（两级中间进程分块写） | 见 3.3：末级只吃 4 行收口行，真实日志 ≈0.4 KB | **理由不成立** |
| `tests/smoke.sh:18441`（`§36⑦`，**被改**） | 会（`sed` 吃 SIGPIPE，`!` 翻成假绿） | 形状成立（64 KB 日志上旧写法 20/20 假绿），但本段日志实测 390 B | 理由不成立于**这一段**，形状是真 |
| `scripts/lib/common.sh:5234`（BLOCKED） | 会，已实测 141 | 见 4.1：形状成立，产品调用路径今天 0/30，+1 KB → 30/30 | 事实成立，**严重度夸大** |
| `tests/panel-b3.sh:682`（BLOCKED，`cap()`） | 会（400 行一次抓） | 见 4.3：`tmux capture-pane` 早退仍 exit 0，`cap \| grep -q` 三次 `PIPESTATUS=(0 0)` | **判错**，无害 |

### 3.2 三类「不会」的理由逐类实测

```
A 内建单写：printf '%s' "$small" | grep -q         payload 15 B      → rc141=0/20
   同类边界：printf '%s' "$big"   | grep -q         payload 18892 B   → rc141=10/10
B 状态被吸收：{ seq 1 100000 | sed -n '1,$p' || true; } | grep -qE '^1$'   → rc141=0/20
   对照（去掉 || true）：同上                                              → rc141=20/20
C 中间级过滤：printf …（2074 B）| grep -A1 … | grep -qF …（中间级 2069 B）→ rc141=0/20
```

三类理由本身都成立。A 这一条值得补一句它自己已经写下的保留：**类的前提是负载，不是 `printf`**；我用 18892 B
实测到 10/10，正是它 §3.3 那句「谁以后把一份长日志塞进 `printf '%s' "$log"`，同一形状立刻回到 §3.2」的量化版本。

管道容量（判定的尺度）本机实测与它一致：

```
$ python3 -c "import fcntl,os; r,w=os.pipe(); print('F_GETPIPE_SZ', fcntl.fcntl(r,1032))"
F_GETPIPE_SZ 8192
```

### 3.3 两处「被改」站点的理由不成立（关键发现）

`§36③`（`smoke.sh:18187-18198`）末级的 `grep -qF "$SMOKE_RED_MARK"` 只吃**收口行**（`^#N `）——真实嵌套日志里
只有一行（`#1 decision=RUN`），约 0.4 KB，离 8192 有一个数量级；我构造的 31 KB 嵌套日志也只有 301 行收口行
（9.2 KB 的抽取文件，但那是**抽取后**的产物，不是管道里的负载）。旧写法在这个负载上不可能吃 SIGPIPE。

更要紧的是：**这条红标检查从 P98 起就是死断言**，与 SIGPIPE 无关。`SMOKE_RED_MARK` 带 ANSI
（`smoke.sh:307`：`"$(printf '  \033[31m✗\033[0m')"`），而被 grep 的是 `sed 's/\x1b\[[0-9;]*m//g'` **去色后**的产物：

```
close-line[1] as the file holds it: #1 decision=RUN    M-bM-^\M-^W          # 去色后是明文 ✗
does the de-colored extract contain the *colored* SMOKE_RED_MARK?  NO (never matches)
does it contain the de-colored form (what a working check would use)?  yes
OLD shape with a matching pattern: mark-seen=20/20  misread-as-absent=0/20  # 能匹配时旧写法是对的
```

也就是说：改前的失败形状（「带了红标被误读成没带」）在**这个**站点上从来没发生过；改动把管道换成文件（无害），
但**没有修到任何会红的东西**，新加的「收口行抽取为空」那条红在真实日志下也触发不了（日志必有一行 `#N`）。
这是一条**新守卫 × 死断言**的组合，按「净零守卫」的纪律（新守卫要替换或退役一个旧的）应当顺手把红标判据改成
去色形态，或把它退役。

`§36⑦`（`smoke.sh:18447-18462`）的形状是真的：`! sed … | grep -q '^== #'` 在 `pipefail` 下把 141 用 `!` 翻成 true。
我造了 64 KB 的早拒日志实测：

```
36⑦ log: 64718 bytes; header lines: 1
OLD shape: 'no headers' (false green, header exists)=20/20   'headers seen'=0/20
NEW shape: headers-seen(correct)
```

但**这一段实际的日志只有 390 B**（坏副本在跑任何段之前被拒，日志就是一个拒绝块）。所以：形状对、改法对、
本段的「会」不成立。

### 3.4 站点账不闭合

我用自己写的枚举器独立数了一遍（规则写明：git 跟踪的 `skills/teamsmith/**/*.sh`、拼 `\` 续行、跳过整行注释、
**引号里的 `|` 不切管道**、管道段上的 `grep` 带 `q` 旗标）：

```
改前 75ead3e3：产品码 19 处 + 测试 271 处 = 290 处（其中末级 grep -q：238 处）
改后 de497f52：产品码 19 处 + 测试 267 处 = 286 处（其中末级 grep -q：235 处）
```

报告报的是 241 → 238（差 3，正好是它改的三处）。两个数的口径不同（我把中间级的 `grep -q` 也算进来，它有 52/51 处
明确排除在外），所以「238」这个数**不能从树上按它写的规则独立复现**；能复现、也更要紧的是**产品面**：

```
报告 §3.2（会）+ §3.3（不会的 13 行）里点到的产品/库站点：13 处
我数到的产品面站点：19 处
差的 6 处，全在 scripts/lib/outbox.sh：
  488  printf '%s' "$1"     | grep -qE '^[[:space:]]*\[paste #…'            (team_box_mid_render)
  489  printf '%s' "$1"     | grep -qE '\[paste #… (lines|chars)\]'          (同上，完整形态一律不算)
  526  printf '%s' "$got"   | grep -qE '^…\[paste #N +K lines\]…'            (team_box_text_holds_only)
  535  printf '%s' "$got"   | grep -qE '^…\[paste #N C chars\]…'             (同上)
  801  printf '%s' "$craw"  | grep -q …                                        (确认期间复检)
  806  printf '%s' "$cbox"  | grep -qF "$ptext"                               (同上)
```

这六处的生产者是**输入框文本**（被 pane 大小约束）或消息正文，按它自己的「内建单写」前提大概率属于「不会」；
但它们**不在任何一组的清单里**，所以那句「3 + 5 + 233 = 241」只对它自己的枚举闭合，不对树闭合。
`outbox.sh` 这一段恰好是「消息正文/框文本」进管道的地方 —— 它 §3.3 结尾自己警告的形状，所以这六处至少该被
**点名**进「前提是负载」那一列，而不是消失。

## 4. 5 处 BLOCKED：事实与判断

### 4.1 `scripts/lib/common.sh:5234`（产品）— 真缺陷，但要**降级**它的严重度说法

形状成立，我独立复现了两种：合成标题流（目标在首行）随体量确定化 —— 12930 B 时 11/20 次 141，17230 B 起 20/20；
本仓 `docs/team/DECISIONS.md` 的标题流 16178 B，同形状直跑 **48/60** 次 141。

但「按本仓账本现在的体量…必吃 SIGPIPE」不成立，至少**走产品自己的调用路径**时：

```
直接调 team_done_phase_evidence P322 explore（TEAM_DOCS_ABS 指向本仓 docs/team）
  real ledger（标题流 16178 B）            false_negatives=0/30
  DECISIONS.md + 1 KB 标题                 标题流 17222 B → false_negatives=30/30
  + 3 KB / + 8 KB / + 20 KB（17292 B…36188 B）        → 30/30
```

（同一份数据、同一个两行管道，写成脚本直跑是 48/60 的 141；把判定嵌进产品那个函数——模式里带
`$(team_regex_escape "$id")`——就是 0/30。这个差异我复现了三次（交错运行 48/60 vs 3/60）但没有解释清楚，
所以结论只按**产品调用路径**的实测与 **+1 KB 翻转**给，不按推断给。）

判断：**产品缺陷，该修**。后果是 `team done` 的 explore 证据把「有 PM 接受记录」报成「没有」；修法与它建议的
一致（先落文件/变量再匹配）。严重度按实测写：今天走产品路径不现形，**标题流再涨 1 KB 就 30/30 必现**，属于
「边界即时」而不是「当前必现」。

### 4.2 `scripts/lib/cmd-status.sh:158`（产品）— 真缺陷，两条腿都要修

```
本仓 main 的 git log --format=%T --max-count=200：8200 B / 200 行
未缓存腿（git log … | grep -qx "$tree"）                rc141=30/30
缓存腿（printf '%s\n' "$_TEAM_PROT_TREES" | grep -qx）  lookback 200（8200 B）→ rc141=0/60
                                                        lookback 400（16400 B）→ rc141=60/60
                                                        lookback 800（32800 B）→ rc141=60/60
```

默认缓存开着（`team_scan_cache_on` 需 `TEAM_SCAN_CACHE=0` 才关），所以今天默认路径**恰好**在 8200/8192 上走钢丝：
8 B 余量，任何 `TEAM_SQUASH_LOOKBACK` 上调（它是文档化开关）都让两条腿同时 141。后果轻（squash 合并后的分支被
报成「领先 N」，收尾提示多一条噪音）但确定。判断：**该修**（两腿都先落变量），优先级低于 4.1。

### 4.3 面板夹具三处（`panel-b3.sh:682 / 1160 / 1183`，`cap()`）— 改判「无害」

`cap()` 是 `tmux -L … capture-pane -p -t … -S -400`（`panel-b3.sh:244`），生产者是 **tmux 进程**。实测：

```
capture: 41893 bytes / 401 lines            # 400 行滚屏、命中在首屏
cap | grep -qE 'row-[0-9]+ '   ×3           PIPESTATUS=(0 0) (0 0) (0 0)
shell 循环生产者 | grep -q（对照） ×3        PIPESTATUS=(141 0) (141 0) (141 0)
tmux capture-pane | head -c 10（硬早关）     PIPESTATUS=(0 0)
```

tmux 对 SIGPIPE 的处理让它早退时**仍然 exit 0**（写失败不致命），所以 `cap | grep -q …` 的管道状态是 `grep` 的，
不会 141，判定也不受影响。这也解释了它自己 §3.3 为什么把 `smoke.sh:19497` 的
`{ tmux capture-pane … || true; } | grep -q` 归进「状态被吸收」——同一类生产者，两处判定互相矛盾。
夹具侧可以顺手统一写法，但没有缺陷可修，不该占产品修复的档期。

## 5. 我跑了什么、没跑什么

**跑的**（全部在候选 `de497f52` 的独立克隆上：`/var/tmp/v84/cand`，`git clone --shared` 后 `checkout --detach`，
不走我的工作树）：

```
G1 00:27:49Z  --select 51，默认环境                rc=0  ✓26 ✗0  （§51 自身 ✓3，嵌套走查 254 条断言绿）
G2 00:45:31Z  --select 51，TMPDIR 导出             rc=0  ✓26 ✗0  （根 source=tmpdir）
G3 01:03:05Z  --select 41，候选                    rc=0  ✓154 ✗0 （§41 ✓93）
G4 01:23:37Z  --select 41，变异（等待永不记录命中） rc=1  ✓154 ✗1 （红行见 §2.2）
```

四次都走门禁锁，没有一次用 `TEAM_SMOKE_NO_LOCK=1` 绕过。**G3 在锁上排过队**：日志原文
`另一套全量 smoke 正在跑（kind=top pid=… cmd=smoke.sh agent=dev-bob … 已跑 1056s …）`，所以那 1232s 里大部分是排队，
段自己只用了 68s。每次跑完的日志留在 `/var/tmp/v84/logs/`。

**破坏试验**都在 `/var/tmp/v84` 的私有副本里（`mini`（候选的 `skills/` 整拷，换旧 `routes.sh` 或改产品优先级）、
`mut41`（克隆 + 一处变异）、`f36`（自造 31 KB / 64 KB 日志的假语言）、以及 `docsbig`（给真实账本加标题的体量实验）），
候选树与我的工作树都没有被写过一行代码。

**没跑的**：整套 `smoke.sh`（任务书只要求选段）；`panel-b3`/`panel-b2`/`panel-p21` 三个面板夹具（不在写集，
且 §4.3 已判无害，跑它们只会多花一小时）。

## 6. 边界与交回

- 只写了本报告（`docs/team/reports/V84-verify.md`）与本席位线程；候选代码一行未改，`git status` 除报告外干净。
- `BLOCKED:` 两处**产品码**需要 PM 派单（都不在我的写集）：
  1. `skills/teamsmith/scripts/lib/common.sh:5234-5236` — 先落再匹配；严重度按 §4.1 的实测写（+1 KB 即必现）。
  2. `skills/teamsmith/scripts/lib/cmd-status.sh:155,158` — 两条腿一起改；默认 8 B 余量，lookback 上调即 141。
- 面板夹具三处（`panel-b3.sh:682/1160/1183`）**不需要动作**（§4.3 实测无害）；若 P327 顺路换等待引擎，可统一写法。
- 给同族清扫留一句：**方法**（生产者会不会在读端退出后继续写）值得留成纪律；**站点账**若要当「全树已清扫」的证据，
  得按一个写明的口径重新枚举，并把 `outbox.sh` 的六处列进「前提是负载」那一列（§3.4）；
  `§36③` 那条红标判据要么改去色形态、要么退役（§3.3）。

---

# 第二轮：返修增量（候选 `553ef655`）

time: 2026-10-21T03:30Z · 增量：`smoke.sh` +18/−5（只动 §36③ 那一段与注释）+ 报告口径 · 我的复看树是
`553ef655` 的独立克隆（`/var/tmp/v84/c2`），变异树是同树拷贝 + 一行（`/var/tmp/v84/c2m`）。

**判定：PASS。** 三件都成立。

## 7.1 正向对照真的有牙（本轮核心）

改动：`SMOKE_RED_MARK` 自带 ANSI，被 grep 的却是去色后的文件 —— 上一轮我判这条断言**两版都是死断言**。现在匹配串
也过同一道去色（`P98_RED_PLAIN`），并加一条正向对照：把真标记去色后写进合成行，匹配器必须认出来，认不出就点名
「红标匹配器是死的」。方向一：门禁里换回 ANSI 匹配器必须红；方向二：还原必须绿。

```
R1  [2026-10-21T03:01:23Z]  c2（= 553ef655）  env -u TMPDIR bash skills/teamsmith/tests/smoke.sh --select 36
    ✓ 36③ 收口行不带门禁红标（匹配器已由正向对照证明活着）
    #5 36 · 选段与分段账本自检 · 参考 用时 900s · ✓121 ✗0 SKIP3
    账本自查：增量 ✓144 ✗0 ｜ 结果行 ✓144 ✗0 —— 一致
    == 选段结果 ==  ✓ 144  ✗ 0                                        R1 rc=0

R2  [2026-10-21T03:16:29Z]  c2m（同一棵树，仅 18201 行 `$P98_RED_PLAIN` → `$SMOKE_RED_MARK`）
    ✗ 36③ 红标匹配器是死的（正向对照没命中：  ✗ 在带真标记的行里没找到）
    #5 36 · … · ✓120 ✗1 SKIP3 ｜ 账本自查：增量 ✓143 ✗1 ｜ 结果行 ✓143 ✗1 —— 一致
    == 选段结果 ==  ✓ 143  ✗ 1                                        R2 rc=1
```

两棵树的唯一差异就是那一行（`diff -r c2/skills c2m/skills` 只有这一处）。**R2 的 143 个 ✓ 一个没少**：红只落在
新加的对照上，没有级联，也就是说这条红点名的就是「仪表死了」本身。

为了看清这条断言的**三个出口**都够得着（而不只是「换回 ANSI 会红」），我把 `smoke.sh:18196-18207` 整块原文抽出来，
在四个现场各跑一次（`$TMP`、`$SMOKE_RED_MARK` 按套件的真实来源注入，`ok`/`bad` 只做打印）：

```
--- 活的匹配器（候选原样） ---
干净收口行              ✓ 36③ 收口行不带门禁红标（匹配器已由正向对照证明活着）
收口行带真红标          ✗ 36③ 收口行带了门禁红标（会污染 flip-m33 的红标计数）
一行收口行都没有        ✗ 36③ 收口行抽取为空（没有一行 ^#N）—— 红标检查因此没有前提
--- 匹配器换回 ANSI（R2 的变异） ---
干净收口行              ✗ 36③ 红标匹配器是死的（正向对照没命中：  ✗ 在带真标记的行里没找到）
收口行带真红标          ✗ 36③ 红标匹配器是死的（…）
一行收口行都没有        ✗ 36③ 收口行抽取为空（…）
```

`✗` 标记的字节：`033 [ 3 1 m 342 234 227 033 [ 0 m`（即 `ESC[31m✗ESC[0m`），去色后是 `  ✗` —— 与上一轮我量到的
「带 ANSI 的串拿去 grep 去色文件永不命中」同一个事实，现在被这道对照挡住了。**要点成立**：上一轮的两版死断言，
现在是「脏现场必红（第二行）、干净现场才绿（第一行）、仪表坏了必红（后段）」。

## 7.2 管道那半仍在，现场也复现了

代码没退回管道：收口行那一行是 `sed … | grep -E '^#[0-9]+ ' > "$TMP/p98-close-lines.txt"`（末级**写文件**，
不是 `grep -q`），对照行同样是 `printf … | sed … > 文件`，判据一律读文件。

「中段一多就翻」我自己扫了一遍（旧形状 `sed … | grep -E '^#[0-9]+ ' | grep -qF <标记>`，标记在**第一条**收口行，
后面跟 1200 行正文，每档 60 次）：

```
close_lines=20   middle_output=571  B   OLD rc141=0/60
close_lines=50   middle_output=1471 B   OLD rc141=0/60
close_lines=100  middle_output=2972 B   OLD rc141=0/60
close_lines=150  middle_output=4522 B   OLD rc141=59/60
close_lines=200  middle_output=6072 B   OLD rc141=59/60
close_lines=250  middle_output=7622 B   OLD rc141=60/60
close_lines=300  middle_output=9172 B   OLD rc141=59/60
```

窄行（~12 B）再扫一遍确认边界不在条数而在字节：1931/2171/2291/2411/2651 B → 全 `0/60`。
所以界线是**中间级的 4096 B stdio 刷写**（与报告「中间级按 4 KB 刷写」一致），不是管道容量（本机
`F_GETPIPE_SZ=8192`）。他们写「200 条收口行 44/60」，我这一侧 200 条（6 KB）是 59/60：同一现象，我量到的更严重，
不是更轻 —— 这条修复该留。

## 7.3 我上一轮点的另两件

**(a) `outbox.sh` 六处进表了。** 报告新增 §3.0 交代漏账原因（判据要求「管道后那一段以 `grep` 开头」，而
`outbox.sh` 写作 `printf … | LC_ALL=C grep -qE …`，段首是 `LC_ALL=C`），改正后 §3.2 逐条列出
`488/489/526/535/806/801`（会）+ `732`（不会），并写明「产品面 19 = 第一轮的 13 + 这 6」——**与我独立数到的 19 完全一致**。
我抽三条按产品原样命令重测：

```
488  printf '%s' "$1" | LC_ALL=C grep -qE '^…\[paste #[0-9]+ [+0-9]+…$'
       首行是半成品占位符 + 33 KB 尾巴   rc141=40/40     （无命中时 0/40）
526  printf '%s' "$got" | … grep -qE '^…\[paste #N +K lines\]…'
       首行占位符 + 33 KB                rc141=40/40
732  printf '%s' "$now_txt" | tr -d '[:space:]' | grep -qF …
       命中在首行、28 KB / 204 KB        rc141=0/40、0/40
```

488 那一行值得补一句精度：**条件是「早命中 + 长尾巴」**，不是「载荷大」（无命中的 33 KB 是 0/40）——
`team_box_mid_render` 要判的正是「框里就是那个半成品占位符」，所以这个条件在它身上是常态而不是巧合。

**(b) `§36⑦`：本轮代码没动，改的是口径 —— 这点必须点名。** 第二轮 `smoke.sh` 的改动只落在 §36③（`git diff
de497f52..553ef655` 只一个 hunk），§36⑦ 的「先落文件」修复是**第一轮**就进去的（`smoke.sh:18447-18462`），所以本轮
没有代码可补；报告把它从「笼统的会」改成「该红的方向上 60/60 是 141 → `!` 翻成假绿」，这个新口径与我自己的量法吻合
（64 KB 早拒日志下旧 `! sed … | grep -q '^== #'` 20/20 假绿，新形状认得出段头）。也就是：**口径修正而非补修**，且
修正后的口径我验过是对的。

**(c) 一处仍不闭合（不影响 PASS，但记下来）：** 报告总数「244 个站点」（改前 247）与我按同一句话数的数还对不上
——我数到的末级 `grep -q` 是 235（改后）/238（改前），把中段 `grep -q` 也算上是 286/290。产品面两边已经一致（19），
所以我只把它记为口径差，不当成账不闭。
