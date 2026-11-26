# P511 · 项目设置管理任务标签

agent: dev-bob · status: DELIVERED FOR INDEPENDENT VERIFICATION · time: 2026-11-26T03:27Z

branch: `task/P511-project-label-management-apply` · PR/MR: — · executable candidate: `64d9cfe09e0211edfd54d650706b83b817c807b5`

项目设置新增「任务标签」，可以填写名称、选择颜色、改变权重和确认删除。实现、面板构建和已有真实终端场景的改动已提交；作者没有运行该场景。原标签命令仍负责定义、关联与拒绝条件，看板默认顺序及算分不改。

## Deliverables

| Path | What |
|---|---|
| `skills/teamsmith/scripts/{team,task-labels.mjs,strings/help.en.tsv,strings/help.zh.tsv}` | `5730ff13`：只给原 `define/edit/delete` 增加 `--json`，两个语言的 `board` 帮助注明用法。未改 `cmd-docs.sh`；它原本已把定义操作的参数交给同一模块。 |
| `skills/teamsmith/scripts/panel/src/{App.tsx,layout.ts,project-settings.ts,types.ts,task-label-settings.ts,strings/}` | `64d9cfe0`：在现有设置列表和返回路径中加入标签目录、草稿、具名颜色和删除确认；完整十进制始终是字符串。 |
| `skills/teamsmith/scripts/panel/src/{main.tsx,data.ts}` | 复用当前项目的命令调用；严格解码完整标签输出，只在确认写入后刷新看板。 |
| `skills/teamsmith/scripts/panel/{panel.js,README.md}` | 原脚本生成的匹配包及入口说明；包 993434 字节，SHA-256 `9d23020a7c65c3ab3aeda43d3386638d9af83c0eadea94a61b57e083bf64840b`。 |
| `skills/teamsmith/tests/panel-p21.sh`、`openspec/changes/project-label-management/tasks.md` | 只扩充既有 `settings` 场景与该场景的准备；勾 1.1–2.3、3.1/3.2，未勾独立执行 3.3。 |

## OpenSpec assessment

| Dimension | Evidence |
|---|---|
| Completeness | 7/8：作者指令回读仅剩 3.3。当前条款、原标签变更及正式规格与基线逐文件无差异。 |
| Correctness | Shell/JS 语法、面板类型及两语词条、当前变更严格校验和原构建均实际退出 0；终端行为未由作者执行。 |
| Coherence | 写入仍由 `changeFor` → `write` → `publish` 负责；读回调用 `label ls`，不从看板反推权重；面板看板保持原 projection 和排序函数。 |

**1.1 基线。** `git merge-base --is-ancestor c9fbb5e705e15763048c803adee9187ca18cfef5 HEAD` 通过。编辑前将其与起点 `3d34444b` 的 CLI、面板源码和 `openspec/changes/task-labels/specs/` 比较，无差异。V196 独立候选终端 46/0、合并版同一性及公开排序通过见 `docs/team/reviews/V196.md`，不是本任务重跑。原 `Project labels are managed by name beside the board` 与 `Board labels and priority are optional read-only views` 对应的实际实现是：`label ls` 只输出名称/RGB/十进制三列；`--` 保护前导连字符；定义写入无机器结果；看板载荷只有目录名称/颜色和每行标签/分数，最近更新仍是默认。新接口无重叠，不修改这两个原要求。

**静态走读。** 结构化结果来自原写入：参数和目录读取失败、重名、字段无效、标签不存在、仍在使用，以及替换前 I/O 失败均非成功；完成实际替换但后续失败给 `unconfirmed`。仅定义操作选入，默认调用不打印 JSON；参数扫描跳过选项值，不把 `--name` 的值或 `--` 后的名称识别为旗标。面板用已解析项目根和独立 argv，编辑只发有变化的字段；取消和无变更均不写。收到拒绝/未确认时保留草稿并单独读取当前目录；读不到时没有保存或删除入口，可重新读取。按 `data.ts` 的缓存对象身份区分看板请求：确认写入后清掉旧样本，旧读完成只释放原请求，再请求 `board` 一个块；此间不展示旧优先级，后一次读报错则看板显示刷新失败。没有新轮询。

**场景改动。** 移用中文第一次点击聚焦、第二次打开及返回检查给「任务标签」；保留原命令三项、原模型记录正文及中英文返回。默认 10→11、长列表 68→69，未增加配置编辑项；英文 70×25 只走筛选、打开和返回。真实写入部分使用有更新时间的 T21：从没有目录开始新增 `-用户 反馈` 并选蓝色；通过原 CLI 设置自定义 RGB 并关联 T21；之后比对原 CLI、保留完整 argv 的日志、`-9007199254740993`、取消和拒绝的文件哈希、原任务行及配置/审计/偏好。场景代码与待执行的观察分开，不将这些断言当作运行结论。

## Final assessment

- CRITICAL：暂未从静态比对发现结构缺口；独立行为证据尚未产生，不可据此合并或归档。
- WARNING：补充尝试 `openspec validate --all --strict` 退出 1，`Totals: 5 passed, 17 failed (22 items)`，失败项均为未改的正式规格（例如 `seat-visibility` 的 Purpose 占位）；当前及原标签两个 change 均列通过。以 3.3 和当前变更严格检查分别判断，不把这次全库检查当成全绿，也未改正式规格。
- SUGGESTION：无偏离已审方案的实现建议。本任务不是缺陷修复，没有变异或红绿对照。
- 尚未实跑：`panel-p21.sh settings`、模型记录和原命令界面的保留行为，以及该场景未覆盖的未使用标签删除、其他拒绝和未确认结果、读失败、写后看板请求先后。后几条本轮仅走读；未跑整套、原标签 46 项、当前 Pulse 或任何发布操作。

