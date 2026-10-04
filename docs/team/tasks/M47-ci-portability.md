# M47 · CI 可移植性：让 GitHub Actions 的门禁真的可信（48 条红的分类与修复）

```
task:   M47
agent:  dev2
issue:  
change: -
specs:  -
phase:  -
anchor: none (infra) — CI runner environment and test portability (no product behaviour change)
deps:   -            # 与本仓库其它在飞任务不重叠（改 .github/ + tests/ 的可移植性）
status: todo
budget: 一个工作块；做不完交 PARTIAL + 分类表
```

> 本地模式：不 push；任务分支留在 `.worktrees/dev2`。CI 触发靠 PM 推送，你**不要**自己推 main。

## Context（证据在 CI 上，取日志的办法在下面）

`.github/workflows/gates.yml`（M38 加的）从此**每次 push 都红**，因为套件是在我们这台 distrobox
机器上长出来的、对环境有不少隐含假设。最近一次 run（main `2752ad1`）：

```
gh run view 35488632867 --log-failed      # 需要 export GH_TOKEN="$(cat .github-pat)"（该文件已 gitignore）
→ 本机：✓ 2362 ✗ 0      CI：✓ 2300 ✗ 48
```

48 条红聚成这些簇（PM 已分类，你要逐条落到「环境 / 套件假设 / 真 bug」三档）：

| 簇 | 条数 | 症状（原样） |
|---|---|---|
| A · skill 装载 | 2 | `✗ skill-load 失败（teamsmith）`、`（teamsmith-init）` —— CI 里没有 pi 或版本不同 |
| B · 登录 shell 夹具 | 2 | `夹具有效：登录 bash 看不到 …/m81-bare-bin`（m82 同）——runner 的登录 profile 与我们的不同 |
| C · team-bg（runner=node） | 5 | `TEAM-BG-CASE FAIL S11 …`（worktree 侧作业日志/账本/唤醒）——**node 跑**与 bun 跑的差异 |
| D · 12b-h 草稿/收回族 | ~12 | ⑨ 打字期间有草稿介入、⑰c/⑰d 升级兼容、⑲a/b/c 收回、⑳ M45 投递内容 |
| E · bundle 可复现 | 1 | `26-a bundle：重建后与提交的 bundle 不一致（源与产物漂了）` |
| F · JS 运行时选择 | 1 | `26-k paths：TEAM_JS_BIN 优先`（期望串是 bun 的） |
| G · 26-m 真 pane 渲染 | 7 | `20s 内没渲染出首帧/标题带`、待命理由、tick |
| H · 面板画面/身份 | 2 | `32⑧b 面板画面是 cwd 项目`、`logs 显示面板画面（wd-logs.log 找不到 [teamsmith pulse]）` |

## Deliverables

1. **逐条分类表**（写进报告）：48 条 → `env`（改 workflow 就能绿）/ `assumption`（套件假设，需要**有理由的显式
   skip 或重写夹具**）/ `bug`（真可移植性缺陷，修或另立任务）。**禁止静默 skip**：每个 skip 必须在输出里
   有一行可见的理由（沿用 `cond_skip`/`fast_skip` 的既有形状）。
2. **CI 运行环境的决定与落地**（择一并在报告里论证）：
   - **(推荐) 容器化**：仓库内加 `Containerfile`/镜像定义（tmux + bash5 + perl + bun 钉版本 + node 20 + locale），
     workflow 在容器里跑门禁 —— 与 M28 的容器纪律一致，环境漂移一次性消失；
   - 或 **钉死 runner 依赖**：`actions/setup-node`(node 20/22) + `oven-sh/setup-bun` 钉版本 + 装 pi（**钉版本**）
     + 任何 locale/tz 设定，并在 workflow 注释里写清为什么。
   - **绝不允许** `PI_OFFLINE`/关闭 pi 更新检查（用户明令）；也不允许 `continue-on-error` 掩盖红灯。
3. **workflow 修正**：`.github/workflows/gates.yml` 按上面的决定重写（含 M38 时代遗留的注释更新）。
4. **交付证据**：一次**绿**的 CI run（PM 负责推送触发；你把要推的提交准备好、告诉 PM），
   或（做不到全绿时）剩余红灯的**逐条理由** + 它们为什么不该拦合并。
5. **本机门禁不许退化**：改动后本机 `openspec validate --all --strict && bash tests/smoke.sh` 仍须 2362+ 全绿。

## Boundaries

- **不许为了 CI 绿而改产品语义**；不许把本机断言变松（宁可给可见 skip + 理由）。
- 不动 `.github-pat`（只在 `GH_TOKEN` 里用，不得回显、不得写进任何文件/提交）。
- 不改 M45/M46/P22 的语义；`smoke.sh` 只做可移植性所需的**最小**改动并在报告里列清单。
- 测试纪律照旧（私有 tmux socket、破坏性调用进容器）。

## Acceptance (must actually be run)

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh </dev/null
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
export GH_TOKEN="$(cat .github-pat)" && gh run list --limit 3        # 读，不要写
```

## Report

`docs/team/reports/M47-dev2.md`（分类表 + workflow 决定 + 需要 PM 推送的提交范围）。
