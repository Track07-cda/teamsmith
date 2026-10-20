# P327 · 写信面夹具接进 §38：一个执行点，且不进地板

agent: dev   status: delivered   time: 2026-10-20T19:20Z
branch: `task/P327-panel-b2-wired`   phase: apply   change: `-`
specs: `verification#The gate judges behaviour only, and never reports a skip as a pass`
写集：`skills/teamsmith/tests/smoke.sh`（选段块 + §38 正文的一条腿）、`skills/teamsmith/tests/section-paths.tsv`（§38 那一行的 patterns）+ 本报告
提交：`e63282cb` + 本报告（`panel-b2.sh` **一个字节没改**）
（任务书头部写的是 `agent: dev3` / `P327-dev3.md`，本次派单给的是 dev 席位并要求 `P327-dev.md`、`Agent: dev` 尾注；按派单走，报告文件名与本席位一致。）

## 结论先写

1. `tests/panel-b2.sh` 现在由 **§38** 的一条腿执行（`38-h`）：成功 → 一条 `ok` 带它的结果行，失败 → `bad`
   并打印它的尾部。**没有新增段、检查器、夹具或等待库**，`section-paths.tsv` 只在 §38 那一行的 patterns
   里加了 `panel-b2.sh`（`--check`：135 行 / 135 段不变）。
2. 它不是无条件跟 §38 跑：**单次全场景 431 s**（本机实测），所以选段块现在导出「本轮直接点到」的键，
   `38-h` 只在「完整门禁 / `--select 38` / 改动路径点到它（含 `--floor --paths`）」时跑；`--floor` 单跑
   只给一条具名 `SKIP（条件不满足）`。实测地板上 §38 的用时：跳过它 **332 s**，跑它 767 s。
3. **第一版接线是错的，是地板实测抓回来的**（`reason` 是逗号分隔列表，我按整串匹配，于是 `floor, needs:63`
   被当成「直接点到」，7 分钟夹具真的进了地板：§38 从 332 s 涨到 767 s）。修法是逐条判原因，见 §5。
4. 反例成立：私有副本里把 `2.2` 那条关键断言（Esc 后草稿保留）的期望值改坏，同一次 `--select 38`
   **rc=1** 并点名那一条（§3.3）。
5. 断言与场景一条不少：`panel-b2.sh` 与 main 逐字节相同（blob `4136a2c7`，见 §3.5），11 场景、167 条
   `✓`（`✓167 ✗0`，与 P336 记录的一致）。

## 1 · 为什么是 §38，不是 §26

读了映射表与段正文后选的 §38，证据是三条：

- **§38 已经在跑同一族的 pty 夹具**：`38-b` 跑 `panel-p21.sh choices`、`38-f` 跑 `panel-p21.sh
  groups settings wheel`，而 `panel-p21.sh` 里的 `readonly` 场景正是 P318 从 `panel-b2.sh` 搬过去的 ——
  写信面的邻居就住在这里。它还有现成的慢段处理（`fast_skip`）与判定器（`p38_verdict`：0 绿 / 1 有失败 /
  3 搭建失败 / 其它意外码），接线直接复用它，不必新写一条腿的形状。
- **§26 会把 431 s 挂到几乎每次推送**：§26 的 patterns 里有 `skills/teamsmith/scripts/*`（选段用的是
  shell `case` 的 glob，`*` 跨 `/`，所以 `scripts/lib/common.sh` 也算命中 —— `section-select --paths
  skills/teamsmith/scripts/lib/common.sh` 的输出里就有 `reason=26`）。把慢夹具放进去，等于让「改一行
  `scripts/lib/*.sh`」就跑 7 分钟 —— 比它现在要避开的「地板后门」更糟。§38 则只被它自己那几行 token
  拉进来（写信面源码 `scripts/panel/src/*`、它的两个 pty 夹具、`scripts/lib/cmd-config.sh`、
  `tests/panel-strings.mjs`）；`--paths skills/teamsmith/scripts/team` 的输出里 §26 在、§38 不在，可以对照。
- §27（面板异步数据层）、§28（渲染/i18n 快照）都不执行 pty 面板夹具，形状不贴。

