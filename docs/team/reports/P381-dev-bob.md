# P381 · dev-bob · 已交付，待独立复验

## 结论

无 upstream 的任务分支现在不会让 `run()` 子进程的 git stderr 漏进 Pi 窗格；成功命令的 stdout 和失败时的空字符串保持不变。真实 Pi 1.4.0、无 upstream 的任务工作树中，第二条 `say` 实测收到一次；人工草稿仍被保留，新消息仍排队。红侧选段在旧实现上失败、绿侧在修复后通过，证据见下。

PM 补充路径授权后，在 `skills/teamsmith/extension/team-notify.ts` 的 `run()` 给 `execFileSync` 增加 `stdio: ['ignore', 'pipe', 'pipe']`；未改上游分支或未推送数量逻辑，也未改投递守卫诊断。原有 `skills/teamsmith/tests/smoke.sh` §13 的断言改为在真实无 upstream 分支上执行扩展，核对未推送数量，并断言该 git fatal 不进入父进程 stderr；没有添加新的测试框架。Node 自身的模块类型警告与 git fatal 分开判断。

产品提交 `df6339c16bbbee9f93250ab5e4f20960e522b70c`；测试提交 `88bd2e65`、`29b4cdb1`。本仓是 local 模式，分支 `task/P381-notify-git-stderr-leak` 留在本地，未推送、合并或发布。`skills/teamsmith/tests/smoke.sh` 的临时借用在交付后归还。

## 翻转证据（red before → green after）

同一条 §13 行为断言：夹具建 `agent/p381-stderr` 分支，先确认真实 git upstream probe 返回 128 和 `no upstream configured`，再跑实际扩展、核对 `unpushed=<git rev-list 的实际数量>(no-upstream)`，最后检查父进程 stderr 不包含该分支的 git fatal。测试提交 `29b4cdb1` 上仍是旧产品实现；修复提交 `df6339c1` 上是同一断言及新产品实现。

- **Red before，失败**：旧实现 `29b4cdb1`，`TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh --select 13`，退出码 1；§13 失败，证据行 `fatal: no upstream configured for branch 'agent/p381-stderr'`，汇总 `✓65 ✗1`。
- **Green after，通过**：修复后 `df6339c1`，非 FAST 选段 `bash skills/teamsmith/tests/smoke.sh --select 11h,13,13b,12b-h0c,12b-pi,47,57`，退出码 0；§13 输出 `扩展：写入 + 去重 + 非 worktree 不触发；无 upstream 不泄漏 git fatal`，汇总 `✓718 ✗0`。其他条件跳过及补验见下。

两次都在 `localhost/teamsmith-gates:p380` 容器中实际运行，Node `v24.22.1`；被测工作树和共享 Git 元数据只读挂载，日志与临时根在宿主机任务证据目录的 bind mount 上。红侧实际容器命令的关键部分：

```sh
# 在红侧提交的独立检出中，COMMON=$(git rev-parse --path-format=absolute --git-common-dir)
# E="$PWD/docs/team/reports/P381-dev-bob"，先建 "$E/logs/tmp"
distrobox-host-exec podman run --rm --network=none --pid=host --cgroups=enabled --userns=keep-id \
  -e HOME=/tmp -e GIT_OPTIONAL_LOCKS=0 -e TMPDIR=/logs/tmp -e TEAM_SMOKE_FAST=1 \
  -v "$PWD:$PWD:ro" -v "$COMMON:$COMMON:ro" -v "$E/logs:/logs:rw" -w "$PWD" \
  --entrypoint bash localhost/teamsmith-gates:p380 -c \
  'git config --global --add safe.directory "$PWD"; bash skills/teamsmith/tests/smoke.sh --select 13 > /logs/red13b.log 2>&1; rc=$?; tail -n 45 /logs/red13b.log; exit "$rc"'
```

红侧摘录：

```text
✗ 扩展测试失败或 stderr 泄漏（runner=node）
ext-ok
fatal: no upstream configured for branch 'agent/p381-stderr'
== 选段结果 ==  ✓ 65  ✗ 1
P381_RED_RC=1
```

绿侧完整命令、结果和跳过补验见“选段”一节。两侧完整原始日志在本席位工作树的忽略目录 `docs/team/reports/P381-dev-bob/logs/red13b.log` 和 `docs/team/reports/P381-dev-bob/logs/green-notify.log`，未作为版本化文件提交。

