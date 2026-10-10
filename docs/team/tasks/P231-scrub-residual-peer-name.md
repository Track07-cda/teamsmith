# P231 · 清掉树里残留的真实对端项目名（13 行）

task: P231
agent: -
phase: apply
category: code
change: -
anchor: none (infra) — 文本清理，不改契约行为
branch: task/P231-scrub-peer-name
deps: P228（routing S1 合并，它拥有其中四个文件）、P229（发布工具合并）

## 背景（PM 2026-10-10 独立复现）

P229 新增的「产品/工具面也查禁用名字」在接上真名单后命中 **13 行 / 9 个文件**（PM 在独立 clone `59018f0` 上用 `TEAM_FORBIDDEN_NAMES=.pi/team/forbidden-names.txt bash docs/team/tools/publish-public.sh` 复现，输出把名字遮蔽为 `«name»`）：

| 文件 | 行 | 性质 |
|---|---|---|
| `skills/teamsmith/scripts/lib/common.sh` | 4358、4515 | 注释（实测来源） |
| `skills/teamsmith/scripts/lib/cmd-watch.sh` | 248 | 注释（反馈来源） |
| `skills/teamsmith/references/protocol.md` | 459、468 | §8f 标题与正文「measured on «name»」 |
| `skills/teamsmith/tests/smoke.sh` | 2797、2798、2822 | 6e 段的标题与两条注 |
| `skills/teamsmith/tests/section-paths.tsv` | 41 | 6e 段键名 |
| `skills/teamsmith/tests/section-budgets.tsv` | 49 | 6e 段键名 |
| `docs/team/ledger/branch-inventory-20261005.tsv` | 150 | 分支名里的对端名 |
| `docs/team/ledger/branch-cleanup-20261005.tsv` | 150 | 同上 |
| `openspec/changes/archive/2026-09-16-rename-watchdog-to-pulse/design.md` | 65 | 归档设计记录里的一次路径引用 |

替换成中性写法（例如「实测现场」「外部项目」或 `<peer>`），**保持句子本意与可读性**，只把名字拿掉。

**诚实边界（写进报告）**：这些名字**已经在已推送的公开历史里**（`public` 的 `main` 停在 `0dbc6ebb`，2026-10-05），清工作树改变不了「已经公开」；不做历史改写、不做 force-push。

## 为什么排在 P228 之后

其中四个文件（`common.sh`、`cmd-watch.sh`、`smoke.sh`、`section-*.tsv`）正被 `task-model-routing` 的 S1/S3 写；`references/**` 属其 S3。按单写者纪律不并行写同一文件——本任务在它合并后**同一席位、新任务、独立提交**地做，避免冲突。

## 验收

```bash
TEAM_FORBIDDEN_NAMES="$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt" \
  bash docs/team/tools/publish-public.sh            # 期望：0 命中（禁用心智形状仍全跑）
bash skills/teamsmith/tests/ledger-ban.sh --names-file .pi/team/forbidden-names.txt   # 期望 hits=0
bash skills/teamsmith/tests/smoke.sh --select 6e    # 改过 6e 段的标题/键名后必须照旧绿
bash skills/teamsmith/tests/section-select.sh --paths skills/teamsmith/tests/smoke.sh
bash docs/team/tools/release-check.sh               # 期望：只报「HEAD 领先 tag」那一条
git diff --check && git status --short
```

红侧：把任意一行的替换**改回**原名 → 扫描必须点名该文件与行号；改回 → 0 命中。
