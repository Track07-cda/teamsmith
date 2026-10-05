# P225 · P222 换人独立验证

agent: verify   status: PARTIAL / NEEDS-CHANGES   time: 2026-10-05
branch: `task/P225-verify`   PR/MR: -（local 模式）
被验修订：`ac4c49ffd68576cf3736ab1c502147ee1b1f4dcf`，含实现 `73ae5a77`；apply=dev，verify 未参与实现。

## Deliverables

| Path | What |
|---|---|
| `docs/team/reports/P225-verify.md` | 独立验证记录 |
| `docs/team/reports/P225-verify/` | 自己构造三棵真 git 树的脚本、对抗性变异、原始日志、独立日志断言；按 D94 留本机，不提交 |

仅改本报告及自己的证据包，没有改实现。三棵树由被验 HEAD 的 `git archive` 独立生成，没有借用产品探针的 scratch 树或断言。内部树的五个 prompt/skill 是明确标注为手写的存在性夹具，并非冒充 OpenSpec 生成物；另从任务书指定的只读账本归档复原两个清单的 17 个原始文件。

## Verification evidence

### 三种形状

容器镜像：`localhost/teamsmith-gate:local`。挂载证据包为 `/evidence`，各副本有真 `.git/`，不用工作树的 git 指针；HOME 指向容器私有目录。实际命令：

```bash
python3 docs/team/reports/P225-verify/prepare.py
distrobox-host-exec podman run --rm --pid=host --cgroups=enabled --userns=keep-id \
  -e HOME=/tmp -v "$PWD/docs/team/reports/P225-verify:/evidence" \
  -w /evidence/.scratch/mixed localhost/teamsmith-gate:local bash /evidence/cases.sh
# cases.sh 在每棵树中分别执行：
openspec validate --all --strict
bash skills/teamsmith/tests/smoke.sh --select 19
bash skills/teamsmith/tests/smoke.sh --select 31
bash skills/teamsmith/tests/smoke.sh --select 58
bash skills/teamsmith/tests/section-select.sh --check
```

`openspec validate --all --strict`：`Totals: 13 passed, 0 failed (13 items)`，exit 0。
三种形状的三个选段与选择器 `--check` 均 exit 0。以下为**目标段自身**的账本计数，不是含依赖段的选段总数：

| 形状 | §19 ✓/✗/SKIP | §31 ✓/✗/SKIP | §58 ✓/✗/SKIP |
|---|---|---|---|
| 公开混合：四个内部面在，两个生成面及证据层不在 | 16/0/10 | 9/0/2 | 13/0/1 |
| 完整内部：六面与全部注册证据在 | 26/0/0 | 9/0/1 | 13/0/0 |
| 纯产品：六个内部面全不在 | 16/0/10 | 9/0/2 | 13/0/1 |

§31 三棵树都有一条与形状无关的既有工具前提 SKIP：容器内无法再次调用 podman，因此 `31b·容器 tmux 自检` 没跑。**两个 lint 本身实际执行了**；内部树没有证据层跳过，§19 十条生成物检查也全部由 SKIP 恢复成 ✓。

公开混合形状的点名行，摘自 `logs/mixed-{19,31,58}.log`（仅去掉 ANSI 色码）：

