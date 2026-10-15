# P265 · 在 Pi 里给用户一个 `/team` 前门（propose：change `slash-team` + 规格 + 设计 + 任务）

agent: dev   status: DONE   time: 2026-10-15T03:19:51Z
branch: `task/P265-slash-team-propose`   PR/MR: -（local 模式，分支留本地，不推送）

## Deliverables

| Path | What |
|---|---|
| `openspec/changes/slash-team/proposal.md` | Why / What Changes / Capabilities / Impact / **需要 PM 裁定的四点** / Evidence（实跑）/ Out of scope。白名单十五条按用户确认过的清单逐条落表；四个裁定点各带推荐版本与备选 |
| `openspec/changes/slash-team/specs/extension-slash/spec.md` | 新能力（带 `## Purpose`）：六条需求——①`/team` 跑真 CLI 且是用户命令而非工具；②白名单单表、表外拒名、菜单/补全同源、每行路径 CLI 真的分发；③`up`/`--fresh-pm` 专用拒绝 + 有界等待；④输出落点与退出码诚实（短→通知、其它→正文、失败必可见、超量省略）；⑤前门不加自己的授权（环境剥离三个「替你说 yes」的变量）；⑥命令只装在项目本地安装目标的那棵树上 |
| `openspec/changes/slash-team/specs/init-skill/spec.md` | 三条 MODIFIED（整块原文 + 修改）：`team init` 的安装步骤（同类目里多装 `/team` 扩展，模式/幂等/冲突/`.gitignore`/逐行输出）、信任提示行（触发资源两个目录 + 两个文档同步）、`team doctor` 安装可见性（缺失/漂移/软链/副本四态 + 修法） |
| `openspec/changes/slash-team/design.md` | 设计：加载路径取舍（`.pi/extensions/` 自动发现 + `/reload` vs `-e` 要重启）、白名单数据形状（读行严格/动行自由尾巴）、分词、输出与退出码映射、边界（不注册工具、argv 逐字、环境剥离清单、项目根/CLI 解析顺序、不加确认框）、安装面、P260 语言依赖方向、三层验证策略与红侧；末尾 §6 是规格→任务对照（无孤儿任务） |
| `openspec/changes/slash-team/tasks.md` | apply/verify 清单（1 冻结、2 扩展本体、3 安装面、4 测试与门禁接线、5 收尾、6 独立验证、7 验收命令）+ 粒度声明（一个 apply 能做） |
| `docs/team/reports/P265-dev.md` | 本报告 |

本阶段只写提案：**没有产品代码改动**（`git status` 里只有 `openspec/changes/slash-team/` 与两份提交 + 本报告），
apply/verify 另派席位。

## Verification evidence (must have actually been run)

本阶段的任务书验收命令（全部跑在本工作树、本分支的树上）：

```bash
$ "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
✓ spec/verification
✓ spec/watchdog
Totals: 21 passed, 0 failed (21 items)          # 20 → 21：新 change 通过 --strict
$ echo $?
0

$ bash skills/teamsmith/tests/spec-refs.sh --check
spec-refs: judged 111 reference(s) (49 distinct) in 11257 effective line(s); retired 0; undeclared 0; id families used [D,E,F,M,P,V] named [D,E,F,M,P,V]
$ echo $?
0

$ bash skills/teamsmith/tests/section-select.sh --paths docs/team/reports/P265-dev.md
decision=RUN
sections=129
keys=5
reason=0 ← prologue … reason=60 ← docs/team/reports/P265-dev.md
$ echo $?
0

$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: names：名单已配置（/home/<user>/Documents/syncthing/Work/Projects/pm-skills/.git/../.pi/team/forbidden-names.txt，命中即红）
ledger-ban: root=/home/<user>/Documents/syncthing/Work/Projects/pm-skills/.worktrees/dev scope=published files=1506 hits=0 names=ok user=resolved
$ echo $?
0

$ git diff --check && git status --short
$ echo $?
0                                              # 报告提交后工作树为空
```

（上面那条 `ledger-ban` 是**本报告已在树里**的那次运行的原文与 rc=hits=0；`files=` 计数含本报告。）

设计所依据的探索证据（本阶段实跑，命令可复制；完整原始输出在 `/tmp/p265-probe/`，未进树）：