## 2 · 接线的形状（净零）

- `smoke.sh` §38 末尾加一条腿 `38-h`：`P327_SUITE`（默认 `tests/panel-b2.sh`，仅为红侧留的旋钮）→
  `bash "$P327_SUITE" --all` → 交给既有的 `p38_verdict`。失败时它打印前 8 条 `✗` 与日志尾两行。
- `smoke.sh` 选段块（`--paths/--select/--floor` 解析完之后）导出 `SELECT_DIRECT_KEYS`：把
  `reason=<key> ← <原因列表>` 逐条拆开，凡有**一条**原因不是 `floor` / `prologue` / `needs:…` /
  `coupled:…`，这个 key 就算「本轮直接点到」。
- `section-paths.tsv` 的第 136 行（§38）patterns 里补 `skills/teamsmith/tests/panel-b2.sh`，basis 里加
  一句「38-h 腿跑写信面夹具」。**不新增行**。
- 净零的账：这条接线替掉的是「这个夹具从不执行」。`panel-b2.sh` 原来被两行以**扫树**的方式声明
  （`12b-h0d` 的 `skills/teamsmith/tests/*`、`40` 的 `skills/teamsmith/tests *`），那两行仍然只是「lint
  会扫到它」，不是执行点；本任务没有删它们，也没有新增检查器。

## 3 · 证据

### 3.1 改动路径会选中它

```
$ bash skills/teamsmith/tests/section-select.sh --paths skills/teamsmith/tests/panel-b2.sh | grep '^reason='
reason=38 ← skills/teamsmith/tests/panel-b2.sh
```

同一份解析（与 smoke.sh 选段块逐字相同的循环）对五种选段形状的判定，用一个临时探针脚本复算：

```
  --floor                                                    间接(38 跳过)
  --floor --paths skills/teamsmith/tests/panel-b2.sh         direct(38 会跑)
  --floor --paths skills/teamsmith/tests/panel-b21.sh        间接(38 跳过)      # 对照：不相关路径不动它
  --paths skills/teamsmith/tests/panel-b2.sh                 direct(38 会跑)
  --paths skills/teamsmith/scripts/panel/src/compose.ts      direct(38 会跑)    # 写信面源码
  --select 38                                                direct(38 会跑)
  --select 12b-h0d                                           间接(38 跳过)
```

### 3.2 `--select 38`：腿真的跑了，读数真实

```
$ bash skills/teamsmith/tests/smoke.sh --select 38          # rc=0 · 953 s
  ✓ 38-h panel-b2.sh 写信面（11 场景） 全绿（ ✓ 167 ✗ 0）
      panel-b2 全绿
== 选段结果 ==  ✓ 432  ✗ 0
#10 38 · 设置选项（M55：choices 读 / 一致性走查 / 选择器夹具） · 参考 用时 773s · ✓16 ✗0 SKIP0 · ticks 16
```

### 3.3 反例：改坏一条关键断言，同一次选段必须红

私有副本：`git archive`-同级的**完整拷贝**（`cp -a skills` 到本任务的私有目录）里只改一处 —— `2.2 Esc 后
state/draft.md 保留草稿` 的期望值改成 `half a thought (RED-SIDE)`：

```
$ P327_SUITE=<私有副本>/skills/teamsmith/tests/panel-b2.sh bash skills/teamsmith/tests/smoke.sh --select 38
                                                            # rc=1 · 937 s
  ✗ 38-h panel-b2.sh 写信面（11 场景） 有失败
        ✗ 2.2 Esc 后 state/draft.md 保留草稿（期望 [half a thought (RED-SIDE)]，实际 [half a thought]）
== 选段结果 ==  ✓ 431  ✗ 1
#10 38 · 设置选项（M55：choices 读 / 一致性走查 / 选择器夹具） · 参考 用时 758s · ✓15 ✗1 SKIP0 · ticks 16
```

（红侧那一行是 `38-h` 的 `bad` + `p38_verdict` 打印的 `✗` 尾部；工作树里那份 `panel-b2.sh` 未被改动，
`grep -c RED-SIDE` 仍是 0。）私有副本单独跑过同一场景，确认是那条断言自己在咬：
`bash panel-b2.sh draft` → `rc=1`，`✗ 2.2 …（期望 [half a thought (RED-SIDE)]，实际 [half a thought]）`，
`== 结果 == ✓ 4 ✗ 1`。

