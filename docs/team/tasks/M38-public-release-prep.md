# M38 · public-release-prep：打包与发布准备（准备工作，**不发布**）

```
task:   M38
agent:  dev-bob
issue:  
change: -            # "-" if no requirement changes
specs:  -
phase:  -
deps:   -            # 与 M35/M36/M37 无依赖
status: todo
budget: 一个工作块；超出就交 PARTIAL 报告
```

> 本地模式：不 push，任务分支留在 `.worktrees/dev-bob`。
> **用户已明确**：只做准备，**暂不公开发布**——仓库可见性、npm 发布、tag push 都不许动。

## Context

用户决定把 teamsmith 做成可公开发布的项目（仓库 `github.com/Track07-cda/teamsmith` 目前 **private**，
已验证：匿名 HTTPS 取不到 refs）。现在的缺口：

- 没有根 `package.json` → pi 的包机制（`pi install`）无法发现本仓库的 skills（pi 支持
  `package.json` 的 `pi` 清单或约定目录；本仓库已有约定目录 `skills/`，但显式清单 + `pi-package` 关键字
  才能被 `pi install`/画廊稳定识别）。
- README 没有「安装 / 依赖 / 快速开始」段（现在是理念与能力介绍）。
- 没有 CI；没有发布清单。

## Deliverables

1. **根 `package.json`**（新增）：`name`（先查 npm 可用性，见 §5）、`version` 与 skill 版本一致
   （现在是 v1.41.0，发布时随版本走）、`description`、`license: MIT`、`repository`、`keywords: ["pi-package", …]`、
   `pi.skills: ["./skills"]`。
   **不要**声明 `pi.extensions`——扩展（`extension/`）是 teamsmith 在会话启动时用 `-e` 注入的，
   不是「装了全局生效」的东西；清单里写明这一点（README 或 package.json 注释不成，写 README）。
2. **README 补三段**：`Install`（`pi install git:github.com/Track07-cda/teamsmith@<tag>`，以及开发者方式
   的本地 path 安装）、`Requirements`（pi 版本下限你要实测确认、tmux、git；可选：bun 重建面板、
   openspec CLI 跑门禁、podman 跑容器测试、magic-context 推荐）、`Quickstart`（在新项目里跑
   teamsmith-init → bootstrap → 第一个任务）。另加一句「本仓库的 `docs/team/` 是它自己的真实运行账本」。
3. **`.github/workflows/gates.yml`**：`push: main` + `workflow_dispatch`，ubuntu-latest，
   装依赖（tmux、bun、openspec CLI）→ 跑 `openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh`。
   Actions 在 private 仓库可用但会消耗额度——workflow 先做成 **手动触发 + main push**（用户可随时关）。
   工作流本身在本地跑不了，报告里写明「未经真实 CI 验证」，并给出本地等价命令。
4. **`docs/team/PUBLISH.md`**：发布清单（逐步）：① 改可见性 ② 推 tag ③ 可选 npm publish ④ pi 画廊
   （`pi-package` 关键字 + 预览图/视频字段）⑤ 公告。每条写「谁做、在哪做、如何验证」。
5. **npm 名检查**：`teamsmith` 是否被占（`npm view teamsmith`）——占用了就给备选名（如 `@<scope>/teamsmith`
   或 `pi-teamsmith`），把实测输出写进报告。
6. **LICENSE 署名**：现在是 `Copyright (c) 2026 pm-skills contributors`——改成 teamsmith 是可选变更，
   报告里给建议但**不要**擅自改（等用户拍板）。

## 必做验收（要真跑，证据进报告）

```sh
# ① 本地 path 安装 —— 证明 pi 清单真能被发现
mkdir -p /tmp/m38-proj && cd /tmp/m38-proj && git init -q -b main
pi install -l <home>/Documents/syncthing/Work/Projects/pm-skills   # 项目级安装，别动用户全局设置
pi list | grep -i teamsmith
pi remove -l <上面列出的包名>
# ② private 仓库的 git 源安装（SSH key 可用）——在 scratch 项目里做，装完即卸
pi install -l git:github.com/Track07-cda/teamsmith@v1.40.0 && pi list | grep -i teamsmith && pi remove -l …
# ③ 文档里的依赖下限：实测 pi --version，把「>= 某版本」写成你验证过的数字并说明依据
```

> ⚠️ 两条纪律：所有 `pi install` 只用 `-l`（项目级，别污染 `~/.pi/agent/settings.json`）；
> 装完必须 `pi remove`，把 scratch 清理干净。

## Boundaries (do not do)

- **不改仓库可见性**、**不 npm publish**、**不 push 任何 tag**、不动 skill 行为代码（`scripts/**`、
  `extension/**`、`panel/src/**`）。
- 不动 `docs/team/` 的既有账本内容（只新增 PUBLISH.md）。
- 不顺手改 `.gitignore`/删软链等无关项。

## Acceptance (must actually be run; put the output in the report)

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh </dev/null
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
# 上面「必做验收」①②③ 的真实输出 + `bash -n`/`python3 -c 'import yaml…'` 检查 workflow 语法
```

## Report

`docs/team/reports/M38-dev-bob.md`。
