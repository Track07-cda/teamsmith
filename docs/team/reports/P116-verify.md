# P116 · `model-id-shape` 独立验证（换人重验）· verify

```
task:   P116
agent:  verify
status: **PASS（我自己的验证包 183 ok / 0 bad / 0 finding，两次独立运行都一样；本地门禁：openspec 16/0 · routes 171/0 · config-cli 311/0 · smoke FAST 3016/0 · 全量 3681/0（我的基点树）与 3701/0（当前 main 整棵树））**
time:   2026-09-28T19:00–21:20Z（本会话）
phase:  verify
change: model-id-shape（propose=P102 dev · apply=P114 dev —— 都不是本席位做的，换人成立）
anchor: change（delta 本体：`openspec/changes/model-id-shape/specs/memory-and-deps/spec.md`）
deltas: `-`（verify 只写报告与证据；实现与 delta 一字未动）
grant:  docs/team/reports/P116-verify.md · docs/team/reports/P116-verify/**（未越界：相对 main 只多了这两处；
  `git diff --stat refs/heads/main HEAD -- skills/teamsmith/scripts/` 为空，唯一差异是 main 后合的 `tests/smoke.sh`）
branch: `task/P116-id`（local 模式：**不 push**；小提交留在本地，等 PM 复验/合并）
验证对象: **main 上已合并的实现** —— 基点 `50dff11c`（P116 任务书提交本身就在 main 上；P114 的 apply
  `fe668226` 是它的父提交）。验证期间 main 从 `8f10c695` 前进到 `62090f65`（P115 的 smoke.sh 修复 `12d96a4d`
  + 几笔文档提交），但 **模型形状/窗口/渲染器的实现逐字节未变**（`git diff --stat refs/heads/main HEAD --
  skills/teamsmith/scripts/` 为空）；唯一与 main 不同的 skills 文件是 `tests/smoke.sh`（测试基建，不属于本 change）。
  因此我把**整包（含全量门禁）在当前 main 的整棵树上再跑了一遍**：`git clone --local --branch main` 到
  `.tmp/p116-main-clone`（本 worktree 内的临时克隆，交付前删除；源仓库零改动），`P116_TREE` 指向它 ——
  两次运行的 7 个分节都是 183 ok / 0 bad。
证据包: `docs/team/reports/P116-verify/pkg/` = `lib.sh` + `run.sh` + `10/20/30/40/50/60/70` 七个分节 + `logs/`
  （每格原始输出；`run.sh` 末行是机器可读汇总）。两次全绿运行：`logs/run-20260928-194912-3816025/`（基点树，含全量）与
  `logs/run-20260928-203424-2997390/`（当前 main 的克隆树，含全量）+ FAST 门禁运行 `logs/run-20260928-193150-257727/`。
```

**总结论**：brief 的 8 条硬要求全部由**本席位自造的夹具**证过，0 finding、0 bad：

| brief 要求 | 我的独立证据（自建 scratch 项目，不引用 P114 的断言） | 结果 |
|---|---|---|
| 1 三个 token × 三条写入路各自都要过，并贴三路输出 | §2：9 格（3 token × 3 路），每格 `--dry-run` 可见 `ok:` 行 + 真写 rc=0 + 契约逐字 + 每格 `config list --json` 回读；另加 `add-agent --model` 奖金路线 | **55 ok / 0 bad** |
| 2 五类畸形非零，逐条核对措辞点名哪一段 | §3：15 格主矩阵（5 类 × 3 路）+ 5 格红队值 + `add-agent` 奖金格；契约 sha256 与审计 `result=ok` 前后不变 | **33 ok / 0 bad** |
| 3 「一处判定」要证明、不许引用 | §4 四层：同值同句（三路原因**逐字相同**）· 唯一入口静态证据（1 个定义、旧措辞 0 处）· trace 影子（三路都真的调用）· 强制拒绝影子（合法 token 三路全被拒）· 真树 `bash -x` 调用栈 | **33 ok / 0 bad** |
| 4 窗口 300000 + 最后一个 `/` 的红侧 | §5：三段 id 目录解析 131k、`TEAM_MODEL_WINDOWS` 300k；最后一个 `/` 影子 → 目录解析变 `?`（红），显式覆盖与两段 id 不受影响 | **10 ok / 0 bad** |
| 5 放宽成「有 `/` 就过」→ `a//b` 必须被接受 | §6：影子里三路 `a//b` rc=0 且**真的落盘**，§3 的拒绝谓词红；还原 → 重新拒绝 | **14 ok / 0 bad** |
| 6 真实值零回归 | §7：brief 点名的两个在用值三路可用 + 逐字回读；worker/PM/`{model}` 三个渲染器按第一个 `/` 切（最后一个 `/` 影子 → 红） | **26 ok / 0 bad** |
| 7 零回归门禁 | §8：`openspec validate --all --strict` 16/0 · `routes.sh` 171/0 · `config-cli.sh` 311/0（含 shape + flip-shape）· FAST 3016/0 · **全量 3681/0（基点树）与 3701/0（当前 main）均 `smoke 全绿`** | 全绿 |
| 8 报告写清 own vs cited + 红/绿原始输出 | §9 + 全文原始输出块 | ✓ |

