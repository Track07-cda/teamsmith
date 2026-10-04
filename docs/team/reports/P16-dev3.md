# P16 · apply: split-teamsmith-init-skill（提案 ACCEPTED）

agent: dev3   status: done   time: 2026-09-18T02:00Z
branch: `task/P16-apply-split-teamsmith-init-s`   PR/MR: -（local 模式：不 push，分支留在 `.worktrees/dev3`，PM 复验后本地合并）
依据：`openspec/changes/split-teamsmith-init-skill/tasks.md`（1.1–4.4，17 条已打勾、4.2 留给 PM，见 §4.2）

## Deliverables

| Path | What |
|---|---|
| `skills/teamsmith-init/SKILL.md` | **新增**，58 行；三拍：有序问答清单（6 条，收编附录 A 的 5 个散点）→ `team bootstrap` → 交接句「日常运转读 teamsmith」 |
| `skills/teamsmith-init/references/bootstrap.md`、`templates/bootstrap-prompt.md.tmpl` | `git mv` 迁入（移动，不复制；日常侧已不存在） |
| `skills/teamsmith/SKILL.md` | 删 `## New project` 与 `## 30-second start` 两节（原位留一段指路）、§Deeper reading 改指兄弟 skill、description 去 3 个 init 短语并加指路（977 → 912 字符） |
| `skills/teamsmith/references/workflows.md` | §A（14 行命令序列）缩成指路（D2，PM 已批准） |
| `skills/teamsmith/references/migration.md` | bootstrap.md 引用改跨 skill 相对路径 |
| `skills/teamsmith/scripts/lib/common.sh`、两个 `SKILL.md`、`CHANGELOG.md` | v1.40.0（四处相等） |
| `skills/teamsmith/tests/smoke.sh` | 版本断言四处一致、§0b 两个 skill 各跑一遍解析器、14b 扫描面扩到两个 skill（含 init 侧独立沙箱翻转）、bootstrap.md 断言迁新家、18 段英文不变量覆盖 init references、**新增 18b 拆分不变量**（16 条断言，每条带注入自测） |
| `skills/teamsmith/tests/skill-load.mjs` | 期望 name 从目录名推导（两个 skill 共用一份加载器） |
| `openspec/changes/split-teamsmith-init-skill/tasks.md` | 17 条打勾；4.2 保留未勾 + 交回 PM 的说明 |
| `docs/team/reports/P16-dev3/**` | 本报告 + `migration-compare.sh`（4.4 可复跑）+ `logs/`（门禁、翻转、逐条验证、指纹、迁移对照） |

提交（分支 tip = `ef9ebfe`，另有报告提交）：

```
91218e2 feat(teamsmith-init): P16 split the initialization guidance into its own skill
39a306b docs(teamsmith): P16 daily skill no longer carries initialization guidance
a91b958 fix(teamsmith-init): P16 make the description a valid YAML plain scalar
cce6771 test(teamsmith): P16 smoke covers both skills
1678802 test(teamsmith): P16 add the split invariants as section 18b
ef9ebfe chore(teamsmith): P16 release v1.40.0 (split-teamsmith-init-skill)
```

## tasks.md 逐条（命令与实测输出：`logs/tasks-verify.txt` 全文）

