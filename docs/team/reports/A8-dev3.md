# A8 · 模型路由三处测试精简的规格同步与归档

agent: dev3 · status: DELIVERED · time: 2026-11-16T06:15:35Z
branch: `task/A8-archive-routing-slimming` · PR/MR: -
change: `routing-argv-check-slimming`

## 结论

OpenSpec 1.16.0 的原生 `archive -y` 已先在唯一私有副本、再在本任务工作树成功执行；归档提交为 `039b12d9f23ed6aa15f0181f663d36041657d0fa`。正式 verification 仅同步已接受的一条 MODIFIED requirement，原 12 个场景全部保留并增加 5 个场景，Purpose 和该条款之外的字节不变。任务书要求的适用短检查均已实际返回 0；选段自检仍有缺本机生成 `.pi/skills` 的 1 项 SKIP，不当作检查通过。既有 W1 如实保留，没有重跑长矩阵或全项目 strict。

## Deliverables

| Path | What |
|---|---|
| `openspec/changes/archive/2026-11-16-routing-argv-check-slimming/` | 原生移动的 `.openspec.yaml`、proposal、design、tasks、verification delta 共 5 个文件，各自字节不变；tasks 8/8 |
| `openspec/specs/verification/spec.md` | 同步 `A gate that cannot judge says so` 的已接受 delta；实际 +82/-3 行，无其他正式规格变化 |
| `docs/team/reports/A8-dev3.md` | 本轮归档授权、原生结果、内容核对与短检查证据 |

没有索引引用需要更新：针对 openspec 和 tests 中 TSV/YAML/index 文件查询该 change，未发现匹配；未修改历史任务书、报告或 PM 账本来改写旧路径。

## 前置、授权与根目录

- 起点 `2cc2e9fa4`，任务分支及工作树均按 brief 核对；初始 `git status --short` 为空。
- `docs/team/reviews/P457.md` 已接受同一非实现者 dev3 的合并后报告 `b6ae8a5c`，绑定实现合并 SHA `f5836f23f1758ec6bd77a2a3f447e6b7b6884532`；Completeness 8/8、CRITICAL 0、WARNING 1。PM 按 D241 既有授权批准小规模可逆的测试精简归档；不是仅以 board done 或结构校验代替独立验证。
- 本轮读取现有 archive skill 与 `references/openspec.md`。skill 的 agent-driven sync/manual move 步骤与本 brief 明授的原生同步归档方式不同，按 brief 执行原生 CLI，不手写替代同步/移动。
- `openspec` 不在 PATH；显式使用已安装的 `"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec"`，`--version` 实际为 `1.16.0`，未安装依赖或改环境。

实际前置输出：

```text
$ bash skills/teamsmith/scripts/team change status routing-argv-check-slimming
change routing-argv-check-slimming · not ready
A8      archive       dev3      wip
P455    opsx-propose  dev2      done
P457    opsx-apply    dev-bob   done
V162    verify        dev3      done
V163    opsx-verify   dev3      done
blockers: only A8 · archive · wip
rc=1
```

此处仅放行任务 ID 等于本 brief 的 A8 且 phase 字面为 archive 的自身未交付项；没有忽略其他任务、checklist 或不可读证据。未改 BOARD 使工具提前返回 0。

```text
$ "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" list --json
root.path=<本 dev3 工作树>; root.source=nearest
routing-argv-check-slimming: completedTasks=8 totalTasks=8 status=complete
$ "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" status --change routing-argv-check-slimming --json
schemaName=spec-driven; planningHome.kind=repo; planningHome.root=<本 dev3 工作树>
proposal/specs/design/tasks=done; isPlanningComplete=true; isComplete=true
artifactPaths.specs.existingOutputPaths=[<本 dev3 工作树>/openspec/changes/routing-argv-check-slimming/specs/verification/spec.md]
$ "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" instructions archive --change routing-argv-check-slimming --json
root.source=nearest; no context/operationGuidance fields
$ "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" instructions specs --change routing-argv-check-slimming --json
artifactId=specs; schemaName=spec-driven; no rules field
```

以上 CLI 均实际返回 0；sync 对象为已有 verification 的一个完整 MODIFIED 块，不是新 capability，也没有 Purpose 修改授权。

## 原生试归档及实际归档

