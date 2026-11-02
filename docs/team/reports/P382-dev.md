# P382 · 账本归属夹具在无用户名的容器内运行

agent: dev · status: delivered · phase: apply · change: - · category: code

specs: `verification#The gate judges behaviour only, and never reports a skip as a pass`

branch: `task/P382-public-ci-ledger-claim`（local）

## 结论及范围

P239 夹具原先依赖运行容器的 UID 能解析为用户名：同一基线在宿主机 15/0，而在指定镜像、UID 无 passwd 条目的环境中为 13/2，失败正是干净报告 ③ 与旧扫描面假绿对照 ⑥。`skills/teamsmith/tests/ledger-claim.sh` 现在只对它创建的夹具树扫描指定虚拟用户名；真实账本扫描器和它的 SKIP/退出码契约未改。实现提交 `bed12c9dca35a2d66f3eee9412ddad29356e06c3`。

本任务不处理发布运行中两个被取消的分片、coverage 失败、超时、调度或工作流；没有运行全量门禁、发布、合并、推送或重试 CI。

## 环境与证据位置

- 基线提交 `db0bea987e73e26d4d287c88505e588bfbea01cb`；候选提交 `bed12c9dca35a2d66f3eee9412ddad29356e06c3`。各自是独立的浅克隆；容器只读挂载其 `/work`，不依赖 worktree 外的 `.git` 指针。
- 镜像 `localhost/teamsmith-gates:ci`：`91fa9dab310641a6f4dca892520a31a3cd9d3699fb34919c468ad22d929df793`。
- 下述 `$CACHE` 均为 `$HOME/.cache/teamsmith-p382-dev`。完整输出和容器的临时根都在该宿主目录；下面只摘关键行。环境探针输出：

```text
uid=1000 gid=1000 HOME=/tmp USER=<unset> LOGNAME=<unset> TMPDIR=/evidence/numeric-tmp
id: cannot find name for user ID 1000
id-name=unresolved
tree=db0bea987e73e26d4d287c88505e588bfbea01cb
git-root=/work
temp-writable=yes
```

Podman 在 `--userns=keep-id` 时默认把宿主用户写入容器 passwd，首次探针因此错误地解析出了用户名。后续复现均使用 `--passwd=false`，保留 UID/GID 1000 和 host PID namespace，且使 passwd 与 GitHub Docker 的无条目形状一致；`--cgroups=enabled` 是此处 Podman 的 `--pid=host` 要求。`container-environment.log` 保存成功探针。

准备克隆与检查镜像的实际命令（执行目录是任务工作树）：

```bash
CACHE="$HOME/.cache/teamsmith-p382-dev"
mkdir "$CACHE"
mkdir "$CACHE/host-tmp" "$CACHE/numeric-tmp"
git init -q "$CACHE/baseline"
git -C "$CACHE/baseline" fetch --quiet --depth=1 "$PWD" db0bea987e73e26d4d287c88505e588bfbea01cb
git -C "$CACHE/baseline" checkout --quiet --detach FETCH_HEAD
distrobox-host-exec podman image inspect localhost/teamsmith-gates:ci --format '{{.Id}}'
TIP="$(git rev-parse HEAD)"
git init -q "$CACHE/candidate"
git -C "$CACHE/candidate" fetch --quiet --depth=1 "$PWD" "$TIP"
git -C "$CACHE/candidate" checkout --quiet --detach FETCH_HEAD
cp -a "$CACHE/candidate" "$CACHE/flip"
```

## 翻转证据：基线红 → 修复绿 → 删除参数重现红

三次容器的执行命令，分别把完整输出保存为 `baseline-container.log`、`fixed-container.log`、`flip-container.log`：

