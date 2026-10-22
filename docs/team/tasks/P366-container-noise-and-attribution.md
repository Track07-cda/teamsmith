# P366 · 组合跑在容器里翻出来的三处红与一处挂住

task: P366
agent: dev3
phase: apply
category: code
change: -
specs: seat-visibility#The orphan survey never reports a process it cannot identify
anchor: none (infra) — 容器内的读数与噪声
deltas: -
branch: task/P366-container-noise

## 证据（PM 已跑，日志在 `~/.cache/acc033/floorpath.log`，fixture 根保留）

钉死镜像里 `--floor --paths <一个产品文件> --keep`：`✓4443 ✗3 SKIP15`、127 段收口、93 分钟、rc=1。三条红：

1. **`M50-②c digest cache 开/关输出不一致`** —— 差异是这两行：
   ```
   /work/skills/teamsmith/scripts/lib/common.sh: line 2847: /proc/2879526/environ: Permission denied
   ```
   `team_orphan_read_environ` 开头是 `[ -r "$f" ] || return 1`，但在容器 `--pid=host` 下，`-r`（访问(2)）
   对宿主进程的 `/proc/<pid>/environ` 回答「可读」、真正 `tr <` 时被拒 —— **shell 自己的报错漏进输出流**，
   把「cache 开/关逐字节一致」这条判据打红。这与今天早些时候那条「诊断里让 shell 报错顶替读数」同族。
2. `✗ 38-a panel-choices.sh 有失败`、3. `✗ 57 delivery-truth 有失败`：这两条在**宿主单跑与容器单跑都绿**
   （57 今天两次单跑各 ✓1 ✗0），只在整套里红。
4. **关键回复面板第 5 页在容器里挂住**：看门狗连续报「已运行 120s / 180s / 240s 没有进度」，平时几十秒。

## 要做的

**第一件（必修，产品代码）**：`team_orphan_read_environ` 不许再让内核的报错上到输出流。做法：显式捕获打开/读取失败
（重定向到自己的判定，不是把声音关掉——失败要返回「身份未知」这个具名结果），并保证三件事：① 读不到时 stdout/stderr
**一个字节都不多**；② 返回值仍是非 0（调用方照旧跳过、不猜身份）；③ 读得到时行为逐字节不变。

**第二、三件（归因，不猜）**：用**同一条命令在宿主与容器各跑一次**（单段）取证，判定它们属于
「整套并发/环境」还是「真竞态」。给判定与依据；若判为真竞态，写清触发条件与最小修法，**先报 PM 再动手**。

**第四件（归因）**：`… --select <63 的段键>` 在容器里跑一次，看是否复现挂住；若是，定位它卡在哪个等待上
（真终端？私有 server？），给出读数与判断。**不要**为了提高上界而改超时——那只是把挂住变成更晚的挂住。

## 必须交的证据

1. 修 `team_orphan_read_environ` 的**双向**证据：容器里同一场景改前有 shell 报错、改后 0 字节；宿主上正常读得到时输出逐字节不变。
2. 红侧：让某个 pid 的 environ 不可读（容器里自然就有）→ `M50-②c` 从红转绿，且「读不到 → 跳过、不点名」那条断言仍绿。
3. 第二/三/四件的宿主 vs 容器对照读数（各贴命令与尾部）。
4. `--select 13,25,26,27,38,63`（按你判定的范围）一次；`bash -n`、`--loop-check`、`section-select.sh --check`、
   `openspec validate --all --strict`、账本禁令、`git diff --check`。

## 边界

- 写集：`skills/teamsmith/scripts/lib/common.sh`（只那一处读 environ）、必要时 `tests/smoke.sh` 的对应断言、
  `docs/team/reports/P366-dev3.md`。改断言要先报 PM。
- **不提高任何超时/上界**；不新增门禁段；不动面板代码（那是第四件的归因对象，不是修法对象）。
- 不跑整套；容器只跑点名的那几段。
