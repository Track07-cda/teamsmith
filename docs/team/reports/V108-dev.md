# V108 · 独立复验：npm 全局只装 `team`，四个信号入口留在 Teamsmith 会话里

agent: dev   status: pass   phase: verify   change: -   deltas: -   category: verify
specs: `init-skill#The CLI ships as one npm bin entry and the package carries what it runs`
anchor: none (infra) — 独立复验：一个 bin entry / 包内携带闸门的安装面边界
branch: `task/V108-npm-command-scope-review`（local 模式，未推）   time: 2026-10-26T11:27Z

## 结论（先看这一段）

**PASS。** 候选 `57ba99f3`（产品 `e79402a5` / 断言 `792b789d` / changelog `ca774396`）在任务书要求的六条上全部
我自己重跑过、可复核，没有一条是转述作者的：

1. **真安装的形状变了，而且只有形状变**：同一份 `npm pack` → `npm i -g --prefix` 流程，`fd971b5a` 的
   `prefix/bin` 是五项（`killall pgrep pidof pkill team`），候选只有 `team`；两边的安装物里
   `pkill/killall/pgrep/pidof/signal-gate/tmux` 六个文件都在、都可执行。
2. **普通 shell 不再被遮蔽**：候选 prefix 放 PATH 最前，四个名字解析到 `/usr/bin/*`；同一条
   `pgrep -f 'v108-mark[e]r'` 在旧 prefix 上进闸门 `rc=64`、在候选 prefix 上就是系统 pgrep（无匹配 `rc=1`）。
   我另加了正向对照：有匹配时候选 prefix 真出 PID，所以不是「命令被吞了」造成的假绿。
3. **会话里的闸门没变弱**：从**安装物**（不是源码树）求 `team_tmux_shim_exports` 并 eval，四个名字全部
   解析回该安装包的 `scripts/shim/*`；同一环境里 `pgrep -f …` 仍然 `rc=64`。没启动也没碰任何真 PM 会话。
4. **升级会清掉旧链接**：同一 prefix 先装五项版、再装候选，`prefix/bin` 由五项变 `team`，四个旧链接消失、
   包内 shim 仍在；反向（先新后旧）npm 会把四个链接重新建出来 —— 与 changelog 写的方向一致。
5. **夹具与选段**：`install-shape.sh` 整轮 ✓165 ✗0 SKIP0（rc=0）；`smoke.sh --select 11f,39` ✓82 ✗0（rc=0）。
   三条负例都按预期变红并点名原因（见 §5）。
6. **改动面就是那三处**：`fd971b5a..57ba99f3` 只有 `package.json`、`skills/teamsmith/tests/install-shape.sh`、
   `skills/teamsmith/CHANGELOG.md`（外加作者的报告）；`scripts/lib/common.sh` 两侧**逐字节相同**，
   `shim/*`、`smoke.sh`、`section-paths.tsv` 零改动。`bash -n` / `git diff --check` / `--check` 选段自检 /
   ledger ban 全绿。

两条**不影响判定**的观察写在 §6：作者报的选段总数是 ✓83，我在干净 clone 上是 ✓82（两边都全绿、都无 SKIP，
差额 1 条我没能归因）；新断言 ④ 在作者夹具的翻转组里没有对应翻转臂（⑥ 只钉软链形状），我用外部负例补了。

## 复验对象与私有副本

| 项目 | 值 |
|---|---|
| 候选 tip | `57ba99f3`（`task/P378-npm-global-command-scope`） |
| 产品 / 断言 / changelog | `e79402a5` / `792b789d` / `ca774396` |
| 作者报告 | 候选树内 `docs/team/reports/P378-dev-bob.md` |
| 我的副本 | `<base>` = `/var/tmp/v108-review`；`git clone --no-hardlinks` 我自己的工作树后 `checkout 57ba99f3`（detached，干净），另用 `git archive` 解出 `fd971b5a` 与候选各一份全量树 |
| 隔离 | 所有安装都在 `<base>/{old,cand}-prefix`、`<base>/{upgrade,downgrade}-prefix`；`env -u` 清掉本会话的 `TEAM_*`/`TMUX`；没有碰真实全局 npm（只读确认本机全局装的是 0.3.1，`~/.local/bin` 里只有 `team`）与真团队会话 |
| 日志 | 每一步的原始输出在 `<base>/logs/01…11-*.log`（宿主路径，未截断保存） |

## 1 · 修复前后的真安装（`<base>/logs/01-install.log`）

两侧都从提交内容打 tarball（不看工作树状态），`npm 11.19.1 / node v24.22.1`：

