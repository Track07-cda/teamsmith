# P378 · npm 只在全局装 `team`，四个信号入口留在 Teamsmith 会话里

agent: dev-bob   status: delivered   time: 2026-10-26T11:14Z
branch: `task/P378-npm-global-command-scope`   PR/MR: - （local 模式，分支留在本地）

**结论**：`package.json` 的 `bin` 现在只有 `team`。隔离 prefix 的全局安装后 `prefix/bin` 里只有 `team`，
普通终端里 `pkill`/`pgrep` 解析到 `/usr/bin` 的那两个可执行文件；四个 shim 文件仍随包发布，
PM/worker 会话的启动前缀（`team_tmux_shim_exports`）仍把它们解析回安装包内的 shim —— 闸门没有变弱，
只是不再占用户的全局命令名。`install-shape.sh` 全绿（✓165 ✗0），受影响的 smoke 选段
（`--select 11f,39`）✓83 ✗0；翻转 ⑤c 把四个名字加回 `bin` 会让「不遮蔽」那条断言变红。

## Deliverables

| Path | What |
|---|---|
| `package.json` | `bin` 从五项（`team` + 四个信号入口）减到一项（`team`）；`files` 仍含 `skills/`、`bin/`、`install.sh` |
| `skills/teamsmith/tests/install-shape.sh` | 声明面改判「只有 team」；新增 `chk_prefix_bin_scope`（装完 `prefix/bin` 只有 `team` + 普通 shell 不遮蔽 + 包内 shim 仍在 + 窗口前缀解析回包内 shim）；删掉原来的「prefix/bin 必须建四个链接」四条断言；新增翻转 ⑤c |
| `skills/teamsmith/CHANGELOG.md` | v0.3.4 增加「安装面：npm 不再遮蔽系统命令」一节（撤链接、闸门仍在会话里、升级会清掉旧链接） |
| `docs/team/reports/P378-dev-bob.md` | 本报告 |

提交（三步，都在 `task/P378-npm-global-command-scope` 上）：

```
$ git log --oneline fd971b5a..HEAD
ca774396 docs(changelog): P378 record that npm no longer shadows the signal commands
792b789d test(install-shape): P378 assert npm no longer shadows the signal commands
e79402a5 fix(package): P378 keep the signal-gate shims out of the global bin map
```

改动的完整 diff 只有三处（`git diff --stat fd971b5a..HEAD` → 3 files changed, 102 insertions(+), 43 deletions(-)）：
除了 `install-shape.sh` 里与 bin 声明面直接相关的那几条断言，没有碰 `scripts/shim/*`、
`common.sh` 的 `team_tmux_shim_exports`、`smoke.sh` 的任何断言或 `section-paths.tsv`。

## Verification evidence（全部实跑）

### 1. 修复前后：隔离 prefix 的真实全局安装

两侧都是从提交内容直接打出来的（不依赖工作树状态）：

```
$ ROOT=/var/tmp/p378-beforeafter; mkdir -p $ROOT/before $ROOT/after
$ git archive fd971b5a | tar -x -C $ROOT/before        # 修复前（bin 五项）
$ git archive HEAD   | tar -x -C $ROOT/after           # 修复后（bin 只有 team）
$ for side in before after; do ( cd $ROOT/$side && npm pack --pack-destination $ROOT >/dev/null ); \
    npm install -g --prefix $ROOT/$side-prefix --no-audit --no-fund $ROOT/$side.tgz; done
before prefix/bin: killall pgrep pidof pkill team
before shims in package: killall pgrep pidof pkill signal-gate tmux
after  prefix/bin: team
after  shims in package: killall pgrep pidof pkill signal-gate tmux
```

安装包（tarball 清单，245 项）里四个入口仍在：

```
$ npm pack --dry-run --json | python3 -c '…列 /scripts/shim/ …'
shim entries in tarball: 6
  skills/teamsmith/scripts/shim/killall
  skills/teamsmith/scripts/shim/pgrep
  skills/teamsmith/scripts/shim/pidof
  skills/teamsmith/scripts/shim/pkill
  skills/teamsmith/scripts/shim/signal-gate
  skills/teamsmith/scripts/shim/tmux
bin/team.mjs in tarball: True
```

### 2. 普通 shell 的解析（prefix/bin 放在 PATH 最前）

```
$ PATH="$ROOT/before-prefix/bin:/usr/bin:/bin" command -v pkill killall pgrep pidof
/var/tmp/p378-beforeafter/before-prefix/bin/pkill
/var/tmp/p378-beforeafter/before-prefix/bin/killall
/var/tmp/p378-beforeafter/before-prefix/bin/pgrep
/var/tmp/p378-beforeafter/before-prefix/bin/pidof

$ PATH="$ROOT/after-prefix/bin:/usr/bin:/bin" command -v pkill killall pgrep pidof
/usr/bin/pkill
/usr/bin/killall
/usr/bin/pgrep
/usr/bin/pidof
```