```bash
$ cd /tmp/p265-probe/proj && { printf '{"id":"1","type":"prompt","message":"/team status"}\n'; sleep 6; } \
    | HOME=/tmp/p265-probe PI_CODING_AGENT_DIR=/tmp/p265-probe/agentdir \
      "$HOME/.bun/bin/pi" --mode rpc --no-session --approve --session-dir /tmp/p265-probe/sessions2
{"type":"message_start","message":{"role":"custom","customType":"team","content":"$ team status\nexit=3\n--- stdout ---\nargv: status\nline two\n--- stderr ---\nboom\n","display":true,"timestamp":…}}
{"type":"extension_ui_request","id":"…","method":"notify","message":"team status → exit 3","notifyType":"error"}
{"id":"1","type":"response","command":"prompt","success":true,"data":{"disposition":"handled"}}
# 结论：项目扩展 .pi/extensions/*.ts 被加载；命令被处理；子进程 argv 与退出码完整；
#       pi.sendMessage 的自定义消息成为对话事件；失败是 error 通知；空 agent dir（无凭据/无模型/无网络）也跑得动。

$ "$HOME/.bun/bin/bun" -e "const m = await import('/tmp/p265-probe/proj/.pi/extensions/team.ts'); console.log('default fn:', typeof m.default)"
default fn: function
# 结论：扩展只做 import type（被擦除），纯逻辑可被 bun 直接加载 —— 这是 apply 夹具与 doctor 预检的形状。

$ for c in status digest ps board "reply list" "reply show 1" "config list" version doctor "meeting inbox" "pulse status"; do
    bash skills/teamsmith/scripts/team $c > /tmp/o 2>/tmp/e; printf '%-22s rc=%-3s lines=%-5s bytes=%s\n' "$c" "$?" "$(wc -l </tmp/o)" "$(wc -c </tmp/o)"; done
status rc=0   lines=440   bytes=43419
digest rc=0   lines=82    bytes=19171
ps     rc=0   lines=28    bytes=1354
board  rc=0   lines=428   bytes=40867
reply list rc=0 lines=1   bytes=3744
reply show 1 rc=0 lines=7 bytes=154
config list rc=0 lines=129 bytes=11814
version rc=0  lines=1     bytes=16
doctor rc=1   lines=36    bytes=…
meeting inbox rc=0 lines=1 bytes=33
pulse status rc=0 lines=12 bytes=1084
# 结论：大输出是常态（status 440 行/43 KB），「短=通知」必须按长度判；doctor 非 0 退出是真实场景。

$ # 表里每行路径喂一个不存在的旗标，判「CLI 是否真的分发这条路径」
$ bash skills/teamsmith/scripts/team frobnicate --teamsmith-slash-probe
✗ 未知子命令：frobnicate（team help 看全部；…）        # 唯一的顶层「未知子命令：<命令>」样本 = 红侧
$ for c in status "status x" digest ps board "board ls" "reply list" "reply show 1" "config list" version doctor \
           "meeting inbox" "meeting read x" "pulse status" "pulse up" "config upgrade-models" "meeting say x" "meeting close"; do
    bash skills/teamsmith/scripts/team $c --teamsmith-slash-probe >/dev/null 2>&1 || :; done
# 结论：18 个形状全部是 rc=0 或「未知参数 / board: 未知子命令」，没有一条落进顶层未知命令 —— 这条判据可跑。

$ env | grep -E '^TEAM_' | sed 's/=.*/=/' | sort        # 本会话：9 个泄漏的 TEAM_*，含 TEAM_ASSUME_YES
TEAM_ASSUME_YES=
TEAM_MAIN_ROOT=
TEAM_PROJECT=
TEAM_ROOT=
TEAM_SESSION=
…
$ grep -n 'TEAM_UPGRADE_CONFIRMED="${TEAM_ASSUME_YES:-0}"' skills/teamsmith/scripts/lib/common.sh
825:  TEAM_UPGRADE_CONFIRMED="${TEAM_ASSUME_YES:-0}"
# 结论：会话里漏进来的 TEAM_ASSUME_YES 会被 config upgrade-models 当成授权 —— 前门剥离它是必要的。

$ TEAM_ROOT=/tmp/p265-none TEAM_MAIN_ROOT=/tmp/p265-none TEAM_PROJECT=nope TEAM_SESSION=nope \
    bash skills/teamsmith/scripts/team status | head -2
! TEAM_IDENTITY_CONFLICT：身份以目录为准 —— …继承的环境指向别的项目
  …继承值被忽略，本命令按目录执行
# 结论：身份四件套不需要前门剥离（CLI 自己按 cwd 执行并说出来）；前门只要保证 cwd=项目根。
```

- Verdict: pass（本阶段四条验收命令全绿；apply/verify 的验收命令写在 `tasks.md` §7，**本阶段未运行**——
  那是下一个席位的证据面）
- Notes / 没跑什么：
  - **没有跑任何门禁段/全量 smoke**：本 change 一个产品文件都还没改，门禁面属于 apply。
  - **没有实现**（propose 只写规划产物）；`slash-team.sh` / `slash-team-e2e.sh` / 安装组都还不存在——它们是
    `tasks.md` §4 的交付物，本报告不声称它们跑过。
  - 探索证据的原始文件放在 `/tmp/p265-probe/`（探针扩展、RPC JSONL、命令规模表、探针表），**未进树**；
    报告与 proposal 的 Evidence 里都是它们的原文摘录。
  - 已知残余（写进 design §4）：会话里漏进来的身份变量由 CLI 自己的 conflict 守卫处理；前门不重复实现它。

