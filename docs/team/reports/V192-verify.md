# V192 · CI 短家目录下的复验记录检查

**定点复验通过。** `HOME=/tmp`、`TMPDIR=/var/tmp` 时，真实 `review` 保留合法的 `/var/tmp/...` 路径，家目录仍显示为 `<home>`。故意关闭路径替换后，真实 `review` 仍生成 PASS 记录，但记录含实际的主工作树和家目录路径，检查正确判失败；恢复同一副本后通过。§10 为 47 通过、0 失败。

agent: verify   status: PASS（仅 §10 及自动前导）   time: 2026-11-24T04:35:20Z（实跑结束）
branch: `task/V192-ci-review-path-verify`   PR/MR: -

## Deliverables

| 路径 | 内容 |
|---|---|
| `docs/team/reports/V192-verify.md` | 候选 `725e7ed223c83ce5c975a06d9cac281cf012c866` 的独立证据。 |
| `docs/team/reports/V192-verify/ci-layout.sUJA7S/` | 本席位未跟踪原件：`run.sh`、`driver.log`、完整 `smoke-10.log`、`smoke-10.rc`、源清单及 `container-var-tmp/` 原现场，保留供 PM 收取。 |

## OpenSpec assessment

N/A — `change: -`；只修既有测试断言，不更改规范或产品。锚点 `openspec/specs/verification/spec.md#Delegated reviews record their actual executor and narrow ledger authority`：§10 正常记录由测试仓的 `verify` 执行，实际校验标题、身份、被验 HEAD、指定记录及伴随日志；§10 验证测试仓主检出的文档写集仅包含这两份文件。真实项目的中央复验账本没有写入。

## Verification evidence

- `git diff --check 725e7ed2^ 725e7ed2` 返回 0。`git diff-tree --no-commit-id --name-only -r`：候选 `725e7ed2` 只改 `skills/teamsmith/tests/smoke.sh` §10；`163377a8` 只增加作者报告。新匹配按字面比较 HOME，左端不允许前一字符为 `/`，所以 `/var/tmp` 中间的 `/tmp` 不作绝对 HOME；本身或 `/` 子路径则匹配。原有四组 C/C.UTF-8 输入和期望、复验身份、记录写入范围和真实 `review` 步骤没有改动。
- 宿主不能直接读 PM 的固定检出 `/var/tmp/p491-review.ocMEmn`，仅从固定检出精确取候选提交，检出到本席位私有 Git 副本。两份 `git ls-tree -r` 的 3,839 项完全相同（`cmp` 返回 0），副本有独立 `.git`、无 alternates、前后均干净，容器再次核验 HEAD。按 V189 复用固定镜像，不拉取；`/work` 只读，容器 `/var/tmp` 只挂载本任务证据目录，`HOME=/tmp` 从未用于宿主。

```text
$ bash docs/team/reports/V192-verify/ci-layout.sUJA7S/run.sh
# 内层：distrobox-host-exec podman run --rm --pull=never --network=none --pid=host --cgroups=enabled --userns=keep-id -e HOME=/tmp -e TMPDIR=/var/tmp -v "$src:/work:ro" -v "$root/container-var-tmp:/var/tmp" -w /work "$image" bash -c '…; bash skills/teamsmith/tests/smoke.sh --keep --select 10 </dev/null'
Image: fa756c126b701b2ca3fae88588799dca7414a57a609e52e729c25beaecec2d20
container head=725e7ed223c83ce5c975a06d9cac281cf012c866 cwd=/work uid=1000 HOME=/tmp TMPDIR=/var/tmp
#11 10 · review（独立 worktree + 门禁） · 参考 用时 18s · ✓47 ✗0 SKIP0 · ticks 47
账本自查：11 段收口 · 增量 ✓193 ✗0 SKIP0 ｜ 结果行 ✓193 ✗0 —— 一致
== 选段结果 ==  ✓ 193  ✗ 0
Podman/smoke exit=0; tee exit=0
END 2026-11-24T04:35:20Z
```

`v192-ci-layout-10` 收取退出码 0。`smoke-10.log` 共 284 行，SHA-256 `005f8757dfdb2c725a72922b696c752224c230fd93ce884f79e86618ca3788ca`。原选段入口自动执行 `0 0b 0c 0d 2 4 4b 5 3b 9`。`0b` 是技能解析前导，并未发起模型请求。

## Flip evidence

