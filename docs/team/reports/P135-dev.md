# P135 · infra tidy：镜像构建确定性 · close 清残留分支 · 镜像补 iproute2 · 合并食谱一行 fallback

agent: dev   status: done（四件交付物齐；FAST 上剩 2 条**继承自 main** 的红，见 §5 FINDING）   time: 2026-09-30T06:25Z
branch: `task/P135-infra-tidy`（工作树 `.worktrees/dev`，local 模式：不 push，PM 复验后本地合并）   PR/MR: -

change: -（无 change）· anchor: none (infra) —— CI 镜像构建确定性 + 镜像依赖 + 一行状态清理 + 一行文档；无产品行为变更
deltas: -

## Deliverables

| Path | What |
|---|---|
| `ci/Containerfile` | **①** pi/openspec 改成 `npm install -g … --ignore-scripts` + 显式 `node <esbuild>/install.js` + `[ -x bin/esbuild ] && --version`（P103）；**②** apt 列表补 `iproute2`（D63）；**③** 镜像自检加 `ss -xlH`（与夹具实际调用同形） |
| `skills/teamsmith/scripts/lib/cmd-review.sh` | `close` 的席位收尾循环里 `branch=` 与 `task=` 同生命周期一起清（D62-a） |
| `skills/teamsmith/references/workflows.md` | `--pr` 食谱补一行可判定 fallback：`# 若 forge 合并 403（缺 Contents: write）：本地 squash + push + 评论 + 关 PR` + 403 的权限归属说明（<peer-c> 0007(1) / D65） |
| `skills/teamsmith/tests/smoke.sh` | §11 夹具（close 前写非空 `branch=` → close 后断言空/删）；§6d 钉住 fallback 那一行 |
| `docs/team/reports/P135-dev/**` | 本报告 + 5 份证据日志（`fast-gate.log` 全量 FAST、两份 red 侧、`image-build.log`、`inherited-14b-red.log`） |

提交（branch tip 见 `git log`）：

```
49d67e8f fix(teamsmith): P135 close 清 branch= + forge 403 fallback 落文档（D62-a · <peer-c> 0007(1)）
ce7cbc8f ci: P135 镜像构建确定性（--ignore-scripts + 显式 esbuild installer）+ 补 iproute2（P103/D63）
（+ 本报告）
```

## 1 · CI 镜像构建的确定性（P103）

**现场**（P103 失败 run 的原文）：`npm install -g` 期间 esbuild 的 `postinstall`（`node install.js`）在给自己
`spawnSync …/node_modules/esbuild/bin/esbuild --version` 做版本自检时收到 **ETXTBSY**，整次镜像构建红。

**机制**：npm 在装包**期间**就跑生命周期脚本；esbuild 的 `install.js` 先把平台二进制 hardlink/rename 成
`bin/esbuild`，紧接着 exec 它自检。此时 npm（以及 fork 出 postinstall、fork 时复制了 fd 表的子进程）还握着
那个新 inode 的写句柄 → exec 目标仍 busy → ETXTBSY（容器/overlay 上更容易撞）。这不是网络抖动或版本漂移，
pin 一个字没动。

**修法（选中 A）**：把「装包」和「跑脚本」拆开 ——

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

竞态被**移除**：npm 退出后才跑 installer，构造上没有「安装中途 exec 自己刚写的文件」。没有重试，没有
`continue-on-error`，installer 或自检失败 = build 红。

**探针（npm 11.16.0 / node 24.19.0 = 镜像同版本；`--prefix` 与镜像的 `-g` 同形）**：

- `--ignore-scripts` 在这两棵 pinned 树里跳过的脚本**全集只有 4 个**：
  `esbuild`（下面显式跑）、`protobufjs`（只打一条版本方案 warning，见其 `scripts/postinstall.js` 早退）、
  `@google/genai`（`preinstall=echo` no-op）、`openspec`（只打 opt-in 补全提示）。功能上只有 esbuild 必须补跑。
