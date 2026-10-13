# P229 · 发布就绪：release-check / publish-public 跟上改写后的模型

agent: dev-bob   status: done（**一条发布前必须定夺的发现**见「发现 F1」）   time: 2026-10-10T09:5xZ
change: `-`   anchor: none (infra) — 发布工具链与发布清单的时效维护，不是某项产品 capability 的行为
branch: `task/P229-release-readiness`（本任务分支，local 模式：不 push，PM 复验后本地合并；派单消息里写的 `task/P159-apply` 是旧 slug，实际分支名以此为准）

> **本轮先合并了 main**：开始时落后 3 个提交，收尾时 main 又多了 2 个（共 5 个）一并并入 →
> `749cd79 Merge branch 'main' into task/P229-release-readiness`。main 那侧只动了 `docs/team/**`
> 与新的 `openspec/changes/long-job-suspend/**`，与我的文件零重叠。
> 本报告里所有计数（落后 tag 的提交数、公开远端落后的提交数、账本面文件数）都是**合并后**在最终树上重跑的。

## 失败现场（先复现，再修）

PM 记的那两条命令，在 **main 的冻结克隆**里原样复跑（不走我的树，否则会看见我新加的文件）：

```
$ cd /tmp/p229-before && bash …/pm-skills-ledger/team/tools/release-check.sh
== 2–3. 公开面导出 + 泄漏扫描 ==
  ✗ 导出/扫描失败 —— 详见下面输出
      bash: docs/team/tools/publish-public.sh: No such file or directory
  ✓ 公开树里没有 docs/team …（因为导出树是空的）
  ✗ npm pack 失败
  ✗ install.sh 失败
  ✗ team init 失败
== 结果 ==  ✗ 发布前检查未通过
$ bash …/release-check.sh --self-test
  ✗ 版本错配没被抓住（ vs ）
== 自测结果 ==  ✗ 自测失败：有检查拦不住变异
```

根因三条：① 两件工具**不在仓里**（`.gitignore:31,32` 忽略 `docs/team/tools/` 与 `RELEASE-PUBLIC.md`），
`release-check.sh` 却按仓内路径调用它们；② 它仍按"白名单导出快照"的老模型工作（改写后**本仓就是公开仓**）；
③ 它的自测只比哈希、不跑真检查 —— 导出失败后 `cmp -s` 两个空文件为真，于是"版本错配"漏网（就是 PM 截图那条）。
全量原文：证据包 `00-before-broken-tool.log`。

## Deliverables

| Path | What |
|---|---|
| `docs/team/tools/release-check.sh`（新，进仓） | 按改写后的模型重写：六处版本落点 · 最新 tag = 那版且 **HEAD 就在 tag 上** · 公开面泄漏扫描（分两面）· 账本面禁令（调 `ledger-ban.sh`）· 公开面不变量（哪些必须进、哪些绝不许进）· 三条安装路线 · `--with-gates` FAST · `--remote` 公开远端新鲜度；`--self-test` **跑真检查**对四棵变异树；`--root/--names-file/--skip-install` 供夹具与诊断 |
| `docs/team/tools/publish-public.sh`（改写，进仓） | 从"白名单导出器"变成**公开面扫描器**：默认扫被跟踪的整棵树，`--scan DIR` 扫任意树，`--out` 仅诊断导出，`--list-shapes` 打印形状表。两面分开：账本面 `docs/team/**/*.md` 只查凭据形状（其余四类归 `ledger-ban.sh`），产品/工具面查全部；**名单外置**（`.pi/team/forbidden-names.txt`，缺失 = 可见跳过，exit 3）；本机用户名运行时解析、不写进仓；命中**先遮蔽再打印**（日志可安全贴） |
| `docs/team/RELEASE-PUBLIC.md`（重写，进仓） | 可执行发布清单：模型一句话 · 四个面 · 前置 · 六处落点 · 提交+打 tag（**D97 产品/账本分两次推**）· 推 `public` · npm · 发布后三条路线验证 · 红侧清单 · 绝不做 |
| `.gitignore` | 去掉 D94 那两条对 `docs/team/tools/` 与 `docs/team/RELEASE-PUBLIC.md` 的忽略（发布机器进仓后才会被跑）；证据层照旧挡在树外 |

提交（全部带 `Agent: dev-bob`；`749cd79` 是并入的 main）：

```
749cd79 Merge branch 'main' into task/P229-release-readiness
59018f0 fix(release): the scanner's comment must not name the peers it hunts
9e08f72 fix(release): assemble the self-test's sample address so the scanner does not flag its own fixture
c039fc0 docs(release): the checklist for the rewrite model, and the tools/checklist come back into the repo
3e3b55e feat(release): release-check.sh follows the rewrite model (6 pins, tag==HEAD, both scan faces, invariants)
d97a6b2 feat(release): publish-public.sh scans the tracked public face (post-rewrite model, names external)
```

