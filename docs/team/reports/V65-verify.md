# V65 · 独立复核 npm 入口与既有 selector 契约（verify）

agent: verify   status: PASS（第二轮收口）   time: 2026-10-20T04:11Z（报告提交 `ce40fc28`；第二轮实测窗口 04:10Z）
status（历史）: PARTIAL（第一轮，2026-10-20T04:01Z，报告提交 `2006f71a`；唯一原因是当时的 F1 文案缺陷 —— 见 §7 与 §10）
branch: `task/V65-npm-entry-review`   PR/MR: -（local 模式）
受检对象：P321 冻结提交 `b5cfdfaacb3035cb1ee6e14de94b54478a23628c`（作者 dev3，不是本席位）
独立检出：`/var/tmp/v65/pm-skills-v65`（本仓 `git clone` 后 checkout 到该提交；`git rev-parse HEAD` = 上述全串；
三次门禁跑完后 `git status --porcelain --untracked-files=all` 为空、HEAD 未变）
独立日志：`/var/tmp/v65/{sg,sg-break,is-pack,indep,symshape}.log`（都在我自己的 /var/tmp 目录，未进仓库）

## 结论

**安装物与判定这一面 PASS，且是我自己从 tgz 装出来测的，不是复述作者读数**：冻结树 `npm pack` 的 tgz 携带
`pkill/killall/pgrep/pidof` 四个 755 普通文件（672 B，字节相同）+ `signal-gate`；装进隔离 prefix 后，gated PATH
里四个名字全部解析到安装包的 shim；十种选择形态各自 exit 64、stdout 为空、同名后端一次都没被调用（10 行
`act=refused`）；放行形态把 argv/stdout/stderr/非零状态原样带回（`pgrep --help` rc=3/`sel-out`/`sel-err`、
`pgrep -P 12` rc=7/`42`、`-fc` rc=1/`0`、`-c -f` rc=0/`2`）；`TEAM_SIGNAL_REAL` 钉在 pkill 上时 `pgrep --help`
仍然只落同名 pgrep 后端。把一次性副本的四个入口退回 0.3.0 的软链形状后，同一条安装检查变红并点名
`pkill killall pgrep pidof`（rc=1），而对照树是 ✓。

**唯一的保留项 F1（PARTIAL 的原因，交回 dev3）**：闸门的拒绝诊断与头注释把 `pgrep -g N` / `-P N` 说成
「不选择进程的只读形式」。它们恰恰是**输出 PID 列表**的选择形式，spec 对它们的定性是「诊断，不是所有权证据」。
见 §7，证据与改法都在那里；其余各项（四入口共享一份实现、按整 argv 判定、空 stdout/64、显式组/父与计数放行、
同名后端解析、pkill pin 隔离）逐条成立。

**证据改了什么**：
1. 「npm 包会带四个入口且装完判定生效」从作者的自述变成我这边可复演的实测（§3）—— 这一面 PM 可以直接采信；
2. 「入口退回软链形状 → 安装检查必红」有牙齿且具名（§4），不是「只查文件在不在」；
3. 被任务书点名的三条额外分支（门禁目录跳过、pin 不进闸门目录、软链兼容）各有实测必要性（§5）：
   删掉前两条会进入无界 `exec` 递归（`timeout` 收在 124）；
4. 覆盖增长 211 条逐段对上 spec 的九条既有场景；其中 56 条是两个文案模板的重复，所以「279 > 68」本身
   不是质量证明，但也不能按数量删（§6）；
5. F1 是本次唯一改变判断的发现：功能面 PASS，文案面未达任务书第 5 条 → **PARTIAL**。

## 1 · 受检面

```
$ git diff --name-status a586b4a7 b5cfdfaa
A	docs/team/reports/P321-dev3.md
T	skills/teamsmith/scripts/shim/killall
T	skills/teamsmith/scripts/shim/pgrep
T	skills/teamsmith/scripts/shim/pidof
T	skills/teamsmith/scripts/shim/pkill
M	skills/teamsmith/scripts/shim/signal-gate
M	skills/teamsmith/tests/install-shape.sh
M	skills/teamsmith/tests/signal-gate.sh
$ git diff --shortstat a586b4a7 b5cfdfaa
 8 files changed, 591 insertions(+), 41 deletions(-)
$ git diff --check a586b4a7 b5cfdfaa; echo rc=$?
rc=0
```

