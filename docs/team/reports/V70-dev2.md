# V70 · CI 减重复：独立静态审（代码 + 现有失败证据）

task: V70   agent: dev2   phase: verify   change: `behavior-focused-ci`
specs: `verification#A changed-path list selects the sections to run, or the full suite`
branch: `task/V70-ci-reduction-static-review`（local 模式；本分支只放这份报告）
status: delivered（静态阶段结论；**不是**这次 change 的独立行为验收）
time: 2026-10-20T07:43:38Z（原判）；§十 的两条静态核对按 PM 07:40:36Z 的追加指令写于 2026-10-20T07:46:25Z；最终报告 ref 按 PM 07:41:37Z 的指定读 `e2b8631d`（相对 `762cd654` 只动报告与 `tasks.md`）
受检 ref：产品与测试面固定 `762cd654`（candidate `task/P326-behavior-focused-ci`），基点 `4eabb0f5`；
作者最终报告按 PM 07:41:37Z 的指定读 `e2b8631d` —— `git diff --name-only 762cd654 e2b8631d -- skills/ openspec/specs/ ci/ .github/`
为空（只改了 `docs/team/reports/P326-dev.md` 与 `openspec/changes/behavior-focused-ci/tasks.md`），所以产品读数对两个 ref 同一份。
方式：只读。**没有跑任何 smoke / probe / 变异 / 容器 / 计时实验**；所有数字来自现有日志与源码。

## 判定（先给答案）

**方案的东西成立，但当前不能进入合并**——理由不是「慢」，是三条可在磁盘上核对的缺口：

1. **C 的 5 处嵌套合并把「一次 run 的退出码」当成三段证据。** 冻结树上 36⑧ 的 11 条红里，5 条正是这种断言
   （`--select 31,58 退出 0` 被 §31、§58 各记一次）；基线树（`4eabb0f5`）上本来就有 8 条红，与本次改动无关（见 §五）。
   这违反了 design §4.2 自己写的「每条断言仍读自己那段的行」——现在读的是同一次运行的同一个 `$?`。
2. **唯一的整体运行（C4）不完整，且现场形状错误。** 2699 s 被 45 分钟预算停掉（rc143），只收口 96/133 段；
   而它的容器只把作者 worktree 挂到 `/work`，worktree 的 `.git` 指向宿主 Git 公共目录、该目录未挂入 ——
   于是「不是 git 检出」，0i/34c/34d 的 12 条红全部落在这一条环境形状上（10 条有直接日志，34c 的 2 条是推定；§三）。
   这些红既不能证明产品红，也不能证明产品绿。
3. **证据树落后 main 50 个提交**，且落后的三个测试文件里有 P318 round 2 —— 它的提交信息明说修掉了 §36 现在
   5 条既有红的那条 §58 lint 红。所以现有 §36 读数不能代表合入后的树（§五、§六）。

合并本身不会抹去 P318/P331：候选 diff 只有 10 个文件，与 main 自 fork 以来改过的文件**不相交**（§六）。

4. **PM 追加核的两条都在磁盘上成立**（§十）：11c 的 986 s 是**管道假阴性**——套件的 `set -uo pipefail`
   把「命中后 `grep -q` 早退、写端吃 SIGPIPE」读成 141，`!` 又翻回真，循环因此不认自己等到的状态；
   而 `gates.yml` 这条路径**没有任何行声明**、也没有任何段读它，改一次 CI 入口就是 `decision=FULL`，
   整套（含 61b 4946 s）跑不完 60 分钟 —— 本 change 自己的入口文件正好落在它解决不了的那条路上。

现有证据支持的最小修正 5 条，见 §七；无法从日志区分的 3 个问题交 PM 裁，见 §八；PM 追加的两条静态结论见 §十。

## 一、floor 与入口，逐项静态核对

全部对照 `skills/teamsmith/tests/section-paths.tsv`、`section-select.sh`、`smoke.sh`、
`.github/workflows/gates.yml`（均在 `762cd654`）。