同一个普通终端命令（模式串写成 `p378-mark[e]r`，避免匹配到命令行自己）：

```
$ PATH="$ROOT/before-prefix/bin:/usr/bin:/bin" pgrep -f 'p378-mark[e]r'; echo rc=$?
✗ teamsmith 信号闸门：已拒绝 pgrep —— 名字或命令行模式**不是身份**…
rc=64
$ PATH="$ROOT/after-prefix/bin:/usr/bin:/bin" pgrep -f 'p378-mark[e]r'; echo rc=$?
rc=1
```

即：修复前的全局安装让 Teamsmith 之外的任何终端敲 `pgrep -f …` 都会进闸门并 exit 64（brief 的缺陷），
修复后同一命令就是系统的 `pgrep`（无匹配 → 1）。

### 3. 管理会话的窗口前缀仍解析到安装包内的 shim

从**安装物**（`after-prefix/lib/node_modules/teamsmith/skills/teamsmith`）取 `team_tmux_shim_exports`，
在私有环境里 eval（不碰真会话、不碰用户全局 npm）：

```
$ env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT -u TEAM_SESSION \
    TEAM_SKILL_DIR="$ROOT/after-prefix/lib/node_modules/teamsmith/skills/teamsmith" \
    TEAM_STATE_DIR="$ROOT/managed-state" bash -c '. "$1/scripts/lib/common.sh"; \
    eval "$(team_tmux_shim_exports)"; for t in pkill killall pgrep pidof; do printf "%s=%s\n" "$t" "$(command -v "$t")"; done' _ "$INST"
pkill=/var/tmp/p378-beforeafter/after-prefix/lib/node_modules/teamsmith/skills/teamsmith/scripts/shim/pkill
killall=/var/tmp/p378-beforeafter/after-prefix/lib/node_modules/teamsmith/skills/teamsmith/scripts/shim/killall
pgrep=/var/tmp/p378-beforeafter/after-prefix/lib/node_modules/teamsmith/skills/teamsmith/scripts/shim/pgrep
pidof=/var/tmp/p378-beforeafter/after-prefix/lib/node_modules/teamsmith/skills/teamsmith/scripts/shim/pidof
```

### 4. 升级会清掉旧的四条链接（CHANGELOG 里那条承诺的依据）

npm 11.19.1 / node v24.22.1：

```
$ npm install -g --prefix "$D/prefix" …/teamsmith-0.3.4.tgz   # 修复前那版（bin 五项）
$ ls -1 "$D/prefix/bin"
killall pgrep pidof pkill team
$ npm install -g --prefix "$D/prefix" …/teamsmith-0.3.4.tgz   # 修复后
$ ls -1 "$D/prefix/bin"
team
```

### 5. 夹具与门禁

```
$ bash skills/teamsmith/tests/install-shape.sh
== surfaces … ==  == install … ==  == conflict … ==  == shell … ==  == pack … ==
== doctor … ==  == extension … ==  == flip … ==
== 结果 ==  ✓ 165  ✗ 0  SKIP 0
install-shape rc=0
```

```
$ bash skills/teamsmith/tests/smoke.sh --select 11f,39
== 选段 == decision=RUN · 运行 7/135 段 · 未跑 128 段
#5 2 · init
#6 11f · 更新与版本自检（mark-loaded / version --check / changelog）
#7 39 · npm CLI 与项目 skill 安装（P40：包装器 / 冲突表 / doctor 行） · 参考 用时 177s · ✓1 ✗0 SKIP0
      == 结果 ==  ✓ 165  ✗ 0  SKIP 0        # §39 里 install-shape.sh 的整轮读数
== 选段结果 ==  ✓ 83  ✗ 0
smoke rc=0
```

`§11f` 覆盖根 `package.json` 的另一个读者（版本五处一致），`§39` 覆盖安装面与打包面。
`§39` 内部会再跑一遍 `install-shape.sh`，所以这一轮 177s。

```
$ bash -n skills/teamsmith/tests/install-shape.sh ; echo rc=$?          rc=0
$ python3 -c 'import json; json.load(open("package.json"))' ; echo rc=$? rc=0
$ git diff --check ; echo rc=$?                                        rc=0
$ bash skills/teamsmith/tests/section-select.sh --check
== 选段自检 ==  ok 12  bad 0  SKIP 1   （rc=0；SKIP 是检出形状 internal 的 `.pi/skills` 一条，既有行为）
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file \
    "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=/home/<user>/…/.worktrees/dev-bob scope=published files=2194 hits=0 names=ok user=resolved
rc=0
```