## Helper 最小复现：实际旧实现对比实际修复

当前任务分支没有 upstream。从旧提交和修复后文件分别提取真实 `run()` 函数，分别在子进程调用成功的分支 probe 和失败的 upstream probe，捕获子进程 stderr；没有给 git 添加 upstream。实际命令：

```sh
node <<'NODE'
const { execFileSync, spawnSync } = require('node:child_process')
const { readFileSync } = require('node:fs')
const path = 'skills/teamsmith/extension/team-notify.ts'
const before = execFileSync('git', ['show', `29b4cdb1:${path}`], { encoding: 'utf8' })
const after = readFileSync(path, 'utf8')
const upstream = execFileSync('git', ['for-each-ref', '--format=%(upstream)', execFileSync('git', ['symbolic-ref', 'HEAD'], {encoding: 'utf8'}).trim()], {encoding: 'utf8'}).trim()
if (upstream) throw new Error('fixture branch has an upstream')
function execute(source) {
  const match = source.match(/function run\(cmd: string, args: string\[\], cwd\?: string\): string \{[\s\S]*?\n\}/)
  if (!match) throw new Error('cannot extract actual run helper')
  const helper = match[0].replace('function run(cmd: string, args: string[], cwd?: string): string', 'function run(cmd, args, cwd)')
  const code = `const {execFileSync}=require('node:child_process'); ${helper}; const cwd=process.argv[1]; const branch=run('git',['rev-parse','--abbrev-ref','HEAD'],cwd); const upstream=run('git',['rev-parse','--abbrev-ref','--symbolic-full-name','@{upstream}'],cwd); process.stdout.write(JSON.stringify({branch,upstream}));`
  return spawnSync(process.execPath, ['-e', code, process.cwd()], { encoding: 'utf8', env: { ...process.env, LC_ALL: 'C' } })
}
const old = execute(before), fixed = execute(after)
if (old.status !== 0 || fixed.status !== 0 || old.stdout !== fixed.stdout || !old.stderr.includes('no upstream configured') || fixed.stderr !== '') throw new Error('minimal comparison failed')
console.log(`fixture: ${JSON.parse(fixed.stdout).branch}, upstream=none`)
console.log(`before: result=${old.stdout}, parent_stderr_bytes=${Buffer.byteLength(old.stderr)}, fatal=${old.stderr.trim()}`)
console.log(`after:  result=${fixed.stdout}, parent_stderr_bytes=${Buffer.byteLength(fixed.stderr)}`)
NODE
```

实际输出，命令退出 0：

```text
fixture: task/P381-notify-git-stderr-leak, upstream=none
before: result={"branch":"task/P381-notify-git-stderr-leak","upstream":""}, parent_stderr_bytes=76, fatal=fatal: no upstream configured for branch 'task/P381-notify-git-stderr-leak'
after:  result={"branch":"task/P381-notify-git-stderr-leak","upstream":""}, parent_stderr_bytes=0
```

## 真实 Pi 1.4.0：无 upstream 的二次投递及草稿对照

P380 候选提交 `779d9d32156ebd6d490342f62ee3d2d22a04c78e` 的 `skills/teamsmith/tests/fixtures/delivery-truth-real/run-case.sh` 与 `judge-second.py` 支持指定 1.4.0；本分支旧版 runner 不支持。将该提交的夹具用 `git archive` 提取到本任务忽略的证据目录，未把 P380 文件合入分支。运行时从本地 `localhost/teamsmith-gates:p380` 镜像复制，包自报 `1.4.0`；实际 Pi 在隔离容器和真实 tmux 中运行，模型后端是夹具的本地 mock，不是外部模型服务。没有设置 `P163_BRANCH_UPSTREAM=1`。