- 入口形状：git 模式下 `120000 → 100755` 的四次类型变更（`T`），四个文件**字节相同**
  （`sha256 32da82e4…` 一行四次），内容只有「把自己的名字 + 原始 argv 交给同目录 signal-gate」那一条 `exec`。
- 判定与记录仍只有一份实现：diff 里没有任何第二份 gate、没有 postinstall、没有新环境变量分支
  （闸门只读 `TEAM_SIGNAL_CALLS_LOG` 与 `TEAM_SIGNAL_REAL` 两个既有 pin）。
- 八个改动文件里没有新的套件/静态守卫/产品钩子，也没有规格文件；`pgrep`/`pidof` 的选择器契约本来就是
  `boundary#Signals go to a recorded pid…` 的既有要求，本次是**恢复**，不是新增守卫。

**丢失的是什么（红前，我在 `a586b4a7` 的闸门 + 四个软链入口上实测）**：

```
$ <P321 之前的 gate> 在软链形状上（四个同名软链 + 同名 argv 记录桩）
pgrep --help      rc=2  stderr=[本文件只应以 pkill / killall 的名字被调用（当前 pgrep）]  log-lines=0
pgrep -g 42       rc=2  同上                                                          log-lines=0
pgrep -P 12       rc=2  同上                                                          log-lines=0
pgrep -fc marker  rc=2  同上                                                          log-lines=0
pidof --help      rc=2  同上（当前 pidof）                                             log-lines=0
pgrep -f marker   rc=2  同上                                                          log-lines=0
后端调用：0
```

也就是说冻结前不是「拒绝得太严」也不是「放得太宽」，而是**没有判定**：入口在、判定不在，每次调用直接以 2 退出，
不记行、不解析后端、也不给诊断。仓库里的三个真实调用点因此在窗口里拿到空答案：`common.sh` 的进程组存活
（`pgrep -g`）、`tests/panel-cpu.sh` 的父进程查询（`pgrep -P`）、`smoke.sh` 的计数断言（`pgrep -fc`）。
冻结提交把这三类形态恢复成 64/放行两条正经判定 —— 这是本任务「既有契约」四个字的实际含义。

## 2 · 第一轮门禁实跑（我自己的检出于 `b5cfdfaa`；`fa030b22` 的复跑见 §10）

```
$ bash skills/teamsmith/tests/signal-gate.sh; echo rc=$?
== signal-gate 结果 == ✓ 279  ✗ 0
signal-gate 全绿
rc=0

$ bash skills/teamsmith/tests/signal-gate.sh --break=pass; echo rc=$?
== 红侧（--break=pass）==
红侧成立：143 条断言变红 —— pkill -f <marker> 退出 64（期望 [64]，实际 [0]）, …
（这就是断侧该有的结果：闸门放行 → 真身被调用、诱饵被收掉、exit 不再是 64）
rc=1          ← 这是已知负向入口，1 才是红侧成立的判据，不是「正常命令失败」

$ bash skills/teamsmith/tests/install-shape.sh pack; echo rc=$?
  ✓ 声明面：一个 bin 键（team → bin/team.mjs）+ files 带 bin/
  ✓ 打包清单：bin/team.mjs + 两个 SKILL.md + install.sh，不含账本：清单齐全（289 项）且不含账本/node_modules
  ✓ 私有 prefix 安装：version/help 与四个信号入口都来自安装物：…四个信号入口在且判定生效
  ✓ 反向守卫（M7.2）：整轮夹具没往真实仓库收件箱写一个字节
== 结果 ==  ✓ 4  ✗ 0  SKIP 0
rc=0
```

`--break=pass` 复用了现成反例（把闸门副本的 `_act="refused"` 改成 `pass`），没有另列永久变异表；
红侧里 pgrep/pidof 新增段逐条由绿变红（拒绝不再是 64、日志行变成 `act=pass · tool=pgrep`、同名后端开始收到调用）。

## 3 · 我自己从 tgz 装出来的安装物

