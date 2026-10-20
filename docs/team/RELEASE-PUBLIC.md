# 发布清单（teamsmith）

> **这份文件是可执行清单，不是历史记录。** 改写之前那份"快照发布"的长篇记录在首次发布时留在仓外账本里；
> 2026-10-04 用户决定**把本地仓库改写（内容 + 历史）后作为公开仓**，此后**本仓就是公开仓的真源**，
> 发布模型随之改变（见 `docs/team/DECISIONS.md` 的 D94 / D97）。任何一步都不是"可以顺手做"的：带
> ⚠️ 的步骤不可逆，必须由用户逐条点头后再执行。

## 0. 发布模型（一句话）

本仓的 `main` **就是**公开仓的 `main`。发布 = **六处版本落点 → 提交 → 打 tag → 推 `public` 远端
（`main` 与**本次那一个 tag**）→ npm 发布 → 发布后验证**。没有"白名单导出一棵快照树"这一步：`git push public main`
推的就是本仓的历史本身。

| 面 | 内容 | 进不进公开仓 |
|---|---|---|
| 产品面 | `skills/` `bin/` `install.sh` `ci/` `.github/` `openspec/specs/` `README.md` `LICENSE` `package.json` | 进（被跟踪即公开） |
| 可读账本层 | `docs/team/*.md`、`docs/team/ledger/*.tsv`、`openspec/changes/archive/**` | 进 —— **写下去即公开** |
| 发布工具 | `docs/team/tools/release-check.sh`、`docs/team/tools/publish-public.sh`、本文件 | 进 |
| 证据层 | `docs/team/reports/<ID>-<agent>/**`、`docs/team/inbox/`、`.pi/**`、`.worktrees/**` | **不进**（`.gitignore` 挡住；只把报告正文 `docs/team/reports/<ID>-<agent>.md` 放进来） |

## 1. 前置（发布前必须为真）

- [ ] 在**冻结克隆 + 钉死容器**里跑过完整门禁，且是在最终 tip 上：
  ```bash
  rm -rf /tmp/mile && git clone -q . /tmp/mile && cd /tmp/mile
  distrobox-host-exec podman run --rm --pid=host --cgroups=enabled --userns=keep-id -e HOME=/tmp \
    -v /tmp/mile:/work -w /work localhost/teamsmith-gate:local \
    bash -c 'git config --global --add safe.directory "*"; openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh </dev/null'
  # 期望：validate 全过；== 结果 == ✓ N ✗ 0；smoke 全绿
  ```
- [ ] 发布前在**钉死镜像**里跑一次参考读数（只参考：没有阈值，不阻塞合并），把打印的数字（含它自述的环境）
      贴进当次发布记录 `docs/team/reviews/release-<version>.md`（就是 `release-0.3.0.md` 那种文件，发布时新建/追加）：
  ```bash
  distrobox-host-exec podman run --rm --pid=host --cgroups=enabled --userns=keep-id -e HOME=/tmp \
    -v "$PWD:/work:ro" -w /work localhost/teamsmith-gate:local \
    bash -c 'bash skills/teamsmith/tests/perf.sh --in-container --tree /work'
  # 退出码：0 = 读到了 / 3 = 建立失败或拿不到性能锁（没结论）；没有判定码
  ```
- [ ] `bash docs/team/tools/release-check.sh` —— 只该剩**一条诚实失败**：`HEAD 领先最新 tag v<上一版> N 个提交`；
      其余全绿。名单那条如果显示"跳过"，把原因写进发布记录（名单是仓外文件，检出里通常没有）。
- [ ] `bash docs/team/tools/release-check.sh --self-test` —— **4/4**（四条变异都被抓住）。
- [ ] ⚠️ 用户对"推 `public`"这一不可逆步骤的**明确授权**（逐条点头；PM 不代批）。

## 2. 版本落点（六处）+ CHANGELOG

```bash
V=0.1.2        # 本次要发的版本号；六处落点必须统一
sed -i "s/\"version\": \"[0-9.]*\"/\"version\": \"$V\"/" package.json
sed -i "s/TEAM_VERSION=\"[0-9.]*\"/TEAM_VERSION=\"$V\"/" skills/teamsmith/scripts/lib/common.sh
sed -i "s/version: \"[0-9.]*\"/version: \"$V\"/" skills/teamsmith/SKILL.md skills/teamsmith-init/SKILL.md
# ↑ 两个 SKILL 的 front-matter 版本是**带引号**的：门禁里的解析器（smoke.sh 的 DOC_V/INIT_V）只认
#   `version: "X"` 这一形状。不带引号写会静默把这两处读成空值，门禁那条「版本号五处一致」就会红。
sed -i "s/v[0-9]\+\.[0-9]\+\.[0-9]\+/v$V/g" README.md          # 四处 @v pin
# CHANGELOG：在 `## v<上一版>` 之前插入 `## v$V · <日期>` 段 —— 写**真摘要**（这一版改了什么），不是占位
$EDITOR skills/teamsmith/CHANGELOG.md
bash docs/team/tools/release-check.sh    # 版本段此时应显示六处一致 = $V；tag 段仍会红（tag 还没打）
```

顺序要紧：**先落点、再提交、再打 tag** —— tag 必须打在"落点已经提交"的那个提交上。

## 3. 提交与 tag（D97：产品提交与账本提交**分两次推**）

```bash
git add package.json README.md skills/teamsmith/SKILL.md skills/teamsmith-init/SKILL.md \
        skills/teamsmith/CHANGELOG.md skills/teamsmith/scripts/lib/common.sh