- 同一棵树：**不跑脚本**时 `bin/esbuild` 是 9,350 B 的 JS shim；**跑完** `install.js` 是 11,427,952 B 的
  静态链接 ELF，`--version` → `0.28.2`。改前改后的最终形态一致（只是不再借 npm 的 postinstall 去跑）。

**真构建**（`ci/Containerfile` 未加任何 build-arg；本地一行）：

```
$ distrobox-host-exec podman build -f ci/Containerfile -t teamsmith-gates:p135 .
STEP 13/21: RUN npm install -g --no-fund --no-audit --ignore-scripts …  && node "$esbuild_install" && "$esbuild_bin" --version
…
added 220 packages in 19s
0.28.2
--> 976be838009d
COMMIT teamsmith-gates:p135
Successfully tagged localhost/teamsmith-gates:p135
BUILD_RC=0
```

镜像内清点（`--user $(id -u):$(id -g) -e HOME=/tmp -v "$PWD:/work:ro"`）：

```
pi:       /usr/local/bin/pi (0.86.0)          openspec: /usr/local/bin/openspec (1.8.0)
bun:      /usr/local/bin/bun (1.3.14)         node:     /usr/local/bin/node (v24.19.0)
npm:      /usr/local/bin/npm (11.17.0)        tmux:     /usr/local/bin/tmux (tmux 3.7b)
ss:       /usr/bin/ss (ss utility, iproute2-6.15.0)
esbuild:  …/esbuild/bin/esbuild (0.28.2) size=11427952
pi parser asset: present
```

**诚实说明**：本地一次构建撞上竞态的概率很低，**它不是「CI 不再红」的决定性证据**（P103 自己也这么说）；
决定性证据是 PM 下一次 push 的 CI 构建。本改动的确定性来自构造（读 installer、显式执行、断言产物的
`--version`），不是来自「本地跑绿了」。完整构建日志：`P135-dev/image-build.log`。

## 2 · `close` 顺手清掉 `state/<agent>.env` 的 `branch=`（D62-a）

**现象**（PM 2026-09-29 实测）：`close` 只清了 `task=`，`branch=` 留着。下一次派单的分支守卫读到
「席位还停在旧任务分支上」→ 拒单；实际工作树早已按规矩准备好了。任务结束后席位就不该再宣称「我在跑谁的分支」。

**修**：`cmd-review.sh` 的席位收尾循环里，`branch=` 与 `task=` 同生命周期一起清（`team_state_set "$a" branch ""`，
行内注释写清理由）。语义不缩水：**工作树实际在哪个分支**仍由现场 `git -C … rev-parse` 读，`state` 里的
`branch=` 只是「这个席位正在跑什么」。`task=` 的既有行为一个字没动。

**Flip evidence（真实 red → green，同一条命令）**：

```
$ sed -i 's|^    team_state_set "$a" branch ""$|    # RED FLIP: 移除|' skills/teamsmith/scripts/lib/cmd-review.sh
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh --select 11   →  rc=1
  ✗ P135（D62-a）：close 后 state 里仍留着非空 branch=（branch=task/T1.1-smoke-task）
  #12 11 · 收尾 · ✓18 ✗1 SKIP1      == 选段结果 ==  ✓ 175  ✗ 1
$ git checkout -- skills/teamsmith/scripts/lib/cmd-review.sh      # 恢复
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh --select 11   →  rc=0
  ✓ P135（D62-a）：close 清掉 state 的 branch= 记录（空或删除）
  #12 11 · 收尾 · ✓19 ✗0 SKIP1      == 选段结果 ==  ✓ 176  ✗ 0
```

red 侧日志 `P135-dev/flip-close-red.log`；green 侧在全量 FAST 里（§门禁）。夹具与快模式无关，两种模式都跑。

## 3 · 门禁镜像补 `iproute2`（D63）

A/B 用**同一份夹具**（本工作树，`-v :ro`）跑旧镜像与新镜像：

