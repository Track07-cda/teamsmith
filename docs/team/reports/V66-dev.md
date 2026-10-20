# V66 · 独立复核 P324：keep 回收探针与失败现场收集（verify）

agent: dev   status: delivered   time: 2026-10-20T04:15Z
branch: `task/V66-ci-scene-review`   PR/MR: -（local 模式）
phase: verify（只读复核 P324；未改产品、测试、CI、规格、版本、看板）
审查对象：`task/P324-ci-scene-and-reclaim-repair`，冻结提交 `7e548ce129d0`；审查时分支 tip 后移到
`df10ed64`（仅注释与报告，见 §1，可执行内容与冻结提交相同）
证据基：私有克隆 `$HOME/tmp/v66-dev-review/tree`（HEAD=`7e548ce129d0807b82fe43a86d8956ab26b11687`，
`git status --porcelain --untracked-files=all` 为空）；全部日志与产物在克隆外 `$HOME/tmp/v66-dev-review/`。
钉住的 SHA-256（冻结提交）：`smoke.sh` `1d994bc0…`、`ci/collect-scene.sh` `ccad9c7d…`、
`.github/workflows/gates.yml` `9da634dd…`（tip 的 gates.yml 只改注释，新哈希 `2a550df0…`）。

## 结论

PASS。两处修复都独立成立，红侧仍然可证伪，可执行内容相对冻结提交一个字没变。

1. **34c 回收探针**：与 CI 同形的容器运行（显式 `TMPDIR`、`mkdir -p` 在前、`--select 34c --keep`）为
   `✓ 49 ✗ 0`、`GATE_RC=0`，外层现场根被保留（332 KB / 129 文件）；把 `TMP_ROOT_BREAK=noreap`
   还给同一入口后，目标断言变红：`✗ 34c 主人退场后根还在（回收没生效？）`、`✓ 48 ✗ 1`、rc=1
   （这是预期的反例，不算通过）。
2. **失败现场收集**：同一个停止的一次性容器、同一个显式根，新 collector `rc=0`、1 个族、tgz 129 项
   （80 文件 + 49 目录），锁名零命中，owner 标记与真实文件都有内容；旧 collector 在同一容器上
   `rc=1`、0 个族，暂存里只有容器 `/tmp` 的 `node-compile-cache` / `tmux-build.log`。
3. **workflow 接线**：唯一值 `$TEAM_CI_TMP_ROOT` 同时喂给两个调用（gate 的 `-e TMPDIR=…` 与 collector
   的 `--tmp-root`），`mkdir -p "$TMPDIR"` 在容器内、在 `openspec validate` 与 smoke 之前执行；
   60 分钟时限、`--min-families` 默认阈值、上传条件（`if: failure()`）都没动。

PM 2026-10-20 的补充（容器的 34c `--keep` 覆盖正向、宿主只跑反例）在本批次启动后才投递到会话；
宿主的正向那一条已随批次在跑，按该指示未再额外跑任何宿主正向运行。下面 §2 的容器腿是正向主证据，
宿主正向只作同机对照保留。

## 1 · 后到增量：只有注释与报告

```bash
git diff --stat 7e548ce129d0 df10ed64
#  .github/workflows/gates.yml    | 7 ++-----
#  docs/team/reports/P324-dev2.md | 8 ++++----

git diff 7e548ce129d0 df10ed64 -- .github/workflows/gates.yml
#  -（P324 旧注释 5 行：TMPDIR 解析器排第一 / 容器 /tmp 与 tmpfs 吃 RAM …）
#  +（P324 新注释 2 行：一个显式临时根、gate 建出来、collector 收同一个值）

# 注释不参与执行：用 js-yaml 解析两份 workflow 后比较
parsed objects identical = true
run blocks identical = true
```

`smoke.sh` 与 `ci/collect-scene.sh` 在 `7e548ce129d0..df10ed64` 里零差异，所以 §2–§4 的实测证据对 tip
同样成立，按任务书不重跑，也不另开验收轮次。

## 2 · 34c 回收：正向与反例（独立实测）

克隆内、私有磁盘临时根、私有锁；每次运行前后比对 HEAD + `git status --porcelain --untracked-files=all`
+ 三个文件的 sha256（§6）。

