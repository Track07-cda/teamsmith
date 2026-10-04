# P137 · references 的「常见被拒与修法」反面清单（纯文档）

agent: dev-bob   status: done   time: 2026-09-30
branch: `task/P137-references`   PR/MR: - （local 模式：分支留在工作树，未 push）

doc revision under test: `ea7918ae` (last commit touching the doc) · sha256[:16] `c27b746ed37a492c`

## Deliverables

| Path | What |
|---|---|
| `skills/teamsmith/references/troubleshooting.md` | 新增 §27「Common rejections and how to fix them」（27a 分支命名 + 27b 头部行对照表 + 27c 一条命令搭好独立复验），并在 §4「team dispatch refuses」加一行指向 §27 |
| `docs/team/reports/P137-dev-bob/logs/before-after.txt` | 前后对照：两个真实撞过的形状在改动前（dabfbff8）references 里 0 命中、`§27` 指针 0 命中；改动后 1/1/1（§27 在 1156 行） |
| `docs/team/reports/P137-dev-bob/logs/refusals.txt` | 改动前**唯一**的教学来源：真实报错（分支守卫、`review` 缺 `--dir`），以及期望分支名的推导样例 |
| `docs/team/reports/P137-dev-bob/logs/doc-sections-final.log` | 最终 revision 上的文档不变量段重跑（14b/15b/18） |
| `docs/team/reports/P137-dev-bob/logs/pre-existing-14b-red.txt` | 14b 两条红的**预先存在**证据（见 Findings） |
| `docs/team/reports/P137-dev-bob/logs/openspec-validate.txt` | `openspec validate --all --strict` 输出（15/15） |

提交（分支 `task/P137-references`，均在本地）：

```
096ca773  docs(teamsmith): P137 — 'Common rejections…': 分支守卫（推导 + 可直接粘的 switch）、头部行对照表（含 change: 括号说明与 deltas: 中点两种真实形状）、带 --dir 的一条命令复验；§4 指向 §27
c5642398  docs(P137): 落盘 before/after 证据（改动前两个形状在 references 里不存在，解析器是唯一老师）
9c904e32  merge(P137): 把分支抬到 main（meeting-liveness + dispatch-friction + P136/P139/P140 任务书）
ea7918ae  docs(teamsmith): P137 — `--force` 那句改成与解析器一致（malformed deltas: 没有逃生门；只有单写者重叠有），复查时发现
b01ffb67  docs(P137): 落盘不变量重跑、openspec 输出、14b 预存红的证据
```

## 要加的三条（逐条对照任务书）

1. **分支命名** ✅：期望名 `task/<ID>-<slug>`；slug 推导四步（小写 → `[^a-z0-9]+` 折叠成 `-` → 去首尾 `-`、截 28 字符 → 全非 ASCII 时回退成 ID，如 `task/P134-p134`），来源是 BOARD 的任务列、其次任务书首行 `# <ID> · …`；可直接粘的修复命令两条（分支已存在 `switch`，不存在 `switch -c … <保护分支>`）；「停在别的任务分支上」为什么必须拒（记录会张冠李戴，`M6.3 F16`）——并写明**续跑同一任务**接受任意 `task/<ID>-*`、新任务必须逐字符相等，且 `--print` 也检查。
2. **任务书头部行** ✅：`change:` / `deltas:` / `specs:` / `anchor:` 的合法-非法对照表，含任务书点名的两个真实形状 `change: panel（说明）`（括号说明非法）与 `deltas: capability-a · capability-b`（中点非法）；每条给出修法；两条细节（非法 `anchor:` 压过合法 `specs:`；只有空白后的 `#` 才是注释）。
3. **复验** ✅：一条命令搭好独立复验（`git worktree add --detach` + `team review <ID> --dir …`），容器场景改 `git clone -b` 并给 `--pid=host`；**每个示例都带 `--dir`**；`--dir` 必须是 checkout 根、必须干净且在被验分支上（点名 `TEAM_REVIEW_ALLOW_DIRTY=1` / `TEAM_REVIEW_ANY_DIR=1`）、`--no-gates` 不是证据、`--pre/post-merge` 不吃 `--dir`。

## Verification evidence (must have actually been run)