| 判据 | 结论 | 证据 |
|---|---|---|
| 声明行只在一处 | 成立 | `section-paths.tsv:17` `# gate-self-check: 0e 0f 0g 0h 0i 36 61b`；`load_table()` 只解析这一行（`section-select.sh:141`） |
| floor = 未点名段 | 成立 | `do_floor()`（`section-select.sh:532–551`）按排除法构造：135 行 − 7 = **128** 段 |
| 新段默认进 floor | 成立 | 同一排除法；行整行删除时 `P_SELF_DECLARED=0` → 全部进 floor（安全方向） |
| floor 的 needs 闭包不会把自检拉回来 | 成立 | 表里所有 `needs` 键与 7 个声明键的交集为空（`... | grep -cE '^(0e|0f|0g|0h|0i|36|61b)$'` → 0） |
| 耦合组不会把自检拉回 floor | 成立（唯一的组是 14/14c） | 用同一条 `bash -n` 跨度规则重算：135 段 / 134 组，唯一的 2 段组是 `14 14c`，两者都在 floor |
| 空行 / 空 floor 不许静默变窄 | 成立 | `do_floor` 先 `die` 空地板（`:534–543`）；`--check` ⑧ 把「行在但为空」判红（`:785–788`） |
| `--check` ⑧ 的三种红 | 成立 | 重复点名、点名前导段、点名不存在段各一条 `cbad`（`:793–805`）；`row_idx` 找不到时输出空串 → 判红 |
| `--floor` 与 `--select` 互斥 | 成立 | `section-select.sh:58–60` 的 `--floor` 分支拒绝其它 MODE；`smoke.sh:133–136` 同规则 |
| 61 留在普通入口、61b 不在 | 成立 | 61 不在声明行；61b 在。61 的 patterns 含 `common.sh` 等产品面 → 产品改动会选到 61；61b 的 patterns 只有 `tests/task-model-routing.sh` 与 `tests/lib/model-routing-flips.py` |
| 61b 的保留入口 | 成立 | ①`--select 61b`；②`task-model-routing.sh --flip`；③合并/里程碑/发布的整套；④CI 里改到它自己那两个文件时由 `--paths` 选回 |
| 未执行段披露 | 成立（选择路径） | C4 头部 `decision=RUN · 运行 133/135 段 · 未跑 2 段`（`0g 61b`）；`smoke.sh` 的 `decision=` / 未跑清单 / `== 选段结果 ==` 三个披露串在 diff 里**一字未动** |
| `58` 的 `needs` 改成 `-` 的依据 | 成立 | §58 正文只读 `$SKILL_DIR/tests/*`、`$TMP` 与前导段已设的 `$TS_RUNNER`/`CHECKOUT_REPO_ROOT`；它自己的 `team bg stop` 记录由段内 harness 现写现用（`smoke.sh:22128–22249`） |

**一处局限（不是新缺陷，但本 change 没有解决它）**：`--paths` 落到 `FULL` 时跑的是**整套**，
`61b`（表内登记 4946 s）就在里面。也就是说「unclaimed 路径 / 不可解析基点」的推送仍会撞 60 分钟上限被取消 ——
与今天同形。提案只承诺「普通推送不再无条件付 61b」，这句话只在 claimed 路径上成立。

## 二、11c 的 1018 s：定位到唯一一条循环

C4 的段落账本第一条是 `1018s 11c`，其余最大 157 s。11c 自己的现场行给出了归属：

```
== #42 11c · agent 续跑是 PM 的事（pulse 不碰） == 2026-10-20T06:56:53+00:00
  现场（有界轮询 986s 内 roster 没看到「pi 已退出」）：窗口=[keep,keep,…pm,…,dev,] pane=[bash]
#42 11c … · 参考 用时 1018s · ✓15 ✗0 SKIP0 · ticks 15
```

对应的唯一一条昂贵调用在 `smoke.sh:6373`：