git commit -m "chore(release): v$V"        # 产品提交：**不带** [skip ci]（否则一次推里的 CI 全被跳过，D97）
git tag -a "v$V" -m "teamsmith v$V"
bash docs/team/tools/release-check.sh      # 期望：全绿（含"HEAD 就在 v$V 上"）
bash docs/team/tools/release-check.sh --self-test   # 期望：4/4
```

账本提交（BOARD / DECISIONS / 报告 / 本清单的更新）**单独提交**、消息带 `[skip ci]`，并且**与产品提交
分两次 push** —— GitHub 只看一次推送的**末端**提交消息决定是否跳过，末端带 `[skip ci]` 会把整批吞掉。

## 4. 推公开远端（⚠️ 不可逆；需用户点头）

```bash
V=v0.2.0                              # ← 本次发布的 tag（写成变量，别用 --tags）
git push public main "$V"             # public 远端：见 `git remote -v`
# ⚠️ 不要用 `git push public main --tags`：本仓还留着 29 个**改写前**的旧 tag（v1.31.0…v1.42.0），
#    它们指向的历史**不在**现在的 main 上；`--tags` 会把它们连同那段旧历史（含当时的账本）一起推到
#    公开仓——实测 `git push --dry-run public main --tags` 会列出这 29 个 `[new tag]`。只推本次的 tag。
#    验证：`git push --dry-run public main "$V"` 只应出现 `main -> main` 与 `$V -> $V`。
bash docs/team/tools/release-check.sh --remote
# 期望：公开远端与本地 main 同点（落后 N 个提交 → 红，先查是不是推错远端/推漏了）
```

绝不 `--force`、绝不改写已经推出去的历史：公开仓一旦有人 clone，重写历史就是让别人的仓库失联。

## 5. npm 发布（⚠️ 不可逆）

```bash
npm publish --access public           # 有 2FA 时：npm 会打暂存包，去网页批准
npm view teamsmith version            # 复核：应等于 $V
```

## 6. 发布后验证（发布跑完**当天**做完，输出贴进发布记录）

```bash
V=0.1.2; rm -rf /tmp/rel && git clone -q --branch "v$V" https://github.com/<owner>/teamsmith.git /tmp/rel
cd /tmp/rel
# 路线 A：仓库自带安装器
HOME=/tmp/rel-home bash install.sh && ls -l /tmp/rel-home/.agents/skills/teamsmith/SKILL.md
# 路线 B：npm 全局包
npm i -g --prefix /tmp/rel-npm teamsmith && /tmp/rel-npm/bin/team help
# 路线 C：装进一个新项目
rm -rf /tmp/rel-proj && mkdir -p /tmp/rel-proj && cd /tmp/rel-proj && git init -q -b main . \
  && /tmp/rel-npm/bin/team init && ls -l .pi/skills/
/tmp/rel-npm/bin/team version --check     # 版本自检：磁盘 vs 已加载
```

三条路线都要"skill 就位 + `team help` 退出 0"，任何一条失败就地回滚（撤 tag、撤 npm 版本），别继续往下走。

## 7. 红侧：发布检查必须**能红**（发之前各做一次，输出留档）

- README 的一处 pin 改错 → `release-check.sh` 点名 `README 的 pin … 与 package.json … 不一致`
- 树里塞一个 `skills/__pycache__/x.pyc` → 泄漏扫描点名 `[file] 文件名形状`
- `install.sh` 改成"两个 skill 都装成同一个名字" → 安装路线点名 `install.sh：… 缺失或内容与源树不一致`
- `--remote` 指到一个落后的远端（可拿临时裸仓当替身）→ 点名 `公开远端落后本地 main N 个提交`

## 8. 绝不做

- 不把证据层（`docs/team/reports/*/`、`.pi/`、`.worktrees/`、`node_modules/`）提交进树 —— 它是**永久公开**的。
- 不把真实项目名 / 家目录 / 内网地址 / 凭据写进仓内任何文件（含本清单）：需要举例就用 `<peer>` / `<home>` /
  `<user>` / `<internal>` 占位符。`skills/teamsmith/tests/ledger-ban.sh` 每次门禁扫 `docs/team/**/*.md`，
  `docs/team/tools/publish-public.sh` 扫整棵被跟踪的树（含产品面）。
- 不 force-push、不改写历史、不删 tag、不打"发布后再补"的补丁；**不用 `--tags`**（见第 4 节的警告：旧 tag 会把改写前的历史带进公开仓）。
- 不在产品提交里混账本改动，也不把两类提交塞进同一次 push（D97）。