- **1.1** 两文件只在新家：`test -f` ×2 + `test ! -e` ×2 → `PASS ✓`
- **1.2** `wc -l` → **58**（≤100）；`grep -c 'scripts/team bootstrap'` → **2**；`grep -c teamsmith` → **10**
- **1.3** 双向跨 skill 链接就位（`bootstrap.md:7` → `../../teamsmith/references/migration.md`；`migration.md:77` → `../../teamsmith-init/references/bootstrap.md`），init 侧旧相对路径 `](migration.md)` 无残留
- **1.4** `workflows.md` 命中 `teamsmith-init` 3 处；§A 已是 5 行指路（无命令序列）
- **2.1** `grep -cE '^## (New project|30-second start)'` → **0**，原位指路段在（`## Starting a new project: use the teamsmith-init skill`）
- **2.2** `grep -n '](references/bootstrap.md)'` → 无命中；Deeper reading 行改指 `teamsmith-init` skill
- **2.3** 日常 **912** 字符 / init **800** 字符（都 ≤1024）；3 个 init 短语只在 init 侧，3 个日常短语只在日常侧；日常 description 点名 `teamsmith-init`
- **3.1** 版本四处一致：`common.sh=1.40.0 ｜ 日常 SKILL=1.40.0 ｜ init SKILL=1.40.0 ｜ CHANGELOG=1.40.0`，且 `skills/teamsmith-init/CHANGELOG.md` 不存在
- **3.2** smoke 日志两段：`✓ skill-load teamsmith：… name=teamsmith desc=912 字符 诊断=0` / `✓ skill-load teamsmith-init：… name=teamsmith-init desc=800 字符 诊断=0`
- **3.3** 14b 扫描清单覆盖两个 skill（含一条「init skill 副本里的已删命令会被抓到」的独立沙箱翻转）；`bootstrap.md` 专属断言迁到 `$SKILL_INIT_DIR/references/bootstrap.md` 并断言双向互链；18 段英文正文口径覆盖 init 的 `references/`（新增 init 侧 CJK 翻转）
- **3.4** 18b：`两条 description 路由干净`、`日常 description 点名 teamsmith-init`、长度上限；两条注入自测（把 init 短语塞回日常 / 把日常短语塞进 init）都会红
- **3.5** 18b：init 侧无 `scripts/extension/tests`；`scripts/ extension/ templates/` 无 `teamsmith-init` 命中；`scripts/` 无 `bootstrap-prompt` 命中；两条注入自测（往副本里塞引用）都会红
- **3.6** 18b 断言 + `logs/fingerprint-scope.txt`（两个方向）：基线 `412893857434` → 改 init SKILL.md 后 `412893857434`（**不变**）→ 再改日常 SKILL.md 后 `7d32d6fd513a`（**变**）；指纹输入仍是 `SKILL.md + extension/team-notify.ts`
- **3.7** 18b：三个模板（config/协议段/PM 提示词）无 `teamsmith-init` 命中；自建 fixture 里 `dispatch --print` 渲染出 `--skill <日常 skill 目录>` 且不含 `teamsmith-init`
- **4.1** 四处相等（见 3.1）+ 无第二个 CHANGELOG
- **4.3** 见下「门禁」
- **4.4** 见下「迁移对照」

## Flip evidence（改坏 → 红 → 还原，逐条真跑；日志在 `logs/flip-*.txt`）

| 项 | 改坏 | 红 | 还原 |
|---|---|---|---|
| 3.1 | `init SKILL.md` 的 `metadata.version` → `9.9.9` | `✗ 版本号四处一致（common/两个 SKILL/CHANGELOG）（期望 [1.40.0\|1.40.0\|1.40.0\|1.40.0]，实际 [1.40.0\|1.40.0\|9.9.9\|1.40.0]）` → `✓ 1454 ✗ 1` | `git checkout` 后绿（见下门禁） |
| 3.2 | `init SKILL.md` 的 frontmatter `name: teamsmith-init` → `name: teamsmith` | 第一段 skill-load 仍绿，**第二段红**：`✗ skill-load 失败（teamsmith-init）` + 详情 `name 不是 teamsmith-init：teamsmith`；附带 install 段两条红（两个同名 skill 的发现入口） | 同上 |
| 3.4 | 把 `organize multiple agents into a team` 追加回日常 description | `✗ description 交叉污染： daily-[organize multiple agents into a team]`（+ 沙箱正对照红）→ `✓ 1453 ✗ 2` | 同上 |
| 3.5 | 往 `skills/teamsmith/scripts/team` 追加一行注释含 `teamsmith-init` | `✗ 工具面引用了 init skill：…/scripts/team:119:# p16 flip probe: teamsmith-init` → `✓ 1454 ✗ 1` | 同上 |
| 3.6 | 见 `logs/fingerprint-scope.txt`：一「不变」一「变」（这条的翻转就是断言本身的双方向口径） | — | — |