```bash
distrobox-host-exec podman run --rm --pid=host --cgroups=enabled --userns=keep-id --passwd=false --user "$(id -u):$(id -g)" -e HOME=/tmp -e TMPDIR=/evidence/numeric-tmp -v "$CACHE/baseline:/work:ro" -v "$CACHE:/evidence" -w /work localhost/teamsmith-gates:ci bash -c 'TEAM_SMOKE_FIXTURE=1 bash skills/teamsmith/tests/ledger-claim.sh' >"$CACHE/baseline-container.log" 2>&1

distrobox-host-exec podman run --rm --pid=host --cgroups=enabled --userns=keep-id --passwd=false --user "$(id -u):$(id -g)" -e HOME=/tmp -e TMPDIR=/evidence/numeric-tmp -v "$CACHE/candidate:/work:ro" -v "$CACHE:/evidence" -w /work localhost/teamsmith-gates:ci bash -c 'TEAM_SMOKE_FIXTURE=1 bash skills/teamsmith/tests/ledger-claim.sh' >"$CACHE/fixed-container.log" 2>&1

distrobox-host-exec podman run --rm --pid=host --cgroups=enabled --userns=keep-id --passwd=false --user "$(id -u):$(id -g)" -e HOME=/tmp -e TMPDIR=/evidence/numeric-tmp -v "$CACHE/flip:/work:ro" -v "$CACHE:/evidence" -w /work localhost/teamsmith-gates:ci bash -c 'TEAM_SMOKE_FIXTURE=1 bash skills/teamsmith/tests/ledger-claim.sh' >"$CACHE/flip-container.log" 2>&1
```

`flip` 是候选副本，只把 `fixture_ban()` 内的 `--user p239fixtureuser` 删除；原工作树没有变异。实际变异命令如下，替换前匹配数断言为 1；`git -C "$CACHE/flip" diff -- skills/teamsmith/tests/ledger-claim.sh` 只显示这一行差异。

```bash
python3 - "$CACHE/flip/skills/teamsmith/tests/ledger-claim.sh" <<'PY'
import pathlib, sys
p = pathlib.Path(sys.argv[1])
s = p.read_text()
old = 'fixture_ban() { TEAM_SMOKE_FIXTURE=1 bash "$@" --user p239fixtureuser; }'
new = 'fixture_ban() { TEAM_SMOKE_FIXTURE=1 bash "$@"; }'
if s.count(old) != 1:
    raise SystemExit('expected exactly one fixture-user anchor')
p.write_text(s.replace(old, new))
PY
```

结果摘录（诊断行的路径省略）：

```text
baseline: ✗ ③ 干净报告没有绿（rc=3）… SKIP user …
baseline: ✗ ⑥ 假绿对照没复现（rc=3）… SKIP user …
baseline: == ledger-claim == ✓ 13 ✗ 2   exit=1
fixed:    ✓ ③ 干净报告（只有占位符 <home>）→ rc=0 hits=0
fixed:    ✓ ③ 植入家目录字面量 → 红并点名 docs/team/reports/planted-report.md:4（原文被遮蔽）
fixed:    ✓ ⑥ 账本面覆盖非 .md：ledger/*.tsv 里的名字 → 红并点名 planted.tsv:2（同一棵树里的 .md 是干净的）
fixed:    ✓ ⑥ 假绿对照：账本面退回「只扫 *.md」→ 同一棵树、同一个植入 hits=0（假绿就是这么来的）
fixed:    == ledger-claim == ✓ 15 ✗ 0   exit=0
flip:     ✗ ③ 干净报告没有绿（rc=3）… SKIP user …
flip:     ✗ ⑥ 假绿对照没复现（rc=3）… SKIP user …
flip:     == ledger-claim == ✓ 13 ✗ 2   exit=1
```

固定用户名只传给扫描夹具树的子进程，包含旧面的扫描器副本；家目录和非 Markdown 名字的红侧断言仍在并实际通过。

## 宿主兼容、扫描器边界和轻量检查

实际命令（基线与候选分别记录在 `baseline-host.log`、`fixed-host.log`）：

```bash
TEAM_SMOKE_FIXTURE=1 TMPDIR="$CACHE/host-tmp" bash "$CACHE/baseline/skills/teamsmith/tests/ledger-claim.sh"
TEAM_SMOKE_FIXTURE=1 TMPDIR="$CACHE/host-tmp" bash skills/teamsmith/tests/ledger-claim.sh
env -u TEAM_SMOKE_FIXTURE TMPDIR="$CACHE/host-tmp" bash skills/teamsmith/tests/ledger-claim.sh
```

三个结果均为 `== ledger-claim == ✓ 15 ✗ 0`、`exit=0`；第三条证明夹具原来公开的直接调用方式不需要调用者设置夹具环境变量。

另在同一数值 UID 容器中对干净的私有控制树执行原扫描器两次：