```
$ npm pack <受检树>                       # cwd 在一次性目录，未写受检树
pack rc=0
$ tar -tvf teamsmith-0.3.0.tgz | awk '$6 ~ /scripts\/shim\/(pkill|killall|pgrep|pidof|signal-gate)$/'
-rwxr-xr-x 672 package/skills/teamsmith/scripts/shim/killall
-rwxr-xr-x 672 package/skills/teamsmith/scripts/shim/pgrep
-rwxr-xr-x 672 package/skills/teamsmith/scripts/shim/pidof
-rwxr-xr-x 672 package/skills/teamsmith/scripts/shim/pkill
-rwxr-xr-x 13332 package/skills/teamsmith/scripts/shim/signal-gate
$ npm install -g --prefix <隔离 prefix> ./teamsmith-0.3.0.tgz; echo rc=$?
install rc=0
$ 安装物 shim 目录里四个名字：pkill file 775 672 / killall file 775 672 / pgrep file 775 672 / pidof file 775 672
$ 四个入口 sha256 去重行数：1
$ gated PATH 里 command -v（四个名字全部 = <prefix>/lib/node_modules/teamsmith/skills/teamsmith/scripts/shim/<名字>）
```

行为（后端一律是我自己的同名 argv 记录桩，没有对任何真实进程发信号；`env -u TEAM_SIGNAL_REAL` 显式钉）：

```
拒绝（10 种）：pkill -f marker / killall sleep / pgrep -f marker / pgrep sleep / pgrep -x sleep /
              pgrep -g 0 / pgrep -P 12 -v / pgrep -fc / pidof sleep / pidof -s sleep
  每条 rc=64、stdout=[]、首行诊断点名工具；后端零调用；日志 10 行 act=refused
放行：
  pgrep --help   rc=3  stdout=[sel-out] stderr=[sel-err]  | STUB tool=pgrep argc=1 argv=--help
  pgrep -P 12    rc=7  stdout=[42]                        | STUB tool=pgrep argc=2 argv=-P 12
  pgrep -fc marker rc=1 stdout=[0]                        | STUB tool=pgrep argc=2 argv=-fc marker
  pgrep -c -f marker rc=0 stdout=[2]                      | STUB tool=pgrep argc=3 argv=-c -f marker
  → 日志两行 act=pass · tool=pgrep（argv 原样）
pkill pin 隔离（TEAM_SIGNAL_REAL=<backends>/pkill）：
  pgrep --help rc=5 stdout=[99]；pin 目标收到的唯一一行是 WITNESS tool=pgrep argc=1 argv=--help
  → 放行的诊断调用没有被路由到 pkill 上
```

拒绝路径没有执行后端这一点不看返回值猜，看的是后端自己的记录文件：全部拒绝之后该文件仍不存在/零行。

## 4 · 软链形状翻转（一次性副本，受检树未动）

```
$ git clone --shared <受检检出> <一次性副本> && git checkout b5cfdfaa
$ 把四个入口 rm 后 ln -s signal-gate …（恢复 0.3.0 的 120000 形状）
$ TEAM_INSTALL_TREE=<一次性副本> bash <副本>/skills/teamsmith/tests/install-shape.sh pack; echo rc=$?
  ✓ 声明面：一个 bin 键 …
  ✓ 打包清单：…（285 项）…
  ✗ 私有 prefix 安装：version/help 与四个信号入口都来自安装物：安装包没有携带信号闸门入口
    （npm 丢 120000 软链的历史形状）：pkill killall pgrep pidof
  ✓ 反向守卫（M7.2）…
== 结果 ==  ✓ 3  ✗ 1  SKIP 0
rc=1
```

对照：同一提交的真实树 `pack` 段 ✓4 ✗0（§2）。同一判据在「有入口」与「入口退回软链」之间翻转，且红侧点名了
缺哪四个名字 —— 不是只查文件存在。为确认这个机制本身（而不是靠作者叙述），我用一个最小包实测了 npm 的打包行为：

```
$ tar -tvf v65-symlink-probe-0.0.1.tgz | awk '{print $1, $6}'
-rwxr-xr-x package/dir/real
-rw-r--r-- package/package.json          # 包里的 dir/link（软链）没有出现在 tarball 里
```

## 5 · 被点名的三条额外分支：各有实测依据

都在 /var/tmp 的一次性副本上做，受检树冻结未改：