## Verification evidence

环境：Node 24.22.1、TypeScript 6.0.3、Bun 1.3.14、OpenSpec 1.16.0。已有依赖版本为 Ink 7.1.1、React 19.3.0、React DevTools 8.0.0、`@types/node` 22.20.3、`@types/react` 19.3.0；`package.json`/`bun.lock` 与起点相同，未安装。

```text
$ bash -n skills/teamsmith/scripts/team
$ bash -n skills/teamsmith/tests/panel-p21.sh
$ node --check skills/teamsmith/scripts/task-labels.mjs
shell and label module syntax: rc=0
$ (cd skills/teamsmith/scripts/panel && PATH="$HOME/.bun/bin:$PATH" tsc --noEmit)
panel tsc --noEmit: rc=0
$ TMPDIR=/var/tmp node skills/teamsmith/tests/panel-strings.mjs
ok: selected settings references — 8 key labels; 110 displayed references
panel-strings: ok
panel string checks: rc=0
$ openspec validate project-label-management --type change --strict --no-interactive
Change 'project-label-management' is valid
strict change validation: rc=0
$ bash skills/teamsmith/scripts/panel/build.sh
Bundled 564 modules in 49ms
panel.js written (993434 bytes, sha256 9d23020a7c65c3ab3aeda43d3386638d9af83c0eadea94a61b57e083bf64840b)
panel build: rc=0
$ node --check skills/teamsmith/scripts/panel/panel.js
bundle syntax: rc=0
$ git diff --check 3d34444b..HEAD
candidate diff --check: rc=0
```

Ledger ban（任务工作树）：

```text
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=…/.worktrees/dev-bob scope=published files=3172 hits=0 names=ok user=resolved
ledger ban exit=0
```

## Suggested next steps

PM 将候选固定给非作者，通过现有隔离运行方式只执行一次 `bash skills/teamsmith/tests/panel-p21.sh settings` 并保全对应画面、ARGV 和读回文件。独立验收之前只保留本地任务分支；未推送、未合并、未改当前项目状态。

## 首轮独立验证后的定点修正

首轮候选 `eb95c48e` 保持 FAIL：25 秒，15 通过／1 失败（V206 报告提交 `04cff028`）。鼠标已打开新增表单，但在输入 `-用户 反馈` 后编辑器为空，也没有保存调用。首轮没有 tmux 退出值，不能据此称产品拒绝了该名称。

本轮候选 `882ecc2ea5b1841dbddb8d5cf4e6b379235c4801` 只改 `skills/teamsmith/tests/panel-p21.sh`：共用 `type_text` 在 `send-keys -l` 后加 `--` 并保留 stderr；标签名称、权重和取消前名称三个调用在发送失败时报告实际退出码并立刻停止当前场景。三个文本的参数和后续画面条件不变。其它调用仍复用同一个发送方法，无新增等待或断言。

```text
# tmux 3.7b，临时私有 socket，仅空窗中的 Bash read，无产品进程
$ tmux -S "$socket" send-keys -t p511-literal:empty -l "$text"
-用户 反馈: rc=1, stderr 含 command send-keys: invalid flag
-9007199254740993: rc=1, stderr 为 command send-keys: unknown flag -9
$ tmux -S "$socket" send-keys -t p511-literal:empty -l -- "$text"
-用户 反馈: rc=0
-9007199254740993: rc=0
$ cmp "$scratch/expected" "$scratch/actual"
exact input bytes: cmp rc=0
$ bash -n skills/teamsmith/tests/panel-p21.sh
shell syntax: rc=0
$ git diff --check eb95c48e
diff --check: rc=0
$ git diff --exit-code eb95c48e -- skills/teamsmith/scripts openspec
# rc=0，无输出；产品和规格字节未变
```

两条带前导减号的输入已确认原样到达空窗；第三条普通文本只核对了送入共用方法的参数。未重跑 `settings`、整套、构建或产品命令。由原独立验证者固定新候选，只补首轮未到达的操作。

## 独立设置通过后的文案修正

V206 在 `3fd44aac` 独立运行真实设置，49 通过／0 失败、116 秒，记录提交 `0f23bec2`。该次 `label-refused.txt:10,13` 把「标签仍在使用，无法删除。任务： T21」显示了两次，拒绝行为已通过，不因文案重复改判。

新候选 `7c7615ae27fc173668bb64e0e82e820329de09aa`：`layout.ts` 只删除表单内容区那一条重复行，共用 `labelNotes` → `diagnoseChunks` 提示仍在，继续采用原 `labelNotice` 的任务 ID。当前标签内容、操作和原测试不变；生成包之外没有其他执行文件变化。未重跑设置、未改产品行为。由原 V206 固定新候选，仅核拒删画面提示出现一次且 T21 仍在，不重复 49 项。

```text
$ (cd skills/teamsmith/scripts/panel && PATH="$HOME/.bun/bin:$PATH" tsc --noEmit)
panel tsc --noEmit: rc=0
$ bash skills/teamsmith/scripts/panel/build.sh
Bundled 564 modules in 44ms
panel.js written (993336 bytes, sha256 235415d9e172719fcacae7b86b01ae9b0484b5ddef3c686e9ca8861d94c92e3d)
panel build: rc=0
$ node --check skills/teamsmith/scripts/panel/panel.js
bundle syntax: rc=0
$ git diff --check 3fd44aac
diff --check: rc=0
$ git diff --numstat 3fd44aac -- skills/teamsmith/scripts/panel/src/layout.ts
0    1    skills/teamsmith/scripts/panel/src/layout.ts
```