```
BEFORE  teamsmith-gate:local（8 天前建的对照像）:
  command -v ss: MISSING
  孤儿私有 server 0 个（socket 已消失）· 陈旧 socket ?（没有 ss，无法判） 个
AFTER   teamsmith-gates:p135:
  command -v ss: /usr/bin/ss
  孤儿私有 server 0 个（socket 已消失）· 陈旧 socket 1 个        # 夹具种的那个
```

同一 A/B 在 smoke §40 里（`--select 40`，两种模式都跑的那段）：

```
BEFORE  teamsmith-gate:local :  ✗ 40 P122 陈旧 socket 没被数出来：… 陈旧 socket ?（没有 ss，无法判） 个
                                #5 40 · ✓13 ✗1；选段结果 ✓33 ✗2
AFTER   teamsmith-gates:p135 :  ✓ 40 P122 status 把无监听的陈旧 socket 数出来
                                #5 40 · ✓14 ✗0；选段结果 ✓34 ✗1
```

「把旧的可见降级关掉」的形状就是想要的那种：断言从「报红 + 现场里写着无法判定」变成「真的数出来」。

> 本地这两次 A/B 都各剩 1 条**与 iproute2 无关**的红：`0d · 冲突标记守卫`——`-v "$PWD:/work:ro"` 挂的是
> **worktree**（`.git` 是指向主 checkout 的指针文件），该段要求真仓库根。CI 的完整 checkout 不受影响；
> 本报告不把它算进容器证据。另外 `ss -V` 只是版本打印，镜内自检用的是夹具真正的调用形状 `ss -xlH`。

## 4 · `workflows.md` 的 403 fallback 一行（<peer-c> 0007(1) / D65）

`--pr` 食谱里补的那一行**逐字**：

```
gh pr merge --squash --delete-branch <PR>                  # GitLab: glab mr merge <iid> --squash
# 若 forge 合并 403（缺 Contents: write）：本地 squash + push + 评论 + 关 PR
git -C <root> fetch origin <protected-branch> && git -C <root> merge --ff-only FETCH_HEAD
bash <skill>/scripts/team board set <ID> done
```

下面的注补了两件事，且**不点名任何项目的凭据状态**：① 403 时要的权限是 **Contents: write**（不是
`pull-requests: write`——这正是当年被误读的那条）；② 本地落地的四步顺序（`merge --squash` + `commit` +
`push` + 在 PR/MR 上留一条评论并**关闭**而不是事后合并，否则等于第二份空改动）。

**Flip evidence**（删掉那一行 → §6d 钉的那条红；恢复 → 全量 FAST 里绿）：

```
$ sed -i '/若 forge 合并 403/d' skills/teamsmith/references/workflows.md
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh --select 6d   →  rc=1
  ✗ workflows 给了 forge 合并 403 的可判定 fallback（本地 squash+push+评论+关 PR）（… 中找不到 [若 forge 合并 403（缺 Contents: write）：本地 squash + push + 评论 + 关 PR]）
  #10 6d · ✓16 ✗1 SKIP0      == 选段结果 ==  ✓ 129  ✗ 1
$ git checkout -- skills/teamsmith/references/workflows.md      # 恢复
（全量 FAST）✓ workflows 给了 forge 合并 403 的可判定 fallback（本地 squash+push+评论+关 PR）
```

red 侧日志 `P135-dev/flip-6d-red.log`。

## 5 · FINDING（交回 PM）：main 上继承来的 14b 红，是 FAST 仅剩的 2 条红

全量 FAST 干净跑：`✓ 3154 ✗ 2`，两条都出自 §14b（同一个根因，一条是真命中、一条是它的双向夹具被同一行
污染）。**它们在 main 上完全相同存在，不是本任务引入的**：

```
$ mkdir /var/tmp/p135-main && git archive main | tar -x -C /var/tmp/p135-main   # 纯净 main 导出
$ <smoke §14b 的 dep_scope_hits 同一条管道>
=== main:      skills/teamsmith/references/troubleshooting.md:1148:image (`ci/Containerfile`) is the one built for the suite. …
=== worktree:  skills/teamsmith/references/troubleshooting.md:1148:（同一行）
$ git log -1 -S 'cannot be mounted for a container' -- skills/teamsmith/references/troubleshooting.md
eb25b765 2026-09-29 19:29:30 +0000  docs(team): one troubleshooting entry for the environment trap …
$ git diff --stat main...HEAD    # 本任务只碰 4 个文件，不含 troubleshooting.md
```