```
$ bash skills/teamsmith/tests/smoke.sh --select 14b,15b,18   # 交付 revision 上的最终重跑
  ✓ review 用法都带 --dir                                         # ← M71 用法不变量（15b）
  ✓ references/** 与 SCOPE.md 的正文全英文（CJK 只出现在代码 span / 围栏块里）   # ← 英文不变量（18）
  ✓ 正对照：真树原始扫到 60 行 CJK，全部在代码里被豁免
✗ 文档还在把容器当依赖：…/references/troubleshooting.md:1152:image (`ci/Containerfile`) is the one built for the suite. …
✗ 翻转自测：测试 harness 的容器说明被误报：/tmp/…/docsandbox-dep/references/troubleshooting.md:1152:…
#9  14b · 文档一致性：… · ✓24 ✗2 SKIP0
#10 15b · 必需依赖：doctor 三态 + paths + dispatch 预检 · ✓26 ✗0 SKIP0
#11 18 · 英文正文不变量与安装器唯一入口（M7.3） · ✓36 ✗0 SKIP0
== 选段结果 ==  ✓ 193  ✗ 2        # 两条都是 14b 的**预存**红，见 Findings
  这次没跑的 104 个键：0e 0f 0g 1 1b 1c 3 4b 4c 6 6b … 15（完整清单在 logs/doc-sections-final.log）

$ <home>/.bun/bin/openspec validate --all --strict
Totals: 15 passed, 0 failed (15 items)

$ grep -rEn 'team review[[:space:]]+[A-Za-z0-9]' skills/teamsmith/SKILL.md skills/teamsmith/references \
    skills/teamsmith/templates README.md | grep -v -- '--dir' | grep -vE '不再|已删|旧签名|v1\.11'
（无输出）→ OK: review 用法都带 --dir
```

- Verdict: pass（P137 的两条目标文档不变量全绿；14b 的两条红经证明与本任务无关，且**在 main 上同样红**）
- Notes:
  - **没跑全套**：按任务书「跑相关文档检查段，不用全量」与 PM 的续跑清单第 4 条，只跑 `--select 14b,15b,18`；上面日志点名了未跑的 104 个键。
  - **没跑** `team review` 本身（复验是 PM 的事）；**没跑** tmux/面板类段落（本次改动不涉及行为）。
  - §27 是文档，没有可执行断言；覆盖它的是 14b/15b/18 的扫描（英文正文、`--dir` 用法、已删命令）。
  - `open spec` 不在我的 PATH 里，用绝对路径 `<home>/.bun/bin/openspec` 跑的（与 P136 报告里的 `PATH="$HOME/.bun/bin:$PATH"` 等价）。

## Flip evidence（before → after，任务书要求的前后对照）

```
$ git show dabfbff8:skills/teamsmith/references/troubleshooting.md | grep -c 'Common rejections'      # before
0
$ git show dabfbff8:… | grep -c 'panel（说明）'            → 0   # change: 括号说明的形状
$ git show dabfbff8:… | grep -c 'capability-a · capability-b' → 0   # deltas: 中点形状
$ git show dabfbff8:… | grep -c '§27'                     → 0   # 连指路都没有

$ grep -n '^## 27\. Common rejections' skills/teamsmith/references/troubleshooting.md                # after
1156:## 27. Common rejections and how to fix them
$ grep -c 'panel（说明）' … → 1        $ grep -c 'capability-a · capability-b' … → 1

# 改动前**唯一**的教学来源就是解析器拒绝（logs/before-after.txt 原文，2026-09-30T05:54:12Z）：
change: 的值是 `panel（说明）` —— 只接受一个 change id（[A-Za-z0-9][A-Za-z0-9._-]*）或 `-`
  change rc=1
deltas: 的值是 `capability-a · capability-b` —— `capability-a · capability-b` 不是 capability token（[A-Za-z0-9][A-Za-z0-9._-]*）
  deltas rc=1

# 第三类拒绝（review 缺 --dir）改动前也只有报错可学（logs/refusals.txt 原文）：
✗ review 需要 --dir <路径>：请 PM 自己准备独立 checkout（skill 不执行 git）
  例： git -C /tmp/p137-branch-fixture worktree add --detach /tmp/review-P137 <branch>
        team review P137 --dir /tmp/review-P137
```