```
$ git -C <clone> archive fd971b5a | tar -x -C <base>/old      # 旧：bin 五项
$ git -C <clone> archive 57ba99f3 | tar -x -C <base>/cand     # 候选：bin 只有 team
$ ( cd <base>/{old,cand} && npm pack --pack-destination <base>/pkg/<side> )   # 两侧各 245 项
$ npm install -g --prefix <base>/{old,cand}-prefix --no-audit --no-fund <tgz>
== old prefix/bin ==        == cand prefix/bin ==
killall                     team
pgrep
pidof
pkill
team
== old prefix/bin link targets ==
killall -> <base>/old-prefix/lib/node_modules/teamsmith/skills/teamsmith/scripts/shim/killall
pgrep   -> …/shim/pgrep      pidof -> …/shim/pidof      pkill -> …/shim/pkill
team    -> <base>/old-prefix/lib/node_modules/teamsmith/bin/team.mjs
== 安装包里（两侧都在）==
-- old-prefix: pkill/killall/pgrep/pidof/signal-gate/tmux 全部 present+executable
-- cand-prefix: pkill/killall/pgrep/pidof/signal-gate/tmux 全部 present+executable
```

装出来的 CLI 仍然可用（不是「链接撤了、入口也坏了」）：

```
$ <base>/cand-prefix/bin/team version   → teamsmith 0.3.4   (rc=0)
$ diff <(<base>/cand-prefix/bin/team help) <(bash <base>/cand/skills/teamsmith/scripts/team help)  → 一致 (rc=0)
```

`install.sh`（Git 检出路线）本来就不建 bin 链接：全文唯一的 `ln -s` 在 `install.sh:65`，是把两个 skill 目录链进
`.pi/skills`，与 `package.json` 的 `bin` 无关。

## 2 · 普通终端的解析（`<base>/logs/02-ordinary-shell.log`）

普通终端形状 = 清掉 `TEAM_*` / `TMUX*` 后只用被测 prefix + `/usr/bin:/bin`：

```
== 系统真身（PATH=/usr/bin:/bin）==        /usr/bin/pkill /usr/bin/killall /usr/bin/pgrep /usr/bin/pidof
== old prefix 最前 ==                       <base>/old-prefix/bin/{pkill,killall,pgrep,pidof}
== cand prefix 最前 ==                      /usr/bin/{pkill,killall,pgrep,pidof}

$ PATH=<old-prefix>/bin:/usr/bin:/bin  pgrep -f 'v108-mark[e]r'
✗ teamsmith 信号闸门：已拒绝 pgrep —— 名字或命令行模式**不是身份**…
rc=64
$ PATH=<cand-prefix>/bin:/usr/bin:/bin pgrep -f 'v108-mark[e]r'
rc=1                       # 系统 pgrep，无匹配
$ PATH=/usr/bin:/bin                   pgrep -f 'v108-mark[e]r'
rc=1                       # 与候选 prefix 上逐字一致
$ pkill -f 'v108-mark[e]r'  →  old rc=64 · cand rc=1
```

正向对照（排除「命令被吞掉」这种假绿）：候选 prefix 的 PATH 上先起一个 `sleep 7` 再 `pgrep -f 'sleep 7'`，
输出里含 `expected_pid=1093537` 那一行（rc=0）—— 真身被执行且结果真实；同一进程在旧 prefix 上仍是 `rc=64`。

## 3 · 会话里的窗口前缀仍解析回包内 shim（`<base>/logs/03-managed-exports.log`）

不碰真会话：`env -u TEAM_* … TEAM_SKILL_DIR=<安装物>/skills/teamsmith TEAM_STATE_DIR=<base>/cand-prefix-state`
里 source 安装物的 `scripts/lib/common.sh`，`eval "$(team_tmux_shim_exports)"`：

```
raw=export PATH=<base>/cand-prefix/lib/node_modules/teamsmith/skills/teamsmith/scripts/shim:"$PATH"; …
    export TEAM_SIGNAL_CALLS_LOG=<state>/signal-calls.log; export TEAM_SIGNAL_REAL=/usr/bin/pkill;
pkill   = <cand-prefix>/lib/node_modules/teamsmith/skills/teamsmith/scripts/shim/pkill
killall = …/shim/killall      pgrep = …/shim/pgrep      pidof = …/shim/pidof
PATH_head = <cand-prefix>/lib/node_modules/teamsmith/skills/teamsmith/scripts/shim
== 同一环境里闸门仍然生效 ==
pgrep_rc=64            # 拒绝并写记录
signal-calls.log / signal-calls.log.forensics 已生成
```

旧 prefix 的安装物做同一件事得到同样的四条解析（闸门本来就在会话里，候选没有把它挪走或改弱）。

## 4 · 升级会清掉旧的四条链接（`<base>/logs/04-upgrade.log`）