```sh
E="$PWD/docs/team/reports/P381-dev-bob"
mkdir -p "$E/source" "$E/.runtime/1.4.0"
git archive 779d9d32156ebd6d490342f62ee3d2d22a04c78e skills/teamsmith/tests/fixtures/delivery-truth-real | tar -xf - -C "$E/source"
distrobox-host-exec podman run --rm --network=none --userns=keep-id \
  -v "$E/.runtime/1.4.0:/runtime:rw" --entrypoint bash localhost/teamsmith-gates:p380 -c \
  'set -e; mkdir -p /runtime/node_modules/@earendil-works; cp -a /usr/local/lib/node_modules/@earendil-works/pi-coding-agent /runtime/node_modules/@earendil-works/; node -p "require(\"/runtime/node_modules/@earendil-works/pi-coding-agent/package.json\").version"'
env -u P163_BRANCH_UPSTREAM -u P138_LONG -u P138_OLD_NOTIFY -u P138_TRACKED -u P138_SETTLE_DELAY \
  P138_SECOND=1 P143_DRAFT=1 P163_EVIDENCE="$E" P163_IMAGE=localhost/teamsmith-gates:p380 \
  bash "$E/source/skills/teamsmith/tests/fixtures/delivery-truth-real/run-case.sh" \
  tmux-p163-p381-no-upstream df6339c16bbbee9f93250ab5e4f20960e522b70c 0 1.4.0
P163_EVIDENCE="$E" python3 "$E/pkg/judge-second.py" tmux-p163-p381-no-upstream
```

运行与判据都退出 0；原始输出摘录：

```text
P163 clean case=tmux-p163-p381-no-upstream run=c9a03a8bd0e7 revision=df6339c16bbbee9f93250ab5e4f20960e522b70c runtime=1.4.0（requested=1.4.0）mode=verdict
say_rc=0
second_say_rc=0
draft_say_rc=0
notify_rc=0
dev_turns= 3 dev_settled= 3
dev_prompt_prefixes= ["P138-SEED-CLEAN", "P138-SAY-tmux-p163-p381-no-upstream", "P138-SECOND-tmux-p163-p381-no-upstream"]
dev_editor_at_settle= ['', '', '']
tmux-p163-p381-no-upstream: pi=1.4.0 second_received=1 backend=1 backend_requests=1 settled=3 settle_editors_empty=1
PASS second say delivered
```

`pi-version.txt` 实测 `1.4.0`；`notify.log` 记录 `branch=task/P138 · uncommitted=0 · unpushed=1(no-upstream)`；`second-say.txt` 报“已确认送达”。第二次投递完成后，负对照向真实输入框写 `P143-HUMAN-DRAFT`：`draft-say.txt` 报 `queued` 和“目标输入框里有草稿：没有写任何键”，`draft-after.frame` 仍有该草稿，`outbox-final.txt` 留有一条 queued。该对照不改变第二次投递前的默认无 upstream 现场。

完整现场在本席位工作树忽略目录 `docs/team/reports/P381-dev-bob/logs/tmux-p163-p381-no-upstream/`；外层日志为 `logs/real-pi-run.log` 和 `logs/real-pi-judge.log`。这些现场没有随提交入库。独立复验应在新的检出重跑可版本化的 `skills/teamsmith/tests/delivery-truth.sh` 及上述 P380 候选夹具，而不是把本次执行当作独立审查。

## 选段、跳过补验和静态检查

非 FAST 运行 `11h,13,13b,12b-h0c,12b-pi,47,57`，依赖闭包实际执行 `0,0b,0c,0d,2,4,5,3b,6,6i,11h,13,13b,12b,12b-h0c,12b-pi,47,57` 共 18 段。命令在隔离容器内持宿主机共享门禁锁 `/tmp/teamsmith-smoke.lock`：

```sh
COMMON=$(git rev-parse --path-format=absolute --git-common-dir)
E="$PWD/docs/team/reports/P381-dev-bob"
mkdir -p "$E/logs/home" "$E/logs/tmp"
distrobox-host-exec podman run --rm --network=none --pid=host --cgroups=enabled --userns=keep-id \
  -e HOME=/logs/home -e GIT_OPTIONAL_LOCKS=0 -e TMPDIR=/logs/tmp -e TEAM_SMOKE_LOCK=/tmp/teamsmith-smoke.lock \
  -v /tmp:/tmp:rw -v "$PWD:$PWD:ro" -v "$COMMON:$COMMON:ro" -v "$E/logs:/logs:rw" -w "$PWD" \
  --entrypoint bash localhost/teamsmith-gates:p380 -c \
  'git config --global --add safe.directory "$PWD"; bash skills/teamsmith/tests/smoke.sh --select 11h,13,13b,12b-h0c,12b-pi,47,57 > /logs/green-notify.log 2>&1; rc=$?; tail -n 70 /logs/green-notify.log; exit "$rc"'
```