临时根仅为本次创建的 `/var/tmp/a8-archive.C09ohu`。先 `mktemp -d -p /var/tmp a8-archive.XXXXXX`，建立 project 子目录并 `cp -a openspec <临时根>/project/openspec`；副本的 `list --json` 确认 root 指向该 project、任务 8/8 后执行：

```text
$ (cd /var/tmp/a8-archive.C09ohu/project && "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" archive -y routing-argv-check-slimming)
Task status: ✓ Complete

Specs to update:
  verification: update
Applying changes to openspec/specs/verification/spec.md:
  ~ 1 modified
Totals: + 0, ~ 1, - 0, → 0
Specs updated successfully.
Change 'routing-argv-check-slimming' archived as '2026-11-16-routing-argv-check-slimming'.
trial_rc=0
```

核对副本结果后，在本 dev3 工作树执行相同 Bun/CLI `archive -y routing-argv-check-slimming`，原生输出逐行与上面的 Task status 至 archived 行一致，rc=0。不是手写规格、`mv` 或复制试归档结果代替实际原生归档。

### 内容与范围核对

原始 openspec 的只读快照保存在同一临时根的 before；一次性 `check_archive.py` 对 before→trial、before→实际工作树分别比较，两个 JSON 结果字节相同，rc 均为 0：

```text
result=PASS
changed_main_specs=[specs/verification/spec.md]
whole_requirement_matches_accepted_delta=true
non_delta_prefix_suffix_and_Purpose=byte-identical
old_scenarios=12 new_scenarios=17
archive_moved_unchanged_files=5
tasks checkbox count=8; all x/X
other_openspec_files=byte-identical
verification_sha256=988d729db13e72e6be449634b93ff894a7e5cb7b68f020d0e807d943b06b4333
```

核对方式：逐字节比较所有 openspec 文件；唯一允许的内容变化是目标 requirement，其正文必须等于原 delta 的完整 MODIFIED 块（仅忽略该块末尾空白）；目标块前缀/后缀严格逐字节相等，因此既有 Purpose、其他 requirement 与格式未改。原 change 的 5 个文件在日期归档目录逐字节相同，其他路径/内容不变，原 live change 不再存在。

正式规格新增的五个场景为：

1. `Routing argv replacements detect the original resplitting errors`
2. `Routing restoration observes the same mutated copy`
3. `Routing short outcomes reach the existing flip parent`
4. `Only the two routing boundary repeats and original-tree second CORE retire`
5. `Routing evidence reports actual scope instead of padding totals`

一次性检查脚本 SHA256 为 `aeb644c65ec7e3ea57ad84bce21f85de3024bdea6474a54a975add32660ba3d5`；trial.log 为 `48dfaba92efa4865107f8ce4b827572d453f0857351312681a0c6c2f601ff3d1`，actual.log 为 `957a8faeb07b30e06f56154738acf37f2e0302f12a9e3a96afceebf77f78ab23`。完整原生关键输出及核对结论已写入本报告；短检查结束后再次核对归档结果与试归档 JSON 字节相同，随后仅清理本次精确临时根，实测 `test ! -e /var/tmp/a8-archive.C09ohu` 返回 0。上述临时原件已删除，不声称仍可回读。

## Verification evidence

后台作业 `a8-archive-short` 已在完成通知后收割：43.6s、exit=0。以下命令全部在本任务工作树执行，逐命令 `.rc` 均为 0；作业起止 HEAD 均为 `039b12d9f23ed6aa15f0181f663d36041657d0fa`，执行时本报告已暂存。

```text
$ "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all
✓ spec/verification
  ⚠ [WARNING] requirements[3]: Requirement text is very long (>500 characters). Move examples and edge cases into scenarios, or split it into separate requirements that each state one behavior.
Totals: 20 passed, 0 failed (20 items)
rc=0

$ bash skills/teamsmith/tests/spec-refs.sh --check
spec-refs: judged 122 reference(s) (49 distinct) in 14321 effective line(s); retired 0; undeclared 0; id families used [D,E,F,M,P,V] named [D,E,F,M,P,V]
rc=0

$ bash skills/teamsmith/tests/section-select.sh --check
ok: 映射表 key 唯一（141 行）
ok: 段 ↔ 行一一对应（源码 141 段 / 表 141 行）
SKIP（条件不满足）: 行 19 的字面模式在检出里不存在（检出形状 internal，机器生成面（工具在本机生成、不进仓库））：.pi/skills
== 选段自检 ==  ok 13  bad 0  SKIP 1
rc=0

$ git diff --check
(no output)
rc=0
$ git diff --cached --check
(no output)
rc=0
```