```text
SKIP（条件不满足） 本仓库为 Pi 生成了相位命令 opsx-explore —— 检出形状 internal：机器生成面（由工具在本机生成、不进仓库） .pi/prompts/opsx-explore.md 在检出里不存在（跳过不是通过）
SKIP（条件不满足） 本仓库为 Pi 生成了相位命令 opsx-propose —— 检出形状 internal：机器生成面（由工具在本机生成、不进仓库） .pi/prompts/opsx-propose.md 在检出里不存在（跳过不是通过）
SKIP（条件不满足） 本仓库为 Pi 生成了相位命令 opsx-apply —— 检出形状 internal：机器生成面（由工具在本机生成、不进仓库） .pi/prompts/opsx-apply.md 在检出里不存在（跳过不是通过）
SKIP（条件不满足） 本仓库为 Pi 生成了相位命令 opsx-verify —— 检出形状 internal：机器生成面（由工具在本机生成、不进仓库） .pi/prompts/opsx-verify.md 在检出里不存在（跳过不是通过）
SKIP（条件不满足） 本仓库为 Pi 生成了相位命令 opsx-archive —— 检出形状 internal：机器生成面（由工具在本机生成、不进仓库） .pi/prompts/opsx-archive.md 在检出里不存在（跳过不是通过）
SKIP（条件不满足） 相位 skill openspec-explore 在位（explore 阶段） —— 检出形状 internal：机器生成面（由工具在本机生成、不进仓库） .pi/skills/openspec-explore/SKILL.md 在检出里不存在（跳过不是通过）
SKIP（条件不满足） 相位 skill openspec-propose 在位（propose 阶段） —— 检出形状 internal：机器生成面（由工具在本机生成、不进仓库） .pi/skills/openspec-propose/SKILL.md 在检出里不存在（跳过不是通过）
SKIP（条件不满足） 相位 skill openspec-apply-change 在位（apply 阶段） —— 检出形状 internal：机器生成面（由工具在本机生成、不进仓库） .pi/skills/openspec-apply-change/SKILL.md 在检出里不存在（跳过不是通过）
SKIP（条件不满足） 相位 skill openspec-verify-change 在位（verify 阶段） —— 检出形状 internal：机器生成面（由工具在本机生成、不进仓库） .pi/skills/openspec-verify-change/SKILL.md 在检出里不存在（跳过不是通过）
SKIP（条件不满足） 相位 skill openspec-archive-change 在位（archive 阶段） —— 检出形状 internal：机器生成面（由工具在本机生成、不进仓库） .pi/skills/openspec-archive-change/SKILL.md 在检出里不存在（跳过不是通过）
```

两个证据层点名行：

```text
SKIP（条件不满足） M28 真树：变更类 tmux 调用全部有隔离证据（豁免清单） —— 检出形状 internal：豁免清单注册的路径逐条不在（冻结的证据层） docs/team/reports/*/pkg/** 在检出里不存在（跳过不是通过）
SKIP（条件不满足） 58 lint 真树：仓库脚本/夹具没有按名字或模式选进程（豁免清单） —— 检出形状 internal：豁免清单注册的路径逐条不在（冻结的证据层） docs/team/reports/*/pkg/** 在检出里不存在（跳过不是通过）
```

### 文档核对：真实 OpenSpec 1.8.0

在空 scratch 目录和私有 HOME 中实际运行：

```text
$ openspec --version
1.8.0
$ openspec config list
profile: core
delivery: both
workflows: propose, explore, apply, update, sync, archive (from core profile)
$ openspec init --tools pi
# exit 0；find .pi -type f 共 12 个文件
```

六个 prompt：`opsx-{apply,archive,explore,propose,sync,update}.md`。
六个 skill：`openspec-{apply-change,archive-change,explore,propose,sync-specs,update-change}/SKILL.md`。
没有 verify pair。`openspec config profile expanded` exit 1，打印 `Available presets: core`。
README 的版本限定说明以及 `references/openspec.md` §6 的生成物列表、verify 由指南定义的解释与实物一致。这里验证的是工具实际生成物，与前述十个手写存在性夹具分开记录。

## Flip evidence

### 救生通道：缺席 → 原始文件复原 → 篡改 → 原字节恢复

`prepare.py` 先逐文件核对 SHA256，17/17 与两个清单一致（tmux 16、signal 1），记录在 `logs/sha256.txt`。
在**同一棵混合树**上复原全部注册文件：

```text
$ bash skills/teamsmith/tests/smoke.sh --select 31
§31 ✓9 ✗0 SKIP1；证据层跳过消失，仅剩容器工具前提跳过；exit 0
$ bash skills/teamsmith/tests/smoke.sh --select 58
§58 ✓13 ✗0 SKIP0；exit 0
$ perl skills/teamsmith/tests/tmux-lint.pl
# exit 0，逐条打印 16 个 LEGACY 文件
$ perl skills/teamsmith/tests/signal-lint.pl
# exit 0，打印 1 个 LEGACY 文件
```

