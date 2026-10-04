# P35 · README 安装示例 pin 修好 + 纳入版本一致性检查（机制，不是承诺）

```
task:    P35
agent:   dev
branch:  task/P35-readme-pin（local 模式：不 push；分支留在 .worktrees/dev，PM 复验后本地合并）
change:  -（anchor: none (infra)——文档版本 pin 与版本一致性检查工具面）
commits: 785a510（README pin @v1.40.0 → @v1.42.0）·
         ed75fff（smoke §11f 扩容：README pin 第六处断言）·
         fcb34fd（PUBLISH.md 发版清单加 README pin 同步条目）·
         <本报告>
status:  完成（FAST smoke ✓2302 ✗0；全量 smoke ✓2811 ✗0；openspec validate --all --strict 15/15；翻转证据齐）
```

## 0. Deliverables

| Path | What |
|---|---|
| `README.md` | §Install 的 4 处 `teamsmith@v1.40.0` → `@v1.42.0`（与 `package.json` version 对齐） |
| `skills/teamsmith/tests/smoke.sh` | §11f 版本一致性检查扩容：README pin 是第六个版本落点，过期即红并点名两处（README 行号 + package.json）；一处找不到也红（检查不许空转） |
| `docs/team/PUBLISH.md` | §2 前置第 1 条：发版时同步 README 示例 pin（附对照命令），与 §11f 互相印证；顺带纠正同条里已过期的「§11f 只钉前两处」（M38 起钉五处） |

边界：未碰版本号本身、`install.sh`、安装语义、PM 台账（PUBLISH.md 除外——任务书明授）。

## 1. 改前 / 改后的 README 行

改前（`git show HEAD~3:README.md`，行号为当时值）：

```
38:pi install git:git@github.com:Track07-cda/teamsmith@v1.40.0      # user level: every project
39:pi install -l git:git@github.com:Track07-cda/teamsmith@v1.40.0   # project level: recorded in .pi/settings.json
44:- The `git@github.com:` form (or `ssh://git@github.com/Track07-cda/teamsmith@v1.40.0`) uses your SSH key. The HTTPS
45:  shorthand `git:github.com/Track07-cda/teamsmith@v1.40.0` only works for a public repository — while this one is
```

改后（当前 tip，`grep -n 'teamsmith@v' README.md`）：

```
38:pi install git:git@github.com:Track07-cda/teamsmith@v1.42.0      # user level: every project
39:pi install -l git:git@github.com:Track07-cda/teamsmith@v1.42.0   # project level: recorded in .pi/settings.json
44:- The `git@github.com:` form (or `ssh://git@github.com/Track07-cda/teamsmith@v1.42.0`) uses your SSH key. The HTTPS
45:  shorthand `git:github.com/Track07-cda/teamsmith@v1.42.0` only works for a public repository — while this one is
```

依据：`package.json` `"version": "1.42.0"`；`git tag --sort=-v:refname | head -1` → `v1.42.0`。
两条 `pi install` 示例之外，同节里另外两种拼写形式（`ssh://…`、`git:github.com/…`）一并对齐。

## 2. 机制：§11f 第六处断言

位置：`skills/teamsmith/tests/smoke.sh` §11f，紧跟 M38 的「版本号五处一致」断言之后。
判据（宽于任务书字面的 `git:git@github.com:…` 一种形式——README 里**任何** `teamsmith@v<X.Y.Z>` 都必须等于
`package.json` 的 version，这样无论文档写哪种安装形式都过期不了）：

```bash
README_MD="$(dirname "$SKILL_DIR")/../README.md"
README_PINS="$(grep -n -o 'teamsmith@v[0-9][0-9.]*' "$README_MD" 2>/dev/null || true)"
README_PIN_BAD=""
while IFS= read -r _p35; do
  [ -n "$_p35" ] || continue
  [ "${_p35##*@v}" = "$PKG_V" ] || README_PIN_BAD="$README_PIN_BAD README.md:${_p35%%:*}=@v${_p35##*@v}"
done <<< "$README_PINS"
if [ -z "$README_PINS" ]; then
  bad "README 安装 pin：$README_MD 里找不到 teamsmith@v<X.Y.Z> 示例（检查本身不许空转）"
elif [ -n "$README_PIN_BAD" ]; then
  bad "README 安装 pin 与 package.json（version=$PKG_V）不一致：$README_PIN_BAD —— 同步 README.md 这些行（发版清单见 docs/team/PUBLISH.md §2）"
else
  ok "README 安装 pin 与 package.json 一致（…处 @v$PKG_V）"
fi
```

