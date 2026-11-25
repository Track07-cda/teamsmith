# P500 · 新项目采用 Pi 已保存的默认模型

**实施已交付，作者静态检查通过；初始化行为尚未运行，待独立验收。** 新项目可不写模型参数：`init` 与 `bootstrap` 共用解析逻辑，把 Pi 用户设置中保存的模型分别填入缺少的任务映射及 PM 设置。显式任务映射整份替换，显式 PM 参数只覆盖 PM。`bootstrap --print` 显示实际拟用模型，缺项时只指引补缺项；已有有效配置的预览显示保留，不再列出不会运行的 `init` 命令。

agent: dev-bob · status: IMPLEMENTED / INDEPENDENT VERIFICATION PENDING · time: 2026-11-25T07:04:00Z

branch: `task/P500-quick-init-model-defaults-apply` · PR/MR: -

## Deliverables

| Path | What |
|---|---|
| `skills/teamsmith/scripts/lib/{cmd-project,cmd-bootstrap}.sh`, `skills/teamsmith/scripts/pi-saved-model.mjs` | `f3750a7f` 共用首跑取值；`b8709770` 使缺项预览给出下一步；`eafd686b` 保留项目现值的原校验；`3daf511c` 用配置发现的结果区分未找到与已载入。 |
| `README.md`，两份技能的说明与模板，`skills/teamsmith/scripts/strings/help.{zh,en}.tsv` | `8e38fd03` 替换旧的双参数必填示例，保留非模型事项确认和旧项目迁移步骤；初始化技能 98 行。 |
| `skills/teamsmith/tests/task-model-routing.sh`，`skills/teamsmith/tests/lib/model-routing-flips.py` | `35cb186d`、`8ce490f5` 更新现有 `init` 组：私有 HOME、Pi 设置目录、可用 JS 且无 Pi 的 PATH；对照配置值、退出值和无写入。旧 `init-legacy-proceeds` 仍返回两行，映射首行改成合法值，避免无关输入抢先失败。 |
| `openspec/changes/quick-init-model-defaults/tasks.md` | `8ce490f5` 只勾实施 1.1–1.4；2.1 留给非作者。与已接受的 `4cd418c15b31b9b3af4c11ff7f2042ed7b1f9c66` 比较，change 中只有 `tasks.md` 变化。 |

## OpenSpec assessment

| Dimension | Status | Evidence |
|---|---|---|
| Completeness | 1.1–1.4 implemented | 两入口、前置路径检查、帮助与原测试组见上表；2.1 未执行。 |
| Correctness | Static only | 显式校验和已有配置检查在 `team_init_saved_model_candidates` 之前。首次缺项才读一次 `settings.json`；Bash 按待填字段校验候选，优先精确思考档，然后通用档，最后用原 ID。已有冒号的 ID 不再拼接后缀。 |
| Coherence | Static only | `team_load_config` 仍负责发现；已发现但不可读的文件在 CLI 的 `sha256sum` 步骤点名并退出，不会进入 `source`。没有发现且指定过路径时在入口拒绝；主工作目录已有目标而 bootstrap 未找到配置时，提示从主目录运行或指定实际文件。原两参数交接、配置读取与写入实现、旧配置迁移建议和正式 bootstrap 后续依赖检查仍留在原调用路径。 |

## CRITICAL / WARNING / SUGGESTION

静态审阅未发现需扩大写集的事项。行为和反例未运行，不做可合并或可归档判断；唯一待验为 2.1，见下。

## Verification evidence

```text
$ export PATH="$HOME/.bun/bin:$PATH" TMPDIR=/var/tmp CI=1 OPENSPEC_TELEMETRY=0
$ for f in skills/teamsmith/scripts/lib/cmd-{project,bootstrap}.sh skills/teamsmith/tests/task-model-routing.sh; do bash -n "$f"; printf 'bash -n %s: rc=0\n' "$f"; done
bash -n skills/teamsmith/scripts/lib/cmd-project.sh: rc=0
bash -n skills/teamsmith/scripts/lib/cmd-bootstrap.sh: rc=0
bash -n skills/teamsmith/tests/task-model-routing.sh: rc=0
$ node --check skills/teamsmith/scripts/pi-saved-model.mjs
node --check pi-saved-model.mjs: rc=0
$ python3 -c 'import ast,sys; ast.parse(open(sys.argv[1], encoding="utf-8").read(), filename=sys.argv[1])' skills/teamsmith/tests/lib/model-routing-flips.py
Python AST parse model-routing-flips.py: rc=0
$ git diff --check
rc=0
$ git diff --cached --check
rc=0
$ git diff --check 32818d23..HEAD
rc=0
$ wc -l skills/teamsmith-init/SKILL.md
98 skills/teamsmith-init/SKILL.md
```

- Verdict: PASS — static checks only. 未运行 `team init`、`team bootstrap`、帮助渲染、OpenSpec CLI、现有 `init` 组选段、冒烟测试、真实 Pi、安装或发布；未改真实项目、Pi 设置、全局安装或运行状态。
- Ledger ban (在本任务工作树执行)：

  ```text
  $ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
  ledger-ban: root=/home/<user>/Documents/syncthing/Work/Projects/pm-skills/.worktrees/dev-bob scope=published files=3081 hits=0 names=ok user=resolved
  ledger-ban rc=0
  ```

## Flip evidence and independent handoff

非作者在固定候选的私有检出运行一次 `TMPDIR=/var/tmp bash skills/teamsmith/tests/task-model-routing.sh --select init`。可用 `TEAM_ROUTING_EVIDENCE` 将 `init-cmds.log` 与私有项目留在验收证据目录，核对下列实际读数：

- `init-saved-machine`：按序恰好 `routine`、`analysis`、`verify`，各为 `vendor/nested/model:high`，PM 独立字段同值；`init-fresh-machine` 及两个单参数用例核对显式覆盖，不增加其他类别。
- `init-print-*` 与 `init-bootstrap-fresh-*`：同一项目预览和正式写入的四个模型值相同，均为 `vendor/nested/model`；预览前后文件哈希一致，无新目录或链接。缺项、非法参数、所选配置不存在以及旧配置拒绝各记录退出值；已有配置重入核对哈希，保留原模型和旧迁移建议。
- 单用例反例：从组内 `init-saved` 复用相同 JSON 和私有环境，在私有候选副本中只将 `team_init_saved_model_candidates` 的函数体替换为 `return 0`，对等价的新 Git 项目直接执行 `bash <candidate>/skills/teamsmith/scripts/team init --no-skills`。期望退出 4、哈希不变，`.pi`、`docs`、`AGENTS.md`、`.worktrees` 同时未出现目录、文件或链接。恢复原函数后在另一等价新项目运行同一命令，以 `config list --json` 读回上面的四个完整值。不重跑现有组或变异矩阵。反例与恢复结果均尚未观测。

## Decisions and deviations

无。候选与报告只留在本地任务分支，未推送、未合并。下一步由 PM 固定候选并指派非作者执行 2.1。