```bash
D1=$(mktemp -d /var/tmp/v66-a1.XXXXXX)          # → /var/tmp/v66-a1.iLD0RU
env TMPDIR="$D1" TEAM_SMOKE_LOCK="$D1/teamsmith-smoke.lock" \
  bash skills/teamsmith/tests/smoke.sh --select 34c --keep      # A1：宿主正向（同机对照）
D2=$(mktemp -d /var/tmp/v66-a2.XXXXXX)          # → /var/tmp/v66-a2.ukBNeK
env TMPDIR="$D2" TEAM_SMOKE_LOCK="$D2/teamsmith-smoke.lock" TMP_ROOT_BREAK=noreap \
  bash skills/teamsmith/tests/smoke.sh --select 34c --keep      # A2：反例
```

```
A1  rc=0   ✓ 34c 私有临时根里收到 15 个条目
           ✓ 34c 主人退场 → 两个根都被回收（生命周期归创建者）
           == 选段结果 ==  ✓ 49  ✗ 0
    临时根（结束）：/var/tmp/v66-a1.iLD0RU/teamsmith-smoke-tree-9f785d39.goVUF7（332 KB · 127 文件）
    保留临时根：…/teamsmith-smoke-tree-9f785d39.goVUF7（TEAM_TMP_KEEP=1）   ← 外层现场照旧保留
    A1 根下顶层：含 .teamsmith-tmp-ledger…、teamsmith-smoke.lock 与 teamsmith-smoke-tree-9f785d39.goVUF7；
    没有 nsprobe 根残留

A2  rc=1   ✗ 34c 主人退场后根还在（回收没生效？）
           == 选段结果 ==  ✓ 48  ✗ 1
```

A2 的 rc=1 是任务书要求的反例，不是通过项；A1 与 A2 用的是同一个入口与同一个 `--keep`，差别只在
`TMP_ROOT_BREAK=noreap`（产品里既有的翻转开关，没有新增测试钩子）。日志：
`$HOME/tmp/v66-dev-review/logs/A1.log`、`A2.log`、`A1-tmp.txt`、`A2-tmp.txt`。

容器腿（正向主证据）：

```bash
PODMAN='distrobox-host-exec podman'
B="$HOME/tmp/v66-dev-review"
$PODMAN run --name v66-dev-gates-3068464 --pid=host --cgroups=enabled --userns=keep-id \
  --user "$(id -u):$(id -g)" -e HOME=/tmp -e TMPDIR=/var/tmp/teamsmith-ci-tmp \
  -v "$B/tree:/work:ro" -w /work localhost/teamsmith-gates:p223 \
  bash -c 'mkdir -p "$TMPDIR" && bash skills/teamsmith/tests/smoke.sh --select 34c --keep </dev/null; \
           rc=$?; echo "GATE_RC=$rc"; exit 7'
```

```
✓ 34c 主人退场 → 两个根都被回收（生命周期归创建者）
== 选段结果 ==  ✓ 49  ✗ 0
临时根（结束）：/var/tmp/teamsmith-ci-tmp/teamsmith-smoke-work-0c9a453f.F3PSmZ（332 KB · 129 文件 · source=tmpdir）
保留临时根：/var/tmp/teamsmith-ci-tmp/teamsmith-smoke-work-0c9a453f.F3PSmZ（TEAM_TMP_KEEP=1）
GATE_RC=0
```

容器随后以 `exit 7` 主动非零退出（`podman inspect` → `exited 7`），让收集步真的跑。
`--cgroups=enabled` 是本机 rootless podman 为了接受 `--pid=host` 的本地适配（CI 是 rootful docker，
不需要这个旗标）；见 §7。

## 3 · 失败现场：一个容器、新旧 collector 对照

同一个停止的容器、同一个显式根。新 collector 与旧脚本（`7fbf072c:ci/collect-scene.sh`，
sha256 `7aa173ac…`）**不**再起第二次容器运行：

```bash
bash ci/collect-scene.sh --container v66-dev-gates-3068464 \
  --tmp-root /var/tmp/teamsmith-ci-tmp --out "$B/artifacts/new" --stage "$B/stage" \
  --gate-outcome failure --docker "$PODMAN" --no-remove                  # B1 新脚本
bash "$B/old-collect-scene.sh" --container v66-dev-gates-3068464 \
  --out "$B/artifacts/old" --stage "$B/stage-old" \
  --gate-outcome failure --docker "$PODMAN" --no-remove                  # B2 旧脚本（同一容器）
```

