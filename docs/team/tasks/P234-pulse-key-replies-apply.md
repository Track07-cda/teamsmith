# P234 · pulse-key-replies apply（发布路径 + 存储 + 面板第五页）

task: P234
agent: dev
phase: apply
category: code
change: pulse-key-replies
specs: panel, key-replies
deltas: panel, key-replies
branch: task/P234-pulse-key-replies-apply
deps: E16（提案 ACCEPTED，见 docs/team/reviews/pulse-key-replies-proposal.md）

## 范围

按已接受的 `openspec/changes/pulse-key-replies/`（proposal / design 六条决策 / tasks.md / 两份 delta）实现**全部条目**。范围以该 change 的 tasks.md 为准，本条不重述；设计要点是：`team reply` CLI 主动提交（正文由调用方显式传入，工具不去 Pi 历史里找「当前回复」）、固定长度提交索引 + 不可变原文、锁与持久提交点、Pulse 第五页复用既有渲染器与详情查看、正文只进仓外账本面（默认不进公开仓）。

边界：只碰该 change 授权的路径（`scripts/lib/**` 的 reply 命令、扩展若需要、`panel/**` 与 bundle、门禁段落登记）。**不要碰** `templates/**`、`references/**`、`SKILL.md`（属 routing S3）；不改 canonical specs；需要契约变动先 `BLOCKED:` 给 PM。

## 前置

- **串行约束**：P232（routing 的面板切片）正在改 `panel/**`。本任务必须在 P232 合并之后才开工——PM 会在派单时确认并把 P232 的交付 tip 写进消息；在此之前保持 todo。
- 交付前自己核对 `openspec/changes/pulse-key-replies/tasks.md` 的每条都有对应实现或明确的未做理由。

## 验收

```bash
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/section-select.sh --paths <你实际改动的路径>
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```
外加该 change 的 tasks.md 里点名的门禁段落与真 tmux 面板取证（第五页渲染帧、长正文滚动、重启后仍可读、失败可见但不阻断正常答复），以及红侧（索引越界 / 原文被改写 / 提交失败仍宣告成功 → 相应断言必须红）。

## 交付

`docs/team/reports/P234-dev.md`（逐条 tasks.md 对照、命令与 rc、渲染帧、未做项）、证据包按 D94 放仓外；不合并、不推送；做完 `team notify pm`，之后由未写过本任务的席位独立复验。

## 返修轮次 1（2026-10-13，独立复验 V27 判 FAIL）

复验记录 `docs/team/reviews/V27.md`（受检 tip `a0107a0`）判 **FAIL**，实体是三条必修；其余逐条为绿（发布路径与五种结局、9 个落点、并发与锁、10 万槽有界 IO、面板第五页真 pty 含坏源与鼠标偏好、45 个快照逐帧审查 UNCLASSIFIED=0、三树回归对照无新红无弱化、bundle 可逐字节重建）。三条请按 V27 §2 的修法建议处理，每条都要**红侧**：

**M1（挂住）**：`index.v1` 或 `bodies/<id>.md` 是 FIFO 时，`reply list`/`show`（含 `--raw`）**永久挂住**（实测 rc 124，`open(2)` 只带了 `O_RDONLY|O_CLOEXEC|O_NOFOLLOW`、缺 `O_NONBLOCK` 与类型判定）。规格 `key-replies`「Traversal and nonregular sources are refused」明文要求**不得读目标、不得阻塞在 FIFO 上**。修法：读路径（索引 fd 与 `readBody()`）加 `O_NONBLOCK` 并复用现成的 `isFile()` 判定后清位。红侧：两条夹具断言「rc≠124 且给出 `not a regular file` 诊断」。

**M2（静默丢游标）**：`team reply list --before <no> --json` 与 `--before=<no> --json` 会**静默返回最新页**（根因：`scripts/lib/cmd-reply.sh` 的 list 分支里 `--json) extra=(--format json) ;;` 是赋值、应为 `extra+=`；文本形态正确）。红侧：把**两种参数顺序**都钉住。

**M3（门禁环境红）**：你登记的那一段在**钉死门禁镜像**里红——`ci/Containerfile` 按 M47 的约定在编译完 tmux 后 purge 掉 `build-essential`，所以镜像里永远没有编译器，IO 计数 shim 编不出来（容器里 `--select bounded` ✓4 ✗1、`--select flip` ✓8 ✗1、走门禁入口 `smoke.sh --select 61` ✓21 ✗1；宿主上同命令全绿）。你的报告里的「§61 ✓1 ✗0」只在宿主成立。**两条路你选一条并给依据**：① 换掉依赖编译器的手段（例如读 `/proc/<子进程>/io` 的 `rchar/syscr`），或 ② 保留 shim 但按项目既有约定让缺工具**可见跳过并点名**（不是静默通过、也不是留在那里让所有人学会忽略的红）。无论哪条，`flip/full_scan` 在 shim 缺席时都必须可见跳过而不是报红；`ci/Containerfile` 若要动，单独提交并在报告里注明那是门禁镜像的契约变化。

验收（都要贴真实输出，容器与宿主各一次）：该 change 自己的三套入口（`key-replies.sh --all`、`-ui.sh --all`、`-pty.sh --all`）+ `smoke.sh --select 61`（容器内）+ 你自造的 M1/M2 红侧 + `section-select.sh --check` + 账本禁令。修后冻结新 tip，由**另一个**席位复验（V29）。