包内合计：**183 ok · 0 bad · 0 finding · 0 skip**（10:55 · 20:33 · 30:33 · 40:10 · 50:14 · 60:26 · 70:12）。

---

## 0 · 对象同一性（验的到底是哪棵树）

```
$ git branch --show-current
task/P116-id
$ git merge-base HEAD refs/heads/main
50dff11c            # 我的分支基点 = P116 任务书提交（它在 main 上；P114 的 apply fe668226 是它的父提交）
$ git diff --stat refs/heads/main HEAD -- skills/teamsmith/scripts/
（空）              # 0 个文件 —— 模型形状/窗口/渲染器的实现与当前 main **逐字节相同**
$ git diff --stat refs/heads/main HEAD -- skills/
 skills/teamsmith/tests/smoke.sh | 8 +-, 127 -      # 只有它：main 后来合入的 P115 测试基建修复（12d96a4d），不属于本 change
$ git rev-parse --short refs/heads/main
62090f65            # 验证结束时的 main（克隆树的 HEAD 也是它）
```

两次 main 位置：证据开始时 `8f10c695`（相比基点只多一笔文档提交），结束时 `62090f65`（多出 P115 的 smoke.sh
修复与几笔文档提交）。**实现一直没动**（上面第一道 diff 为空），所以我既在基点树上跑完了整包（§2–§7 引用的原始输出），
又在当前 main 的**整棵克隆树**上把整包（含全量门禁）重跑了一遍（§8）—— 两次 7 个分节都是 183 ok / 0 bad。
克隆树是 `git clone --local --branch main` 到 `.tmp/p116-main-clone`（交付前删除；源仓库零改动）。

## 1 · 我的夹具（自建；期望值自定，不引用 P114 的断言）

- 每格一个**全新 scratch 项目**：`$TMPDIR/p116pkg.XXXX` 下 fresh `git init -b main` + `team init --agents 'dev verify'
  --vcs local --gates true`；绝不读写本仓库的真配置/真名册（本仓库 `skills/**` 在验证全程零改动）。
- 身份隔离：`lib.sh` 在加载时把**环境里实际存在的** `TEAM_*` 与 `TMUX`/`TMUX_PANE` 全部 `env -u` 掉；
  tmux 走 PATH 第一位的**私有 `-L p116pkg-<pid>` server 包装**，`TMUX_TMPDIR` 指向已 `mkdir -p` 的私有目录
  （memory #1250 的两个回退形态都堵住）；`TEAM_PI_AGENT_DIR` 指向夹具自己的 `models.json`，不读真实 `~/.pi/agent`。
- 影子树：`p116_shadow_tree` 只把 `scripts/templates/references` 拷进 scratch（真树不动），再按用例做**一处**变异
  （放宽判定 / 最后一个 `/` 切窗口 / 最后一个 `/` 切渲染器 / 强制拒绝 / trace 包装）；每个红侧都在**同一段里**给出
  还原后的绿。
