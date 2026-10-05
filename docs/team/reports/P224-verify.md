# P224 · P223 失败现场保留与收集的独立验证

agent: verify   status: PASS   time: 2026-10-05
branch: `task/P224-verify`   PR/MR: -（local 模式）
被验源码：`508c7e9d`；被验实现：`3ec94fb9`（apply=dev2）。

## Deliverables

| Path | What |
|---|---|
| `docs/team/reports/P224-verify.md` | 独立结论、实际命令与输出、接线判断及验证边界 |
| `docs/team/reports/P224-verify/` | 本地证据包：驱动脚本、影子 diff、日志、根清单、归档及逐包内容清单；按 D94 ignore，不提交 |

## Verification evidence

结论：任务书六项通过。没有修改产品实现，所有变异只发生在自己的证据包 scratch clone 内。

### 1. 真入口两个方向与决定性影子

实际执行入口：

```bash
bash docs/team/reports/P224-verify/run.sh
```

驱动创建独立 git clone，使用已有 `localhost/teamsmith-gate:local` 镜像，经 `distrobox-host-exec podman run --rm --pid=host --cgroups=enabled --userns=keep-id -e HOME=/tmp` 运行。源码只读挂载，证据包单独可写挂载。每次探针清除 keep、FAST、锁及团队身份的继承环境，用自己的 `TMPDIR` 与 `TEAM_SMOKE_LOCK`；精确清洗列表见包内 `container-checks.sh`。

容器内真正调用（不是截取函数）：

```bash
TMPDIR=/tmp/p224-probes/shadow TEAM_SMOKE_LOCK=/tmp/p224-probes/shadow/probe.lock \
  bash /shadow/skills/teamsmith/tests/smoke.sh --keep --select 15 </dev/null
TMPDIR=/tmp/p224-probes/keep TEAM_SMOKE_LOCK=/tmp/p224-probes/keep/probe.lock \
  bash /work/skills/teamsmith/tests/smoke.sh --keep --select 15 </dev/null
TMPDIR=/tmp/p224-probes/nokeep TEAM_SMOKE_LOCK=/tmp/p224-probes/nokeep/probe.lock \
  bash /work/skills/teamsmith/tests/smoke.sh --select 15 </dev/null
```

三次都有“全量门禁互斥：持有”行，且入口子套件均 rc=0，确实经过锁的 re-exec。根清单是退出后在各私有 base 内重新 `find` 得到的，不以提示文字替代实际存在性。

| 版本 / 参数 | 入口 rc | 退出后现场根 | 点名保留路径 |
|---|---:|---:|---|
| 影子：仅删掉解析后 export / `--keep` | 0 | 0 | 无 |
| 原实现 / `--keep` | 0 | 1 | 有，且与实际根路径一致 |
| 原实现 / 无 `--keep` | 0 | 0 | 无 |

原实现输出：

```text
PROBE keep rc=0 roots=1
保留临时根：/tmp/p224-probes/keep/teamsmith-smoke.rXIU5O（TEAM_TMP_KEEP=1）
PASS restored GREEN: closing line names the retained path
PROBE nokeep rc=0 roots=0
PASS negative control: no root and no kept-path line
```

### 2. 收集器三向、边界与成功路径

自己造暂存目录：四种前缀目录、三种点名日志、锁和 holder，另加 `other-big/blob`（8 MiB）、顶层 `self -> self`，及合法现场族内 `loop -> loop`。

```bash
bash /work/ci/collect-scene.sh --stage /tmp/p224-collector/stage \
  --out /evidence/artifacts/positive --gate-outcome failure
bash /work/ci/collect-scene.sh --stage /tmp/p224-collector/empty \
  --out /evidence/artifacts/empty --gate-outcome failure
bash /work/ci/collect-scene.sh --stage /tmp/p224-collector/empty \
  --out /evidence/artifacts/disabled --min-families 0
```

```text
COLLECT positive rc=0 expected=0
[族] config-cli.case  2 文件  8 B
[日志] m28-lint.log  1 文件  8 B
[族] teamsmith-smoke.case  3 文件  12 B
同前缀但不算现场（计入产物、不计入阈值）：teamsmith-smoke.lock teamsmith-smoke.lock.holder
判据：现场族 7 个（打包 7，打包失败 0）· 阈值 1
COLLECT empty rc=1 expected=1
找到的现场族（0）少于阈值（1）—— 失败现场没带出来
找过的路径：
$STAGE/teamsmith-smoke.* → 0 项
$STAGE/m28-lint.log 不在
暂存目录里实际有什么（前 30 项）：
COLLECT disabled rc=0 expected=0
注意：--min-families 0 —— 阈值自证被**关掉**（影子实验形态），找不到现场也绿
```

