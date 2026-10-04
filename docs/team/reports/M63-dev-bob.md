# M63 · 破坏性 tmux 调用的授权模型重做（propose）

```
task:    M63
agent:   dev-bob   status: DONE（提案包四件套完成；未碰任何实现/测试/引用文件）   time: 2026-09-21T17:0xZ
branch:  task/M63-argv-2（tip `4866093`；提交 `01fdcf0` → `a7f7e25` → `a4b9c7c` → `99fa25a`（报告）→ `4866093`；验收跑在 `a4b9c7c`，其后只有 design 措辞与本报告两处 docs 提交）
PR/MR:   -（local 模式：不 push，分支留在 .worktrees/dev-bob）
change:  tmux-gate-grant-redesign（phase: propose；`anchor: change`，`deltas: boundary`）
base:    421bebb（main 只比它多一个 docs 提交 `da77573` M65 任务书，与本 change 的产物无交集）
```

## Deliverables

| Path | What |
|---|---|
| `openspec/changes/tmux-gate-grant-redesign/proposal.md` | 提案（491 词；Why / What Changes / Capabilities / Impact / Acceptance / What flips / Boundaries / Evidence） |
| `openspec/changes/tmux-gate-grant-redesign/specs/boundary/spec.md` | delta：**3 条 ADDED requirement / 14 条 scenario**（只钉封闭 token，每条可证伪） |
| `openspec/changes/tmux-gate-grant-redesign/design.md` | 六问逐一裁决（D2/D3/D5/D4/D6/D7）+ D1（base 文本与排序）+ D8（不变量）+ 证据总表（每条 requirement 的复核方法）+ 风险 + 迁移 |
| `openspec/changes/tmux-gate-grant-redesign/tasks.md` | 两个 apply 批次（B1 = 判定 + 退场，B2 = 夹具 + 翻转）+ PM 的 B3（转移、trial archive、归档）；覆盖图与路径授权 |

`git diff --stat 421bebb..HEAD`：4 个新文件，597 行（+ 本次修订）。**零实现改动**（本任务只写 docs）。

## 1. 验收命令（真跑，原始输出）

```sh
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
✓ change/tmux-gate-grant-redesign
✓ spec/verification
✓ spec/watchdog
Totals: 18 passed, 0 failed (18 items)          # 基线 17 → 新增本 change 1 项

$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null      # tip a4b9c7c（最终验收）
== 结果 ==  ✓ 2205  ✗ 0
FAST 模式：跳过 27 个真进程段落（… 31b·容器 tmux 自检（podman）|31c·真私有 server 生死|31c·窗口注入端到端 …）
smoke 全绿
FINAL_SMOKE_EXIT=0

$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null      # 同树更早一次（引用修订后）
== 结果 ==  ✓ 2205  ✗ 0
smoke 全绿
SMOKE_EXIT=0

$ git status --porcelain
（空）
```

**基线对比（证明本任务零行为改动）**：同一命令在未改动的 `421bebb` 上（`/tmp/m63-base`，`git archive` 展开）：

```sh
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
== 结果 ==  ✓ 2205  ✗ 1
✗ 冲突标记守卫：找不到受检的 git 工作树（/tmp/m63-base/skills/teamsmith 不在仓库里？…）
```

✓ 数与分支**逐条相同（2205）**，基线那一条红是我用 `git archive` 展开、没有 `.git` 造成的**夹具环境假红**（§0d 的
git 工作树判据），不是覆盖率差异；分支树（真 worktree）同一命令 ✗0。

## 2. 任务书六问的裁决（细节在 design，此处给结论与位置）