证据链：那一行由 `eb25b765`（2026-09-29 19:29:30 UTC，纯文档、带 `[skip ci]`，直接进 main）引入，自身
没被任何门禁跑过；守卫 `dep_scope_hits` + M58 的 harness 豁免是 2026-09-21 进来的（远早于那一行）。
`docs/team/reviews/` 里最近一次全量 FAST 记录是 P133（2026-09-29T20:0x，`✓3152 ✗0`）——该守卫是确定性 grep、
自 2026-09-21 起就在，✗0 只可能出现在**没有这条线**的树上（两边断言总数不同步是正常的：P133 到本轮
之间 main 还落了别的任务）；那份树 cut 在什么时候已不可回放（`task/P133-p133` 今天已被复用、指向
59f5463e），所以我不声称「它一定跑在线落之前」，只说：**从这条线落地到现在，没有任何
一次门禁记录跑在含它的树上，直到本轮**。机制的细节：`dep_scope_hits` 是**逐行白名单**
（`container-tmux.sh|team perf|perf.sh|TEAM_PERF|性能套件` 全在这一行上才豁免），而这一行讲的是「套件在
容器里跑」这条 harness 语境，恰好一个豁免词都没带——所以它命中，而同一段里的另外 3 处 `ci/Containerfile`
（都挨着 `perf.sh`）不命中。

**为什么我不修**：`references/**` 按 `OWNERSHIP.md` 默认归 PM（任务书**明授**才动刀），我的 brief 只授了
`workflows.md` 这一个 references 文件；改这里属于跨目录。**两条候选修法**（PM 选，任选其一都是一行）：

- **(a) 改文档**（PM / 被明授的 agent，`references/troubleshooting.md:1148`）：
  `The pinned gate image (\`ci/Containerfile\`) is the one built for the suite.` → 去掉括号里的路径
  （`The pinned gate image is the one built for the suite.`），该段语义不变；`ci/Containerfile` 在这份
  troubleshooting 里另有 3 处（1010/1020/1039，都带 `perf.sh` 豁免词）不受影响。
- **(b) 扩豁免**（我的地盘 `tests/smoke.sh` 的 `dep_scope_hits`，但这是不动量的**语义**变更，等 PM 发话）：
  追加一个只覆盖 harness 语境的关键词（例如 `gate image`），双向夹具仍然成立（产品语境的
  `podman container` 那句话照旧被抓住）。

不选的原因只有一个：它超出本 brief 的四条授权路径，且 (a)/(b) 是设计取向问题，不是 worker 能替 PM 定的。

## 门禁（在最终 tip 上真跑）

```
$ openspec validate --all --strict          # 本容器 PATH 上没有 openspec（rc=127），改在钉死镜像里跑
（distrobox-host-exec podman run --rm … -v "$PWD:/work:ro" teamsmith-gates:p135 bash -c 'openspec validate --all --strict'）
✓ spec/… 13 项 → Totals: 13 passed, 0 failed (13 items)      OPENSPEC_RC=0

$ TMPDIR=/var/tmp/p135-run TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
账本自查： 115 段收口 · 增量 ✓3154 ✗2 SKIP34 ｜ 结果行 ✓3154 ✗2 —— 一致
== 结果 ==  ✓ 3154  ✗ 2          # 仅剩 §5 的 2 条继承红；本任务新增的 §11（2 条）/§6d（1 条）断言都绿
SMOKE_RC=1                        # ← 非 0 的原因就是那两条继承红
FAST 模式：跳过 34 个真进程段落（1c/6/6g/6h/6i/6j/6k/10c-②/11·close 后窗口/11b/11b2/11b3/11b4/11c/
  11d/11g②/11g③/11j/12b-e/12b-h/12b-pi3 ⑤/26-m/31b/31c×3/32⑧/12g/12h/38-b/38-f/41/42/44/52·p113-live）
```