- 全部七个现场项都打印数量与字节；逐一 `tar -tvzf` 检查九个产物，均不含 `other-big/`、blob 或顶层 self 软链。族内 loop 以软链条目保存，没有遍历，未触发 ELOOP。
- 锁、holder 是明确点名的兼容产物，不计现场阈值；不是声称“每个归档都是现场族”。补跑仅锁的目录，rc=1，现场族数为 0，能拒绝历史上的“只有锁文件却绿”。
- 补跑 `--gate-outcome success` + 空目录，rc=0，打印“不收集现场”，没有阈值判定、没有产物目录。
- 补跑 success + `--container p224-not-a-real-container --docker /tmp/p224-collector/docker-recorder`，只有 `rm -f p224-not-a-real-container` 一次，没有 cp。此项是 argv 记录桩，不是停容器拷贝实测。
- 诊断精度说明：空目录逐项路径使用字面 `$STAGE`，真实暂存路径在首行；“文件数”采用 `find` 条目数，包含目录本身及软链，不是仅普通文件数量。两点不影响本任务的保留、阈值及排除结果。

```text
INDEPENDENT_CHECKS pass=27 fail=0
```

### 3. 工作流接线（静态独立阅读）

读取 `.github/workflows/gates.yml`：

- 第 78 行 `id: gates`，第 91 行入口仍为 `openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh --keep </dev/null`。
- 第 94 行收集步 `if: always()`；第 96 行实际变量名是 `GATES_OUTCOME`（复数），值来自 `${{ steps.gates.outcome }}`；第 107 行通过 `--gate-outcome "$GATES_OUTCOME"` 交给收集器。
- `ci/collect-scene.sh` 第 67–70 行：success 在拷贝和阈值判断前清理容器并 exit 0；failure 走收集及第 164 行阈值判断。空现场不会把原本成功的 gate 变红，已用上述 success 实跑交叉确认。

### 4. 门禁

在同一容器的干净只读 clone 内实际运行，无 FAST：

```bash
openspec validate --all --strict
bash /work/skills/teamsmith/tests/smoke.sh --select 40 </dev/null
```

```text
OPENSPEC rc=0
Totals: 13 passed, 0 failed (13 items)
SECTION40 rc=0
P223 --keep 探针真走了机器锁的 re-exec（不是白捡的绿）
P223 --keep 探针：选段子套件真跑完（rc=0）
P223 --keep 穿过 re-exec：根留在原处（teamsmith-smoke.tsoeaP）
P223 反向对照：不带 --keep 时根被收走（判据分得出两者）
40 · 临时根纪律 · 用时 18s · ✓21 ✗0 SKIP0
账本自查：5 段收口 · 增量 ✓42 ✗0 SKIP0 ｜ 结果行 ✓42 ✗0 —— 一致
选段结果：✓42 ✗0
```

第 40 段及依赖 0、0b、0c、0d 均实跑。没有用全套绿替代选段证据。

## Flip evidence

只在 scratch 影子删除唯一一行：

```diff
-[ "$KEEP" = "1" ] && export TEAM_TMP_KEEP=1
+# P224 shadow: remove only the pre-lock keep export.
```

真入口影子侧输出：

```text
PROBE shadow rc=0 roots=0
KEEP_CONTRACT rc=1 (expected RED on the single-line shadow)
```

上面的原实现真入口 `roots=1` + 路径实存为恢复后的绿侧；入口 rc=0 并不证明 keep 契约，独立守卫以根存在性判红。

另跑现有第 40 段守卫，证明它会抓住这次变异（不是只靠新写的断言）：

```bash
bash docs/team/reports/P224-verify/shadow-gate.sh
# 在只读影子 clone 内：bash skills/teamsmith/tests/smoke.sh --select 40 </dev/null
```

```text
SHADOW_SECTION40 rc=1 (expected 1)
✓ P223 --keep 探针真走了机器锁的 re-exec（不是白捡的绿）
✓ P223 --keep 探针：选段子套件真跑完（rc=0）
✗ P223 --keep 没有穿过 re-exec：跑完根被收走了
✗ P223 --keep：收尾行点名保留路径（现场真的留下了）
账本自查：5 段收口 · 增量 ✓40 ✗2 SKIP0 ｜ 结果行 ✓40 ✗2 —— 一致
选段结果：✓40 ✗2
PASS existing P223 guard rejects the single-line shadow
```

红侧恰好是两条保留现场断言；反向清理仍绿。保留修复的原实现同一选段为 `rc=0 / ✓42 ✗0`，日志分别在证据包 `logs/shadow-section40.log` 与 `logs/section40.log`。

## Decisions and deviations

- 无实现变更，无跨目录修改。local 模式不 push、不建 PR/MR。
- 按任务书跑严格规格和容器第 40 段；没有跑全套 smoke、FAST 全套、perf、远端 CI、GitHub 上传 action，也没有真实停容器 `docker cp`。其余 120 个 smoke 键未跑（具体清单见包内 `logs/section40.log`）。
- 原始证据、可重建 clone 与归档只留本地证据包，不 force-add，遵守 D94。

## Suggested next steps

- PM 在独立检出复验后决定收取报告。无 BLOCKED。