另有一条**在工作过程中真实发生的** frontmatter 破环证据：init SKILL.md 初稿的 description 里带 `: `（YAML 普通标量不允许），
pi 自己的解析器当场报 `Nested mappings are not allowed in compact mappings`、加载 0 个 skill —— 这就是 3.2 那条断言存在
的理由；修法是把冒号换成破折号（提交 `a91b958`），修后 `name=teamsmith-init desc=800 字符 诊断=0`。

## 4.4 迁移对照：存量项目零改动（`logs/migration-compare.txt`，`bash migration-compare.sh` 可复跑）

两个 revision 都用 `git archive` 导出到**等长路径**的临时树（否则绝对路径长度差会污染「提示词 N 字」这类计数行），
各建同名 fixture 仓库（`fx`），跑 `init / doctor / task / add-agent / dispatch --print`：

```
== 逐命令对照：拆分前 37a1d7f vs 拆分后 ef9ebfe（都是 git archive 的干净树）==
--- init：IDENTICAL ✓
--- doctor：DIFF（只有 skill 版本 1.39.0 → 1.40.0，外加两个夹具各自的 RAM 读数与 commit 号）
--- task：IDENTICAL ✓
--- add：DIFF（只有那个夹具自己的 main commit 号）
--- dispatch：IDENTICAL ✓        ← 渲染出的启动命令与 worker 提示词逐字节一致
--- config.sh：IDENTICAL ✓       ← 没有新键
--- agents-section.md：IDENTICAL ✓ ← 注入 AGENTS.md 的协议段一字未改
```

即：存量项目既不需要改配置，也不需要改协议段或启动命令；唯一可见变化是版本号（发布预期）。

## 4.2 安装软链（**留给 PM**；本任务按边界不动 `~/.agents/`）

```sh
# PM 执行（<仓库> = <home>/Documents/syncthing/Work/Projects/pm-skills）
ln -s <仓库>/skills/teamsmith-init ~/.agents/skills/teamsmith-init
readlink ~/.agents/skills/teamsmith-init        # 期望：<仓库>/skills/teamsmith-init
bun skills/teamsmith/tests/skill-load.mjs ~/.agents/skills/teamsmith-init   # 期望：退 0，name=teamsmith-init
```

worker 侧已用**等价的临时目录**证明「穿软链可加载」（不改 `~/.agents/`）：

```
$ ln -s "$PWD/skills/teamsmith-init" /tmp/p16-agents/teamsmith-init
$ readlink /tmp/p16-agents/teamsmith-init
<home>/.../dev3/skills/teamsmith-init
$ bun skills/teamsmith/tests/skill-load.mjs /tmp/p16-agents/teamsmith-init
✓ pi 解析器加载成功：name=teamsmith-init desc=800 字符 诊断=0
  baseDir=/tmp/p16-agents/teamsmith-init        # 走的是软链路径，解析器跟随
```

当前 `~/.agents/skills/` 只有一条 `teamsmith -> …`（未动）。另外 `install.sh` 会**自动**把新 skill 一起装上
（它遍历 `skills/*/`，第 18 段实测：目标条目数 == 仓库真实 skill 目录数 = 2，无重名入口）。

## 门禁（`logs/` 里是全文）

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
✓ change/split-teamsmith-init-skill（含在 13 项里）
Totals: 13 passed, 0 failed (13 items)                     （rc=0）

$ bash skills/teamsmith/tests/smoke.sh                     # 全量（含真 tmux 舞台）
== 结果 ==  ✓ 1870  ✗ 0                                    （rc=0，01:51:24→01:59:4x）

