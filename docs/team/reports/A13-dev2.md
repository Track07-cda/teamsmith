# A13 · 项目设置精简的规格同步与收尾

agent: dev2   phase: archive   branch: `task/A13-archive-project-settings-simplify`

## 结论

已在本人稳定工作树原生归档至 `openspec/changes/archive/2026-11-17-pulse-project-settings-simplify/`。归档前原根为本人的 `.worktrees/dev2`，`root.source=nearest`、`planningHome.kind=repo`，原生任务 **9/9**，四个规划工件均done；实际绝对路径及三份delta来源保存在下述 `E/status.json`，未选择store、创建或初始化其它根。

七个工件含 `.openspec.yaml` 与归档前提交逐文件 `cmp` 全部rc0。三份正式spec仅同步已接受delta：panel为3新增/3修改/4移除，memory-and-deps及verification各1修改。完整普通Git差异逐块核对后，三份Purpose、原标题、未点名需求/场景及其顺序不变；没有目标外正文或独立空行压缩差异。产品、测试、bundle及其它可执行文件没有改动。实际树与私有试做的完整openspec树 `diff -qr` 相同（`E/archive-compare.log`）。归档结果已先保存为 `0f015049`；指定五项交付短检查均已实际执行并收取rc0，其中全仓结构检查为非strict的20项通过/0失败，不是重新验证产品或全仓strict通过。

## 前置依据与真实边界

- 本任务基线 `82d388a6a1a7c1c9e5aa135969a64cde2e7ec624`；`git merge-base --is-ancestor 967da9843ed46c884bcabae29dea5e1a850954e9 HEAD` rc0（`E/baseline-ancestor.log`），已包含获接受的merged产品基线。
- 实现者dev，验证者dev3。已读 `docs/team/reviews/P471.md` 的merged正式记录与 `docs/team/reports/V177-dev3.md` 最终“合并后唯一短接入”完整评估；报告最终提交c03a27051e34，正式记录绑定967da984、实际执行者dev3、21秒短接入及五项导航通过。CRITICAL无未解决项，WARNING无新增需返修项；这里引用既有独立证据，没有重新验证产品。
- D262及A13 brief明确接受该merged证据，依据用户D241授权确认本次收尾；`team change status pulse-project-settings-simplify --json` 实际rc1只列A13自身、literal `phase: archive` 的wip项。P470/P471/V175/V177均done，没有其它未完成兄弟项（`E/team-change-status.json`）。A13不伪造exit0，不自行写BOARD或接受记录。
- **D261完整typecheck仍FAIL/rc2，四个既有OutboxListBlock TS2339不变。** V177原177/16、第二轮55/2及临时cut失败原件继续保留；最终PASS是已接受的组合证据加merged必要短接入，不是旧失败被抹掉或全仓重新全绿。完整计时V174也未改判。详细产品评估只指向V177报告，不另起要求或设计。

## 实际步骤与原始证据

本次唯一证据/试做根：`E=/var/tmp/a13-project-settings-archive.ON6z0z`。本人的普通独立副本在 `E/project`，由 `mkdir "$E/project"; cp -a openspec "$E/project/openspec"` 创建；没有hardlink、手动合并、手写移动或跳同步/验证。

所有OpenSpec调用使用现有1.16.0及以下环境；版本、平台和源盘点未变，沿用已有回执，不重跑安装或盘点。

```sh
export PATH="$HOME/.bun/bin:$PATH" TMPDIR=/var/tmp CI=1 OPENSPEC_TELEMETRY=0
openspec list --json
openspec status --change pulse-project-settings-simplify --json
openspec instructions archive --change pulse-project-settings-simplify --json
openspec instructions specs --change pulse-project-settings-simplify --json
bash skills/teamsmith/scripts/team change status pulse-project-settings-simplify --json
# 前四项rc0；change status仅本任务自身阻塞，rc1。
```

对应原件：`E/list.*`、`status.*`、`archive-instructions.*`、`specs-instructions.*`、`team-change-status.*`，各存JSON、stderr及rc。archive guidance无context/operationGuidance；specs规则快照只取一次并按既有已接受正文使用，没有把提示或规则复制进规格。