**哪些规则真的只存在于报错里、文档里确实没有**（任务书要求点名）：`change: panel（说明）` 与
`deltas: a · b` 这两个形状改动前在 `references/**` 里 0 命中；`review` 的「skill 不执行 git、PM 自己准备
checkout」原先只在 `--dir` 缺失的报错和 §10（workflows）里零散出现，没有一条可直接照抄的完整配方。
§27b/27c 现在把这三样都写成了可照抄的形状。

## Decisions and deviations

- **加了 §4 的一行指针**（超出「一处成节」的最小面）：没有它，§27 在 1200 行的文档里只能靠翻到结尾找到；
  §4 正是读「dispatch 被拒」的人所在的位置。PM 若不想要，删这一行即可，不影响 §27。
- **`git merge main`**：按 PM 续跑清单第 1 条把旧基线抬到 main；`skills/**` 在 main 上没有新提交，语义冲突 0。
- **落盘了原先未跟踪的证据目录**：P76 会在合并前拦未入账记录（PM 清单第 2 条）。
- **`--force` 那句在自查时改了**（`ea7918ae`）：初稿写「`anchor:`/`deltas:` 都能 `--force` 覆盖」是**错的**
  —— 复查 `cmd-agents.sh` 发现 malformed `deltas:` 行**没有**逃生门（它决定单写者检查），只有「合法声明
  但撞了未结束兄弟」才有 `--force` + 审计行；`anchor:` 有。改后与代码逐条对齐。
- 正文英文、中文只出现在行内代码的 CLI 输出里（18 段的正对照证明这条豁免有效）。
- local 模式：不 push、不开 MR，分支留在 `.worktrees/dev-bob`。

## Findings handed to the PM（不是 P137 的范围）

**F1 · 14b 的两条红是 main 上的预存回归，不是本分支引入的。**（完整证据 `logs/pre-existing-14b-red.txt`）

- main 的 `skills/teamsmith/references/troubleshooting.md:1148` 就是被点的那句；把 14b 的 `dep_scope_hits`
  原样跑在 **main 的版本**上，同样命中 1148 行。
- 引入提交：`eb25b765`（2026-09-29 19:29，`[skip ci]`，PM 自己写的 troubleshooting 段）——`git merge-base
  --is-ancestor eb25b765 main` = YES；此后没有任何提交动过 `tests/smoke.sh` 的这条检查。
- 判据本身：`dep_scope_hits` 把含 `podman|--container|Containerfile` 的行报红，逐行豁免只认
  `container-tmux.sh|team perf|perf.sh|TEAM_PERF|性能套件`。那段话讲的是**测试套件**在钉死的门禁镜像里跑
  （M28 明确允许的 harness 语境），但行里没有豁免词，于是被误报；14b 的第二条「翻转自测」用的就是真树副本，
  同一条预存命中把它也带红了。
- 影响面：**所有**任务的全量门禁复验都会踩这两条红，不只是 P137。
- 两条修法（都**不是我该单方面选的**）：
  - (a) 改文案（`references/**`，我的 grant 覆盖）：让该句带上一个豁免词（例如点名
    `tests/perf.sh` / `tests/container-tmux.sh`），最小、但只治这一句；
  - (b) 改判据（`skills/teamsmith/tests/**`，OWNERSHIP 属 **agent:dev**，不是我的目录）：把「门禁镜像/
    测试套件」这类 harness 措辞加进逐行豁免。
- 我**没有**动它：任务书范围是新增 §27，改判据不在我的目录，改别人的段落属于范围外；请 PM 定 (a)/(b)。
  `BLOCKED: no` —— 它不阻塞 P137 的交付（任务书要求的两条不变量 15b/18 全绿），只是提前交底。

## Suggested next steps

- PM 决定 F1 的 (a)/(b)；若选 (a)，一行改动即可，之后 `--select 14b` 应为 ✓26 ✗0（当前 ✓24 ✗2）。
- 复验 P137：`git -C <root> worktree add --detach /tmp/review-P137 task/P137-references && team review P137
  --dir /tmp/review-P137`（全量门禁会先撞上 F1 的两条红 —— 那就按 (a)/(b) 处理后再判本任务）。