- 断言词汇：`ok`/`bad`/`finding`/`skip`；每段 `== <id> 结果 ==` 收尾，`run.sh` 聚合，只有 `bad` 或脚本崩溃非零。

## 2 · 接受侧（brief 第 1 条）：9 格主矩阵 + 1 格奖金

三个 token × 三条写入路，每格：`--dry-run`（可见 `ok:` 行）→ 真写 rc=0 → 契约行逐字 → 该格读面回读。

```
$ team config set TEAM_DEFAULT_MODEL openrouter/amazon/nova-lite-v1 --yes --dry-run
ok: TEAM_DEFAULT_MODEL=openrouter/amazon/nova-lite-v1（dry-run，未写契约、未写审计）          # rc=0
$ team config set TEAM_AGENT_MODELS dev=openrouter/amazon/nova-lite-v1 --yes --dry-run
ok: TEAM_AGENT_MODELS=dev=openrouter/amazon/nova-lite-v1（dry-run，未写契约、未写审计）        # rc=0
$ team config set-agent-model dev openrouter/amazon/nova-lite-v1 --yes --dry-run
ok: TEAM_AGENT_MODELS=dev=openrouter/amazon/nova-lite-v1（dry-run，未写契约、未写审计）        # rc=0
（opencode-go/deepseek/deepseek-v4.1-flash 与 kimi-coding/kimi-for-coding:high 三路同形，原始输出见
 logs/run-20260928-194912-3816025/section-10.log）
```

| token | `config set TEAM_DEFAULT_MODEL` | `config set TEAM_AGENT_MODELS` | `config set-agent-model` |
|---|---|---|---|
| `openrouter/amazon/nova-lite-v1` | rc=0 · 行逐字 · 读面 default 逐字 | rc=0 · `dev=…` 逐字 · 读面席位逐字 | rc=0 · 行逐字 · 席位 `override=true` |
| `opencode-go/deepseek/deepseek-v4.1-flash` | 同上 | 同上 | 同上 |
| `kimi-coding/kimi-for-coding:high` | rc=0 · 行逐字保留 `:high` · 审计 `new='…:high'` | rc=0 · 逐字 | rc=0 · 逐字 |

奖金路线（brief 只要求三路，这条加严）：`add-agent api --register --model openrouter/amazon/nova-lite-v1 --no-install`
→ rc=0 且 `api=openrouter/amazon/nova-lite-v1` 落盘。终态读面：

```
known-has-token=True
default=kimi-coding/kimi-for-coding:high
dev=kimi-coding/kimi-for-coding:high   dev-override=True
```

## 3 · 拒绝侧（brief 第 2 条）：5 类 × 3 路，逐条核对点名段落

主矩阵 15 格全部 rc=4，且措辞**点名被拒的那一段**（不是笼统"不合法"）。原始输出（`section-20.log`）：

```
✗ TEAM_DEFAULT_MODEL=a       不合法：provider 缺失：需要 provider/model 形状（没有 /）
✗ TEAM_AGENT_MODELS=dev=a    不合法：席位 dev 的模型：provider 缺失：需要 provider/model 形状（没有 /）
✗ 模型必须是 provider/model 形状（provider 缺失：需要 provider/model 形状（没有 /））：a
✗ TEAM_DEFAULT_MODEL=/a      不合法：provider 为空（/ 前没有内容）
✗ TEAM_AGENT_MODELS=dev=/a   不合法：席位 dev 的模型：provider 为空（/ 前没有内容）
✗ 模型必须是 provider/model 形状（provider 为空（/ 前没有内容））：/a
✗ TEAM_DEFAULT_MODEL=a/      不合法：model 为空（/ 后没有内容，或 :思考档 后缀前为空）
✗ TEAM_AGENT_MODELS=dev=a/   不合法：席位 dev 的模型：model 为空（/ 后没有内容，或 :思考档 后缀前为空）
✗ 模型必须是 provider/model 形状（model 为空（/ 后没有内容，或 :思考档 后缀前为空））：a/
✗ TEAM_DEFAULT_MODEL=a//b    不合法：model 有空段（/ 分隔的每一段都必须非空）
✗ TEAM_AGENT_MODELS=dev=a//b 不合法：席位 dev 的模型：model 有空段（/ 分隔的每一段都必须非空）
✗ 模型必须是 provider/model 形状（model 有空段（/ 分隔的每一段都必须非空））：a//b
✗ TEAM_DEFAULT_MODEL=a b/c   不合法：provider 含空白（空格/制表符/换行）
✗ TEAM_AGENT_MODELS=dev=a b/c 不合法：席位 dev 的模型：provider 缺失：需要 provider/model 形状（没有 /）
✗ 模型必须是 provider/model 形状（provider 含空白（空格/制表符/换行））：a b/c
```