先在 `E/project` 执行一次、读完整输出及生成差异后，再在本人任务分支执行一次同样的原生命令：

```sh
openspec archive -y pulse-project-settings-simplify
# trial rc=0; actual rc=0; stderr均空。
```

两次输出相同（`E/trial-archive.stdout`、`E/archive.stdout`），关键完整尾部：

```text
Applying changes to openspec/specs/verification/spec.md:
  ~ 1 modified
Totals: + 3, ~ 5, - 4, → 0
Specs updated successfully.
Change 'pulse-project-settings-simplify' archived as '2026-11-17-pulse-project-settings-simplify'.
```

两次都保留原生非阻断提示 `Consider splitting changes with more than 10 deltas`；这是已接受变更的规模提示，不为收尾拆改已验正文。

### 原样工件与三份正式spec

`E/trial-artifact-compare.log` 逐文件比较源与试做归档，`E/archive-compare.log` 逐文件比较基线Git正文与实际归档，以下七项全部rc0、实际归档文件数7：

```text
.openspec.yaml
proposal.md
design.md
tasks.md
specs/panel/spec.md
specs/memory-and-deps/spec.md
specs/verification/spec.md
```

实际active目录已不存在；`diff -qr "$E/project/openspec" openspec` rc0，实际归档和全部正式spec与已审试做逐字节相同。

`E/trial-specs.diff`（885行）及 `E/archive-specs.diff`（885行）为未过滤的普通Git差异。逐个完整hunk与三份delta核对：memory-and-deps只改新增键进入UI的跨层承诺；panel恰为四个退休块、三个替代块及三个已有修改块；verification只改既有覆盖块中本次selected-settings例外及对应场景，保留此前route-page/reply/routing例外和原场景。差异未涉及三份标题/Purpose或其它需求，没有delta-style headers进入正式spec。未加normalize或ignore-whitespace处理，也没有新增比较框架。

## 本任务交付短检查

报告暂存后，以下串行短检查通过后台作业 `A13-archive-short-checks` 实际执行，完成唤醒后已收取，整体rc0（工具参考用时69.6秒）。各项真实command/stdout/stderr/rc原件分别为 `E/validate-all.*`、`spec-refs.*`、`ledger-ban.*`、`diff-check.*`、`cached-diff-check.*`。

```sh
openspec validate --all
bash skills/teamsmith/tests/spec-refs.sh --check
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check
git diff --cached --check
```

实际结果：

| 命令 | rc | 实际输出/限制 |
|---|---:|---|
| `openspec validate --all` | 0 | `Totals: 20 passed, 0 failed (20 items)`；stderr保留222条需求正文超过500字符及1条Purpose占位提醒，无其它诊断 |
| `spec-refs.sh --check` | 0 | `judged 122 reference(s) (49 distinct) in 14237 effective line(s); retired 0; undeclared 0; id families used [D,E,F,M,P,V] named [D,E,F,M,P,V]`；stderr空 |
| `ledger-ban.sh --names-file …` | 0 | `scope=published files=2875 hits=0 names=ok user=resolved`；stderr空 |
| `git diff --check` | 0 | stdout/stderr空 |
| `git diff --cached --check` | 0 | stdout/stderr空 |

全仓使用非strict，不称全仓strict通过；没有为了去掉原生warning重写已验正文或Purpose。名单仅从既有路径传给既有扫描器，不读取名单正文；扫描后只追加本收据及替换报告中的等待状态，提交前再次核两种diff。没有产品/UI/CLI、编译/build/strings、smoke/FAST/meta、真实Pi/模型、计时或安装执行。

## 交接与权限

分支只本地交付，不push/merge/tag/npm，不操作真实Pulse/配置/提醒/待命，不代PM关单。七工件、三正式spec及本报告为唯一写集；临时spec写权交付后归还PM。本次试做/日志原件先留给PM收存，通知PM前不删本次根，未清理P471/V177或任何别人的目录。