```
$ npm install -g --prefix <base>/upgrade-prefix <旧 tgz>    → changed/added 1 package
prefix/bin after old:     killall pgrep pidof pkill team
$ npm install -g --prefix <base>/upgrade-prefix <候选 tgz>
prefix/bin after upgrade: team
residual links:  gone: pkill · gone: killall · gone: pgrep · gone: pidof
team link: <base>/upgrade-prefix/lib/node_modules/teamsmith/bin/team.mjs
installed package shims after upgrade: pkill/killall/pgrep/pidof present+executable
（反向对照：先候选后旧版 → prefix/bin 又变回五项，说明这是 npm 按新 bin 字段重算的结果，不是残留清理的巧合）
```

## 5 · 夹具与选段，以及三条负例（`<base>/logs/05…10-*.log`）

在候选的干净副本里跑（`--select 11f,39` 会自动带上 0/0b/0c/0d/2 五个前导段，共 7 段）：

```
$ bash skills/teamsmith/tests/install-shape.sh
== 结果 ==  ✓ 165  ✗ 0  SKIP 0        rc=0

$ bash skills/teamsmith/tests/smoke.sh --select 11f,39
#1 0 · 临时仓库 · ✓3 ✗0 ｜ #2 0b · skill 可被 pi 解析器加载 · ✓3 ✗0 ｜ #3 0c · 静态检查 · ✓9 ✗0
#4 0d · 冲突标记守卫 · ✓9 ✗0 ｜ #5 2 · init · ✓38 ✗0 ｜ #6 11f · 更新与版本自检 · ✓19 ✗0
#7 39 · npm CLI 与项目 skill 安装 · 参考 用时 163s · ✓1 ✗0 SKIP0
      ✓ 39 install-shape.sh 全绿（166 条断言，含翻转绿/红两侧）  →  §39 内的整轮读数 ✓165 ✗0
账本自查：7 段收口 · 增量 ✓82 ✗0 SKIP0 ｜ 结果行 ✓82 ✗0 —— 一致
== 选段结果 ==  ✓ 82  ✗ 0           rc=0      （没跑的 128 段在日志末尾逐个点名）
```

三条负例（都在 `<base>` 的 scratch 树上，用候选自己的夹具判据判，不是我另写一套）：

| 负例 | 怎么破 | 结果 | 红在哪 |
|---|---|---|---|
| b（brief 要求的那条） | 把四个信号入口加回 `bin`（`bin = team + pkill + killall + pgrep + pidof`），其余不动 | `rc=1`，✓2 ✗2 | `声明面…：bin 键不是只有 team：['team','pkill','killall','pgrep','pidof']`；`私有 prefix 安装…：安装后 prefix/bin 里有 pkill killall pgrep pidof —— npm 又把信号闸门做成了全局命令（…exit 64）；它们只应由 team_tmux_shim_exports 注入 PM/worker 窗口的 PATH` |
| c（我加的：撤链接不能顺手把闸门弄丢） | `bin` 保持只有 `team`，删掉包内 `scripts/shim/pkill` | `rc=1`，✓3 ✗1 | `安装包里没有可执行的信号闸门入口：pkill` |
| e（我加的：作者夹具没给 ④ 配翻转） | `bin` 不动，把 `team_tmux_shim_exports` 改成直接 `return 0`（窗口前缀不再注入 shim 目录） | `rc=1`，✓3 ✗1 | `窗口前缀下 pkill 解析到 [<main worktree>/skills/teamsmith/scripts/shim/pkill]，不是包内 shim [<临时 prefix>/…/shim/pkill]` |

负例 b 的两条红正好是 brief 说的「for the intended reason」：一条打声明面，一条打真安装的 `prefix/bin` 遮蔽。
负例 e 说明新断言 ④ 本身有判别力（它只在 `team_tmux_shim_exports` 真的把安装目录渲染进 PATH 时才绿）。

**覆盖没有缩水（我自己重跑的父提交读数）**：同一台机器、同一份夹具脚本，父提交 `fd971b5a` 的整轮是
`== 结果 == ✓ 163 ✗ 0 SKIP 0`（rc=0），候选是 `✓ 165 ✗ 0`。差额 +2 正是新增的 ⑤c 一对（对照 + 翻转）；
被删掉的「`prefix/bin` 必须为四个名字建链接」是 `chk_prefix_signal_entries` **内部**的分支（整函数只贡献
一条 ✓），替代它的 `chk_prefix_bin_scope` 在同一个标签下把方向反过来 —— 所以标签总数不降、被删的那几条
断言由反向判据接管。父提交那轮里 `⑥ 对照…四个信号入口在且判定生效` 也是绿的，说明「从安装物出发闸门
确实生效」这条判据在改动前后都成立，不是新夹具自己说自己绿。

## 6 · 改动面与静态检查（`<base>/logs/09-static.log`）

