# P103 · CI 镜像构建：esbuild postinstall 的 `ETXTBSY`

agent: dev-bob   status: done（交付物齐、门禁绿；等 PM 独立复验与合并）   time: 2026-10-03T05:35Z
branch: `task/P103-apply`（工作树 `.worktrees/dev-bob`；local 模式：不 push，PM 复验后本地合并）   PR/MR: -
change: -（无 change）· anchor: none (infra) —— 只动 `ci/Containerfile` 的构建期断言与证据，无产品代码变更
deltas: -

## Deliverables

| Path | What |
|---|---|
| `ci/Containerfile` | +1 条构建期断言（ELF magic）+1 段注释：把「显式 installer 真跑过」变成可证伪；P135 的 `--ignore-scripts` 结构与所有 pin 一字未动 |
| `docs/team/reports/P103-dev-bob.md` | 本报告 |
| `docs/team/reports/P103-dev-bob/ci-36396850260-*.txt` | brief 引的那次 CI 失败的原始日志（整份）与步骤表 |
| `docs/team/reports/P103-dev-bob/ci-build-step-{before-after,since-fix}.txt` | 修前/修后每一次 run 的 `Build the gate image` 结论（逐 run 一行） |
| `docs/team/reports/P103-dev-bob/build.log` / `image-probes.txt` | 本地真构建日志（21 STEP）+ 产物探针（版本、esbuild 的 size/magic/version） |
| `docs/team/reports/P103-dev-bob/flip-red-build.log` / `flip-assertion-probe.txt` | 翻转红（删掉 installer → 构建 rc=1）与两态断言探针 |
| `docs/team/reports/P103-dev-bob/gate-fast-clone.log`（交付门禁）/ `gate-fast.log`（作废的预跑） | 见 §6.2 / §6.3 |

## 0 · 结论先说

1. **P103 的修法 (A) 早就在 main 上**：`802ace48`（P135，2026-09-30T06:36:34Z；`ci/Containerfile:80` 那行注释自己写着
   `P135/P103: install with --ignore-scripts and run the one skipped installer that matters`）。
   本次 apply **没有重写它**——那段已经跑绿了，再改一遍只会把已经证实的确定性重新变成待证。
2. **brief 要的"决定性证据"已经存在，我把它读回来了**（§3）：失败 run `36396850260` 的
   `Build the gate image` 是唯一红的步骤；**修后 33 次真正跑到构建步的 run 里，构建步 0 次红**。
3. **还剩一个真洞，本任务补上**（§4）：P135 留下的产物断言 `[ -x bin/esbuild ] && bin/esbuild --version`
   对"installer 真跑过"和"installer 静默失效"两种状态**都通过**——实测未替换的 9,350 B JS shim 同样可执行、
   同样打印 `0.28.2`。新增一条 ELF magic 断言后，这条路径变成**可证伪**：删掉显式 installer，构建必红（§5）。

## 1 · 诊断（引用失败 run 的原文，不是转述）

取自 run `36396850260`（commit `66d74e4d`，2026-09-28T08:44Z）的 `--log-failed`，原文保存在
`P103-dev-bob/ci-36396850260-log-failed.txt`（665 行，整份；下面是逐字摘录）：

```
#11 18.19 npm error code 1
#11 18.19 npm error path /usr/local/lib/node_modules/@earendil-works/pi-coding-agent/node_modules/esbuild
#11 18.19 npm error command failed
#11 18.19 npm error command sh -c node install.js
#11 18.19 npm error <ref *1> Error: spawnSync /usr/local/lib/node_modules/@earendil-works/pi-coding-agent/node_modules/esbuild/bin/esbuild ETXTBSY
#11 18.19 npm error     at Object.execFileSync (node:internal/child_process:971:15)
#11 18.19 npm error     at validateBinaryVersion (/usr/local/lib/node_modules/@earendil-works/pi-coding-agent/node_modules/esbuild/install.js:103:28)
#11 18.19 npm error     at /usr/local/lib/node_modules/@earendil-works/pi-coding-agent/node_modules/esbuild/install.js:298:5 {
#11 18.19 npm error   errno: -26,
#11 18.19 npm error   code: 'ETXTBSY',
#11 18.19 npm error   spawnargs: [ '--version' ],
```

