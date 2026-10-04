# P37 · 安装形态对齐 openspec：npm 全局 CLI + 项目内初始化装 skill（propose）

```
task:   P37
agent:  dev2
issue:
change: npm-cli-and-project-init
specs:  -
phase:  propose
anchor: change
deltas: init-skill, memory-and-deps
deps:   M38（package.json 的 pi.skills 清单与 PUBLISH.md）· D35（scope = Pi-only）
status: todo
budget: 一个工作块（只出提案包；不写实现）
```

> 本地模式：不 push。**只 propose。**

## 用户要的形态（2026-09-22）

> 「能否做成像 openspec 的安装形式，**CLI 作为一个 npm 应用来安装**，并且可以**通过类似于 `openspec init` 在项目中安装 skill**。」

对照 OpenSpec：`npm i -g @fission-ai/openspec` → `openspec` 在 PATH → `openspec init` 在项目里生成/接好项目文件。

## 已核实的事实（提案据此设计，别重新发明）

- **今天**：`package.json` 有 `pi.skills:["./skills"]`，**没有 `bin`** → 从 npm 装不出 CLI；
  安装靠三条路（`pi install git:…@tag` / `pi install -l <checkout>` / `./install.sh` 软链进 `~/.agents/skills`）。
- **Pi 的 skill 搜索路径**（pi `docs/skills.md`）：`~/.pi/agent/skills/` · `~/.agents/skills/` ·
  **`.pi/skills/`（项目级）** · `.agents/skills/`（cwd 及祖先）· 以及包的 `skills/` 或 `pi.skills` 条目。
- **`team init` 今天** = 「只做配置/文档骨架（bootstrap 的其中一步）」；`bootstrap` = init + worktrees + pulse + 下一步。
- 扩展（`team-notify/team-bg/team-inbox-watch.ts`）**由启动器用 `-e` 注入**，不需要"安装到项目"。

## 提案要裁决的设计问题

1. **bin 形态**：`bin: {"team": …}` 直接指 bash 脚本（`skills/teamsmith/scripts/team`，带 shebang），
   还是加一个**薄 JS 包装**（`bin/team.mjs`：定位包根 → `execFileSync` 调 bash 脚本；顺带在缺
   bash/tmux/pi 时给人话报错）？**给取舍**（跨平台、`npx`/`bunx`、错误可读性、npm 的 shim 行为）。
2. **`team init` 的语义扩张**：从"只写配置/文档骨架"扩成 **"装 skill + 写配置/文档骨架"**（对齐
   `openspec init`）。要点：
   - 目标目录默认 **`<project>/.pi/skills/`**（Pi 的项目级搜索路径；比污染 `~/.agents/skills` 更干净，
     也支持**按项目锁版本**）；`--copy` 复制、默认**软链**（指向已安装包/检出，改动即时生效）；
   - **幂等**：重复 init 不重复装、不覆盖用户改过的文件（冲突时给可选处置）；
   - `--no-skills` 跳过装 skill（只想写配置的场景）；
   - `bootstrap` 沿用 init 的新语义（它内部调 init），**不新增第二条语义分支**；
   - 老的 `install.sh` **保留**（非 Pi 宿主 / `~/.agents/skills` 用户）。
3. **契约与文档**：`init-skill` 能力要把"安装"作为**第一步**写进去（今天写的是"装好之后"）；README §Install
   重写成"npm 全局 CLI + `team init`"为主路径，另两条作为替代；`PUBLISH.md` 的发版清单加"npm publish 后
   演练一次 `npm i -g` + `team init`"。
4. **与 D35 一致**：一切措辞按 Pi-only。
5. **规模**：预计 3–5 条 requirement 改动、10–18 条 scenario；别膨胀。

## 硬要求

- **跨任务规则（安装路径/项目契约）→ policy B 强制**：delta 落 `init-skill`（+ 视需要 `memory-and-deps`）；
  每条可证伪；MODIFIED 不得删 base scenario；
- 每条 requirement 给"复核方法"（跑什么、看哪一段、期望值）；
- 明写**不做什么**：不改 `team` 子命令语义（除 `init` 的安装步）、不动扩展注入、不动门禁、不删 `install.sh`、
  **本次不发 npm**（publish 仍按 PUBLISH.md 待命）。

## Deliverables

- `openspec/changes/npm-cli-and-project-init/{proposal.md,design.md,tasks.md}`
- `openspec/changes/npm-cli-and-project-init/specs/{init-skill,memory-and-deps}/spec.md`
- 报告 `docs/team/reports/P37-<agent>.md`

## Acceptance

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
git status --porcelain
```