| 证据 | 实际结果 |
|---|---|
| V191 原 CI `138190141527.log:1914–1936`、`138190141486.log:2402–2424` | 真实复验成功；正常和恢复时检查都报 `absolute home remains`。 |
| 候选 `smoke-10.log:219–238`，`review.log`，`p440-review-{sibling,home-checkout}.log` | 真实复验 `rc=0`，记录为 PASS。原记录断言确认独立检出及命令保留 `/var/tmp/teamsmith-smoke-work-0c9a453f.KctVBP/...`，兄弟目录逐字保留，真正 HOME 子路径显示为 `<home>/checkout`。C/C.UTF-8 × `/srv/u`/`/tmp` 四组原样例均过，包括标点、真正根与子路径、同名前缀及 `/var/tmp` 不被改写。 |
| 同一轮私有副本取消 `team_review_ledger_display`，`p440-review-mutant.log`、`p440-review-red.log` | `review` 实码 0、记录存在且 PASS；原测试先分别确认绝对主工作树和真正的 `/tmp` 家目录都出现，再确认记录检查以 `absolute main root remains` 失败。绝对 HOME 是此失败的前提之一，不是红侧日志打印的失败原因。 |
| 同一轮原测试恢复文件，`p440-review-restored.log`、`p440-review-restore-green.log` | 真实 `review` 再 PASS，原记录检查恢复通过；`cmp` 确认私有副本的 `cmd-review.sh` 和候选原文件字节相同。 |

日志名对应 `container-var-tmp/teamsmith-smoke-work-0c9a453f.KctVBP/`。原 §10 后续测试会覆盖 `repo/docs/team/reviews/T1.1.md`；保留下来的最终记录仍可直接看到合法 `/var/tmp/...` 和 `<home>`，但不是上述各次复验记录的逐次快照。各次正常、故意改坏、恢复的结论取自当时原断言和各自的命令输出。

## Final assessment

- CRITICAL 0 · WARNING 0 · SUGGESTION 0（仅本轮范围）。候选可由 PM 按原范围处理，合并后只核相关文件字节，不重跑本段。
- 没有运行完整 smoke、OpenSpec 校验、远端 CI、真实模型或发布。未执行的 130 段：`0e 0f 0g 0h 0i 1 1b 1c 3 4c 6 6b 6c 6d 6e 6f 6g 6h 6i 6j 6k 7 7b 8 10b 10c 11 11b 11b2 11b3 11c 11d 11e 11f 11g 11h 11i 11j 14b 15b 15c 12 13 13b 13c 12b 12b-h0 12b-h0b 12b-h0d 12b-h0c 12b-pi 12b-pi2 12b-pi3 14 14c 54 14d 17 18 18b 18c 19 20 21 22 23 24 25 26 27 28 29 30 31 31c 32 33 12e 12f 12g 12h 12i 12j 12k 34 34b 34c 34d 35 36 37 38 38m 39 40 41 42 43 44 45 46 47 48 49 50 51 51m 51b 51c 52 53 57 58 15 55 56 59 60 61 61b 62 63 64 65 66 68 69 67`。

## Ledger ban（本任务分支）

```text
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=/home/<user>/Documents/syncthing/Work/Projects/pm-skills/.worktrees/verify scope=published files=3025 hits=0 names=ok user=resolved
ledger-ban rc=0
```

## Decisions and deviations

任务书允许在宿主看不到固定检出时建私有副本，已按上文核对来源。首次会话恢复前没有测试启动，本次只运行一次 §10。未更改产品、测试、包或标签；报告仅本地提交，原件等 PM 收取后再清理。

## 合并版本回执

2026-11-24T04:39:14Z，独立检出 `/var/tmp/p491-merged.qqCfBg` 的 HEAD 为 `e32c3bcb25f72348c7f11404fe1c56bfc28bb4a3`；`git status --porcelain=v1 --untracked-files=all` 无输出。`cmp` 比对该检出的 `skills/teamsmith/tests/smoke.sh` 与实际跑过 §10 的 `725e7ed2` 私有副本，退出码 0。两份文件的 SHA-256 均为 `820d82660d05b1bef474cfd90e3d4bf8fa0d2a2e3d6c0c5cf9475310cc2bfe3b`。原始回执：`docs/team/reports/V192-verify/ci-layout.sUJA7S/merged-byte-receipt.log`。只核了该文件及检出状态，没有在合并版本重跑 §10；候选原件仍保留。