**根因类别：竞态（"写句柄还没关就 exec"），不是网络，也不是版本漂移。** 三条依据都来自上面这几行：

- 报错发生在 `esbuild/install.js:103 validateBinaryVersion` 的 `spawnSync(…, ['--version'])` 上——installer
  **自己**刚写下/替换完那个二进制，紧接着 exec 它做版本自检；
- 失败被 npm 记在 `command sh -c node install.js` 名下——也就是它正处在 **npm 装包期间的生命周期脚本**里，
  此刻 npm 进程（以及 fork 出 postinstall 的子进程，fork 时复制了 fd 表）还握着该 inode 的写句柄；
- `errno: -26` = `ETXTBSY`，`Build the gate image` 是那次 run 里**唯一**红的步骤（`ci-36396850260-steps.txt`：
  `X Build the gate image`、`- Gates (pinned container)` 被跳过）——门禁没跑、测试一条没红。

pin 一个字没动：node 24.19.0 / bun 1.3.14 / pi 0.86.0 / openspec 1.8.0 在镜像里逐条断言（§6 的构建日志 STEP 8/10/13）。

## 2 · 修法 (A) 为什么是"移除竞态"，而不是"把它藏起来"

main 上的实现（`ci/Containerfile`，P135 引入）：

```dockerfile
RUN npm install -g --no-fund --no-audit --ignore-scripts \
      "@earendil-works/pi-coding-agent@${PI_VERSION}" \
      "@fission-ai/openspec@${OPENSPEC_VERSION}" \
 && npm cache clean --force >/dev/null 2>&1 \
 && command -v pi >/dev/null && command -v openspec >/dev/null \
 && esbuild_install="$(find "$(npm root -g)" -path '*/esbuild/install.js' -print -quit)" \
 && [ -n "$esbuild_install" ] \
 && node "$esbuild_install" \
 && esbuild_bin="$(dirname "$esbuild_install")/bin/esbuild" \
 && [ -x "$esbuild_bin" ] \
 && "$esbuild_bin" --version
```

把"装包"和"跑脚本"拆成两个时刻：`--ignore-scripts` 让 npm 在装包期间**不跑任何生命周期脚本**；
npm 退出之后，installer 作为**自己的进程**跑一次。这时系统里没有任何别的进程持有那个文件的写句柄，
`spawnSync(…, '--version')` 不可能再撞 ETXTBSY —— 竞态是被**移除**的，不是被重试掩盖的：
没有 `continue-on-error`、没有重试循环、没有 `|| true`，installer 或自检失败 = 构建红。

代价 P135 已逐条测过（`docs/team/reports/P135-dev.md` §1）：`--ignore-scripts` 在这两棵 pinned 树里跳过的
脚本全集是 4 个，其中只有 esbuild 必须补跑（protobufjs 只打一条 warning、`@google/genai` 的 preinstall 是
`echo`、openspec 只打补全提示）。

## 3 · 决定性证据：CI 自己的记录（brief 说"只有它算数"）

brief §4 写「决定性证据只能是 CI 的那次构建 → 报告里写"待 PM 在下一次 push 后确认"」。那几次 push 已经发生，
所以这条不再是待办：**我直接把 CI 的记录读回来了**（证据：`P103-dev-bob/ci-build-step-before-after.txt`，
逐 run 一行；`ci-build-step-since-fix.txt` 是修后那张表）。

| 窗口 | 真正跑到 `Build the gate image` 的 run 数 | 构建步非 success |
|---|---|---|
| **修之前**（2026-09-28 00:00 → `802ace48`） | 6 | **1** —— run `36396850260`（就是 brief 引的那次） |
| **修之后**（`802ace48` → 现在） | 33 | **0**（32 次 `success`；1 次是该提交自己的推送 run `36679122364` 在 runner 侧 2 秒内 setup 失败、一个步骤都没跑，没有日志可看，不是构建步红） |