## Verification evidence（brief 的验收清单，逐条真跑）

证据包（仓外，D94）：`pm-skills-ledger/team/reports/P229-dev-bob/`，含复跑脚本 `run-acceptance.sh`。

### 1. `release-check.sh --self-test` → **4/4**

```
  ✓ ①内网地址：被抓住（rc=1，命中「[net]」）
  ✓ ②编译缓存：被抓住（rc=1，命中「[file]」）
  ✓ ③装错skill：被抓住（rc=1，命中「install.sh」）
  ✓ ④版本错配：被抓住（rc=1，命中「不一致」）
== 自测结果 ==   抓住 4 · 漏掉 0
✓ 自测通过：四条变异全部被抓住
```

四条都**跑真检查**（`--root` 指向从 HEAD 导出的变异树），不是比哈希 —— 这正是 F4 的病根。

### 2. 预发布形状：恰好一条诚实的失败

```
$ bash docs/team/tools/release-check.sh          # 在 PM 的工作树（没有 .pi/ 名单 → 名单那项可见跳过）
== 1. 版本六处落点 ==  ✓ package.json = 0.1.1 · ✓ SKILL.md · ✓ CHANGELOG 最新段 · ✓ teamsmith-init · ✓ common.sh · ✓ README 4 处 pin 全一致 → ✓ 六处落点一致 = 0.1.1
== 2. 最新 tag 与 HEAD ==  ✓ v0.1.1 = package.json · ✓ 是 HEAD 的祖先 · ✗ HEAD 领先最新 tag v0.1.1 113 个提交 —— 发布前先做版本落点 + 打 tag
== 3. 公开面泄漏扫描 ==  ✓ 0 命中（1901 个文件：产品/工具面 573 · 账本面 1327 · 例外 1）
== 3b. 账本面禁令 ==     ✓ 干净（files=1327 hits=0 names=ok）
== 4. 公开面不变量 ==    ✓ 内部目录没被跟踪 · ✓ 证据层没被跟踪 · ✓ 无编译缓存 · ✓ 账本+工具+安装入口都在树里 · ✓ .gitignore 仍挡证据层 / 不挡报告正文
== 5. 三条安装路线 ==    ✓ npm pack → 全局装 → team help 0 · ✓ 包内带 skills/ · ✓ install.sh 两个 skill 逐字节相同 · ✓ team init 软链 + 项目内 team help 0
== 结果 ==  通过 24 · 失败 1 · 跳过 2        # 失败的就是 tag 那条；跳过两条都是"名单缺失"
```

### 3. 红侧：把一处 pin 改错 → 变红并点名（改回 → 全绿）

```
$ sed -i '0,/@v0\.1\.2/s/@v0\.1\.2/@v0.1.1/' README.md     # 只改错一处
$ bash docs/team/tools/release-check.sh
  ✗ README 的 pin（0.1.1 0.1.2）与 package.json（0.1.2）不一致
== 结果 ==  通过 24 · 失败 1 · 跳过 2   → RC=1
$ sed -i '0,/@v0\.1\.1/s/@v0\.1\.1/@v0.1.2/' README.md     # 改回
== 结果 ==  通过 25 · 失败 0 · 跳过 2   → RC=0    ✓ 发布前检查全部通过
```

### 4. 演练（临时 clone，不动主仓）：落点 + tag → **全绿**

```
$ rm -rf /tmp/p229-dry && git clone -q --branch task/P159-apply . /tmp/p229-dry
$ V=0.1.2;（六处落点 sed + CHANGELOG 段落）; git commit -m "chore(release): v$V"; git tag -a v0.1.2 -m …
$ bash docs/team/tools/release-check.sh
== 1 == ✓ 六处落点一致 = 0.1.2      == 2 == ✓ 最新 tag v0.1.2 = package.json · ✓ HEAD 就在 v0.1.2 上
== 3/3b/4/5 == 同上面全绿
== 结果 ==  通过 25 · 失败 0 · 跳过 2   → RC=0   ✓ 发布前检查全部通过
```

### 5. 记录面检查

```
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file .pi/team/forbidden-names.txt
ledger-ban: SKIP names —— 禁令名单未配置（.pi/team/forbidden-names.txt 不存在；这一项不是通过）
ledger-ban: root=… scope=published files=1322 hits=0 names=missing user=resolved   → RC=3（可见跳过，**不是通过**）
$ bash skills/teamsmith/tests/section-select.sh --paths docs/team/RELEASE-PUBLIC.md docs/team/DECISIONS.md
decision=NONE · reason=豁免类（docs/*）：团队账本，门禁不为它开火            → RC=0
$ bash skills/teamsmith/tests/spec-refs.sh --check
spec-refs: judged 104 reference(s) (49 distinct); retired 0; undeclared 0       → RC=0
$ git diff --check  → RC=0        $ git status --short → 空（干净）
```

