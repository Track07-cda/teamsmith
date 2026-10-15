# P269 · 检测并报告「孤儿席位进程」（tmux 死了但 Pi 还活着，白占内存）

task: P269
agent: dev3
phase: propose
category: analysis
change: orphan-visibility
specs: -
deltas: -
branch: task/P269-orphan-visibility-propose
deps: 2026-10-15 的 OOM 事故（PM 实测，见下）

## 交付物

一个 OpenSpec change（新能力，名字你定，例如 `seat-visibility`）：`openspec/changes/orphan-visibility/{proposal.md,design.md,tasks.md}` + 新能力的 `spec.md`。本阶段**只写方案**，不实现。

## 现象（PM 2026-10-15 实测）

机器 OOM 之后：本项目的五个席位进程全没了，但**同机其他项目**留下了一批**孤儿 Pi 进程**——它们的 tmux 窗口已死（`tmux list-panes` 里找不到），进程本身还活着并各自占 0.2–0.6 GB：

```
pid=240764  0.58 GB  <项目甲>/dev2        无窗口
pid=2928294 0.27 GB  <项目丙>/infra       无窗口
pid=3631594 0.59 GB  <项目丙>/verify      无窗口
pid=3635865 0.58 GB  <项目丙>/explore     无窗口
pid=3644571 0.61 GB  <项目丙>/design      无窗口
pid=3647350 0.56 GB  <项目丙>/arch        无窗口
pid=4059338 0.65 GB  <项目丙>/core        无窗口
合计约 4 GB（外加一个身份为空的 0.23 GB）
```

它们对使用者是**不可见**的：窗口没了、`team status`/`team resume` 也看不到（判活按窗口算），但内存被占着，直接加剧下一次 OOM——而 OOM 会连带杀掉**所有**项目的团队（这次就是）。

## 要做什么

1. **检测**：`team up` / `team status` / `team ps` 里增加一项**孤儿席位进程**的读数：扫描本机（`/proc/*/environ` 里 `TEAM_PROJECT`/`TEAM_SESSION`/`TEAM_ROOT` 指向本项目）且**不属于任何活着的 tmux pane** 的 Pi 进程，打印 pid、RSS、它记录的席位与任务、以及它的启动时间。
2. **只报告，不擅自杀**：默认**只报告**并给出一条可复制的清理命令（`kill <pid>` 或 `team reap <pid>`）；跨项目只报告**本机总量**与「有几个别的项目的孤儿、合计多少内存」，**不点名别的项目**（账本禁令：仓内记录不写其他项目名）。
3. **本项目的孤儿**（身份属于本项目）：可以给一个**显式**的收编/清理入口（例如 `team resume --adopt-orphans` 或 `team reap --orphans`），带 `--yes` 与审计；默认不动。
4. **顺手记进 digest**：孤儿合计内存超过阈值（例如 1 GB）时，在 `team digest` 的容量行里显示一条提示（不是红、不改退出码）。
5. **红侧**：① 造一个假的孤儿（起一个带本项目身份但不在 tmux 里的 `sleep`/`pi` 替身）→ 检测点名它、`--yes` 清理后消失；② 正常在跑的席位**不得**被误判为孤儿（这是关键：判据必须「无 pane」而不是「不是当前 pane」）；③ 身份为空或属于别的项目的进程：只计入总量、不点名、不清理。

## 边界

- 只写提案；apply 与 verify 另行换人。
- **不许**跨项目动手（不许杀别的项目的进程、不许改它们的仓库）；本任务只做**可见性 + 本项目的显式清理入口**。
- 不改 `team ps` 现有的容量读数含义（新增一行，不改旧行）。
- 排期：todo。

## 验收（本阶段）

```bash
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/spec-refs.sh --check
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```
