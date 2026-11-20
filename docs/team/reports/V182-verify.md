# V182 · 帮助测试与性能测量分开的方案审阅

agent: verify · status: REWORK（仅方案） · time: 2026-11-20T07:33:27Z

branch: `task/V182-help-perf-entry-proposal-review` · PR/MR: -

**方向可行，先修两处文字再实施。** 方案能删掉帮助测试中的一次无效测量，并保留真实 `team perf --host` 的调用交接和临时项目不变检查。但两条故意改坏的验收样本按当前任务清单会选错目录，在启动 CLI 前一起退出；规格中另有一处封闭的例外清单遗漏了本次替换。两处都只需修方案，不需要改产品或增加测试。

## Deliverables

| Path | What |
|---|---|
| `docs/team/reports/V182-verify.md` | 独立审阅 PM 准备的只读检出 `79cd6a73421a19c6cc5af3496660852a9b814829`；相对共同基线 `58aec8a9` 只有五份提案文件与作者报告。 |

## 必须修正

1. **`tasks.md` 的两个故障样本必须把 `tree` 指向复制目录的根，而不是技能目录。** `tests/help-surface.sh:59–62,118–119` 将 `skills/teamsmith` 固定接在 `TEAM_HELP_SURFACE_TREE` 后；按“set `tree` … to the corresponding disposable copy of its `skills/teamsmith` tree”把变量指向技能目录，会实际查找 `…/skills/teamsmith/skills/teamsmith/scripts/team`，在建临时项目和调用 CLI 前就以 3 报“没有 CLI”。静态存在性检查：检出根的两个前置文件都存在；把技能目录当 `tree`，两个都不存在。沿用 `help-surface.sh:1400–1417` 的既有复制形状：每个 `<copy-root>` 内保留 `skills/teamsmith/`，在 `<copy-root>/skills/teamsmith/scripts/team` 改 `perf` 分支，传 `TEAM_HELP_SURFACE_TREE=<copy-root>`；正常样本仍传独立检出根。这样私有 CLI 的 `scripts/` 才会从实际选中的故障版本复制。无需新参数或新脚本。
2. **`specs/verification/spec.md` 的旧反例场景须与新增的唯一例外一致。** 提案在主要求与 *The internal checkout loses no existing coverage* 已明确允许单一 `perf` 替换；同一要求的 *The named replacement cannot hide a lost CLI or renderer assertion* 末尾仍称“only … are allowed”，只列到 selected-settings（候选第 238 行）。在该句加上已定义的单一 `perf` 例外，保留原先“漏掉仍应执行的任何 CLI 检查必须失败”的判据及场景其它内容；不扩大例外。

## OpenSpec assessment

| Dimension | Result | Evidence |
|---|---|---|
| Completeness | 只审方案，结构通过 | OpenSpec 1.16.0 strict 通过；差异只涉及 `verification#A gate that cannot judge says so` 的一项替换和三个场景，既有封闭清单需同步。实施清单尚未执行，不计完成。 |
| Correctness | 路线可行，验收目录需修 | `help-surface.sh:359–386,1025–1044` 先在临时 `p-perf` 目录用完整选中源码初始化，然后才取指纹和调用；私有 `scripts/` 应仅用于这次性能入口。`scripts/team:24–26,59–65,78–90,141` 从自身目录装载 `lib/common.sh` 及 `cmd-*.sh`，其中 `cmd-review.sh:10–14` 另需同目录的 `gate-lock.sh`，完整 `scripts/` 已涵盖。`common.sh:28–37` 从实际加载的 `common.sh` 定技能根，`team_cmd_perf`（`cmd-docs.sh:148–152`）只从它的 `tests/perf.sh` 转发原参数、返回 Bash 的状态，没有回退到原测量程序。项目身份从调用目录解析，既有 `env_run` 在 `p-perf` 内清除继承身份；私有脚本的存放位置不会变成调用项目。未发现需额外复制的启动文件。 |
| Coherence | 一换一；未束缚真实测量 | `help-surface.sh:929,1047–1061` 只从原 `smoke perf` 有界分支拿掉 `perf`；方案仍要求一条完整记录、确切 `--host`、物理目录、预期退出状态及六项指纹同时符合，不以缩短等待冒充成功。`team smoke --select 0`、其余帮助检查及正式超时保留。基准 `help-surface`、性能规格、CLI、`tests/perf.sh` 和 `.github/workflows/gates.yml:333–341` 的独立参考测量在候选无差异。 |