```bash
while [ "$R_WAIT" -lt 1500 ] && ! $TEAM roster 2>/dev/null | grep -qF "pi 已退出"; do sleep 0.2; R_WAIT=$((R_WAIT + 1)); done
```

- 每一次迭代跑一次**完整的 CLI**（`bash scripts/team roster`：读名册与 pane），不是读一个文件；
  1500 次 × 约 0.66 s ≈ **986 s**，与现场行吻合（当时 loadavg 11.75 / 32 核，机器上还有别的席位在跑门禁）。
- 同一行的注释写「有界轮询 roster 本身（**最多 5s**）」（`smoke.sh:6370`）。代码的界是 `1500 × 0.2 = 300 s`，
  实测是 986 s —— 界用**轮数**表达，真实时长随每次 roster 的成本漂移，注释的 5 s 与实现差两个数量级。
- 这段**不在本 change 的写集里**：`git diff 4eabb0f5 762cd654 -- skills/teamsmith/tests/smoke.sh` 里与 `11c`
  相关的改动行是 0。所以它是既有成本，不是本 change 引入；但它在 **floor** 里（不是自检段），因此它会被
  「每次推送都跑 floor」原样带进 CI，而 design §3.4 的 2113 s 预算是从记录里减出来的、从未包含这 1018 s。
- 必要产品行为不可因慢而删：这 15 条断言（roster 区分「窗口在但 pi 已退出」、resume/up --agents 续跑）是产品行为，
  慢的是那一次轮询。最小修正落在夹具（另开单，见 §八 Q1）。

## 三、现有失败证据的归因：一条环境形状 + 两条推定

**环境形状（已确认）**：容器的挂载来自 `/var/tmp/p326-c4.sh`：

```
-v "$REPO:/work:ro" -v "$C/tmp:/c4tmp"     # REPO=.worktrees/dev
```

而 `REPO/.git` 是**指针文件**：`gitdir: $HOME/…/pm-skills/.git/worktrees/dev` —— 那个目录没有挂进容器。
后果在日志里有两处独立证据：

```
c4.log 头部：注意：运行指纹不可用（/work 不是 git 检出）—— 本次不判「树在跑动中被改动」
c4.log #4 0d：✗ 冲突标记守卫：找不到受检的 git 工作树（/work/skills/teamsmith 不在仓库里？…）
```

**同根的红（有直接嵌套日志）**

| 红（C4 全量 ✗ 行） | 证据 | 归因 |
|---|---|---|
| `0i P310：深嵌套 TMPDIR 下照常跑…（期望 0，实际 1）`、`0i 夹具自报两条腿都对上`、`0i socket 路径 ? 字节` | `$HOME/.cache/p326-c4/tmp/teamsmith-flip-p310sock-…/green.log`：那条 leg 的嵌套门禁 `== 选段结果 == ✓22 ✗1`，唯一的红是 §0d 的同一句；`?` 是解析 `leg green：rc=0 · socket 路径 N 字节` 失败的结果 | 同根；3 条红是同一条腿的三个断言 |
| `34d①/②/③/④ shadow/正常退出码（期望 0，实际 1）` 共 6 条 | `…/teamsmith-smoke-work-…/p287-id/{del-shadow,swap-shadow-rm,swap-shadow-mv,entry-shadow,clean-1,clean-2}.log`：每份都只有 1 条 ✗，且都是 `冲突标记守卫：找不到受检的 git 工作树`，`== 选段结果 == ✗ 1` | 同根；它们的 `--select 3 / 0c / 0b` 都会带上前导 `0 0b 0c 0d` |

**同根，但只是推定（日志已被段自己删掉）**