| 形状 | 三路 rc | 措辞点名 | 契约 sha256 | 审计 `result=ok` |
|---|---|---|---|---|
| `a`（无 `/`） | 4/4/4 | provider 缺失 | 不变 | 不增 |
| `/a`（前导 `/`） | 4/4/4 | provider 为空 | 不变 | 不增 |
| `a/`（尾随 `/`） | 4/4/4 | model 为空 | 不变 | 不增 |
| `a//b`（空段） | 4/4/4 | model 有空段 | 不变 | 不增 |
| `a b/c`（空白） | 4/4/4 | provider 含空白（pairlist 那格按空格分词先命中 `dev=a` → provider 缺失，同样点名段落、非静默放行） | 不变 | 不增 |

奖金格：`add-agent --model 'a//b'` → rc=4 且 `模型必须是 provider/model 形状（model 有空段…）`。
红队值（brief 之外）：`a/:high` → model 为空 · `a:q/b` → provider 不能含 `:` · `a/b␠` → model 含空白 ·
`a⇥b/c` → provider 含空白 · `a␊b/c` → model-kind 路先被**值层**「值不能含换行（契约是单行 KEY=value）」拦下，
席位路给出 provider 含空白（两条都是 rc=4 的明确拒绝，如实记录）。
**零写入**：整个矩阵前后契约 sha256 相同、`result=ok` 行数不变、`result=invalid` 行数增加（拒绝被审计）。

## 4 · 「一处判定」（brief 第 3 条）：证明，不引用

**A · 同一畸形值 → 三条路得到逐字相同的原因**（三路各自剥掉自己的前缀后比对）：

```
model-kind       : model 有空段（/ 分隔的每一段都必须非空）
pairlist         : model 有空段（/ 分隔的每一段都必须非空）      # 与上一行逐字相同
set-agent-model  : model 有空段（/ 分隔的每一段都必须非空）      # 与上一行逐字相同
```

**B · 唯一入口（静态）**：`grep -n 'team_config_model_violation\|team_config_model_shape_ok'` 的原始输出：

```
cmd-config.sh:374:      if mwhy="$(team_config_model_violation "$val")"; then return 0; fi          # model kind
cmd-config.sh:387:        if ! mwhy="$(team_config_model_violation "$model")"; then               # pairlist token
cmd-config.sh:456:team_config_model_violation() { # <model> → 0 合法；1 时 stdout 是原因          # 唯一判定
cmd-config.sh:477:team_config_model_shape_ok() { # <model> → 0 合法 / 1 不合法                      # 布尔包装
cmd-config.sh:478:  team_config_model_violation "${1-}" >/dev/null 2>&1                            # （自身不判形状）
cmd-config.sh:1094:  if [ "$model" != "-" ] && ! team_config_model_shape_ok "$model"; then          # set-agent-model
cmd-config.sh:1095:    team_err "模型必须是 provider/model 形状（$(team_config_model_violation "$model")）：$model"
cmd-agents.sh:209:  if [ "$has_model" = "1" ] && [ "$model" != "-" ] && ! team_config_model_shape_ok "$model"; then
cmd-agents.sh:210:    team_err "add-agent --model：模型必须是 provider/model 形状（$(team_config_model_violation "$model")）：$model"
```