```
B1 rc=0
  collect-scene: distrobox-host-exec podman cp rc=0
  collect-scene: 暂存里一共 5 个顶层项
    [族] teamsmith-smoke-work-0c9a453f.F3PSmZ  129 文件  59.3 KB
         → …/artifacts/new/teamsmith-smoke-work-0c9a453f.F3PSmZ.tgz  25.7 KB
  collect-scene: 判据：现场族 1 个（打包 1，打包失败 0）· 阈值 1
  collect-scene: ✓ 现场带出来了（1 个族进 …/artifacts/new）

B2 rc=1
  collect-scene: 找过的前缀：teamsmith-smoke. panel-p21. config-cli. pty-wait-selftest.
  collect-scene: distrobox-host-exec podman cp rc=0
  collect-scene: 暂存里一共 2 个顶层项
  collect-scene: ✗ 找到的现场族（0）少于阈值（1）—— 失败现场没带出来
  暂存目录里实际有什么：node-compile-cache / tmux-build.log
```

产物与暂存的实际内容（不是只有目录和锁）：

```
== artifacts/new ==   只有 1 个文件：teamsmith-smoke-work-0c9a453f.F3PSmZ.tgz（26342 B）
== stage 顶层 ==      .t-1000.0YhyID/  .teamsmith-smoke.lock.machine  .teamsmith-tmp-ledger.smoke-…
                      teamsmith-smoke-work-0c9a453f.F3PSmZ/  teamsmith-smoke.lock
== tgz 条目 ==        129 项：80 个普通文件（-）+ 49 个目录（d）
== 锁名命中 ==        none（teamsmith-smoke.lock / .holder 都不在产物里）
== owner 标记 ==      kind=smoke  pid=3577771  start=35768380  boot=bdf82bb5-…  run=smoke-3571135-…
== 具名现场文件 ==    teamsmith-smoke-work-0c9a453f.F3PSmZ/run-fingerprint.txt：
  # P158 · 运行指纹
  root: /work
  at_start: 2026-10-20T04:10:41+00:00
  start: head=7e548ce129d0807b82fe43a86d8956ab26b11687 dirty=0 sha=01ba4719…
  at_end: 2026-10-20T04:11:42+00:00
  end: head=7e548ce129d0807b82fe43a86d8956ab26b11687 dirty=0 sha=01ba4719…
  verdict: same
  另一份：conflict-marker-sandbox/.git/config 是正常的 git 配置内容（[core] / [user]）
```

日志：`logs/B0.log`、`B1.log`、`B2.log`、`B3-inspect.txt`。

## 4 · 小实验：软链 / 空目录 / 仅锁 / 旧前缀

复用 §3 的暂存现场（把软链加进暂存的现场族里，不 `podman start`、不重跑容器命令）：

```
C1 软链（--stage 同一现场）  rc=0
   lrwxrwxrwx … teamsmith-smoke-work-0c9a453f.F3PSmZ/link-out -> /etc/passwd
   lrwxrwxrwx … teamsmith-smoke-work-0c9a453f.F3PSmZ/sub-link-out -> /etc/shadow
   （两条按 l 类型入包，没有变成内容文件）
C2 空暂存目录               rc=1，产物 0 项    ✗ 找到的现场族（0）少于阈值（1）
C3 仅锁（lock + .machine + .holder，3 个顶层项） rc=1，产物 0 项    ✗ 同上
C4 旧脚本 + 同一个带 ns 的暂存现场  rc=1，0 个族（旧前缀 teamsmith-smoke. 不再命中）
```

另外两条入口守卫（与“没有静默回落到 /tmp”直接相关）：

```
bash ci/collect-scene.sh --container nobody --out …            → rc=2
  collect-scene: --container 还要 --tmp-root <门禁在容器里的临时根>（与 gate 步同一个值）
bash ci/collect-scene.sh --container nobody --tmp-root relative/x --out …
  → rc=2  collect-scene: --tmp-root 要是容器内的绝对路径（给的是 [relative/x]）
```

日志：`logs/C1.log`、`C1-inspect.txt`、`C2.log`、`C3.log`、`C4.log`。

## 5 · workflow 接线静态复核

against `7e548ce129d0`（与 tip 的差异只有注释，§1）：

