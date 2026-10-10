# P229 · 发布就绪：把发布工具与清单修到改写后的形状

task: P229
agent: dev-bob
phase: apply
category: code
change: -
anchor: none (infra) — 发布工具与发布清单的布局修复，不改产品行为、不新增能力
branch: task/P229-release-readiness
deps: -

## 背景与失败现场（PM 2026-10-10 实测）

2026-10-04 仓库做过 `git filter-repo` 改写（产品面 + 设计记录 + 账本可读层留在仓内；报告证据包与维护工具被 ignore），
但**发布工具是改写前写的**，路径与发布模型都对不上了。PM 今天两条实测：

```
$ bash ../pm-skills-ledger/team/tools/release-check.sh
  ...
  ✗ 导出/扫描失败 —— bash: docs/team/tools/publish-public.sh: No such file or directory
  ✗ npm pack 失败      ✗ install.sh 失败      ✗ team init 失败
  == 结果 == 通过 7 · 失败 4   → 发布前检查未通过
$ bash ../pm-skills-ledger/team/tools/release-check.sh --self-test
  ✗ 版本错配没被抓住（ vs ）
  == 自测结果 == 抓住 3 · 漏掉 1 → 自测失败
```

根因不是产品缺陷，是工具过期与位置漂移：

- `.gitignore:31,32` 明确 ignore `docs/team/tools/` 与 `docs/team/RELEASE-PUBLIC.md` → 工具**不在 git 里**，没人跑它，坏了两周无人知；
- `release-check.sh` 第 35/41/44/81 行仍按仓内路径调用 `docs/team/tools/publish-public.sh`（该路径在本仓里被 ignore，工具本体只在仓外 `../pm-skills-ledger/team/tools/`）；
- `publish-public.sh` 代表的是**改写前的快照发布模型**（白名单导出成"每次发布一个提交"）。而用户 2026-10-04 已定：**改写后的本仓即公开仓的真源**，发布 = 版本落点 + 提交 + 打 tag + 推 `public` 远端（`git@github.com:Track07-cda/teamsmith.git`）+ npm 发布；公开仓也带可读账本层（`docs/team/*.md`、`openspec/changes/archive/**`）。快照导出那套已不再是发布载体。

现状数据（供对照）：`main` 领先 `v0.1.1` **101** 个提交，产品面只动 10 个文件（CI 现场收集、公开树门禁测试、README/openspec 参考更正），**运行时行为未变**；六处版本落点当前全是 `0.1.1`。

## 目标

1. **让发布检查在新形状下有意义且能红**：`release-check.sh` 重写为对"改写后 + 公开仓即真源"的检查；`--self-test` 的四条变异**全部**要被抓（现在是 3/4）。
2. **工具进仓，别再悄悄腐烂**：把两件工具移到仓内 `docs/team/tools/`（跟踪），并去掉 `.gitignore` 里那两条；`RELEASE-PUBLIC.md` 同样进仓（改写为新的发布清单）。
   `publish-public.sh` 里的**禁用名单/例外清单必须外置**（今天实测它在仓内跟踪会命中账本禁令：`rg -c -f .pi/team/forbidden-names.txt` = 1 命中；`release-check.sh` = 0）。名单继续放仓外 `.pi/team/forbidden-names.txt`（已存在，且被 ignore），脚本用参数读它，缺失时**可见跳过**（不是通过）。
3. **把发布清单改成能照着跑的东西**：六处版本落点 → 提交（产品提交**不带** `[skip ci]`，账本提交带，且分两次推，D97）→ 打 tag → `git push public main --tags` → npm 暂存发布 + 网页 2FA 批准 → 发布后验证（新克隆、三条安装路径、`team version --check`）。
4. **两条合法发布路径都要有断言**：发布前（版本还没动）应当**只报一条**诚实的失败「HEAD 领先最新 tag N 个提交」，其他项全绿；在临时 clone 里做完版本落点 + 打 tag 后应当**全绿**。这两面都要有命令与输出。

## 边界

- 不改产品行为：`skills/teamsmith/scripts/**`、`extension/**`、`templates/**`、`bin/**` 一律不动（`ci/collect-scene.sh` 也不动）。
- 不推任何远端、不建 tag、不清远端、不改 npm 状态；这些是不可逆步骤，由用户在执行时刻逐条点头。
- 不改 `docs/team/DECISIONS.md`（PM 单写者）；不动其它席位的分支与证据。
- 不把真实项目名/家目录/内网地址写进仓内任何文件（含清单文档）；需要举例就用 `<peer>` / `<home>` / `<internal>`。
- **不要**把 `release-check.sh` 做成"永远通过"：它必须能对以下任一情况变红——版本三方不一致、最新 tag 不是 HEAD 祖先、公开远端落后于 main、泄漏扫描命中禁用形状、安装路线失败。

## 验收命令（每条都要在报告里贴真实输出）

```bash
# 1. 自测：四条变异全部被抓住
bash docs/team/tools/release-check.sh --self-test            # 期望 4/4

# 2. 发布前形状：只报一条诚实失败（HEAD 领先最新 tag），其余全绿
bash docs/team/tools/release-check.sh                        # 期望失败项恰好 1 条且是版本/标签那条

# 3. 临时 clone 里做完整发布演练（不改主仓、不推远端）
rm -rf /tmp/p229-dry && git clone -q . /tmp/p229-dry && cd /tmp/p229-dry
#    六处版本落点改成 0.1.2 + CHANGELOG 段 + git commit + git tag -a v0.1.2
bash docs/team/tools/release-check.sh                        # 期望全绿（含"HEAD 就在 v0.1.2 上"）

# 4. 红侧：故意把 README 的一处 pin 改错 → 检查必须变红并点名
#    仍要在 /tmp/p229-dry 里做；改回后恢复全绿

# 5. 账本禁令与记录面
bash skills/teamsmith/tests/ledger-ban.sh --names-file .pi/team/forbidden-names.txt
git diff --check && git status --short
```

另有两条记录面检查（走既有工具）：`bash skills/teamsmith/tests/section-select.sh --paths docs/team/RELEASE-PUBLIC.md docs/team/DECISIONS.md`（若选段为 NONE 也照实记录）与 `bash skills/teamsmith/tests/spec-refs.sh --check`。

## 交付

- 仓内 `docs/team/tools/{release-check.sh,publish-public.sh}`（跟踪；禁用名单外置）、`docs/team/RELEASE-PUBLIC.md`（新清单）、`.gitignore` 相应两条去掉。
- `docs/team/reports/P229-dev-bob.md`：失败现场复现 → 根因 → 改动清单 → 上面五条命令的真实输出（含红侧）→ 遗留与未解问题；证据包按 D94 放仓外 `pm-skills-ledger/team/reports/P229-dev-bob/`。
- 不 push、不合 main、不建 tag；做完按协议通知 PM（`team notify pm`）。