| # | 问题 | 裁决 | 位置 |
|---|---|---|---|
| 1 | argv 标志的名字/语法/剥离位置 | `--teamsmith-allow-destructive`，**只认全局选项位**（子命令之前）；每次出现都剥掉再 exec；`--…=1` 这种形式不认（透传给 tmux→报错 = fail-closed）；子命令之后出现的同名字一律当**数据**（`send-keys` 载荷必须原样透传）。带标志的调用总是 `act=explicit-flag`（标志是人的授权，与 socket 无关） | D3 |
| 2 | "本项目会话内具名对象"的判据 | 有效 `-t`（最后一次，`-t x` 与 `-tx` 都认）非空，且 `:` 前的会话名是字面量、等于非空 `TEAM_SESSION`，并且 **M40 绑定**成立（`TEAM_ROOT`/`TEAM_MAIN_ROOT` realpath 后是闸门 cwd 或其祖先）；缺/空 `-t`、`%N`、`@N`、`:win`、`.`/`+`/`-`、裸窗口名、跨会话名 → 一律拒；`kill-server` 与 `kill-session -a` 在共享 socket 上**无条件拒**（服务器不是具名对象；`-a` 的杀伤集越出目标会话） | D2 |
| 3 | 现有合法破坏路径逐个点名 | 表：`team teardown`（cmd-agents.sh:1069）、add-agent/dispatch 清窗（:779/:812）、review 清理（cmd-review.sh:883）、pulse/watch 关窗（cmd-watch.sh:1361/1376/1380）、两个包装（common.sh:1325–1332）、`team up/resume`（respawn-pane 不在守卫集）→ **全部按"own session 具名对象"放行，没有一个需要标志**；宿主 shell 里没有闸门，行为不变 | D5 |
| 4 | 旧环境变量退场 | **保留为 refuse 类墓碑**（不删：删了存量 `.pi/team/config.sh` 里的键会变成未知键、且没有可见的迁移出口）：shim/CLI 不再读、不再导出；描述改成"不再授权"；`team doctor` 报 **server 全局环境残留** + 重启 server 的建议；`references/config.md`、`references/troubleshooting.md §18`、`CHANGELOG.md` 同步 | D4 |
| 5 | 测试夹具怎么写 | 默认 socket 上的判定探针**一律钉 argv 记录的桩**（错判也只执行脚本）；真杀只在私有 socket 或容器；**泄漏形状在容器里复现**；lint 的 A–D 与绝对路径红不变，标志**不算隔离证明**，但带标志的变更调用必须仍被识别为变更（不能被标志藏起来） | D6 |
| 6 | 审计行形状与 "override" | `act=pass\|refused\|allowed-owned\|explicit-flag`；"override" 从**闸门自己的词汇表**删除（shim、拒文、`references/` 的闸门段落、`CHANGELOG.md` 对应条目）；其它合法说 "override" 的机制（`TEAM_REVIEW_ALLOW_*`、`TEAM_BOARD_DONE_FORCE`、打字守卫）不动；字段与 2000/1000 上限不变（不加字段，argv 已带目标） | D7 |

用户五条决定 → 落点：①目标归属判定 = R1（D2）；②argv 一次性标志 + 绝对路径 = R1（D3）；③不再 export/退役 =
R2（D4 + D5）；④默认值对齐 = R2（删 export，schema 的 `0` 成为唯一默认）；⑤证据 = R1/R3 的 scenario 与 tasks 的翻转项。

## 3. 覆盖图

requirement → task item：**R1** → 1.1–1.3, 2.1, 2.5 ｜ **R2** → 1.3–1.5, 2.2 ｜ **R3** → 2.3–2.5。

scenario → fixture（apply 期落地；每条 scenario 都指名了夹具）：

| scenario（delta） | fixture |
|---|---|
| own-session 具名目标放行 | smoke §31c（桩 + `TEAM_SESSION=teamx` 绑定身份，三条子命令） |
| 非本会话目标被拒 | smoke §31c（`otherproj:pm`、`%1`、`dev`、`:dev`、`""`、裸 `kill-session`） |
| server/加宽形状 | smoke §31c（`kill-server`、`kill-ser`、`kill-session -a`） |
| 未绑定/空身份 | smoke §31c（cwd 在 root 之外 + 继承 `TEAM_SESSION`；unset/空值） |
| 继承环境不授权 | smoke §31c（探针 env 带 `TEAM_ALLOW_DESTRUCTIVE_TMUX=1`）+ 容器夹具（server 全局环境带它） |
| argv 标志一次性 | smoke §31c（桩 argv / 子进程 env / `send-keys` 载荷） |
| 私有放行 + 假隔离仍拒 | smoke §31c（M41 矩阵，target 用 own session） |
| 只读从不拒 | smoke §31c（`ls`/`list-sessions`/`display-message`/`capture-pane`/`send-keys`） |
| 日志四值 + 上限 | smoke §31c（字段、2100→1000、FIFO） |
| 新窗口无授权 | smoke §31c ⑩（真窗口 env dump，worker + PM；FAST 可见 SKIP） |
| CLI 不授权 + 墓碑可见 | smoke §31c/真窗口（CLI 调用记 `allowed-owned`）+ `config set` 负例 + doctor 残留行 |
| 默认 socket 探针不碰真身 | smoke §31c 的结构断言（桩 + 段首尾默认 server 探活 `L10052–10053`/`L10246`/`L10286`） |
| lint 看穿标志 | `perl tests/tmux-lint.pl --selftest` 新夹具（带标志无隔离红、带 `-L` 私有净、绝对路径红） |
| 容器里复现泄漏形状 | `tests/container-tmux.sh`（容器内起带旧变量的 server；无运行时 exit 77 可见 SKIP） |

## 4. 需要 PM 在提案审查里先裁决的一处**结构问题**（design D1）

**事实**：base `boundary` 里**没有**闸门 requirement（基线 grep：只有 L11/23/33/45/63 五条）；闸门两条还挂在
**未归档**的 `spec-backfill-2026-09/specs/boundary/spec.md`（L5 闸门、L68 日志+注入、L106 容器）：