全 lib 只有 **1 个** `team_config_model_violation` 定义（`cmd-config.sh:456`，`grep -l '^team_config_model_violation()'` 命中 1 个文件）；
旧措辞「恰好一个」在 `scripts/`+`references/`+`templates/` 里 0 处（skill 里 19 处「恰好一个」都是无关的 UI/测试短语，
`恰好一个 /` 这一串 0 处）。

**C · trace 影子（三路都真的调用）**：在 scratch 树给唯一判定套一层打印包装 → 一个**合法** token 在三条路上
都打出 `P116TRACE call=openrouter/amazon/nova-lite-v1` 且 rc=0（合法路径也经过它，不是只拦坏值）。

**D · 强制拒绝影子（裁决真的从这一处流过）**：把唯一判定改成永远拒绝 → 同一个**合法** token 在三条路上全被拒，
且拒绝理由逐字来自影子：

```
✗ TEAM_DEFAULT_MODEL=openrouter/amazon/nova-lite-v1 不合法：P116 forced refusal: verdict flows through the single predicate
✗ TEAM_AGENT_MODELS=dev=openrouter/amazon/nova-lite-v1 不合法：席位 dev 的模型：P116 forced refusal: verdict flows through the single predicate
✗ 模型必须是 provider/model 形状（P116 forced refusal: verdict flows through the single predicate）：openrouter/amazon/nova-lite-v1
```

对照：同一 token 在真树上被接受（rc=0）。**若哪条路自带副本，它在 D 里仍会放行** —— 三条全被拒，副本不存在。

**E · 真树 `bash -x`**：不改任何代码，拒绝路径的调用栈里出现 `+ team_config_model_violation a//b`（三路各一条）。

## 5 · 窗口与切分（brief 第 4 条）

夹具：`TEAM_DEFAULT_MODEL=openrouter/amazon/nova-lite-v1` + 夹具自己的 `models.json`
（`provider=openrouter`、`model.id=amazon/nova-lite-v1`、`contextWindow=131072`）+ `TEAM_PI_AGENT_DIR` 指向它。

```
$ team ps                     # 真树，无覆盖
MODEL                           RUNNING    LIMIT    WINDOW
-----                           -------    ----- ---------
openrouter/amazon/nova-lite-v1        0        -      131k
$ TEAM_MODEL_WINDOWS='openrouter/amazon/nova-lite-v1=300000' team ps
… openrouter/amazon/nova-lite-v1      …       …       300k
```

| 用例 | 真树 | 影子（切分改成最后一个 `/`） |
|---|---|---|
| 三段 id · Pi 目录（131072） | **131k** | **`?`**（红：目录解析失效） |
| 三段 id · `TEAM_MODEL_WINDOWS=…=300000` | **300k** | 300k（显式覆盖不走切分 —— 变形精确，不是把整条路打红） |
| 两段 id · Pi 目录（262144） | 262k | 262k（最后一个 `/` 对两段 id 无影响 —— 同刀口验证） |

还原后真树仍 131k。`git diff --stat main HEAD -- skills/` 全程为空。

## 6 · 拒绝集的红侧（brief 第 5 条）

scratch 影子把唯一判定放宽成「含 `/` 就过」（`cmd-config.sh:458` 插入 `case "$val" in */*) return 0 ;; esac`）：

```
影子[default] TEAM_DEFAULT_MODEL=a//b  → rc=0（输出为空 = 接受）
影子[pairlist] TEAM_AGENT_MODELS=dev=a//b → rc=0
影子[seat]   set-agent-model dev a//b   → rc=0
契约：TEAM_DEFAULT_MODEL='a//b' 与 dev=a//b 都真的落盘        # 不是假接受
§3 的拒绝谓词（rc=4 + 点名「model 有空段」）在这三条输出上 → 红（同一把尺，逐条打印）
还原（真树）：三条路重新 rc=4 且点名「model 有空段」
```

## 7 · 真实值零回归 + 渲染器（brief 第 6 条）

brief 点名的两个在用值，在三条写入路上各跑一遍（rc=0 + 契约逐字）后，读面：

```
$ team config list --json → models.known
opencode-go/deepseek/deepseek-v4.1-flash,kimi-coding/kimi-for-coding:high
```