分别给 `M23-dev2/pkg/namespace-demo.sh`、`M35-dev2/pkg/lib.sh` 追加一行注释，不修改原调用：

```text
$ bash skills/teamsmith/tests/smoke.sh --select 31
§31 ✓8 ✗1 SKIP1；exit 1
$ perl skills/teamsmith/tests/tmux-lint.pl
✗ tmux-lint: baseline —— docs/team/reports/M23-dev2/pkg/namespace-demo.sh：文件已改（sha 不再匹配）→ 豁免失效，本文件按普通文件判（8 条红）
# exit 1
$ bash skills/teamsmith/tests/smoke.sh --select 58
§58 ✓12 ✗1 SKIP0；exit 1
$ perl skills/teamsmith/tests/signal-lint.pl
✗ signal-lint: baseline —— docs/team/reports/M35-dev2/pkg/lib.sh：文件已改（sha 不再匹配）→ 豁免失效，本文件按普通文件判（2 条红）
# exit 1
```

拷回核过 SHA 的原字节后，§31/§58 回到上述恢复态的绿；原始日志分别为 `restored-*`、`tampered-*`、`re-restored-*`。

### 牙齿：证据层仍缺席时，真实违规不能被吞

清除复原的全部注册文件，回到公开混合形状，仅在副本的 `skills/teamsmith/tests/p225-adversarial.sh` 放入：

```bash
#!/usr/bin/env bash
tmux kill-server
pkill -f p225-adversarial-marker
```

这份文件只供静态 lint 读取，**没有执行**两条危险调用。

```text
$ bash skills/teamsmith/tests/smoke.sh --select 31
RED skills/teamsmith/tests/p225-adversarial.sh:2 tmux kill-server
§31 ✓8 ✗1 SKIP2；exit 1
$ bash skills/teamsmith/tests/smoke.sh --select 58
RED skills/teamsmith/tests/p225-adversarial.sh:3 pkill -f p225-adversarial-marker
§58 ✓12 ✗1 SKIP1；exit 1
```

每个目标段**恰好红一条断言**，仍同时保留证据层的 SKIP。删除植入文件后两段回到公开混合形状的绿，exit 0。

### 生成面边界：空面不能假装缺席

同一混合树创建空 `.pi/prompts`、`.pi/skills`：§19 `✓16 ✗10 SKIP0`，exit 1。删除这两个空面：`✓16 ✗0 SKIP10`，exit 0。两向日志为 `empty-surfaces-19.log` / `absent-again-19.log`。

## Finding F1 · 探针在证据文件已复原的完整内部树上判红

**Verdict：NEEDS-CHANGES。** 前述三形状 §19/§31/§58、证据复原/篡改、混合形状牙齿与文档核对均符合预期，但探针本身未通过，不能给本任务 PASS。

实际命令（由 `team_bg_run` 拉起、`team_bg_wait` 已收割）：

```bash
distrobox-host-exec podman run --rm --pid=host --cgroups=enabled --userns=keep-id \
  -e HOME=/tmp -v "$PWD/docs/team/reports/P225-verify:/evidence" \
  -w /evidence/.scratch/internal localhost/teamsmith-gate:local bash /evidence/probes.sh
# probes.sh 第一条，在完整内部副本中：
bash skills/teamsmith/tests/checkout-shape-probe.sh
```

实际输出尾与失败项：

```text
name=standalone-shape-probe rc=1 expected=0 elapsed=586s
bad: ⑨ 内部树 + 清单文件都在 → --select 31 退出 0（照旧判定）（期望 [0]，实际 [1]）
bad: ⑨ 内部树 + 清单文件都在 → M28 照旧带清单跑（1 个历史豁免文件）
bad: ⑩ 内部树 + 清单文件都在 → --select 58 退出 0（照旧判定）（期望 [0]，实际 [1]）
bad: ⑩ 内部树 + 清单文件都在 → signal-lint 照旧逐条核对（LEGACY 打印）
== 检出形状探针 == ok 134 bad 4 skip 0
```