$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
== 结果 ==  ✓ 1455  ✗ 0                                    （rc=0）
```

M23 的两个机制未动：私有 socket（`TMUX_TMPDIR`）与全量门禁互斥锁照旧生效（`SMOKE_PRIVATE_TMUX=1` 的逻辑与
`TMUX_TMPDIR` 段落一行未改；18b 是纯逻辑段，未新增 tmux 交互）。

全量 smoke 跑在代码提交 `ef9ebfe` 上；其后的两个提交只动文档（本报告 + `tasks.md` 打勾 + 日志），并在**最终 tip**
上重跑了 `openspec validate --all --strict`（13/13，`logs/openspec-final-tip.txt`）与 FAST smoke（✓1455/✗0，
`logs/smoke-fast-final-tip.txt`）以确认这两类文件不影响门禁。

## Deviations / 决策

- **init description 的 YAML 冒号**：初稿用 `toolkit: organize…` 让 pi 的解析器报错（见上），改为破折号；措辞与
  D7 的三短语/交接语义不变。这是 apply 期发现的、不违反 spec 的修正。
- **`skill-load.mjs` 期望 name 改为目录名推导**：任务书 3.2 要求「对两个目录各跑一遍」，而脚本原来硬编
  `teamsmith`；改为 `basename(skillDir)` 后两个目录共用一份加载器（旧调用 `bun tests/skill-load.mjs` 行为不变）。
- **18 段英文正文口径扩到 init skill 的 `references/`**：`bootstrap.md` 搬过去以后，若口径不扩，它就从「正文必须
  全英文」的守门范围里静默消失（D6 第 3 类「文档扫描段覆盖两个 skill」的同一条理由）；为此加了一条 init 侧 CJK
  翻转，证明范围不是空跑。
- **3.7 的 `dispatch --print` 用自建 fixture**：直接借 7 节的 `$REPO` 在 FAST 模式下不保证还能渲染（实测该处
  dispatch 会因工作树/分支状态被拒，`--skill` 断言会变成假红或假绿）；改成自建 `init → task → add-agent → 规范分支
  → dispatch --print` 的夹具，与模式无关，且仍然渲染**真实**启动命令。
- **CHANGELOG 位置**：按仓库既有惯例，`## v1.40.0` 插在 `## v1.39.0` 之前（版本解析取第一个 `##` — 第一个现在是
  v1.40.0）。观察（不在本任务边界内）：文件顶部的 `**未发布（… M3.2 …）**` 块仍是历史遗留，PM 可决定何时清理。
- **4.2 未勾**：见上，安装软链是 PM 的动作（worker 不动 `~/.agents/`）；tasks.md 里留了注记。

## Risks / 未验证

- **模型级路由**：两个 skill 都能被 pi 的解析器加载、description 词汇不重叠（有断言），但「模型看到两条 description
  时是否按预期把新项目路由到 init skill」只能由真实首次会话检验（E7 的分析 + 本任务的措辞约束是间接证据）。
- **旧会话**：`team_skill_hash` 不含 init 文本（已验证），所以拆分不会吵醒在跑的 PM；但已在跑的会话里缓存的
  description 仍是旧文本，要 `/reload` 才更新——这是既有机制，不是本 change 引入的。
- **init SKILL.md 的内容质量**：三条硬性拍点有断言；清单措辞（附录 A 的收编）是文字判断，没有语义测试。
- **`install.sh --copy` 模式**：新 skill 会被一起复制（第 18 段实测条目数与真实目录数相等）；未额外验证 copy 模式
  下 init 侧 `templates/` 的可执行位（那里没有可执行文件）。

## Next steps

1. PM：独立复验（`team review P16 --strong`）→ 本地合并 → 执行 §4.2 的软链 → 按流程归档 change（用户确认后）。
2. 合并后建议在 main 上跑一次 `/reload` 语义检查（`team version --check` 应报 1.40.0）以便在跑的会话切到新描述。
3. 可选：把 `CHANGELOG.md` 顶部那块「未发布」历史段落清理/归位（PM 独占，一行决策）。