| 分支 | 删掉之后（一次性副本实测） | 保留时 |
|---|---|---|
| 后端查找「跳过闸门目录」 | `pgrep --help` → `timeout 3` 收在 **rc=124**（wrapper → gate → wrapper 无界 exec），后端 0 调用 | 后端收到 `argv=--help` |
| `TEAM_SIGNAL_REAL` 必须不在闸门目录 | `TEAM_SIGNAL_REAL=<gate>/pkill` + `pkill --help` → **rc=124** 同类递归 | pin 被跳过，PATH 后端收到 `argv=--help` |
| 历史软链形状兼容 | （今天 main 的树仍是 `120000` 入口，见 §1） | 软链形状上 `pgrep --help` / `pgrep -P 12` / `pkill --help` / `pkill -V` 全部放行且 argv 原样，拒绝形态仍 64 |

补一条现场依据：本席位窗口的环境里 `TEAM_SIGNAL_REAL=/usr/bin/pkill`（launch 钉的），也就是「pin 通常钉在
pkill 上」不是推测；选择器忽略这个 pin、按自己名字解析，正是为了不把放行的诊断调用变成换名字的信号工具。

## 6 · 覆盖增长：211 条新增断言分别守什么

```
68（P321 之前）→ 279（现在），新增 211，按段分布：
  42  PID 产出的选择形态全部拒（10 形态 × 4 + 2 汇总）
  73  隐式/部分匹配与额外谓词不能放宽（18 形态 × 4 + 1 汇总）
  32  显式 group/parent 与三种整命令计数（-g 5、-P 3、6 次 -fc 调用 × 4）
  28  只读信息词走各自同名真身、旧 pkill pin 不接线（2 工具 × 4 词 × 3 + 4）
  13  选择器拒绝走同一份记录、熬得过轮转（2 × refuse_sel 4 + 5）
  10  拒绝不看 pin、也不看继承环境（2 腿 × 2 形态 × 2 + 2）
   5  保留写失败可见、不改判定、不挂住
   5  闸门之外的只读工具照旧直通、不记行
   3  被拒的替换不交出 pid
```

- 这九段与 `boundary#Signals go to a recorded pid…` 下新增的九条场景**逐条对上**（场景标题就是段标题）：
  每条都是既有契约的一个面，没有一条是为了凑数新造的守卫。
- 独立判定的部分：10 + 18 个形态是 28 个不同的分类输入（`-g 0` vs `-g 12`、`-fcl` vs `-fc`、
  `-P 12 -u 1000` vs `-P 12` 都是只差一个词的近失形态，靠同一段 `case` 的不同分支才被挡住）；
  6 次 `-fc` 调用就是 spec 明写的「两种响应 × 三种拼写」；2 工具 × 4 个信息词也是 spec 明写的逐词要求。
- 重复的部分（这点上不同意用断言数当质量证明）：28 个拒绝形态 × 4 条断言 = 112 条评估，其中「诊断里点名完整
  argv」和「日志行记 `tool=`」两条是对**同一个 printf 模板 / 同一个日志格式判定**的重复 —— 56 条评估只是换了插值，
  没有新行为；而「后端零调用」「N 次调用 N 行 refused」两条汇总断言已经在集合层面覆盖了每形态的日志效果。
  56 / 211 属于模板重复，剩下 155 条才是九条场景各自的行为。
- 结论：不按数量删（恢复的正是曾经丢失的安全契约），但「279 > 68」本身不构成质量证明。

## 7 · F1（PARTIAL 的唯一原因）· 拒绝诊断把 PID 列表说成「不选择进程」

**现场（冻结提交）**：

```
signal-gate: 拒绝 pgrep 时打印：
  pgrep 只放行不选择进程的只读形式：`-g <正整数>`、`-P <正整数>`、`-fc <命令>`（整命令计数，只出个数不出 PID 列表）。
signal-gate 头注释：
  放行的是**不选择任何进程**的只读形式：… 加上 pgrep 的 -g N / -P N（N 是显式正整数）与三种「整命令计数」拼写…
```

**反证（真实 /usr/bin/pgrep，无害调用，只读）**：

```
$ sleep 5 & child=$!; /usr/bin/pgrep -P $$          → 打印 child 的 PID（一行）
$ /usr/bin/pgrep -g <当前进程组>                     → 打印 4 个 PID（161622 161685 161688 162677）
$ /usr/bin/pgrep -fc <某命令行>                      → 打印 60（只有计数）
```