同一张表里能看到的最近几次（构建步全绿，红的是 `Gates (pinned container)` 那一步，那是套件自己的事，与本任务无关）：

```
2026-10-03T02:48:19Z  37091063283 a744bbfc  build=success  gates=failure
2026-10-03T00:58:51Z  37084281909 76f68d40  build=success  gates=failure
2026-10-02T23:40:25Z  37078677437 a22c442f  build=success  gates=failure
2026-10-03T04:11:03Z  37095687391 293bcdae  build=success  gates=…
```

> 关于取数：本工作树里没有 `.github-pat`（它按配置躺在主工作树根、已 gitignore），我按 brief §1 给的命令用它
> 作 `GH_TOKEN` 调 `gh`，全程只作为环境变量传递，没有回显、没有写进任何文件或提交。

## 4 · 本任务的改动：把"installer 真跑过"变成构建期断言

P135 的产物断言是 `[ -x "$esbuild_bin" ] && "$esbuild_bin" --version`。实测（`P103-dev-bob/flip-assertion-probe.txt`，
在钉死镜像里跑，esbuild 0.28.2）：

| 状态 | 文件 | `[ -x ]` | magic | `--version` |
|---|---|---|---|---|
| installer 跑过（正常） | 11,427,952 B 静态链接 ELF | pass | `7f454c46` | `0.28.2` |
| `--ignore-scripts` 且 installer **没**跑（= 回归状态） | 9,350 B JS shim | **pass** | `23212f75`（`#!/u`） | **`0.28.2`** |

也就是说：显式 installer 哪天静默失效（npm 行为变化、路径变了、`find` 找错了树），**构建照样绿**，而镜像里
装的是 shim。这不是假想的形状——它正是 `--ignore-scripts` 这一改动**引入**的那个状态。

改动只有一行断言 + 一段注释（`ci/Containerfile`）：

```dockerfile
# The ELF assertion at the end is what makes that install provable rather than assumed
# (P103): with esbuild 0.28.2 an un-replaced shim is a 9,350 B JS script and the replaced
# binary is an 11,427,952 B static ELF — both are executable and both print `0.28.2`, so the
# `--version` check alone passes in either state. The magic bytes are the difference, and
# they are what turns `--ignore-scripts` + a silently ineffective installer into a red build.
…
 && [ -x "$esbuild_bin" ] \
 && [ "$(head -c 4 "$esbuild_bin" | od -An -tx1 | tr -d ' \n')" = "7f454c46" ] \
 && "$esbuild_bin" --version
```

**没有放松任何别的东西**：pins、`--ignore-scripts` 的用法、镜像自检（`ss -xlH` / GNU time / `tmux -V` /
`node -v` / `bun --version` / `PI_DIST`）全部原样；`--version` 那条也留着（它证明二进制**能跑**，ELF 那条证明
它**是**真二进制，两条互补）。

## 5 · Flip evidence（缺陷修复收口）

**红侧（实现被破坏 → 断言必须红）**：把显式 installer 那一行从 Containerfile 里删掉（同一个文件，其它一字不改），
真跑 `podman build`：

```
$ python3 - <<'PY'
src=open('ci/Containerfile').read()
line=' && node "$esbuild_install" \\\n'
assert line in src, 'installer line not found'
open('/tmp/p103-flip-red.Containerfile','w').write(src.replace(line,'',1))
PY
red variant written: installer line removed
$ distrobox-host-exec podman build -f /tmp/p103-flip-red.Containerfile -t teamsmith-gates:p103-flip-red .
STEP 13/21: RUN npm install -g --no-fund --no-audit --ignore-scripts … && [ -x "$esbuild_bin" ] && [ "$(head -c 4 …)" = "7f454c46" ] && "$esbuild_bin" --version
added 220 packages in 21s
Error: building at STEP "RUN npm install …": while running runtime: exit status 1
FLIP_RED_BUILD_RC=1
```