```
$ git diff --stat fd971b5a..57ba99f3
 docs/team/reports/P378-dev-bob.md       | 207 ++++++++++
 package.json                            |   6 +-
 skills/teamsmith/CHANGELOG.md           |  13 ++
 skills/teamsmith/tests/install-shape.sh | 126 +++++++++-------
$ git diff --name-only fd971b5a..57ba99f3 -- skills/teamsmith/scripts 'skills/teamsmith/tests/smoke.sh' \
      'skills/teamsmith/tests/section-paths.tsv' skills/teamsmith/tests/signal-lint.pl
  （空：shim / common.sh / smoke.sh / 选段表 / signal-lint 一个都没动）
$ diff <(git show fd971b5a:…/lib/common.sh) <(git show 57ba99f3:…/lib/common.sh)  → 逐字节相同
$ bash -n skills/teamsmith/tests/install-shape.sh   rc=0   （smoke.sh 同）
$ python3 -c 'json.load(open("package.json"))'      bin=['team']  files=['skills/','bin/','install.sh']  rc=0
$ git diff --check fd971b5a..57ba99f3                rc=0   （工作树同）
$ bash skills/teamsmith/tests/section-select.sh --check
== 选段自检 ==  ok 12  bad 0  SKIP 1   rc=0
$ bash skills/teamsmith/tests/ledger-ban.sh --root <clone> --names-file <main>/.pi/team/forbidden-names.txt
ledger-ban: root=<clone> scope=published files=2195 hits=0 names=ok user=resolved   rc=0
```

## 7 · 观察（不影响本次判定，交给 PM 取舍）

1. **选段总数对不上 1 条**：作者报 `== 选段结果 == ✓ 83 ✗ 0`，我在干净 clone 上跑同一句
   `--select 11f,39` 是 ✓82 ✗0（七段逐段读数见 §5，每段都全绿、零 SKIP）。我试了两个形状假设都没复现 83：
   把副本做成 **linked worktree**（`git worktree add`，与作者的工作树同形）跑前导五段仍是 ✓62（3+3+9+9+38）；
   再给副本补出 `.pi/skills` 后单跑 §11f 仍是 ✓19。所以差额出在 §2/§11f/§39 之一的**环境相关**一条上，
   我没归因成功。方向上是「作者那侧多一条绿」，不是候选少一条 —— §39 自己的判据
   「install-shape.sh 全绿（166 条断言）」在我这里逐字命中，被审的那条断言两边都绿。
2. **新断言 ④ 缺一个内部翻转臂**：候选的翻转组新增了 ⑤c（声明面 / prefix/bin 两侧），但「窗口前缀把四个名字
   解析回包内 shim」这条只在对照侧出现，作者的夹具没有「把 `team_tmux_shim_exports` 弄空」的翻转。我用外部
   负例 e 补验了它确实会红，**但它没被写进夹具** —— 下次谁改 `team_tmux_shim_exports` 时这条不会自己叫。
   是否补一条臂，是门禁口径问题，留给 PM。
3. **判据里的硬编码 PATH**：`chk_prefix_bin_scope` 的 ③ 用 `PATH=<prefix>/bin:/usr/bin:/bin` 找系统同名可执行；
   机器上 `pgrep` 不在 `/usr/bin` 时它退化成「不是包内入口」并在消息里点名（`（本机没有系统的 …）`），
   不假装验过。本机两侧都在 `/usr/bin`，所以这条退化路径没被走到。
4. **本机不在缺陷射程内**：真实全局 npm 是 0.3.1（0.3.1 的 `bin` 只有 `team`），`~/.local/bin` 里只有 `team`；
   被这个缺陷打到的是装过 0.3.2/0.3.3 的 npm 用户。
5. **规格侧的好消息**：`openspec/specs/init-skill/spec.md:352` 本来就写「exactly one `bin` entry, `team`」——
   候选不是新增约定，是把 `package.json` 改回规格要求（0.3.2 的 P360 是那次偏离）。所以这次没有、也不该有
   spec delta；`change: -` 的写法与实际情况一致。

## 8 · 没做 / 边界

- **没有跑全套门禁**（brief 明确要求）：只跑 `--select 11f,39` 与 `install-shape.sh`。没跑的 128 个键在
  `<base>/logs/08-smoke-select.log` 末尾逐个点名。
- 没有在 Windows / 其它 npm 大版本上验；升级清链接的读数是 npm 11.19.1 一次实测 + 一次反向对照。
- 没有启动、修改或重启任何真 PM/worker 会话；`team_tmux_shim_exports` 的解析都是在私有 `TEAM_STATE_DIR`
  下的独立 bash 里做的。
- 没有改候选、没有合并/推送/发布；本分支只有这份报告。
- 没有针对「作者报告的其它数字」复核（例如他报告里 `--select 11f,39` 的用时），只核对与判定直接相关的读数。