- 唯一值：顶层 `env: TEAM_CI_TMP_ROOT: /var/tmp/teamsmith-ci-tmp`（tip `gates.yml:53-54`）。
- gate：`-e TMPDIR="$TEAM_CI_TMP_ROOT"`，容器内 `bash -c 'mkdir -p "$TMPDIR" && openspec validate … && smoke.sh --keep'`
  —— 建根在 `openspec validate` 与 smoke **之前**，同一个 `&&` 链；容器跑在 runner 的 uid 上
  （`--user "$(id -u):$(id -g)"`），镜像里 `/var/tmp` 是 `root:root 1777`，我的容器实跑里
  `mkdir -p /var/tmp/teamsmith-ci-tmp` 成功（§2 B0）。
- collector：`--tmp-root "$TEAM_CI_TMP_ROOT"`，与 gate 是同一个值（不是重算的 ns）。
- 没动的：`timeout-minutes: 60`、collector 的 `if: always()`、upload 的 `if: failure()`、
  `--min-families` 没有出现在命令行（默认 1）、CI 触发条件（diff 里只有上述两个 step 与顶层 env）。
- 语法：`bash -n skills/teamsmith/tests/smoke.sh` rc=0、`bash -n ci/collect-scene.sh` rc=0；
  四个 workflow `run:` 块抽出后逐个 `bash -n` 全 rc=0（js-yaml 解析 + spawn，见 §1 同一脚本）。

## 6 · 运行指纹与只读

```bash
# 克隆内，全部实测前后各取一次
git rev-parse HEAD            → 7e548ce129d0807b82fe43a86d8956ab26b11687（前后相同）
git status --porcelain --untracked-files=all → 空（前后相同）
sha256sum smoke.sh ci/collect-scene.sh .github/workflows/gates.yml → 与 fp-before 逐行相同
```

对比文件 `logs/fp-before.txt`、`fp-after-a.txt`、`fp-after-all.txt`：`diff` 无输出。
容器里的那份 `run-fingerprint.txt` 自己也是 `dirty=0`、`verdict: same`（§3）。

## 7 · 未观测边界

- **没跑全量 / FAST / 安装套件 / 路由变异 / 新计时实验**（任务书禁止）；这里只是 `--select 34c` 与收集步。
  所以「workflow 在真 GitHub CI 上端到端正确」要等合入后的第一次真运行。
- **本机 rootless podman**：`--pid=host` 必须配 `--cgroups=enabled` 才被接受（纯 `--pid=host` 报
  `containers not creating Cgroups must create a private PID namespace: invalid argument`）。CI 是 rootful
  docker，没有这个限制；34c 选段不需要 POSIX/信号角，这次容器运行没有覆盖 §10c 的 SIGTTIN 形状。
- **镜像**：只用了本机已有的 `localhost/teamsmith-gates:p223`（与 `ci/Containerfile` 同一条钉住链，
  2026-10-03），没有重建；它比当前树早，但 34c 在里面全绿，说明够跑这一段，不等于 CI 明天构建的那份。
- **族前缀表覆盖的 kind**：表里的四个前缀与代码里的四个 kind 逐字对应
  （`smoke` / `panel-p21` / `config-cli` / `pty-wait-selftest`；`tmp_root_create` 的调用点已核）。
  全套跑动里还会建 `spec-refs-*` 等其他 kind 的根，它们不在表里 —— 这与旧表（同一组四个 kind）一致，
  不是本次引入的收窄；`--select 34c` 不产生它们，因此这次没有观测到它们是否会以目录形态留到失败现场。
- 克隆的 ns 是 `tree-9f785d39`，容器里的 ns 是 `work-0c9a453f`：两处都只是前缀表里的 kind+`-` 前缀命中，
  collector 不猜 ns，符合设计。

## 8 · 观察（不影响结论）

- PM 要求精简的两句 workflow 注释在冻结提交里还在，作者随后用 `df10ed64` 把它们删成了两句事实
  （不再声称 TMPDIR 排第一，也不再声称容器 `/tmp` 是内存盘）；可执行内容逐项相同（§1）。
- 为审计留档：就本树核对的解析器实现（`scripts/lib/common.sh` 的 `team_tmp_root_source`：tmpdir →
  config → default；`references/config.md:344` 与 verification 规格的同名场景也是 TMPDIR 优先），
  老注释第一句与代码一致；第二句（把容器 `/tmp` 笼统说成内存盘）确实不严谨（我的镜像里 `/tmp` 是容器的
  overlay 目录，`/var/tmp` 同一层）。两句都已删除，没有留下错误断言；我没有改任何文件。