`-g` / `-P` **输出 PID 列表**；只有 `-fc` 三种拼写才是「只出个数」。spec 的定性也正是这两句话：

- 「A parent/group query is diagnostic, not proof that its returned PIDs were recorded by a spawner.」
- 「A count is not a PID. Neither permits signalling by predicate.」

现在的文案把前半句丢了，只剩「不选择进程」——看这条诊断的 agent 会把 `-g/-P` 返回的 PID 列表读成「不是 PID 列表」，
而这恰好是 spec 逐字否定的方向。任务书第 5 条点名的就是这句（「诊断文案不应把会输出PID列表的 `pgrep -g/-P`
说成'不选择进程'」）。

**要改成什么**：把 `-g`/`-P` 表述成「允许的**诊断查询**：输出 PID 列表，但那不是记录过的身份、不授予任何信号权限」；
`-fc` 保持「只出计数」。两处（拒绝诊断的一行 + 头注释那一行）一起改，语义与 spec 对齐。

**谁改**：`skills/teamsmith/tests/` 面之外的 `skills/teamsmith/scripts/shim/signal-gate` 在 OWNERSHIP 里冻结给
dev3（P321 待独立复核，返修仍归 dev3），本席位按红线不改实现 → 交回 PM 派 dev3 返修。

**影响面**：只有文案（消息 + 注释）。测试没有断言这句话（`grep -c '不选择进程' signal-gate.sh install-shape.sh` = 0），
所以返修不需要动夹具，也不会改变任何判定、记录或退出码。

## 8 · 没跑的与边界（明说，不当成通过）

- **没跑** `smoke.sh` / FAST / 发布自检全套 / 模型路由 / CI（任务书明确不要求）。`smoke.sh` 的 §31c（渲染 PATH 里
  `pgrep`/`pidof` 解析到闸门目录）、§39（入口就是 `install-shape.sh`）、§58（入口就是 `signal-gate.sh`）只做了
  只读核对：三个入口现在都是普通可执行文件，`command -v`/`-x`/`assert_file` 的判据形状不变。
- **没跑** `install-shape.sh` 全段与其他五条翻转（作者已跑全段 ✓144 ✗0；我只跑 `pack` 段 + 任务书授权的那一条
  软链翻转，并且是从真实 tgz 独立安装复核的）。
- **没跑** 跨平台（BSD/macOS）的 `pgrep`/`pidof` 选项语义：契约是「放行形态原样透传、不翻译状态」，本改动没有
  引入平台分支，但也没有在别的平台实测。
- 没有对任何真实项目进程发信号：所有「真身」都是同名 argv 记录桩；唯一的真实调用是 §7 那三条只读
  `pgrep`（`-P` / `-g` / `-fc`），只读列表与计数，不发信号。
- 没有改受检树、作者代码、产品、测试、规格、主分支或全局安装；三次门禁跑完后受检检出 `git status` 仍为空。

## 9 · 交付卫生

```
$ git diff --check a586b4a7 b5cfdfaa; echo rc=$?       # 受检差量
rc=0
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
（见本报告提交前的最后一次实跑，rc=0 hits=0）
```

本报告只新增 `docs/team/reports/V65-verify.md`；P321 分支与冻结提交未触碰。

## 10 · 第二轮（`fa030b22`）：F1 关闭 + 重复列合并

**受检增量**：`b5cfdfaa → b56fe460 → fa030b22`（作者 dev3；两个提交都在 `task/P321-npm-command-entry-repair`
上，最终 tip `fa030b221f5cf42d9c75a9c18c027fbed4602791`）。我的检出已切到该 tip，跑完 `git status` 为空。

```
$ git diff --stat b5cfdfaa fa030b22
 docs/team/reports/P321-dev3.md            | 64 +++++++++++++++++++++++++++--
 skills/teamsmith/scripts/shim/signal-gate | 18 +++++----
 skills/teamsmith/tests/signal-gate.sh     | 14 +++++--
 3 files changed, 81 insertions(+), 15 deletions(-)
$ 机械分类 gate 的 18 条变更行：comment lines=16 printf lines=2 other=0
```