（完整日志 `P103-dev-bob/flip-red-build.log`。前 12 层走缓存，只有被改的那一层重跑，所以红侧很便宜。）

**绿侧**：同一棵树、同一台机器，未改动的 Containerfile 构建 `BUILD_RC=0`（§6）。

**为什么红侧一定落在新增那条断言上**：删掉 installer 后，链上前面几条都还会通过——
`[ -n "$esbuild_install" ]`（install.js 文件还在）、`[ -x "$esbuild_bin" ]`（shim 有 +x，探针表里两态都是
`-rwxr-xr-x`）——**唯一**能红的只有新加的 ELF magic 那条。探针表（§4）就是这条推理的实测版本。

## 6 · 门禁与本地构建

### 6.1 本地构建（真跑）

```
$ distrobox-host-exec podman build -f ci/Containerfile -t teamsmith-gates:p103 .
STEP 13/21: RUN npm install -g --no-fund --no-audit --ignore-scripts … && [ -x "$esbuild_bin" ] && [ "$(head -c 4 "$esbuild_bin" | od -An -tx1 | tr -d ' \n')" = "7f454c46" ] && "$esbuild_bin" --version
added 220 packages in 32s
0.28.2
--> f38924e146a6
STEP 14/21: ENV PI_DIST=…  STEP 15/21: RUN [ -f "$PI_DIST" ]  …
COMMIT teamsmith-gates:p103
Successfully tagged localhost/teamsmith-gates:p103
BUILD_RC=0
```

完整日志 `P103-dev-bob/build.log`（65 行，21 个 STEP 都在；前 12 层缓存命中，只有被改的 STEP 13 重跑，
所以这次真构建只花了几分钟）。

**产物探针**（在刚建出来的镜像里跑，`P103-dev-bob/image-probes.txt`）：

```
pi:       /usr/local/bin/pi (0.86.0)          openspec: /usr/local/bin/openspec (1.8.0)
node:     /usr/local/bin/node (v24.19.0)      npm:      /usr/local/bin/npm (11.17.0)
bun:      /usr/local/bin/bun (1.3.14)         tmux:     /usr/local/bin/tmux (tmux 3.7b)
time:     /usr/bin/time                       ss:       /usr/bin/ss (ss utility, iproute2-6.15.0)
esbuild:  …/esbuild/bin/esbuild  size=11427952 magic=7f454c46 version=0.28.2
PI_DIST:  present   marker: teamsmith-gate:1   TEAM_PERF_PINNED_CONTAINER=1
```

即 brief §4 要的那条：**esbuild 二进制真的被正确安装**（11,427,952 B 的静态链接 ELF、magic 是 ELF、
`--version` 打得出来），镜像自检（`ss -xlH` / GNU time / `tmux -V` / `node -v` / `bun --version` / `PI_DIST`）
全绿，pin 一个没动。

### 6.2 门禁（openspec + FAST，跑在交付 tip 的干净检出上）

跑法：`git clone --no-hardlinks --branch task/P103-apply <worktree> <home>/p103-gate-checkout`（干净检出，
和 CI 的 `actions/checkout` 同形——**不是**把工作树目录挂进容器：工作树的 `.git` 是指针文件，容器里读不到
仓库，会造出与改动无关的红，见 6.3），然后按 PM 的容器配方跑。
（小坑一笔：clone 必须放在 **`$HOME` 下**这种与宿主共享的路径——podman 跑在宿主上，容器内的 `/var/tmp`
它看不到，第一次放在那里得到 `Error: statfs …: no such file or directory`、包装器 rc=125。）