### 3.4 耗时对照（参考值，不作判据）

| 运行 | 用时 | 读数 |
|---|---|---|
| `panel-b2.sh --all`（基线，接线前，树与 main 同 blob） | **431 s** | `✓167 ✗0` |
| `smoke.sh --select 38`（§38 全段，含该腿） | 953 s（§38 = 773 s） | `✓432 ✗0` |
| `smoke.sh --select 38`（红侧） | 937 s（§38 = 758 s） | `✓431 ✗1` |
| `smoke.sh --floor`（该腿**跳过**） | §38 = **332 s** | `✓15 ✗0 SKIP1` |
| `smoke.sh --floor`（第一版接线，该腿**跑了**） | §38 = **767 s** | `✓16 ✗0 SKIP0` |

V75 记录的 482 s / 483 s 是同一份夹具在它那台机器负载下的读数，本任务没有为「稳过」动任何上界或断言；
夹具内部等待引擎的参数（默认 knob 下一次等待的视界约 35 秒、上限约 500 轮）一字未改 —— 那是 P336 的成果。

### 3.5 场景与断言一条不少

`panel-b2.sh` 在两个树里是同一个 blob：`git rev-parse main:…panel-b2.sh` 与 `HEAD:…panel-b2.sh` 都是
`4136a2c7e4712cfe5d6cab45b3de3f016ea3d382`，`git diff --stat main -- skills/teamsmith/tests/panel-b2.sh`
输出为空 —— 因此「改前改后的场景名集合与断言行集合 diff」按构造是空 diff，不存在「为了接线动了断言」。

现树上的静态读数（同一条命令对 main 导出树与分支树输出一致）：

```
ALL="cursor keys multiline clipboard draft editor receipt settle pause paste actions"   # 11 个场景
断言/ok/bad 站点：181      wait_frame/wait_draft 调用：8      仍留的固定 sleep：5（P336 逐条写过理由）
```

全场景实跑 `✓167 ✗0`，与 P336 交付时记录的 `✓167 ✗0` 相同。

## 4 · 地板不跑它

```
$ bash skills/teamsmith/tests/smoke.sh --floor
  SKIP（条件不满足） 38-h·panel-b2-写信面 —— 本轮没有直接点到 38（地板 / needs 带进来的；单次全场景 431 s 不进地板，改写信面源码或本夹具时才跑）
#96 38 · 设置选项（M55：choices 读 / 一致性走查 / 选择器夹具） · 参考 用时 332s · ✓15 ✗0 SKIP1 · ticks 16
```

**选段清单没有变**：`section-select.sh --floor` 在本分支与 main 上的输出 `diff` 为空（128 个 key，
含 38 与不含 `38-h` —— 地板仍是段粒度的）。

底线与代价：这只地板运行是我按 **55 分钟预算**（`timeout 3300`）掐断的，**没有跑完**（停在
`#109 51`，`rc=124`），所以它不是「整套绿」的证据；它要证明的那件事（地板上这条腿跳过、代价只剩一行）
在 `#96` 就已经成立。

## 5 · 第一版接线错在哪（地板实测抓回来的）

第一版按**整串**匹配 `reason`：`case "$_sel_why" in floor|prologue|needs:*|coupled:*) continue`。但选段输出
的原因是**逗号分隔列表**：

```
$ bash skills/teamsmith/tests/section-select.sh --floor | grep '^reason=38'
reason=38 ← floor, needs:63
$ bash skills/teamsmith/tests/section-select.sh --floor --paths skills/teamsmith/tests/panel-b2.sh | grep '^reason=38'
reason=38 ← skills/teamsmith/tests/panel-b2.sh, floor, needs:63
```