- Verdict: pass
- Notes / 没跑到的东西：
  - **没有跑全套门禁**（brief 明确要求）：选段自检 135 段里跑了 7 段，其余 128 段没跑。
    选段的理由不是「我猜」，而是：改动的三条路径都被 `--select 11f,39` 覆盖（`install-shape.sh` 归 §39，
    根 `package.json` 的读者是 §11f 与 §39）。
  - 选段脚本对根 `package.json` 的判定是 **FULL**（映射表里没有任何一行声明它），所以用 `--paths` 会跑全套；
    我**没有**为此改 `section-paths.tsv`（把一条保守兜底改窄是门禁口径变更，应当由 PM 裁定，不该顺手做）。
  - 只在本机 Linux + npm 11.19.1 上验过；没有 Windows/其他 npm 大版本的读数。
  - `chk_prefix_bin_scope` 里「普通 shell 的 `pkill`/`pgrep` 是系统可执行」这条在**没有系统同名命令**的机器上
    会退化成「不是包内入口」，消息里会点名（`（本机没有系统的 …）`），而不是假装验过。

## Flip evidence

夹具里新增的翻转对（`install-shape.sh flip ⑤c`，实跑输出）：

```
✓ ⑤c 对照：真实树安装后 prefix/bin 只有 team，普通 shell 的 pkill/pgrep 仍是系统可执行：
   prefix/bin 只有 team；普通 shell 的 pkill/pgrep 仍是系统可执行；窗口前缀把四个名字解析回包内 shim
✓ ⑤c 翻转：四个信号入口加回 bin（npm 又全局遮蔽这四个命令）：翻转后红（安装后 prefix/bin 里有
   pkill killall pgrep pidof —— npm 又把信号闸门做成了全局命令（Teamsmith 之外的普通终端敲这些名字
   会进闸门、exit 64）；它们只应由 team_tmux_shim_exports 注入 PM/worker 窗口的 PATH）
```

翻转的做法：把 `HEAD` 的 `package.json` 复制到 scratch 树，用 json 把四个 `bin` 项加回去，
对 scratch 树真跑 `npm pack` + `npm install -g --prefix`，再对安装物跑同一套判据 —— 判据必须红。
「红→绿」的原始两侧也在第 1、2 节的实测里：修复前 `prefix/bin` 五项、普通 shell 的 `pgrep` exit 64；
修复后 `prefix/bin` 只有 `team`、同一命令 rc=1。

## Decisions and deviations

1. **删掉的是断言，不是覆盖**（净零那一条的交代）：原来 `chk_prefix_signal_entries` 里「prefix/bin 必须为四个
   名字建链接、链接必须落在包内 shim」这一段被删了 —— 它断言的正是要撤掉的行为。替代它的
   `chk_prefix_bin_scope` 在**同一次安装**上做反向断言（只有 `team`、普通 shell 不遮蔽、包内 shim 在、
   窗口前缀解析回包内 shim），并把「包内闸门文件在不在 + 判定生效」留在原函数里。
   所以本 change 没有新增「只加检查」的东西：一处旧判据被反向的新判据替换，四处旧断言（`pkill`/`killall`/
   `pgrep`/`pidof` 的 prefix/bin 链接）退出，`chk_prefix_bin_scope` 一次性覆盖它们。
2. **`--select 11f,39` 而不是 `--paths …`**：见上（`package.json` 未声明 → FULL）。
3. **CHANGELOG 的一句承诺是实测的**：「升级会清掉旧链接」不是推断，第 4 节是 npm 11 上的读数。
4. 没有改 `install.sh`（Git 检出这条路本来就不建 bin 链接，`grep -n bin install.sh` 只有 shebang 行），
   也没有改 `scripts/shim/*` 与 `team_tmux_shim_exports` 一行。

## Suggested next steps

- 复验建议：独立树里 `bash skills/teamsmith/tests/install-shape.sh`（约 2 分钟）+ 一次隔离 prefix 安装后
  `ls prefix/bin`（应只有 `team`）；若要连闸门一起看，用第 3 节那条命令（私有环境，不碰真会话）。
- 发版层面：这是 0.3.4 里的一条安装面修复；打包/发布与 tag 不在本任务内（brief 明确禁止）。
- 顺带想到、但**没有**动的一条：根 `package.json` 在映射表里没有归属行，任何改动都会把选段退成 FULL。
  要不要给 §39 加一行 `package.json` 是门禁口径问题，留给 PM 裁定。