| 红 | 证据 | 归因 |
|---|---|---|
| `34c 嵌套运行正常跑完…（期望 0，实际 1）` 与 `34c 红侧没兑现（rc=1，命中=[teamsmith-smoke.NseXhR]）` | 34c 的嵌套运行是 `--select 0b,0c`（`smoke.sh:16986`），同样带前导 §0d；但它的现场 `rm -rf "$P287C" "$P287C_TMP"`（`smoke.sh:17081`）在段尾执行完，C4 被停时已无日志 | **推定同根，未观测**。注意红侧的「平铺命中」本身是对的（`teamsmith-smoke.NseXhR` 就是 flat-name 的根），失败的是它对 `rc=0` 的附加要求 |

**尚不能归因的**：C4 里 12 条红全部落在上面两表，没有第三条来源。但这 12 条都产生在一个**判不了 git 的现场**上，
所以它们不构成任何产品结论 —— 既不红也不绿。

## 四、C4 的读数与它的三个缺口

| 项 | 读数 |
|---|---|
| 墙钟 / 退出 | 06:49:36 → 07:34:19，**2699 s**，rc=**143**（作者按 45 分钟预算停手） |
| 收口段 | **96 / 133**（收口用时合计 2601 s；第 97 段 `34d` 被杀时在跑） |
| 选择 | `decision=RUN · 运行 133/135 · 未跑 0g 61b`，keys=133 |
| 机器 | 宿主 loadavg 11.75 / 12.84 / 14.12，32 核（`p326-c4-floor.log` 头） |

三个缺口（都不是「再跑久一点」能补的）：

1. **选择的不是 floor。** floor = 128 段；C4 的 133 段因为把本 change 的路径喂了进去，额外拉进
   `0e 0f 0h 0i 36` 五个自检段（0g/61b 未跑）。design §3.4 说 C4「同时是 floor 的实测墙钟」——它测的不是 floor。
2. **§36 从未开跑。** 收口到 #96（34c）为止，§36 在源序里更靠后；所以「§36 在容器里多贵」这一轮没有读数，
   只有宿主 FAST 的 853 s（§五）。
3. **现场形状无效。** 见 §三：这一轮的红全部产生在「/work 不是 git 检出」的形状里。

## 五、36⑧ 在冻结 ref 上的读数（本 change 自己的自检）

作者自己的两份日志（`p326-gate-runs.log` 的 ①、`p326-probe-compare.log`）× 同一份探针：

| 树 | 读数 |
|---|---|
| `4eabb0f5`（fork 点，基线） | probe `rc=1`，988 s，`ok 138 bad 8` |
| `77babbc5`（= 冻结 ref 的代码面；`762cd654` 只改发布文档） | probe `rc=1`，629 s，`ok 136 bad 11` |

逐条归属（`p326-probe-compare.log` 的集合差 + 现场）：

- **5 条两边都有**（既有红，不是本 change 引入）：§58 在 scratch 产品面树上的 real-tree lint 红，
  明细是 `RED skills/teamsmith/tests/signal-gate.sh:410 kill @CMD@`（该处是**负例夹具**里 `kill $(pgrep -f …)`
  的字面量，`shell-lex.pl` 把它归一成 `@CMD@`）。
- **5 条只在候选树出现**：`⑤b --select 19,31,58 退出 0`（§19）、`⑤b --select 31,58 退出 0`（§31、§58 各记一次）、
  `⑨ --select 31,58 退出 0`、`⑩ --select 31,58 退出 0`。它们的根因就是上一条既有红 —— 合并后的 run 退出码被它染红，
  于是**三段共用同一个 `$?`** 的断言一起红。这正是 §一 判据表里「一次退出码当三段证据」的可观测后果。
- **1 条是路径差异，不是行为差异**：两边 `⑩ 影子…§58 仍红` 的文本里嵌了各自的现场路径，被集合差当成差异。

**关键**：main 上的 `dfafd317`（P318 round 2）提交信息写着
「Also fixes a real pre-existing §58 red: signal-gate used a literal kill with a substituted target, which the
signal lint forbids in tests/」—— 也就是说这 5 条「两边都有」的红**已经在 main 上被修掉，而候选树没有它**。
所以 §36 在冻结 ref 上红，不等于在合入后的树上红；现在不能拿它当产品结论，也不能当候选的否决理由。