`floor, needs:63` 既不是 `floor` 也不是 `needs:*`，于是第一版把它判成「直接点到」，7 分钟夹具进了地板。
修法是逐条拆开原因（`IFS=','` 分词，去除前导空格），只要有一条不在这四类里才算直接点到 —— 这样
`--floor --paths 写信面` 仍然算（路径排在最前），`--floor` 单跑不算。修法是同一个提交里的 `SELECT_DIRECT_KEYS`
那段；上一版的读数（§3.4 的 767 s 行）原样留在报告里当红侧。

## 6 · 轻量收口

```
$ bash -n skills/teamsmith/tests/smoke.sh                         # OK
$ bash skills/teamsmith/tests/section-select.sh --check           # == 选段自检 ==  ok 9  bad 0  SKIP 1
                                                                  # ok: 段 ↔ 行一一对应（源码 135 段 / 表 135 行）
$ openspec validate --all --strict                                # Totals: 21 passed, 0 failed
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
                                                                  # files=1937 hits=0 names=ok rc=0
$ git diff --check                                                # OK
```

`--check` 的那 1 条 SKIP 是预先存在的检出前提（`.pi/skills` 机器生成面），与本任务无关。

## 7 · 本轮没验到的

1. **CI（容器 / GitHub Actions）没跑**：接线让它在 workflow 里可达，但我没有推远端、也没有跑
   `workflow-entry`；本机门禁是我能给的证据面。
2. **完整地板没有跑完**（§4）：55 分钟预算后被我停掉，停在 `#109 51`。
3. 这两只地板运行里的红不是本任务造成的。为了不靠「我觉得无关」交差，我用 `git archive main` 导出一份
   **干净的主分支树**（`/var/tmp` 下的独立目录，不是主检出），只跑那几段做对照
   （`smoke.sh --select 25,30,41,51`，rc=1，`== 选段结果 == ✓ 239 ✗ 3`）：

   | 段 | 我这次地板运行 | 干净 main 导出树 |
   |---|---|---|
   | §25 `M9.8` 隔离 | ✗ 夹具痕迹在真实账本里 | ✓ `✓58 ✗0` |
   | §30 `M16` 隔离 | ✗ 同上 | ✓ `✓27 ✗0` |
   | §41 `P55 ④` roster 四态 | ✗ ×2 | ✗ ×2（`✓91 ✗2`） |
   | §51 `routes.sh` | ✗ rc=1 | ✗ rc=1（`✓2 ✗1`） |

   `P55 ④` 与 `51` 在**没有我这个改动的树上同样红**，是预先存在的；`M9.8`/`M16` 的红只在这只**带有真实
   运行痕迹的检出**里出现（它读真实账本的 `.pi/team/state/release-030/*.log`，那些痕迹来自别人的一次
   release 运行，导出树里那份账本是空的），与写集无关但值得点名 —— 在真实检出上跑地板会先撞到它。
   这四段都不读我改的两个文件。

4. 分支 fork 于 `2c70708f`；main 之后并入了 `757fe86a`/`3b302d09`（改 `smoke.sh` 的锁与记录寿命区域：
   640–730 / 1394 / 16861 / 16981 行），与本任务两处（238 行选段块、§38 末尾 18854 行）**不交叉**，
   但本报告的实测读数都出自 fork 点的树。

## 8 · 边界

- 只改了两个文件（外加本报告）。没碰产品实现、没碰 `panel-b2.sh`、没碰 `panel-p21.sh`、没新增夹具/等待库/
  门禁段/时限预算、没动任何上界或断言。
- 夹具照旧跑私有 tmux server（`-L p13b2-$$`）与私有夹具项目；我的每次运行都用私有 `TMPDIR` /
  `TMUX_TMPDIR`（在 `/var/tmp` 下，不在仓库内），所以**没有去抓机器级门禁锁**（任务书就是这么要求的），
  我的几次运行只在我自己那把私有锁上排队。代价是它们可能与别的席位的运行重叠 —— 那只会把上面的用时
  **推高**（431 s / 767 s 是这种情况下量到的），不会推低；夹具本身对并发不敏感（私有 tmux server + 私有
  夹具项目，端口/socket/临时根都不共享）。
- 那次基线运行用的是 `git archive main` 导出的独立树（`/var/tmp` 下，含 `git init` 的一次本地提交，
  因为门禁要在跑动前后对指纹），没有读写主检出。