输出：`18 段收口 · 增量 ✓718 ✗0 SKIP2`，退出 0。两项 SKIP 是 §12b-h0c 的假 PM 敲门和 watchdog 敲门/排水，因为该轮外层没有在 tmux 内启动；不是通过。随后在同一镜像的私有 tmux 会话中补跑，使用同一共享锁与相同挂载：

```sh
mkdir -p "$E/logs/home" "$E/logs/outer"
distrobox-host-exec podman run --rm --network=none --pid=host --cgroups=enabled --userns=keep-id \
  -e HOME=/logs/home -e GIT_OPTIONAL_LOCKS=0 -e TMPDIR=/logs/tmp -e TEAM_SMOKE_LOCK=/tmp/teamsmith-smoke.lock \
  -v /tmp:/tmp:rw -v "$PWD:$PWD:ro" -v "$COMMON:$COMMON:ro" -v "$E/logs:/logs:rw" -w "$PWD" \
  --entrypoint bash localhost/teamsmith-gates:p380 -c '
    set -u; git config --global --add safe.directory "$PWD"; export TMUX_TMPDIR=/logs/outer
    rm -f /logs/green-tmux-h0c.status
    tmux new-session -d -s p381-outer -x 120 -y 35 -c "$PWD" "bash -c '\''bash skills/teamsmith/tests/smoke.sh --select 12b-h0c > /logs/green-tmux-h0c.log 2>&1; rc=\$?; printf \"%s\\n\" \"\$rc\" > /logs/green-tmux-h0c.status'\''" || exit 2
    while [ ! -s /logs/green-tmux-h0c.status ]; do
      sleep 3
      if [ ! -s /logs/green-tmux-h0c.status ] && ! tmux has-session -t p381-outer; then
        printf "%s\n" "outer tmux ended before gate status"; tail -n 40 /logs/green-tmux-h0c.log; exit 2
      fi
    done
    rc=$(< /logs/green-tmux-h0c.status); tail -n 65 /logs/green-tmux-h0c.log; exit "$rc"'
```

补验结果 `8 段收口 · ✓277 ✗0 SKIP0`，退出 0。原先跳过的 ⑤、⑥实际执行了 11 项断言，包含草稿未提交、通知入队和后续排水。补验完整日志 `docs/team/reports/P381-dev-bob/logs/green-tmux-h0c.log`。

按任务书没有运行全量门禁；第一轮未跑以下 117 个键：

```text
0e 0f 0g 0h 0i 1 1b 1c 3 4b 4c 6b 6c 6d 6e 6f 6g 6h 6j 6k 7 7b 8 9 10 10b 10c 11 11b 11b2 11b3 11b4 11c 11d 11e 11e2 11f 11g 11i 11j 14b 15b 15c 12 13c 12b-h0 12b-h0b 12b-h0d 12b-pi2 12b-pi3 14 14c 54 14d 17 18 18b 18c 19 20 21 22 23 24 25 26 27 28 29 30 31 31c 32 33 12e 12f 12g 12h 12i 12j 12k 34 34b 34c 34d 35 36 37 38 39 40 41 42 43 44 45 46 48 49 50 51 51b 51c 52 53 58 15 55 56 59 60 61 61b 62 63 64 65
```

静态验收：

- `bash -n skills/teamsmith/tests/smoke.sh`：退出 0。
- `bash skills/teamsmith/tests/section-select.sh --check`：退出 0，`ok 12 bad 0 SKIP 1`；唯一 SKIP 为本检出不存在的机器生成目录 `.pi/skills`，该项不计为已检查。
- `bash skills/teamsmith/tests/ledger-ban.sh`：退出 0，扫描 2212 个已发布范围文件，`hits=0`；名单与本机用户名检查均可用。
- `git diff --check f2940897`：退出 0，无空白错误；该命令检查从任务基点到当前工作树的产品、测试及报告差异。

## 交接

PM 独立复验 `team review P381 --strong` 后决定合并；本次不是独立复验。后续可从 `df6339c1` 重跑行为及真实 Pi 证据，原始日志为本地忽略文件，不应当作随分支提交的证据包。
