# P61 · trust-prompt-and-fixtures 独立验证（verify 阶段）

```
task:   P61
agent:  dev3
issue:
change: trust-prompt-and-fixtures
specs:  verification#A fixture's input-box judgement distinguishes an unexpected overlay / init-skill#The project-local install names Pi's trust consequence
phase:  verify
anchor: change
deltas: verification, init-skill
grant:  docs/team/reports/P61-dev3.md · docs/team/reports/P61-dev3/**（只写报告与证据，不改实现）
deps:   P57（propose）· **P59（apply，dev-bob）**——apply 作者不是你
status: todo
budget: 一个工作块（只写复验证据与报告）
```

> 本地模式：不 push。

## 要对抗性验证的（每条给可复现命令 + 原始输出）

1. **覆盖层 vs 草稿**：自己造三种现场——① 真信任弹窗（`M24_TRUST=prompt`）② **带真草稿的正常框**
   ③ **整屏但不是弹窗的其它界面**（若存在）——要求：弹窗**不得**被判成 `idle-read=NOT-EMPTY`、
   真草稿**必须**仍被判成"有草稿"（别把这条误伤）；弹窗在场时**一个键都不许敲**。
2. **就绪等待的口径**：确认它**不是**"看到第一条整行分隔线就放行"（自己造一个"先画分隔线、后画输入框"的慢帧序列验）。
3. **trust store 的证据**：跑完夹具后 `$HOME/.pi/agent/trust.json` 的 **sha256 + mtime 不变**（自己比对前后）；
   另确认它**没有**用 `--no-skills` 绕过（读夹具源码 + 断言 `.pi/skills` 在项目里存在）。
4. **帧的可证伪性**：关掉覆盖层判据 → **同一份存下的真实帧**必须被判成草稿（红侧）；
   还原绿。**帧文件本身**要与真 pi 版本绑定（写明来源与版本）。
5. **安装提示行**：`team init` 打一行（含三条出路）、`--no-skills` 不打、**退出码不变**；
   `bootstrap` 的既有 config 升级路径**也打**（自己造既有 `config.sh` 的场景验）。
6. **零回归**：FAST + 全量 smoke（§31b2 必须绿，这是本 change 修的那条红）、
   `install-shape.sh`、`pm-box-real.sh` 三态。

## 至少三条变异（红→绿原始输出）

- 关掉覆盖层判据 → 真实帧被判成草稿；
- 让夹具在弹窗上继续跑投递 → 断言红（敲键即失败）；
- 让 `--no-skills` 也打提示行 → 红；
- 还原后 `git status --porcelain` 干净。

## Acceptance

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
bash skills/teamsmith/tests/pm-box-real.sh --expect-overlay
```