**① F1 关闭（判定/后端/记录一字未动，只动文案）**。闸门的全部变更行只有注释与两处 `printf`，`other=0`
—— 分类、`_bounded_append`、`exec`、pin 解析、退出码都没有落进 diff。实跑一次 stub 拒绝取到的渲染文案：

```
✗ teamsmith 信号闸门：已拒绝 pgrep —— 名字或命令行模式**不是身份**，无法证明这些进程归调用者
  调用参数：pgrep -f x
  为什么：…
  pgrep 只放行三类形态，**都不授予信号权限**：
    · 帮助/版本：`--help` / `-h` / `-V` / `--version`（不选择任何进程）；
    · 显式 group/parent 的 PID 查询：`-g <正整数>` / `-P <正整数>`（输出 PID 列表）——
      结果是查询输出，不是任何记录过的身份；
    · 整命令模式计数：`-fc <命令>`（含 `-f -c` / `-c -f`）—— 按完整命令行模式匹配，
      只出个数不出 PID 列表。
rc=64
```

与 spec 的三句话逐条对上：`-g`/`-P` 是「diagnostic」且**输出 PID 列表**、结果不是记录过的身份；`-fc` 一族
「return only a count, not a PID list」；「Neither permits signalling by predicate」对应「都不授予信号权限」。
头注释同一口径。**§7 的 F1 关闭。**

`b56fe460` 中间态还有一句新写的总括「都不按名字/模式选进程」——对 `-fc` 不准确（它**正是**按完整命令行
模式匹配后计数）。`fa030b22` 把这句删掉、改成正面列三类形态；这句不是我在第一轮提的，但方向与 spec 一致。

**② 重复列合并（这是对我 §6 量化的直接回应）**。`refuse_sel` 去掉两列（诊断插值文案、记录行 `tool=` 模板），
两列移到既有的轮转段，在两次代表调用（`pgrep -f <marker>`、`pidof sleep`）上各验一次：

```
30 次 evaluate × 2 条被删 = 60；代表调用 +4 条；净 −56
223 = 279 − 56     87 = 143 − 56     （与 §6 量出的「56 条模板重复」逐条相等）
```

独立判定全部保留：28 个不同输入各自的 `exit 64` + 空 stdout、每段的「后端零调用」与「N 次调用 N 行 refused」
汇总、轮转与 `.forensics` 逐字节保留。没有新增 helper、开关、调用或脚本。

**③ 实跑（按任务书：只跑原来的正反入口，不重跑安装）**：

```
$ bash -n skills/teamsmith/scripts/shim/signal-gate; echo rc=$?
syntax ok rc=0

$ bash skills/teamsmith/tests/signal-gate.sh; echo rc=$?
== signal-gate 结果 == ✓ 223  ✗ 0
signal-gate 全绿
rc=0

$ bash skills/teamsmith/tests/signal-gate.sh --break=pass; echo rc=$?
== 红侧（--break=pass）==
红侧成立：87 条断言变红 —— …
（这就是断侧该有的结果：闸门放行 → 真身被调用、诱饵被收掉、exit 不再是 64）
rc=1
```

红侧里除了 28 个形态的分类判据照旧变红，**两条代表调用断言也各自变红**（「代表调用（pgrep）的理由点名
工具与完整 argv」「代表调用（pgrep）的日志行记 act=refused · tool=pgrep」，pidof 同）—— 合并后的那两列
仍然有牙齿，不是搬过去当摆设。（日志：`/var/tmp/v65/r2-sg.log`、`/var/tmp/v65/r2-break.log`。）

**④ 复用上一轮安装证据的前提我核了**：`git diff --name-only b5cfdfaa fa030b22` 恰好是上面三个文件 —— 四个
wrapper、`install-shape.sh`、`package.json` 逐字节未变，且闸门只改了注释与文案，所以上一轮「真实 tgz 里四个
入口都在、判定在安装物上生效」的结论对 `fa030b22` 仍然成立；本 tip 的 tgz 字节会因闸门文本而不同，
按任务书我没有重跑 pack/安装。

**⑤ 本轮判定：PASS**。F1（第一轮唯一保留项）关闭；我的 §6 量化被按「合并重复列、保留独立判定」落实；
正反入口在我自己的检出上复跑成立；产品判定面零改动。
