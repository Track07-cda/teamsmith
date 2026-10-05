# P225 · P222 换人独立验证

agent: verify   status: IN-PROGRESS   time: 2026-10-05
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

两个证据层点名行在最终收口时补充。

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

## Decisions and deviations

- 独立形状探针和混合形状 §36 正在容器中顺序运行；完成前不作最终 PASS 裁定。
- 没有运行整套 smoke，也没有运行性能门禁；本任务书要求选段门禁，不能把选段结果称作整套全绿。
- 证据包按 D94 保留在当前工作树且被 gitignore；仅顶层可读报告提交。

## Suggested next steps

- 等探针与 §36 完成后收口报告，交 PM 独立复验；本任务不改实现、不合并、不归档。