## Flip evidence

本阶段是 **propose**，不是缺陷修复，所以没有「红→绿」可翻（没有实现可破坏）。红侧已经**写死在 change 里**，
由 apply 与 verify 两个席位执行、并把原始红/绿输出放进他们的报告与复验记录：

- `tasks.md` 4.6（apply，七条）：改白名单表一行 ⇒ 菜单断言红；短路拒绝分支 ⇒ 拒绝断言红；清空 unset 列表 ⇒
  环境断言红；去掉失败通知 ⇒ 失败可见性红；把 `sendMessage` 换成 notify ⇒ 正文断言红；去掉保险丝 ⇒ 超量红；
  安装改成无条件覆盖 ⇒ 冲突表红。
- `tasks.md` 6.2/6.3（verify，独立造）：把表里一行换成 CLI 不认的命令（探针方向）；`TEAM_ASSUME_YES=1` 的会话下
  真 CLI 预览 ⇒ 配置字节不变；`/team up`、`/team --fresh-pm`、表外命令、读行多余 token、未闭合引号 ⇒ 桩日志为空
  （零子进程）。

## Decisions and deviations

1. **change 覆盖两个能力**：任务书头是 `specs: extension-slash`，提案也以新能力 `extension-slash` 为主；但安装面
   （`team init` 装什么、信任行、doctor 行）**已经**被 `init-skill` 的三条既有需求规定着，所以按「同一条行为只能有
   一个说法」的规矩写成 **MODIFIED**，而不是在新能力里另写一份平行说法。这是对任务书字面的一种扩展读法，请评审
   时确认（if 不同意：把三条改成不动 `init-skill`、只在 `extension-slash` 里写安装，会立刻产生两份平行规格）。
2. **doctor 行动了 `cmd-project.sh`**（任务书边界说「不改 `team` CLI 本身」）：它是**安装态的可见性**，与既有
   「notify 扩展」行、`init-skill#The project-local install is visible in team doctor…` 同族；命令语义一行没动。
   已作为裁定点 3 摊在提案里——若评审按字面读，删掉那一条即可（规格与任务里同步删）。
3. **读行严格、动行自由尾巴**：用户只确认了命令集合、没有确认旗标集合；读行多一个 token 会被拒（`--json`、
   `--check` 也在内），动行把用户自己的命令行原样透传（`--intent/--task-models/--yes` 都在这里）。这是「表要多宽」
   这个问题的封闭答案，也让拒绝面可以机械判。
4. **有界等待 + 保险丝**略超出任务书「清单里的都很快」这句话：那句话是事实陈述，不是机制；`design.md` §3.4 把它
   做成 60s 有界等待与 500 行/64 KiB 的省略（今天最大的 `status` 是 440 行/43 KB，够不到）。若不想要这两条，
   删掉后规格里的对应场景一并删。
5. **环境剥离**（裁定点 2）与**大输出进上下文**（裁定点 1）都按推荐版本写；备选与代价在 proposal 里写明。
6. **语言**：P260（帮助面）的语言层今天没落地（`TEAM_LANG` 只在 pending change 里），所以只写中文一份，语言列在
   数据表里留成「加一列」的形态；依赖方向写进 `design.md` §3.7，**不写进规格**（今天不可证伪的场景不写）。
7. **不进会话指纹**：`team_skill_hash` 仍只哈希 `SKILL.md` + `extension/team-notify.ts`（既有要求），`/team` 靠
   `/reload`；这样不会因为加一个扩展就叫醒正在跑的会话。
8. **分支位置**：本分支在 main 之后 5 个 `[skip ci]` 账本提交处（`git log HEAD..main` 全是 PM 的账本提交，
   无产品差异），本阶段没有合并 main——没有需要它的改动。PM 复验/合并时按 local 模式处理。

## Suggested next steps

- PM 的提案评审（`docs/team/reviews/slash-team-proposal.md`）：先裁四个点（大输出进上下文 / 环境剥离 / doctor 行 /
  安装默认软链），再判 ACCEPTED。裁定结果与 `design.md`/`specs` 不一致的地方，apply 前必须回写规格再评审一次
  （这是协议里的门，不是可选项）。
- ACCEPTED 之后派 apply：一个席位能做完（`tasks.md` 的 1–5 节）；再另派一个未参与 apply 的席位做 6 节。
- 用户可见的预期：apply 落地后，主工作树里跑一次 `team init --force`（或首次 `team init`）+ `/reload` 就能用
  `/team`；这一步要 PM 提醒用户（安装与重载不由本变更自动完成）。
