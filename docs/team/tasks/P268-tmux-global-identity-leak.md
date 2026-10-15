# P268 · 别把本项目的身份泄漏进 tmux 的全局环境（同机其他项目因此在共享 tmux 服务里起不来）

task: P268
agent: -
phase: propose
category: analysis
change: tmux-identity-scope
specs: pm-lifecycle
deltas: -
branch: task/P268-tmux-identity-scope
deps: 用户 2026-10-15 报的现象（原文与现场见下）

## 现象（用户报，PM 已复现）

用户的机器上**三个项目共用一个 tmux 服务**（`default` socket 上的 `teamsmith` / `<会话乙>` / `<项目丙>` 三个会话）。GNOME 崩溃把 tmux 服务带走、用户重开之后：**在别的项目目录里跑 `team pulse up` 被拒**：

```
✗ 身份冲突（pulse）：当前目录属于 '<项目甲>'（…/<项目甲>），而继承的环境指向别的项目
  TEAM_ROOT=…/本仓（继承） ‹ …/<项目甲>（按目录推导）
  TEAM_PROJECT=本仓（继承） ‹ <项目甲>（按目录推导）
  TEAM_SESSION=teamsmith（继承） ‹ <会话乙>（按目录推导）
处理: 清掉继承变量（env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT -u TEAM_SESSION …）或 cd 到目标项目
```

**PM 实测的成因**（`tmux show-environment -g` / `-t <session>` 对照）：

| 位置 | TEAM_* |
|---|---|
| tmux **全局**环境 | **6 个**（`TEAM_ROOT`/`TEAM_MAIN_ROOT`/`TEAM_PROJECT`/`TEAM_SESSION`/`TEAM_ASSUME_YES`/`TEAM_CONFIG_FILE`），都指向先启动该服务的那个项目（本仓） |
| `teamsmith` / `<会话乙>` / `<项目丙>` 三个会话**各自**的环境 | **0 个** |

也就是说：**本项目起服务/窗口时把调用者的身份写进了 tmux 的全局环境**，于是该服务里**任何**新窗口/pane（不管属于哪个项目）都继承它；别的项目在自己的目录里跑 `team up` / `team pulse up` 就撞身份守卫。守卫本身是对的（防止继承身份静默赢过 cwd），**错的是泄漏**。

## 要修什么

1. **起窗口/服务时不要写全局环境**：本项目启动自己的窗口（`team up` / `pulse up` / 派单建窗口）时，身份必须**限定在自己的会话或窗口内**（例如用 tmux 的 `-e`/会话级 `set-environment`，或干脆只通过启动命令的显式 `export`——现在派单已经是显式 export 的写法），**不得**调用会把变量写进 `-g` 全局环境的路径。
2. **已经泄漏的要能自愈或给出干净出路**：`team up` / `pulse up` 在**非嵌套**场景（人类在终端里直接跑）发现「全局环境里有别的项目的 TEAM_*」时，应当**清掉或忽略它并按 cwd 执行**（并打印一行说明），而不是让用户去查 `env -u` 的写法。判据要能区分「嵌套调用（夹具/门禁，继承身份是对的）」与「人类直接跑」——你评估可行的判据（例如父进程/`TEAM_IDENTITY_*` 链、或「cwd 能解析出项目且继承身份指向另一个已存在的项目」），并在 design 里写明误判的代价与兜底。
3. **保留守卫**：继承身份与 cwd 冲突时仍不许静默赢（这是既有合同），只是不再让**本工具的启动路径**制造这种冲突。
4. **红侧**：① 模拟污染：`tmux set-environment -g TEAM_PROJECT=<别的项目>`，然后在第二个项目的目录里跑 `pulse up --print` → 必须按 cwd 解析并打印一行说明（改前被拒）；② 真嵌套（在夹具/门禁里）仍按继承身份执行、不误清；③ 本项目起窗口后 `tmux show-environment -g` 里**不得**出现本项目的 `TEAM_*`（这条是根因的直接断言）。

## 边界

- 只写提案；apply 与 verify 另行换人。
- 不改身份守卫的语义（继承不许静默赢 cwd）、不改项目的配置键。
- 不碰其他项目的仓库；本任务只改本仓工具与它的夹具。
- 排期：todo（席位空出来再派）。

## 验收（本阶段）

```bash
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/spec-refs.sh --check
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```