- **推荐（本 delta 就按这个写）**：把 L5/L68 两条**转移到本 change** —— 本 change 用 ADDED + 新名字，spec-backfill
  只保留容器那条（L106 仍然成立）。转移是 spec-backfill 名下的一次小返工（tasks 3.1，PM 执行），是 M63 归档的
  **前置条件**。好处：M63 的归档不依赖另一个 change 的完成顺序，且同一规则不会留下两条并行陈述。
- **备选（MODIFIED）**：M63 归档时 base 仍没有这条 requirement —— OpenSpec 只在 **trial archive** 才抓
  "MODIFIED 指向 base 没有的 requirement"（`references/openspec.md` §5）；而且 spec-backfill 只能在修复落地后才
  **诚实**归档，届时它文本里的 `TEAM_ALLOW_DESTRUCTIVE_TMUX=1` 逃生口已被本 change 删掉 —— 两种排序都会记录一个
  假陈述，因此不采用。
- **若 PM 既不转移、又归档 spec-backfill**：base 会出现同一规则的**两条并行 requirement**（提案审查清单第 7 条会红）。

这不是 `BLOCKED:`（我做完了本任务的 propose；转移是另一个 change 的账本动作），但**派 apply 前必须裁决**。

## 5. 证据（全部已落盘，本任务只引用）

- M62 BLOCKED 复现链：`docs/team/reviews/M62.md`（PM 独立复现 + 2026-09-21T12:19:58Z 第 7 次默认 server 死亡，
  `act=refused` → `act=override` 两行；同一文件附录写明"演示破坏性路径本身就是违规"）。
- 审计账本（本节实测）：
  ```
  $ grep -o 'act=[a-z-]*' .pi/team/state/tmux-calls.log | sort | uniq -c
        1 act=override
     1823 act=pass
        1 act=refused
  $ grep -E 'kill-server|kill-session|kill-window|kill-pane' .pi/team/state/tmux-calls.log | grep -o 'act=[a-z-]*' | sort | uniq -c
        1 act=override     # 闸门上线以来的全部真破坏性调用
       41 act=pass         # 全是私有 socket（复验/夹具）
        1 act=refused
  ```
- 两个互相矛盾的代码点：`scripts/team:19`（`export …:-1`，注释还写着"窗口侧不会继承"）vs
  `skills/teamsmith/scripts/lib/cmd-config.sh:65`（默认 `0`）。
- shim 现状与重构必须保留的部分：`shim/tmux` L89–147（M41 socket 路径表 + 两个假隔离形态）、L149–157（破坏集合、
  前缀写法）、L165–181（日志字段与截断）、L183–201（拒文）；`common.sh` L622–641（M40 身份契约）、L2051–2100（注入前缀）。

## 6. Flip 证据（本任务不是 defect-fix）

本任务只写 docs：`git diff --stat 421bebb..HEAD` = 4 个新文件、零实现/测试改动；FAST smoke 在改动前后同绿
（§1 的基线对比），所以没有"红→绿"可交。**apply 期必须交的四条翻转**（design 证据表 + tasks 2.5）：

1. 把 shim 里读 `TEAM_ALLOW_DESTRUCTIVE_TMUX` 的那一行放回去 → 继承环境探针不再拒（转绿/红）；
2. 让判定接受任意目标 → 跨会话探针执行到桩；
3. 去掉 M40 绑定 → 未绑定身份被放行；
4. 不剥标志 → 桩看到 token。

## 7. Decisions and deviations

1. **与任务书第 3 条字面要求的偏差（需要 PM 一句话）**：任务书写"CLI 自己的破坏性调用改用 argv 标志"，本设计裁定
   **一个调用点都不加标志** —— 它们全是 `$TEAM_SESSION:<窗口>` 形式的 own-session 具名对象，走归属放行；加标志需要
   每处先探测"闸门在不在 PATH"（CLI 也会在无闸门的宿主 shell 里跑，那时标志会让 tmux 报错），而且会把审计账本冲成
   `explicit-flag` 噪声。理由与替代改法见 design D5。
2. **D1 用 ADDED 而不是任务书硬要求里提到的 MODIFIED**：原因与硬事实见 §4。
3. 三条 requirement 是**新名字**：旧名 "…that resolve to the shared default socket are refused" 已不描述新判定
   （判定不再只看 socket，而是看目标）。
4. 规模：3 requirement / 14 scenario（任务书 3–5 / 12–20）；只钉封闭 token（exit 64、四个 act 值、标志拼写、字段名），
   不冻结消息原文。
5. 未触碰：`scripts/**`、`tests/**`、`extension/**`、`references/**`（brief 明令）；任务书本身未改。

## 8. Suggested next steps

- PM 提案审查 → `docs/team/reviews/tmux-gate-grant-redesign-proposal.md`：先裁决 §4（转移 vs MODIFIED）与 §7.1
  （CLI 不加标志），再派 B1/B2。
- 归档链：B1 → B2 → 独立 verify → tasks 3.1（spec-backfill 转移）→ 3.2 trial archive → 用户确认后 3.3 归档。