- 全量日志：`P135-dev/fast-gate.log`（ANSI 已剥）。**选段运行不算门禁**：本报告另附 §11/§6d/§40 的选段
  证据（每份日志都自带「这次没跑的段」清单），交付判据是上面这次全量 FAST。
- 第一次全量 FAST（05:37–05:55）撞上 **`/tmp` 满（15G tmpfs，ENOSPC）**：`smoke.sh:16334 printf: write
  error: No space left on device`，✗330 里有大量 ENOSPC 次生红（含 P95/14d 的账本混乱）。把 `TMPDIR` 指到
  overlay（288G 可用）后的干净重跑就是上面这次（✓3154 ✗2）。这正是 main 上 D67/P141 记的那个坑：与
  P135 的改动无关，`/tmp` 里的存量多半是其他人（verify-T32.x / review-M8.x）还没清的现场，我没有动它们。

## Flip evidence（缺陷修复任务的收口）

| 项 | red 侧（真的看过它红） | green 侧 |
|---|---|---|
| close 清 `branch=` | `✗ P135（D62-a）：close 后 state 里仍留着非空 branch=（branch=task/T1.1-smoke-task）`（删掉实现那一行，`--select 11` rc=1） | 同一夹具恢复实现后 ✓；全量 FAST 里 `✓ P135（D62-a）：close 清掉 state 的 branch= 记录（空或删除）` |
| workflows 403 fallback | `✗ workflows 给了 forge 合并 403 的可判定 fallback…（删掉那一行，`--select 6d` rc=1）` | 恢复后全量 FAST 里 ✓ |
| 镜像确定性 | 无法在本地确定性地重现 ETXTBSY（P103 原文：本地构建撞不上），所以没有伪造 red 侧；证据是「构造上移除竞态」+ 与镜像同版本的探针 + 真构建 0 退出 + 产物自检 | 同上 |

## Decisions and deviations

- **改构建而不是重试**：没有加 `continue-on-error`，没有 `npm rebuild`/重试循环；把「跑脚本」从安装过程里拿开。
- **不动任何 pin**：node/bun/pi/openspec/tmux 的 ARG 与阈值一字未动（diff 可逐字核）。
- **`--ignore-scripts` 的代价如实列出**：多跑一步显式 installer（4 个被跳过的脚本各自的作用见 §1 探针），
  换来的是构建不再抽签。
- **超出 brief 的路径一个字没改**：`git diff main...HEAD` 只有 4 个文件（brief 点名的四个）。
- **未做**：非 FAST 的全量 smoke（brief 明说不需要；PM 复验会独立跑）、CI 本身（P103 的决定性证据要等 PM
  的下一次 push）。FAST 跳过的 34 段里含 `11·close 后窗口`（真 tmux 场地）：本改动落在 close 的**公共收尾
  循环**里，快模式 §11 已覆盖；真窗口那半留给 PM 的全量跑。**注意**：本任务会碰 `ci/**`；合并进 main 的
  那次 push 若带 `[skip ci]` 就不会有 CI 证据，若要 CI 证据就不要 skip。
- 我的提交信息里没有加 `[skip ci]`（local 模式不 push，合并/推送由 PM 决定）。

## Suggested next steps

1. **先裁决 §5**：在 (a) 改 `troubleshooting.md:1148` 与 (b) 扩 `dep_scope_hits` 豁免词之间选一个（都是一行），
   否则任何含 main tip 的树都过不了全量 smoke（含 PM 对本任务的独立复验）。
2. 复验本任务时：`team review P135 --strong` 会用 `teamsmith-gates:p135` 那类镜像里的 `openspec`（本容器没有），
   且 §5 的红会照旧出现——请按「继承红」处置，别算到这张单上。
3. §2 的行为修复建议顺带在 PM 自己的流程里核一次：下一个 `close` 之后 `grep -E '^branch=' .pi/team/state/<agent>.env`
   应当是空行。