三个渲染器（真树）：

```
worker（team_pi_args）：--provider opencode-go --model deepseek/deepseek-v4.1-flash
PM（team up --print） ：--provider kimi-coding  --model kimi-for-coding:high
{model} 占位符        ：deepseek/deepseek-v4.1-flash
```

影子（把 worker/PM/`{model}` 三处切分改成最后一个 `/`）：`worker=[--provider opencode-go --model deepseek-v4.1-flash]`
`model=[deepseek-v4.1-flash]`（两段 id 的 PM 渲染器不变 —— 退化只针对多段），即上面三条绿断言在影子里会红。
奖金：Ollama 风格 `ollama/hf.co/user/repo:Q4_K_M` 被接受且逐字落盘（后缀只剥一次，不是把 `:` 全当分隔）。

## 8 · 零回归门禁（brief 第 7 条）——**我本人在本树跑的，并在当前 main 的克隆树上重跑**

| 门禁 | 命令（原始日志） | 结果 |
|---|---|---|
| 规格库 | `PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict`（`logs/run-20260928-194912-3816025/gates/10-openspec.log`） | rc=0；**Totals: 16 passed, 0 failed (16 items)** |
| 路由诚实性 | `bash skills/teamsmith/tests/routes.sh`（同目录 `20-routes.log`） | rc=0；**✓ 171 ✗ 0 SKIP 0**（含 8 条翻转全绿） |
| 配置 CLI（shape 所在） | `bash skills/teamsmith/tests/config-cli.sh`（同目录 `30-config-cli.log`） | rc=0；**✓ 311 ✗ 0 SKIP 0**；`shape` 段与 `flip-shape` 段都确实跑了 |
| FAST | `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null`（`logs/run-20260928-193150-257727/gates/40-smoke-fast.log`） | rc=0；**✓ 3016 ✗ 0**；`smoke 全绿`；33 个真进程段落**可见 SKIP**（跳过清单在日志里） |
| **全量 smoke（决定性）** | `TEAM_SMOKE_FAST` 未设（`logs/run-20260928-194912-3816025/gates/40-smoke-full.log`） | rc=0；**✓ 3681 ✗ 0**；`smoke 全绿`；无 FAST 跳过清单；先排队（19:43:58 记下持锁者 dev3 的全量门禁 pid=2734814，20:08:35 拿锁）再跑完（19:52:56 → 20:32:04，含 ~15.5 min 排队） |

全量那一次的原始收尾行（去 ANSI）：

```
账本自查： 112 段收口 · 增量 ✓3681 ✗0 SKIP0 ｜ 结果行 ✓3681 ✗0 —— 一致
== 结果 ==  ✓ 3681  ✗ 0
smoke 全绿
```

**一次可复现的全绿运行**：`logs/run-20260928-194912-3816025/` 里 7 个分节全在同一运行目录（`== P116 结果 ==
sections=7 ok=183 bad=0 finding=0 skip=0 script_bad=0`），四道门禁日志在它的 `gates/` 下。

**同一包在当前 main（`62090f65`）的整棵克隆树上再跑一遍**（`P116_TREE=.tmp/p116-main-clone`，`logs/run-20260928-203424-2997390/`）：

| 门禁 | 结果（main 整棵树） |
|---|---|
| `openspec validate --all --strict` | rc=0；**Totals: 16 passed, 0 failed (16 items)** |
| `routes.sh` | rc=0；**✓ 171 ✗ 0 SKIP 0** |
| `config-cli.sh` | rc=0；**✓ 311 ✗ 0 SKIP 0**（shape + flip-shape 都在） |
| **全量 smoke** | rc=0；**✓ 3701 ✗ 0**；`smoke 全绿`；无 FAST 跳过（main 的 smoke.sh 比基点树多 20 条断言：3681 → 3701） |
| 包内 7 分节 | **183 ok / 0 bad / 0 finding / 0 skip**（与基点树逐节相同） |