## 六、候选 vs main：不会抹去 P318/P331，但证据树是旧的

```
$ git merge-base 762cd654 main                → 4eabb0f5
$ git diff --name-only 4eabb0f5 762cd654      → 10 个文件（下表）
$ git log --oneline 4eabb0f5..main -- <这 10 个文件>   → 空
$ git log --oneline 4eabb0f5..main -- skills/teamsmith/tests/signal-gate.sh …/team-bg-stop.sh …/panel-b2.sh
                                              → dfafd317（P318 round 2）、c4bc9ef9（P331）
```

候选 diff：`gates.yml`、`RELEASE-PUBLIC.md`、`SKILL.md`、`protocol.md`、`section-paths.tsv`、`section-select.sh`、
`smoke.sh`、`checkout-shape-probe.sh`、`perf.sh`、`openspec/changes/behavior-focused-ci/tasks.md`。

结论两条：① main 在 fork 之后**没有**改过这 10 个文件，所以 squash/merge 只会应用这 10 个文件的 diff，
P318/P331 的成果不会被抹去；② 反过来，候选树里 `signal-gate.sh` / `team-bg-stop.sh` / `panel-b2.sh`
比 main 旧两个提交，而 §58 与探针的 ⑩ 正好读这些文件 —— **本轮所有门禁读数都不是合入后树的读数**。

## 七、最小修正（按现有证据，不扩面）

1. **修现场形状，不改产品**：让容器能看见 Git —— 把 `<main>/.git` 只读挂到同一绝对路径（`gitdir:` 指针里那个），
   或 `TEAM_SMOKE_MARKER_ROOT` 指一个真仓库，或改用带 `.git` 的导出去跑。这一条不做，0i/34c/34d 永远红，
   而它们恰好是「§58 门禁锁」这类产品断言的现场。
2. **在合入后的树上跑那一次 C4**（先 `git merge main` 或对「main + 这 10 个文件」的临时树验证），
   不要用现在这棵落后 50 个提交的树；重点看 §58 的 5 条既有红是否随 `dfafd317` 消失。
3. **floor 的墙钟单独给**：`smoke.sh --floor`（128 段）一次，或如实把 C4 的选择写清并**不要**称它为 floor。
4. **删掉 5 条共享退出码断言**（`--select a,b,c 退出 0`）：各段自己的收口行断言已经在
   （§19 的 `✗0` 行、§31 的 `M28 真树` 行、§58 的 `signal-lint 判定` 行），保留它们，去掉重复计数的 `$?`。
   这是**减**断言，不新增守卫，符合净零。
5. **两处文字收口**：`skills/teamsmith/SKILL.md:305` 还写着「The **performance** red lines live in `tests/perf.sh`」
   ——与本 change 的新契约（只有读数、没有红线）矛盾，而 SKILL.md 在本 change 的写集里；
   delta 的 `**Migration**` 说「the three premise-`SKIP` scenarios retired」，实际退场的是 4 条 premise 场景
   （base 的 4/5/6/7 条 scenario 都以前提为 GIVEN），其中第 6 条「A skipped fixture is never reported as a passing one」
   的承接者是 `verification#A gate that cannot judge says so`，没有点名。

§十 的两条不在本 change 的写集里：11c 的管道判定与轮数界属夹具修复批次（§十·1）；`--floor` 的未声明路径兜底
需要 spec 决定（§十·2），改了就落在本 change 的写集里，但要 PM 先裁。

唯一后续入口：`git merge main` → 上面第 1 条的容器形状 → `--floor`（128 段）与
`--floor --paths <本 change 路径>`（133 段）各一次 → `--select 36` 一次。**不需要**再跑 §61b 或性能套件。

## 八、交 PM 裁的三个最小可区分问题（本任务不运行）