修正样本目录后，两处改坏会命中 `scripts/team:141` 的同一个 `perf` 分支，而不会影响初始化分支。提前 `exit 0` 应无记录、六项指纹不变；写入临时调用项目的 `.pi/team/state/` 后仍调用原 `team_cmd_perf "$@"`，应有有效记录和预期非零状态，且只有 `state` 指纹变化。`help-surface.sh:312–352` 的 `state` 指纹包含文件目录形状与内容；写入失败、缺记录、意外退出或无关报错均不能代替第二个反例。`--select claims` 与 `TEAM_HELP_SURFACE_ONLY=perf` 只选这一个命令探测，仍按原逻辑检查共同词表并统计失败（`:1166–1179,1594–1607`），不能只凭脚本退出 1 即当故障命中。

**取证边界：** 入口替身不执行真实测量的准备或运行，因此不能证明真实测量全程未写调用项目；既有独立测量提供读数，也不补这项证据。`design.md` 与 delta 均已明示，符合 P481 接受记录，不列为阻碍。不重估历史 §51 的 705 秒或承诺节省量。

## Final assessment

- CRITICAL 2 · WARNING 0 · SUGGESTION 0。返修范围只限上述两处；不授权实施或行为验证。修正后可只复看相应文字和路径。
- 未运行帮助、性能、smoke、完整套件、两个故障样本或试归档；`openspec-verify-change` 生成指引未在席位及固定检出找到，本阶段按任务书做等价的提案结构、差异和调用路径审阅，不是实施后的 OpenSpec 验证。

## Verification evidence

```text
$ git --no-optional-locks -C "$S" status --porcelain=v1  # S 为固定检出
[无输出；HEAD=79cd6a73421a19c6cc5af3496660852a9b814829]
$ PATH="$HOME/.bun/bin:$PATH" openspec --version
1.16.0
$ (cd "$S" && export PATH="$HOME/.bun/bin:$PATH" OPENSPEC_TELEMETRY=0 TMPDIR=/var/tmp && openspec validate help-perf-entry-without-measurement --strict)
Change 'help-perf-entry-without-measurement' is valid
change_strict_rc=0
$ git -C "$S" diff --check 58aec8a9..HEAD
proposal_diff_check_rc=0
$ git -C "$S" diff --exit-code 58aec8a9..HEAD -- .github/workflows/gates.yml skills/teamsmith openspec/specs
unmodified_real_paths_rc=0
$ bash -n <各文件单独执行>
tests/help-surface.sh syntax_rc=0
scripts/team syntax_rc=0
scripts/lib/common.sh syntax_rc=0
scripts/lib/cmd-docs.sh syntax_rc=0
tests/perf.sh syntax_rc=0
$ test -f "$tree/skills/teamsmith/scripts/team"  # 同样检查 scripts/strings/commands.tsv
检出根：两者 rc=0；技能目录：两者 rc=1
```

账本公开文件检查（本席位工作树；工具自身遮掉了用户名）：

```text
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=…/.worktrees/verify scope=published files=2931 hits=0 names=ok user=resolved
ledger_rc=0
```

本报告首次 `git diff --cached --check` 发现第 3 行文末空格（退出 2）；去除后 `report_diff_check_rc=0`，暂存区只有本报告。

## Flip evidence

未执行。当前是提案审阅；两种故障的分支、观察和预期结果为静态判断，不是运行结果。

## Decisions and deviations

只写本报告并在任务分支本地提交，不推送、不改正式审阅记录。请 PM 将第 1、2 项交 P482 作者修订；独立行为验收仍留给实施后的一次定点验证。