与 §11f 其它版本读数一样读**真实仓库**文件（`$(dirname "$SKILL_DIR")/..`），不是 /tmp 夹具仓库——
这正是版本一致性检查的语义：查仓库内容，不查夹具行为。
逻辑单测（改 smoke 前）：正例 BAD 为空；负例（模拟 @v0.0.1）点名全部 4 行。

## 3. 翻转证据（红 → 还原 → 绿）

① 改坏：`sed -i 's/teamsmith@v1\.42\.0/teamsmith@v0.0.1/g' README.md`（4 处全坏，未提交）。

② 红（`TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null`，原始输出）：

```
  ✓ 版本号五处一致（common/两个 SKILL/CHANGELOG/package.json）
  ✗ README 安装 pin 与 package.json（version=1.42.0）不一致： README.md:38=@v0.0.1 README.md:39=@v0.0.1 README.md:44=@v0.0.1 README.md:45=@v0.0.1 —— 同步 README.md 这些行（发版清单见 docs/team/PUBLISH.md §2）
…
== 结果 ==  ✓ 2301  ✗ 1
EXIT=1
```

全场唯一红就是新断言，且点名两处（README 四个行号 + package.json 的 version=1.42.0）。

③ 还原：`git checkout -- README.md` → `git diff --exit-code` 为空（树与绿基线逐字节一致）。

④ 绿（同一条 FAST smoke 重跑，原始输出）：

```
  ✓ README 安装 pin 与 package.json 一致（4 处 @v1.42.0）
…
== 结果 ==  ✓ 2302  ✗ 0
smoke 全绿
EXIT=0
```

## 4. Acceptance 实跑

任务书第一条里的 `<版本一致性那个脚本>` 落实为 `skills/teamsmith/tests/smoke.sh`——版本一致性检查没有独立脚本，
就是 smoke 的 §11f（纯逻辑段，FAST 模式照跑）。已核实全仓库只有 smoke.sh 含该检查。

| 命令 | 结果 |
|---|---|
| `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null` | ✓ 2302 ✗ 0，EXIT=0（基线绿与还原绿各跑一次，均绿） |
| 同上，README pin 改坏为 @v0.0.1 | ✓ 2301 ✗ 1，EXIT=1（红的就是新断言，见 §3） |
| `PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict` | 15 passed, 0 failed，EXIT=0 |
| `bash skills/teamsmith/tests/smoke.sh </dev/null`（全量） | ✓ 2811 ✗ 0，EXIT=0，含 `✓ README 安装 pin 与 package.json 一致（4 处 @v1.42.0）` |

## 5. PUBLISH.md 条目

§2 前置第 1 条改为「版本对齐（五处 + README 示例 pin）」：五处由 §11f 全钉，README pin 自 P35 起同样进 §11f
（发版忘同步 → 门禁红并点名行号），并给发版前第三条对照命令
`grep -n -o 'teamsmith@v[0-9.]*' README.md`。清单与检查互相印证：清单告诉人发版要做什么，检查保证忘了做会红。
同一条里「smoke §11f 只钉前两处」的说法在 M38（第五处 package.json）后已过期，随本次一并纠正。

## 6. 偏差说明

- 检查口径比任务书字面宽：任务书点名 `git:git@github.com:…` 一种形式，实现覆盖 README 里**所有**
  `teamsmith@v<X.Y.Z>`（当前 4 处、3 种形式）。理由：否则换种写法就能绕过检查，「不再过期」不成立。
- 无 BLOCKED 项；未越界改任何未授权路径；local 模式不 push。