- **Q1 · 11c（§十·1 已把机制核成「构造性缺陷」，这里只剩一个残留判别）**：这一轮是「1500 轮耗尽」还是
  「最后一轮命中」——日志两者都能解释。一个最小判别：在 `smoke.sh:6374` 那行现场打印里加 `R_WAIT` 终值。
  但**修复不依赖它**：管道判定不可靠、界是轮数、注释写错三件事各自独立成立，都落在夹具，应进修复批次。
- **Q2 · FULL 兜底要不要动？** 具体案例已经落地（§十·2）：改 `gates.yml` 自身就是 `FULL`，整套跑不完，
  而这个文件今天没有任何段在读。§十·2 给了三个选项，推荐「`--floor` 遇未声明路径仍跑 floor、`--paths` 单独
  用时语义不动」——它要让 spec 里「unclaimed → full suite」跟着改，所以是产品决定，不是实现细节。
- **Q3 · floor 墙钟是合入前置还是合入后测？** design §3.4 自己没承诺「装得进 60 分钟」；现有 C4 也给不出这个数。
  若作为前置，需要第 1、2、3 条一起做；若不作前置，落单时应写明「floor 墙钟未测」。

## 九、未验证边界（如实）

- 没有跑 smoke / probe / 变异 / 容器 / 计时；§二–§五 的每个数字都来自上面点名的日志文件或源码行。
- 未验：合入后树的 §36 是否绿；floor 的真实墙钟；11c 的根因（Q1）；C4 未跑到的 36 段（含 §58、§61、§38）
  在钉死镜像里的时长；CI 的真实运行（本仓库本地模式，没有远端）。
- 本任务**不冒充**独立行为验收：完整验收要等修复批次的最终固定环境运行；本报告的「可合入」判定只能是
  **有条件**的（§七 五条）。

## 交付检查

```
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=/home/<user>/Documents/syncthing/Work/Projects/pm-skills/.worktrees/dev2 scope=published files=1867 hits=0 names=ok user=resolved
$ echo $?
0

$ git diff --check
（空）
$ git status --short
?? docs/team/reports/V70-dev2.md      ← 本报告；提交后即空
```

local 模式：分支留在本地，未 push、未开 MR。

## 十、PM 追加的两条静态核对（2026-10-20T07:46:25Z，无新实验）

### 十·1 · 11c 的管道假阴性：机制成立，且这份代码库已经记录过同族两次

PM 的方向是对的，静态核下来它是**构造性缺陷**。注意这与作者最终报告 `e2b8631d` 的 §C4-2 **不同**：那里写的是
「这里的读数是『慢』，不是『错』」，并建议「把界改回注释声明的量级、或让它 break 在与断言同一个条件上」——
两条都不成立（缩短 1500→25 仍是同一条 pipeline；「同一个条件」就是那条被判 141 的条件）。把这条明确成「假说」
并说「缩短界不足以修」的文字在 `e2b8631d` 之后的 `af58b620`；若归档口径取 `e2b8631d`，这条更正应记在它上面。机制如下：

1. 套件顶层 `set -uo pipefail`（`smoke.sh:16`），全文 `set +o pipefail` 出现 **0** 次 —— 11c 处在那条规则下
   （另有四处 `set -uo pipefail` 是各段自己的 heredoc 头部：`:3692`、`:12354`、`:16361`、`:18328`）。
2. `team roster` 在打出「○ pi 已退出」那行（`cmd-status.sh:445` 的 agent 行）**之后还有五行输出**：
   图例行 `:447`、三行说明 `:448–450`，以及在 `TEAM_SESSION` 非空时的一行 `team_dim`（`:451`）。命中之后写端一定还有写。