归档后 `openspec list --json` 实际返回 `changes=[]`、本工作树 root.source=nearest，rc=0。普通 all 的对象数从先前 21 降为 20，是 live change 已移入 archive，不是丢失正式规格。

### Ledger ban

本报告在自己的任务分支暂存后实际执行；root 的 `<user>` 是工具原生脱敏输出，不是主检出代跑：

```text
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=/home/<user>/Documents/syncthing/Work/Projects/pm-skills/.worktrees/dev3 scope=published files=2727 hits=0 names=ok user=resolved
$ echo $?
0
```

- Verdict：本轮归档及适用短命令 PASS；上述 SKIP 和既有警告不转成通过。
- 最终报告定稿后补 ledger-ban、diff-check 及只读归档内容复核，实际仍为 files=2727/hits=0、diff 无输出、归档字节不变；不因文字更新重复运行其他检查。

## OpenSpec assessment

| Dimension | Score | Evidence |
|---|---|---|
| Completeness | 8/8 checklist，归档 5/5 文件 | CLI 任务计数、归档后 checkbox 及原文件同一性核对 |
| Correctness | 内容核对及适用短命令 PASS | 新 requirement 与接受 delta 相同，12 个旧场景保留及 5 个新场景同步；普通 all 20/0、引用 undeclared=0、选段 13/0/SKIP1 |
| Coherence | 仅 native archive 的批准范围 | 一个正式规格目标块；其他 openspec 字节、Purpose、产品、测试、配置未修改 |

## CRITICAL

- None：前置任务/授权、原生试归档与实际归档、批准范围及全部适用短命令已核，未发现未解决 CRITICAL。

## WARNING

- W1 保留：V163 合并后接受的既有全项目 strict 长 requirement 警告。候选阶段实测 `validate --all --strict` 为 4 passed / 17 failed；普通 all 为 21/0（包含当时未归档 change）。本轮普通 all 为 20/0，仍打印长文本警告；也打印既有 `seat-visibility` Purpose placeholder 警告，该文件经全 openspec 比较确认未改。未重跑 strict，不把这一项写成通过，不修其他规格或 Purpose。依据为 `docs/team/reports/V163-dev3.md` 的 WARNING 和合并后 assessment、`docs/team/reviews/P457.md` 的明示接受，以及本轮普通 all 的真实输出。

## SUGGESTION

- None；本次只执行授权的规格同步与归档，不引入新检查机制或改写 Purpose。

## Final assessment

- Counts：CRITICAL 0 · WARNING 1（既有全项目 strict 边界）· SUGGESTION 0。
- Readiness：授权的原生归档已交付，适用短命令均 rc=0；可交 PM 接受并集成，本席位不合并或关闭任务。
- 未验证项：选段自检的本机生成 `.pi/skills` 1 项 SKIP，因本工作树没有该生成目录；没有补建或借主检出目录冒充完成。
- 未重跑范围：全项目 strict、短 argv/父级反例、61b/full/meta/夜间/安装/性能；本 brief 仅要求文档归档的适用短检查，行为证据引用已接受的 P457/V163，不冒称本轮重新执行。

## Flip evidence

N/A — 本任务没有缺陷实现或行为变化；原三处测试精简的同副本 0→1→0、独立短反例和唯一完整 61b 已由 P457/V163 及 PM 接受记录覆盖，本轮不重跑、不改写其 receipt。

## Decisions and deviations

- 无范围偏离。主规格与 change/archive 的临时写权来自 A8 brief 的逐路径授权及现有 verification archive requirement；不写 PM 的 BOARD、任务书或主检出。
- 未运行真实团队 PM，不改配置/运行状态、产品、测试或版本。`0.4.7` 标签 `fdd3247a` 与已发布 npm 原包未改；不 push、merge、建/移 tag 或发布。

## Suggested next steps

PM 检查本分支的原生归档提交及本报告后自行集成、登记和关闭 A8；保持本轮与已发布 0.4.7 分离，不因此重新发布。