工作树里没有 `.pi/`（被 ignore），所以 brief 写的原样命令是**可见跳过**；点名真名单后（下一节）账本面是干净的。

### 6. `--remote`：公开远端新鲜度（要求⑥）

```
$ bash docs/team/tools/release-check.sh --remote --skip-install
== 7. 公开远端新鲜度 ==
  public  git@github.com:Track07-cda/teamsmith.git
  远端 main 0dbc6ebb0dd0 · 本地 main 3c7b941c3440
  ✗ 公开远端落后本地 main 77 个提交 —— 推之前先按清单走            → RC=1
```

（默认**不联网**：`--remote` 才做 `ls-remote`；连不上、没有 `public` 远端都是**可见跳过**。）

### 7. 回归：FAST 产品套件（最终树上重跑）

```
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null      # 在合并 main 后的最终树上
== 结果 ==  ✓ 3897  ✗ 0
FAST 模式：跳过 36 个真进程段落（dispatch 真拉起 / 真 pane / 真沙盒窗口 / 容器自检 …，逐条点名）
检出前提 SKIP（条件不满足）：15 条 —— 检出里按构造缺失的内部开发面/机器生成面/证据层（跳过不是通过）
smoke 全绿        → RC=0
```

P229 只动 `.gitignore` + 两个仓外工具进仓 + 一份文档，产品代码零改动；FAST 用于确认没有旁路影响。
全文：证据包 `08-fast-gate.log`（2533 秒）。

## 发现 F1 · 公开面上还有 13 处**真实对端项目名**（发布前必须定夺）

把**真的**禁令名单接上（`--names-file …/pm-skills/.pi/team/forbidden-names.txt`）后：

| 面 | 结果 |
|---|---|
| 账本面（`docs/team/**/*.md`，`ledger-ban.sh`） | **干净**：`files=1322 hits=0 names=ok user=resolved` |
| 产品/工具面（`publish-public.sh`，本任务新增的那一面） | **13 行命中**（9 个文件），全是名单里的一个短名 |

命中的文件（输出里名字按设计遮蔽成 `«name»`，这里给路径与行号）：

```
skills/teamsmith/scripts/lib/common.sh:4358, 4515      # 注释：实测踩过的两个坑
skills/teamsmith/scripts/lib/cmd-watch.sh:248          # 注释：位置参数当 agent 名的反馈来源
skills/teamsmith/references/protocol.md:459, 468       # §8f 标题与正文："measured on …"
skills/teamsmith/tests/smoke.sh:2797, 2798, 2822       # 6e 段的标题与两条注
skills/teamsmith/tests/section-paths.tsv:41            # 6e 段的键名
skills/teamsmith/tests/section-budgets.tsv:49          # 6e 段的键名
docs/team/ledger/branch-inventory-20261005.tsv:150     # 分支名 task/P138-…-team-say
docs/team/ledger/branch-cleanup-20261005.tsv:150       # 同上
openspec/changes/archive/2026-09-16-rename-watchdog-to-pulse/design.md:65   # 归档设计记录里的一次路径引用
```

三点补充（都已实测）：

1. **不是"导出漏了"**：这些名字在**已经推出去**的公开 `main`（`0dbc6ebb`，2026-10-05）里同样存在
   （`git show 0dbc6ebb:skills/teamsmith/references/protocol.md | grep -cw` 与当前树同值）→ 它**已经不是秘密**，
   清工作树也改变不了"已经公开"这件事。
2. **`ledger-ban.sh` 看不见这一面**：它只扫 `docs/team/**/*.md` —— 上面 13 行里有 11 行在产品/工具/`openspec` 面。
   这就是本任务新增"产品面也扫名字"的**直接价值**（也是我为什么没把四类形状抄两遍）。
3. **怎么修都是 PM/用户的决定**（我这条不动它）：
   - ① **接受**（名字已公开，且是"实测来源"的技术记录）→ 在 `RELEASE-PUBLIC.md` 写明例外，扫描器加白名单；
   - ② **清掉工作树里的这 13 行**（改成 `<peer>` 之类占位符）→ 需要一个**产品面**的小任务（`skills/**`、`openspec/changes/archive/**`、
     `docs/team/ledger/*.tsv` 不是我这份 brief 的范围）；注意**历史里仍有**，只是不再扩散；
   - ③ 重写历史再推 → 与"H 那条已经推出去、绝不 force-push"冲突，**不建议**。