3. `grep -qF` 命中即退出并关闭读端 → 写端下一次 `printf` 撞 EPIPE、进程吃 **SIGPIPE**、退出码 **141**。
4. `pipefail` 把整条 pipeline 判成 141 → `!` 把它翻回**真** → 循环体继续跑（`sleep 0.2` + 计数）。
   也就是说：**字符串在，条件仍然成立**。命中反而让循环继续，这正是 1500 轮耗尽、紧接着那次
   **不带管道**的 `$TEAM roster >"$TMP/roster-dead.log"`（`smoke.sh:6378`）却通过的形状。
5. 这不是新发现：同一份 `smoke.sh` 已经为这个族写过两次墓碑 —— `:20632–20636`（「与 P28 的
   `printf | grep -q` 同族」）与 `:21144–21146`（「grep 命中即退 → 写端 SIGPIPE → pipefail 把真命中读成
   141 → 等待报「没出现」」），并且 §53 已经把**修好的形状**落在 `tests/lib/pty-wait.sh:88–96`
   （bash 内部匹配，不经外部写端）。11c 这一行没有跟着改，是唯一漏下的那一处：
   `grep -nE "while .*\| *grep -q" smoke.sh` → **1 命中，就是 `:6373`**。

边界：**「每一轮都假阴性」仍是一个时序竞态**——只有写端在 grep 退出前写完，pipeline 才会是 0。
所以本报告不说「必然」，只说「判据不可靠」，而修复不依赖这个竞态：把匹配改成先取输出再判
（或复用 `pty-wait.sh` 的 bash 内部匹配）、把界改成按时间（现在是 `1500 × 0.2`，注释写「最多 5s」），
并在退出时打印 `R_WAIT` 终值。**这三样都在夹具里，不属本 change 写集**，应落在修复批次。

### 十·2 · 改 CI 入口自身 → `FULL`：目标缺口，且这个文件今天没有任何段在读

- 表里**没有任何一行声明 `.github/**`**（唯一提到 `ci/` 的是 `14b` 的 `ci/Containerfile`）；作者最终报告
  `e2b8631d` 的「未观测边界 / 待 PM 裁定」也点了这条，并说明写集没授权给它补 patterns。
- 作者自己的日志已经量到它：`p326-gate-runs.log` 的「（对照）workflow 自己那条路径 → `decision=FULL`
  sections=135 keys=0」。
- 于是：改 `gates.yml` 的推送 → `--floor --paths .github/workflows/gates.yml` → `FULL` → 135 段全跑，
  **含 61b（表内登记 4946 s）** → 60 分钟上限内跑不完 → 被取消，没有判定。这正是 change 的 Why 里
  「CI 已经跑不完」那件事，而它发生在 change **自己的入口文件**上。
- 静态核对补上两点是那份报告没有的：① `git grep -n "gates\.yml" 762cd654 -- skills/ ci/ .github/` 只命中
  `skills/teamsmith/CHANGELOG.md:158` 一处历史提及 —— **没有任何门禁段读这个文件**，所以「给它补 patterns」
  会是一条没有检查支撑的覆盖声明；spec delta 里「The workflow carries two independent conclusions」是给人读的
  文本，不是门禁里的断言。② 兜底语义本身可以改（见本节末）。

最小修正（需要 PM / spec 裁定，不是实现问题）：

- **改 `--floor` 的兜底语义**（推荐）：`--floor` 遇到未声明路径仍跑 **floor**，只把「这条路径谁也没声明」
  如实披露；`--paths` 单独用的 `NONE/RUN/FULL` 一个字不动（PM 条件 6 仍然成立）。产品覆盖率不降
  （未声明的产品段本来就在 floor 里），少掉的只是自检段 —— 正是这个 change 要少掉的那部分。
  代价是 spec 那句「An unclaimed path … SHALL give the full suite」要跟着改，属于产品决定。
- 或者：给 `gates.yml` 找一个**真读它**的段（今天没有；新增检查会违反净零，除非同时退役一条）。
- 或者：把该路径当豁免类（等于承认入口文件不进门禁）—— 这会把它从 `FULL` 变成 `NONE`/floor，
  但也就永远不再有人核对它。
