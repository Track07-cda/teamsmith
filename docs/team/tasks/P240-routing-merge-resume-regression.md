# P240 · 修回合：routing 合并把「崩溃 agent / resume」这条链弄坏了（真回归，不是文本）

task: P240
agent: dev
phase: apply
category: code
change: task-model-routing
specs: dispatch, pm-lifecycle
deltas: -
branch: task/P240-resume-regression
deps: 你（dev）是 S1（P228）的作者；这条回归随 routing 合并进入 main

## 缺陷（PM 已在容器里定位到引入点）

同一段 `smoke.sh --select 11c`（agent 续跑是 PM 的事）在钉死容器里：

| 树 | 结果 |
|---|---|
| `v0.1.2`（`69692a6`，上一次全绿的门禁 ✓4653 ✗0） | `✓15 ✗1`（resume 相关断言全绿） |
| 合并 routing 的 `e897a7d` | `✓7 ✗9` |

`e897a7d` 上的九条红（原文）：

```
✗ §11c 夹具：5s 内 dev 窗口还在（「窗口仍不在」的前提没成立）
✗ 崩溃 agent 的任务记录还在（…/.pi/team/state/dev.env 中找不到 [task=T1.1]）
✗ digest 仍把崩溃 agent 算成待办（…/digest-crash.log 中没有匹配 [停了的 agent [0-9]]）
✗ 死窗口释放模型槽位（RUNNING=0）（期望 [0]，实际 [可用]）
✗ resume --dry-run 能识别待续跑任务（…/resume-dry.log 中找不到 [可续跑：T1.1]）
✗ resume 重新派单（…/resume.log 中找不到 [续跑 dev]）
✗ resume 后 dev 窗口回来了（期望 [1]，实际 [0]）
✗ up --agents 才会续跑 agent（…/up-agents.log 中找不到 [续跑 dev]）
```

PM 的证据（仓外）：`pm-skills-ledger/team/reviews/routing-merge-regressions/`（baseline 与 `e897a7d` 的完整选段日志 + README）。

**性质**：这是**行为回归**，不是「文本变了断言该同步」——「崩溃的席位记录还在、digest 把它算作待办、`team resume` 能重新派单并把窗口拉回来」是既有合同与既有断言，routing 合并之前一直绿。

## 要求

1. **先复现**：在钉死容器里跑 `--select 11c`，贴出与上表一致的 9 条红（不许改夹具来「修好」前提）。
2. **根因**：说明 S1 的哪处改动导致（`cmd-agents.sh` 的派单身份选择 / `cmd-watch.sh` 的 resume / 记录写入字段 / `cmd-status.sh` 的 digest 判据，哪个是主因），并给出代码位置的引用。
3. **修**：让这条链恢复绿，且**不许削弱断言**（不许删、skip 或用改夹具代替）——它们是合同。同时**不许回退 S1 的既有行为**：routing 的核心语义（类别→模型映射、同任务复用记录里的 model/SID、换模型必须 `--fresh`、发布身份不得多于 argv 交付）都要保住；`task-model-routing.sh --select dispatch,resume,transaction,pm` 必须仍全绿。
4. **红绿证据**：修前（`e897a7d` 或修前 tip）9 红 → 修后 0 红，逐条对照；再跑 `--select 11c` 与 `task-model-routing.sh --select dispatch,resume,transaction,pm,config` 各一次贴结果。
5. **边界**：只碰你判定为根因的文件；若根因落在别人正在改的文件（`smoke.sh`/`section-paths.tsv` 被 P238 占着），先 `BLOCKED:` 给 PM，不要并行改同一文件。

## 验收命令（贴真实输出）

```bash
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/smoke.sh --select 11c
bash skills/teamsmith/tests/task-model-routing.sh --select dispatch,resume,transaction,pm,config
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```

（门禁跑在容器里、干净 clone 上：`git clone --no-local . /tmp/<dir>` + `distrobox-host-exec podman run … localhost/teamsmith-gate:local`；不要在 worktree 里跑门禁。）

## 交付

`docs/team/reports/P240-dev.md`（复现证据、根因、改动清单、修前 9 红 → 修后 0 红的逐条对照、routing 组仍绿、未做项）；证据包按 D94 放仓外；不合并、不推送；做完 `team notify pm`，之后由未写过本任务的席位独立复验（复验必须用 **v0.1.2 这批绿基线**对照，不许拿父 tip 当基线）。