```
$ distrobox-host-exec podman run --rm --pid=host --cgroups=enabled --userns=keep-id -e HOME=/tmp \
    -v <home>/p103-gate-checkout:/work -w /work localhost/teamsmith-gates:p103 bash -c '
      git config --global --add safe.directory /work
      git config --global user.email gate@teamsmith.local; git config --global user.name "teamsmith gate"
      openspec validate --all --strict && TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null'

tip: 4ca43cd0 docs(team): P103 — evidence: …
Totals: 13 passed, 0 failed (13 items)                                    VALIDATE_RC=0
账本自查： 123 段收口 · 增量 ✓3801 ✗0 SKIP36 ｜ 结果行 ✓3801 ✗0 —— 一致
== 结果 ==  ✓ 3801  ✗ 0                                                   SMOKE_RC=0
smoke 全绿
FAST 模式：跳过 36 个真进程段落（1c/6/6b/6g/6h/6i/6j/6k/10c-②/11/11b/11b2/11b3/11b4/11c/11d/11g②/11g③/11j/
  12b-e/12b-h/26-m/31b/31c×3/32⑧/12g/12h/38-b/38-f/41/42/44/52/55）——完整门禁请不带 TEAM_SMOKE_FAST 重跑
```

日志 `P103-dev-bob/gate-fast-clone.log`（4300+ 行）。跑在 `4ca43cd0`（本分支 tip：改动 + 证据）上；
**本报告文件本身不在那次检出里**——它是门禁跑完后才写的，与 CI 的次序相同（报告不可能先于它记录的门禁存在）。

### 6.3 一次被作废的预跑（如实记，免得 PM 读日志时误判）

第一跑（`P103-dev-bob/gate-fast.log`）在容器里挂的是**工作树目录本身**、tip 也早两小时（尚未并入 main 上
`80e08341` 恢复的 `scripts/shim/pgrep|pidof` 软链）：`✓3785 ✗16`。16 条红的归因：

- **1 条 §0d + 9 条 §36 连锁**：容器里只有工作树目录，它的 `.git` 是**指针文件**，指向容器外的
  `…/pm-skills/.git/worktrees/dev-bob` → `git ls-files` 报「找不到受检的 git 工作树」，§36 的嵌套 run
  又把它当「非环境红」逐层放大；
- **6 条 §31c（P167）**：当时 tip 还没有 main 上恢复的两个软链。

两条都是**跑法/基线**问题（一个是我挂载的写法，一个是我并 main 晚了），不是改动引入的；换成 6.2 的
「干净 clone + 已并 main 的 tip」后归零。

## 7 · Decisions and deviations

- **不重写 P135 的修法**：brief 给了 (A)/(B) 两条路，(A) 已在 main 上落地且已被 CI 证明；本任务只补它缺的那条
  可证伪断言，没有动 `--ignore-scripts` 的结构，也没有加 (B) 的重试（那会把"抽签"留在构建里）。
- **不加 `--no-cache`、不改 pins、不动 CI workflow**：`paths-ignore`/单次构建镜像那部分是 P130 的事，不在本 brief 里。
- **超出 brief 的路径一个字没改**：`git diff` 对 main 只有 `ci/Containerfile` 一处改动（+7 行）。
- **证据不落在 `/tmp`**：全部证据写在 `docs/team/reports/P103-dev-bob/`，与分支一起交付（`/tmp` 是 15G tmpfs，
  今天已用到 94%，D67/ENOSPC 的坑就在那里）。
- **门禁跑在干净 clone 上、不是工作树挂载**：这样容器里看到的是一棵真仓库（与 CI 同形）；代价是多一次 clone，
  换来的是红/绿都能直接归因。

## 8 · Suggested next steps

1. **新断言自己的 CI 证据**：PM 的下一次 push 会带上这条断言（STEP 13 里）；那次 `Build the gate image` 绿，
   就等于「显式 installer 真跑过」在 CI 里也被钉住。若那次 push 带 `[skip ci]` 就没有这份证据（P135 的报告
   也提过同一个注意点）——要不要专门为它跑一次 CI，由 PM 定。
2. **复验口径**：`ci/Containerfile` 不是 smoke 套件的输入，所以 §6.2 的 `✓3801 ✗0` 是**零回归**证据；
   改动本身的功能证据是 §5 的翻转红（删掉 installer → 构建必红）与 §4 的两态探针。
3. 无 BLOCKED、无越界改动、无需要用户裁决的开放问题。分支停在 `task/P103-apply`（local 模式，未 push）。