```bash
mkdir -p "$CACHE/control-root/docs/team/reports" "$CACHE/control-root/.pi/team"
printf '# clean fixture report\n' >"$CACHE/control-root/docs/team/reports/clean.md"
printf '# names fixture\nfixture-peer\n' >"$CACHE/control-root/.pi/team/forbidden-names.txt"
distrobox-host-exec podman run --rm --pid=host --cgroups=enabled --userns=keep-id --passwd=false --user "$(id -u):$(id -g)" -e HOME=/tmp -e TMPDIR=/evidence/numeric-tmp -v "$CACHE/candidate:/work:ro" -v "$CACHE:/evidence" -w /work localhost/teamsmith-gates:ci bash -c '
  bash skills/teamsmith/tests/ledger-ban.sh --all --root /evidence/control-root --user p239fixtureuser
  r1=$?
  TEAM_SMOKE_FIXTURE=1 bash skills/teamsmith/tests/ledger-ban.sh --all --root /evidence/control-root --user p239fixtureuser
  r2=$?
  printf "nonfixture_rc=%s fixture_rc=%s\n" "$r1" "$r2"
  [ "$r1" = 3 ] && [ "$r2" = 0 ]
' >"$CACHE/scanner-boundary.log" 2>&1
```

```text
ledger-ban: 注意：--user 只给夹具路径用；非夹具路径忽略它（改用运行时解析出的本机用户名）
ledger-ban: SKIP user —— 本机用户名解析不出来（id -un / $USER / $HOME 都不可用；这一项不是通过）
ledger-ban: root=/evidence/control-root scope=all files=1 hits=0 names=ok user=unresolved
ledger-ban: root=/evidence/control-root scope=all files=1 hits=0 names=ok user=resolved
nonfixture_rc=3 fixture_rc=0
```

基线与候选的 `ledger-ban.sh` SHA-256 均为 `66f698ad4f6ab5eaab045f6e7ad7906fddea0e280239e521a206a2dfd4ac0443`。

```bash
bash -n skills/teamsmith/tests/ledger-claim.sh
git diff --check
bash skills/teamsmith/tests/section-select.sh --check
```

```text
bash -n exit=0
git diff --check exit=0
== 选段自检 ==  ok 12  bad 0  SKIP 1
section-select --check exit=0
```

选择器的 1 项 SKIP 是检出中不存在 `.pi/skills`，不是通过。完整记录在 `host-checks.log`。宿主找不到 `openspec`（exit=127，`openspec.log`），随后在上述指定镜像的候选克隆里执行 `openspec validate --all --strict`，`Totals: 19 passed, 0 failed (19 items)`，exit 0（`openspec-container.log`）。

## 指定容器选段

实际命令（修复源码提交的独立干净克隆、只读挂载；完整日志在 `select-60.log`）：

```bash
distrobox-host-exec podman run --rm --pid=host --cgroups=enabled --userns=keep-id --passwd=false --user "$(id -u):$(id -g)" -e HOME=/tmp -e TMPDIR=/evidence/numeric-tmp -v "$CACHE/candidate:/work:ro" -v "$CACHE:/evidence" -w /work localhost/teamsmith-gates:ci bash -c 'bash skills/teamsmith/tests/smoke.sh --select 60 </dev/null' >"$CACHE/select-60.log" 2>&1
```

```text
✓ P212 真实账本：无命中（root=/work scope=published files=2215 hits=0 names=missing user=unresolved）
SKIP（条件不满足） P212 他项目名形状（真实账本） —— SKIP names —— 禁令名单未配置（/work/.pi/team/forbidden-names.txt 不存在；这一项不是通过）
SKIP（条件不满足） P212 本机用户名形状（真实账本） —— SKIP user —— 本机用户名解析不出来（id -un / $USER / $HOME 都不可用；这一项不是通过）
✓ P239 归属与红侧全绿（15 条用例：归属 / 承重 / 开火 / 假绿对照）
#5 60 · … · ✓17 ✗0 SKIP2 · ticks 19
账本自查： 5 段收口 · 增量 ✓41 ✗0 SKIP2 ｜ 结果行 ✓41 ✗0 —— 一致
== 选段结果 ==  ✓ 41  ✗ 0
exit=0
```

两项真实账本检查是 SKIP，不计为通过。选段实际运行 60 及前导 0、0b、0c、0d；另有 130 个键未运行，不是全量门禁。克隆在门禁前后均无未提交改动。这里是作者的验证结果，独立复验和合并由 PM 安排。