门禁的每一条断言里，与 P116 相关的有 dev 自己写的 `config-cli.sh shape`/`flip-shape` 段（F-S1/F-S2）与 `routes.sh` 的三条
模型 promise（下面三条，均在我这次门禁里绿）—— 我**运行**它们（它们是门禁的一部分，也是零回归证据），但把
「抓形状/抓一处判定」的判定归到我自己的 §2–§7，见 §9。

```
✓ promise（TEAM_DEFAULT_MODEL）：dispatch --print 渲染出的启动命令带着 --provider vendor --model dm9
✓ promise（TEAM_AGENT_MODELS）：席位行写入、审计，读侧的 dev 席位带着 vendor/m9 与 override:true
✓ promise（TEAM_PM_MODEL）：team up --print 渲染出的命令带着 --provider vendor --model pm9
```

## 9 · 哪些是我的证据、哪些只是引用

**我自己的（可复核）**：`pkg/` 的全部夹具、断言、期望值与 `logs/` 原始输出；§0 的对象同一性（包括 main 动了两次、
实现逐字节未变的 diff）；§2–§7 的每一格数字（9+1 接受格、15+6 拒绝格、四处判定证据、3 个窗口格、3 个影子格、3 个渲染器、红侧全部）；
§8 的四条门禁是我在本树亲手跑的（命令与 rc 都在日志里），而且在**当前 main 的整棵克隆树**上又跑了一遍（含全量 smoke）。
临时克隆 `.tmp/p116-main-clone` 已在交付前删除，源仓库未被动过。

**引用（只作上下文，不参与判定）**：
- `docs/team/reviews/model-id-shape-proposal.md`（PM 的提案评审 ACCEPTED）与 `docs/team/reports/P114-dev.md`（apply 报告）——
  我只用它们知道**要验什么**；它们的前后值、断言、结论都没有被当作我的证据（我重跑/重造才算数）。
- 交付树里 `tests/config-cli.sh` 的 `shape`/`flip-shape` 段是 dev 写的：我运行它（门禁的一部分），
  但它不是我的判定依据；抓「一处判定/点名段落」的是本包的 §2–§7。
- `openspec validate` 的 delta 文本（`openspec/changes/model-id-shape/specs/memory-and-deps/spec.md`）是我对照
  brief 的规格来源，不是证据。

## 10 · 观察（不计 finding）

1. `config set TEAM_DEFAULT_MODEL $'a\nb/c'`（含换行的值）先在**值层**被「契约是单行 KEY=value」拦下（rc=4），
   措辞点名换行本身；席位路给出形状层的「provider 含空白」。两条都是明确拒绝，但同一类输入在不同路上措辞不同 ——
   与「一处判定」不冲突（形状判定仍是一处，值层守卫是另一层），如实记录。
2. `TEAM_AGENT_MODELS='dev=a b/c'` 按空格分词后先命中 `dev=a`，报「provider 缺失」而不是「provider 含空白」——
   点名了段落、非静默放行，但不是最贴切的那条措辞（brief 只要求点名段落，满足）。
3. 三段 id 在 `TEAM_MODEL_WINDOWS` 里命中是**后缀匹配**（`*/openrouter/amazon/nova-lite-v1` 之类）与完整 key
   两条路都试；显式覆盖优先于目录解析（300k 胜过 131k），与 proposal 一致。
4. 验证期间 main 前进了 1 格（纯文档）；已按 §0 记录，skills 逐字节未变。

## 11 · 复现

```bash
cd <home>/Documents/syncthing/Work/Projects/pm-skills/.worktrees/verify
bash docs/team/reports/P116-verify/pkg/run.sh                      # 全跑：183 ok / 0 bad / 0 finding
P116_GATES_FULL=1 bash docs/team/reports/P116-verify/pkg/run.sh 70 # 门禁含全量 smoke
# 换树复验（如当前 main 的克隆）：
#   git clone --local --branch main <repo> .tmp/p116-main-clone
#   P116_TREE=$PWD/.tmp/p116-main-clone P116_GATES_FULL=1 bash docs/team/reports/P116-verify/pkg/run.sh
# 逐段：run.sh 10 | 20 | 30 | 40 | 50 | 60 | 70 ；P116_KEEP=1 保留夹具目录
```