**根因是探针夹具没有隔离好证据层，不是 lint 放过了真实违规，也不是机器慢。**

- `checkout-shape-probe.sh:100-108` 的 `scratch_tree()` 把源内部树中实际存在的历史注册证据文件拷进夹具；本次源内部树拥有已经核过 SHA 的 17 个文件。
- `checkout-shape-probe.sh:536-542` 的 ⑨b 控制在同一树里创建 `P222-fixture/pkg/legacy.sh`，再把 tmux 清单替换成**仅这一条**合成记录，但没有移走原始历史文件。
- ⑩ 的 signal 控制沿用同一棵树，并同样改写成仅一条合成清单。两个 lint 扫描到仍在树中的原始文件时，它们已经不在当前清单里，依法报 RED。
- 原始日志的嵌套 §31 已明确点名 `docs/team/reports/M23-dev2/pkg/namespace-demo.sh:36` 等；嵌套 §58 点名 `docs/team/reports/M35-dev2/pkg/lib.sh:46` 等。直接跑同一来源、未被探针改写清单的内部树 §31/§58 却是绿，见三形状计数。这排除了缺依赖、SHA 错误和源文件本来就不合法等解释。

探针的关键牙齿和影子**仍实际执行并通过**，这不能抵消上述四条红：

```text
ok: ⑩ 缺失的产品面条目照旧判红并点名该文件
ok: ⑩ 缺失的产品面条目不得记成前提跳过
ok: ⑩ 影子：删掉逐条内部面判据（=「任何缺失即跳过」）→ 同一条产品面缺失被吞、§58 判绿（牙齿真咬在判据上）
ok: ⑩ 产品文件里的 pkill -f 照旧判红并点名 file:line
ok: ⑧ 真实树指纹前后一致（夹具只动 scratch 树）
```

完整输出在 `logs/standalone-shape-probe.log`，包含四条失败的嵌套门禁输出。我的独立 `judge.py` 也真实运行：三形状、逐段计数、原始恢复、SHA 失效、确切 file:line、双向恢复、空面拒绝与真实生成物断言全部通过，随后在 `standalone shape probe executes all 138 controls` 上失败，exit 1；没有把失败改成预期绿。

## Decisions and deviations

- **自己跑过**：容器内三种形状各自的 §19/§31/§58 与选择器 `--check`；两次 lint 原始恢复与篡改；混合形状植入/移除两条调用；生成面空目录/整面缺席；真实 OpenSpec 初始化/profile；严格 spec 校验；完整内部形状的 standalone probe（586 秒，失败）；独立日志断言（失败点与 probe 一致）。
- **没跑**：混合形状的独立 §36 调用。`probes.sh` 在第一条 standalone probe 返回 1 时按 `set -e` 中止，第二条 §36 没有执行；它不是超时，也不能把计划写成已跑。完整内部与纯产品形状也没有单独跑 §36。其余未选 smoke 段、整套 smoke、性能门禁均未跑；每份选段日志附有完整未跑键列表。
- §31 的嵌套容器自检是既有工具前提跳过，不能记成已通过；本次所有门禁都在容器中跑，没有在宿主跑 smoke。
- 两个后台作业均已收割：cases exit 0（535.3 秒）；probes exit 1（590.5 秒，含容器拉起时间）。
- 证据包按 D94 保留在当前工作树且被 gitignore；只提交顶层报告。本任务不改实现、不合并、不归档，也不用 push/PR（local 模式）。

## Suggested next steps

- **BLOCKED:** 需 PM 派给 `dev` 修 `skills/teamsmith/tests/checkout-shape-probe.sh` 的合成证据控制：构造只有合成证据的隔离树，或完整保留仍被扫描文件的豁免记录，不能清空/跳过真树 lint 来换绿。复验应同时覆盖原始证据缺席和 17 文件恢复在位这两个源形状，并保留产品违规与缺失产品条目的牙齿/影子。
- 已通过 `team notify verify` 通知 PM，工具确认 `notified pm`；verify 未越权修改实现。修复后由 PM 安排重验探针及 §36。
