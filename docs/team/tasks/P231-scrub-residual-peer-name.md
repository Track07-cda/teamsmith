# P231 · 清掉树里残留的真实对端项目名 + 让账本扫描覆盖所有被跟踪的账本文件

task: P231
agent: dev-bob
phase: apply
category: code
change: -
anchor: none (infra) — 文本清理与扫描面收紧，不改产品契约行为
branch: task/P231-scrub-peer-name
deps: P228/P232/P235（routing 已并入 main）、P238、P242、P244（末尾三项都动过 `smoke.sh` 与两张 tsv，已或即将并入）

## 背景与两部分目标

**第一部分：清掉残留的真实对端项目名（13 行 / 9 个文件）。** PM 在独立 clone 上用扫描器 + 真名单复现过（`TEAM_FORBIDDEN_NAMES=.pi/team/forbidden-names.txt bash docs/team/tools/publish-public.sh`）：

| 文件 | 性质 |
|---|---|
| `skills/teamsmith/scripts/lib/common.sh` | 两处注释（实测来源） |
| `skills/teamsmith/scripts/lib/cmd-watch.sh` | 一处注释（反馈来源） |
| `skills/teamsmith/references/protocol.md` | §8f 标题与正文「measured on …」 |
| `skills/teamsmith/tests/smoke.sh` | 6e 段的标题与两条注 |
| `skills/teamsmith/tests/section-paths.tsv`、`section-budgets.tsv` | 6e 段的键名 |
| `docs/team/ledger/branch-inventory-20261005.tsv`、`branch-cleanup-20261005.tsv` | 分支名里的对端名 |
| `openspec/changes/archive/2026-09-16-rename-watchdog-to-pulse/design.md` | 一次路径引用 |

替换成中性写法（「实测现场」「外部项目」或 `<peer>`），**保持句子本意与可读性**，只把名字拿掉；**改到的段/键名要跟着改**（6e 的标题与两张 tsv 的键、§8f 的标题），改完在门禁里跑一次确认。

**诚实边界（写进报告，不许含糊）**：这些名字**已经在已推送的公开历史里**（public 的 main 停在 `ca7c176`，2026-10-13）。清工作树**改变不了「已经公开」**；不做历史改写、不做 force-push。清理的意义是「从今以后不再新增暴露」。

**第二部分：把账本扫描面收紧到「所有被跟踪的账本文件」（P239 复验的三条 OBS，已并入本任务）**

1. **最要紧**：现在的账本检查只读 **`.md`**——往 `docs/team/ledger/*.tsv`（恰恰是放分支名/项目名的地方）植入泄漏会得到**假绿**。要求：覆盖 `docs/team` 下**所有被跟踪文件**（不只 `.md`）。
   **注意顺序**：放宽扫描面后本仓**今天就是红的**（上表那两张 tsv 里还有对端名）——所以必须在**同一次交付**里先清干净、再放宽，并给出完整链条：**「植入 → 假绿（假绿必须被自己复现出来）→ 清理 → 真绿」**。
2. **归属要落在承载该检查的那一段**：`# ledger-scan:` 指向别的段今天也能过；要求指向承载账本禁令的那一段，否则装载时报错点名。
3. **两行表头今天最后一行赢**：要求**拒绝**（报错点名文件与行号），不许静默取最后一行。

## 边界

- 允许改：上表 9 个文件 + `skills/teamsmith/tests/ledger-ban.sh`（或承载它的脚本/库）+ 必要的清单登记（`section-*.tsv`）。
- **不许**改：`.pi/team/forbidden-names.txt`（仓外私名单，别提交任何名字）、`docs/team/DECISIONS.md`（PM 单写者）、其他项目。
- 不许改历史记录里的**其他**内容（报告/复验记录/归档规格里的名字若不是本表所列，先报给 PM，不要顺手重写）。
- 不删/skip 断言换绿；两条不可逆动作（历史改写、force-push）明令禁止。

## 验收（贴真实输出）

```bash
TEAM_FORBIDDEN_NAMES="$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt" \
  bash docs/team/tools/publish-public.sh            # 期望 0 命中（含「禁用心智形状仍全跑」的自证）
bash skills/teamsmith/tests/ledger-ban.sh --names-file .pi/team/forbidden-names.txt   # 期望 hits=0
bash skills/teamsmith/tests/smoke.sh --select 6e    # 改过 6e 的标题/键名后必须照旧绿
bash skills/teamsmith/tests/section-select.sh --check
bash docs/team/tools/release-check.sh               # 期望：只报「HEAD 领先 tag」那一条
git diff --check && git status --short
```

**红侧（三条，各给可跑证据）**：
① 把任意一行的替换**改回**原名 → 扫描必须点名该文件与行号；改回 → 0 命中；
② 在 `docs/team/ledger/` 造一个**非 `.md`** 的被跟踪文件并植入泄漏 → 新扫描面必须**红并点名**（改前会假绿——先把假绿复现出来）；
③ 把 `# ledger-scan:` 指向别的段、或写两行表头 → 装载必须报错点名。

## 交付

`docs/team/reports/P231-dev-bob.md`（两部分各自的改动、三条红侧的前后证据、假绿复现、诚实边界一句、未做项）；证据包仓外；不合并、不推送；做完 `team notify pm`，随后由未写过本任务的席位独立复验。