**这条会挡住发布**：接上真名单后 `release-check.sh` 的第 3 节会红（我这边的形态是 1 条 tag 失败 + 1 条泄漏失败）。
所以我把它写成"发布前必须定夺"，而不是悄悄加白名单。

## Flip evidence

1. **失败现场 → 修好**：`00-before-broken-tool.log`（`publish-public.sh: No such file` 连带 npm/install/init 四条红、
   自测 3/4）↔ 现在同样两条命令在**冻结克隆**里：预发布 24/1/2（唯一失败是 tag），自测 4/4。
2. **自测本身是翻转器**：四条变异（内网地址 / 编译缓存 / `install.sh` 装成同一个 skill / 版本错配）各自把
   **对应的那条真检查**打红并且只红在该条上（`--root` 指到变异树）。
3. **红侧 → 绿**：演练 clone 里改错一处 README pin → `✗ README 的 pin（0.1.1 0.1.2）与 package.json（0.1.2）不一致`；
   改回 → `通过 25 · 失败 0 · 跳过 2`。
3. **扫描器/禁令自己的三处“自伤”修复**（说明检查是真在跑的）：自测夹具里写死的内网地址、工具注释里写的两个对端短名、
   **本报告自己**在“词匹配”那条里写的两个短名，分别被自己的扫描器 / `ledger-ban.sh` 点名
   （`✗ 命中 [net]` / `✗ 命中 [name]` / `docs/team/reports/P229-dev-bob.md:193 [names]`）
   → 地址改成分片拼、注释与本报告改用描述（`hits=0`）；此后产品面命中剩余 13 行**全是真问题**（F1）。

## Decisions and deviations

- **扫描对象 = 被跟踪的整棵树**（brief 要求①）；`--out` 只留作诊断，导出流程本身不再是发布步骤。
- **形状不抄两遍**：账本面交给既有的 `ledger-ban.sh`（占位符放行、网段三组八位、日志掩码这些语义都在它那里），
  `publish-public.sh` 对账本面只查凭据形状，**新增的那一面是产品/工具面**（F1 就是它抓到的）。
- **例外可见**：必须引用泄漏样本的文件（`ledger-ban.sh` 自己的夹具）走 `EXEMPT_PATHS`，**每次运行都打印**，
  没有静默豁免；`--list-shapes` 打印形状表与例外理由。
- **名单外置**：`--names-file` / `TEAM_FORBIDDEN_NAMES`，默认 `<root>/.pi/team/forbidden-names.txt`（被 ignore）；
  缺失或为空 = `exit 3` **可见跳过**（与 `ledger-ban.sh` 的约定一致），绝不当通过。短名按**词**匹配
  （`grep -w`），否则名单里的三字母短名会命中 `acceptable` / `fingerprint` 这类普通词。

  > 顺带一条**真被抓住**的记录：本报告自己最初也写了那两个短名（就在上面这行），
  > `ledger-ban.sh` 立刻点名 `docs/team/reports/P229-dev-bob.md:193 [names]` —— 改成描述后 `hits=0`。
  > 发布检查第 3b 节确实在盯着账本面（不是摆设）。
- **HEAD 领先 tag 现在是失败**（旧工具只是 warn）：发布对象是 tag，领先就是"版本号指向过去"。
- **`--remote` 默认不联网**；连不上/无远端 = 可见跳过，不假绿。
- **`.gitignore` 只去掉那两条**（工具与清单进仓），证据层、`.pi/`、`node_modules/` 照旧挡在树外。
- **本任务不碰**：`.github/workflows/gates.yml`（不相交，留在原处）。

## 未做 / 风险 / 待定夺

- **版本落点 + 打 tag + 推 `public` + npm 发布本身**：演练已在临时 clone 里跑通（0.1.2 → 全绿），
  但**真仓的这三步是不可逆动作**，按红线必须用户逐条点头后由 PM 执行（清单见 `docs/team/RELEASE-PUBLIC.md`）。
- **F1（13 行真实对端名）**：见上，需要 PM/用户选一条路；在定夺前"接上真名单"的发布检查会红。
- **`.github/workflows/gates.yml` 与公开仓 CI**：本次没跑公开仓的 GitHub Actions（不外发、不动设置）；
  `--with-gates` 的公开树自跑 FAST 在旧工具里有、新工具里保留为可选项（本次只在工作树里跑了 FAST ✓）。
- **公开远端已有 `main`（`0dbc6ebb`，落后 73 个提交）**：说明首发推送**已经发生过**，"首次推送"的
  历史改写路线（若还要重写）必须先与用户确认 —— 重写已公开的历史 = force-push，红线不允许。
