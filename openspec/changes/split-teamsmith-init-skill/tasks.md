# split-teamsmith-init-skill · tasks

## 1. 建 init skill 骨架（capability: init-skill，R1/R4）

- [x] 1.1 `git mv skills/teamsmith/references/bootstrap.md skills/teamsmith-init/references/bootstrap.md`，
  `git mv skills/teamsmith/templates/bootstrap-prompt.md.tmpl skills/teamsmith-init/templates/bootstrap-prompt.md.tmpl`。
  验证：`test -f skills/teamsmith-init/references/bootstrap.md && test ! -e skills/teamsmith/references/bootstrap.md`
  （模板同口径）
- [x] 1.2 写 `skills/teamsmith-init/SKILL.md`：frontmatter（`name: teamsmith-init`、description 按 design D7、
  `metadata.version` 跟随 TEAM_VERSION）、正文三拍（问答清单 → `scripts/team bootstrap` → 交接句），≤100 行，
  问答清单内容按附录 A 收编 5 个散点。验证：`wc -l` ≤100；`grep -c 'scripts/team bootstrap' ≥1`；
  `grep -c 'teamsmith' ≥1`（交接句）
- [x] 1.3 修跨 skill 互链：`bootstrap.md` 里的 `migration.md` 链接改 `../../teamsmith/references/migration.md`；
  `skills/teamsmith/references/migration.md:77` 的 bootstrap.md 引用改
  `../../teamsmith-init/references/bootstrap.md`。验证：grep 两处新路径存在、旧相对路径无残留
- [x] 1.4 `workflows.md` §A 缩成一行指路（指向 teamsmith-init；PM 评审若砍 D2 则跳过本项并在报告注明）。
  验证：`grep -c 'teamsmith-init' skills/teamsmith/references/workflows.md` ≥1

## 2. 日常 skill 瘦身（capability: init-skill，R2/R3）

- [x] 2.1 删 `skills/teamsmith/SKILL.md` 的 `## New project: one command` 与 `## 30-second start` 两节，
  在原位留一行指路（新项目的初始化走 teamsmith-init）。
  验证：`grep -cE '^## (New project|30-second start)' skills/teamsmith/SKILL.md` = 0 且指路行在
- [x] 2.2 §Deeper reading 表的 `references/bootstrap.md` 行改为 init skill 指路行。
  验证：`grep -n '](references/bootstrap.md)' skills/teamsmith/SKILL.md` 无命中
- [x] 2.3 改两条 description：日常侧删 3 个 init 短语、加指路句；init 侧收编 3 个短语 + 交接语义
  （措辞按 design D7）。验证：python 提取两条 description——三条 init 短语只在 init 侧、
  `dispatch tasks to worker agents`/`run the patrol`/`review an agent's work independently` 只在日常侧、
  两条长度均 ≤1024

## 3. smoke 与测试重排（capability: init-skill，R3/R4/R5/R6）

- [x] 3.1 版本断言（smoke.sh:3210-3211，现状「common/SKILL/CHANGELOG 三处一致」）扩成「四处一致」
  （TEAM_VERSION = 两个 SKILL.md 的 metadata.version = CHANGELOG 顶部）。
  验证：翻转——临时改 init SKILL.md 版本号 → 该断言红 → 还原后绿
- [x] 3.2 §0b skill-load 对 `$SKILL_DIR` 与 `$SKILL_DIR/../teamsmith-init` 各跑一遍。
  验证：smoke 日志出现两段 skill-load 输出；故意写坏 init frontmatter → 第二段红 → 还原
- [x] 3.3 文档扫描段（14b 等，smoke.sh:3642-3730）扫描清单扩到两个 skill；bootstrap.md 专属断言
  （smoke.sh:4840/4848）路径迁到 `skills/teamsmith-init/references/bootstrap.md` 并断言跨 skill 互链。
  验证：全量 smoke 绿；把 bootstrap.md 里的 migration 链接改回旧相对路径 → 断言红 → 还原
- [x] 3.4 新增「description 无交叉污染」断言（口径 = 2.3 的三+三短语清单）。
  验证：翻转——把一条 init 短语塞回日常 description → 断言红 → 还原
- [x] 3.5 新增结构断言：`find skills/teamsmith-init -maxdepth 1 -type d` 无 scripts/extension/tests；
  `grep -rn teamsmith-init skills/teamsmith/scripts/ skills/teamsmith/extension/ skills/teamsmith/templates/*.tmpl`
  无命中；`grep -rn bootstrap-prompt skills/teamsmith/scripts/` 无命中。
  验证：翻转——在 scripts/ 某文件临时加一行注释含 teamsmith-init → 断言红 → 还原
- [x] 3.6 新增指纹范围断言：fixture 复制两个 skill 目录、source 库函数，改 fixture 的 init SKILL.md →
  `team_skill_hash` 不变；改 fixture 的日常 SKILL.md → 变（翻转证明断言非空跑）。
  验证：两个方向各跑一次，输出一「不变」一「变」
- [x] 3.7 新增「存量项目零改动」断言：fixture 项目 `team dispatch … --print` 渲染的启动命令含
  `--skill <teamsmith 目录>` 且不含 `teamsmith-init`；config.sh.tmpl / AGENTS.section.md.tmpl /
  pm-prompt.md.tmpl 无 `teamsmith-init` 命中。验证：smoke 绿 + 3.5 的 grep 兜底

## 4. 发布与安装（capability: init-skill，R5/R6）

- [x] 4.1 随本次发布 bump `TEAM_VERSION`（具体号以 apply 任务书为准），两个 `metadata.version` 跟随；
  CHANGELOG 在 `skills/teamsmith/CHANGELOG.md` 记一条（init skill 无 changelog）。
  验证：`test ! -e skills/teamsmith-init/CHANGELOG.md` + 3.1 的三方相等断言绿
- [ ] 4.2 安装软链（形态 A）：`ln -s <仓库>/skills/teamsmith-init ~/.agents/skills/teamsmith-init`。
  **（P16 交回 PM：worker 不动 `~/.agents/`。命令与预期 `readlink` 见 `docs/team/reports/P16-dev3.md` §4.2；
  等价的临时目录探针已在报告里给出：穿软链 `skill-load.mjs` 退 0。）**
  验证：`readlink ~/.agents/skills/teamsmith-init` 指向仓库目录，
  且 `bun skills/teamsmith/tests/skill-load.mjs ~/.agents/skills/teamsmith-init` 退 0（穿软链可加载）
- [x] 4.3 全量门禁（非 FAST）：`PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict` 与
  `bash skills/teamsmith/tests/smoke.sh` 全绿，输出尾部进报告（本项需要真 tmux 舞台，不可 FAST 替代）
- [x] 4.4 迁移期承诺核对：报告附「既有 fixture 项目流程（init/doctor/dispatch --print）逐命令对照
  拆分前后输出」一节，证明存量项目零改动（R6）

## 附录 A · init SKILL.md 问答清单大纲（1.2 的内容源，收编 E7 §Q3 的 5 个散点）

有序清单的条目与出处：

1. **前置体检**：git 仓库 ≥1 commit、tmux 在场、`team doctor` 全绿（magic-context / OpenSpec / JS runtime /
   bash≥4）——出处：SKILL.md §Requirements + bootstrap.md「What the PM does afterwards」
2. **身份与名册**：session 名、PM 窗口、名册、每 agent 模型、`TEAM_MODEL_LIMITS`、adapter 四键（非 Pi 时）——
   出处：config.sh.tmpl 注释
3. **门禁与安装**：`TEAM_GATES`（验收 pass/fail 的命令）、`TEAM_INSTALL_CMD`、VCS 模式（local/remote 措辞）、
   `TEAM_PULSE_INTERVAL`——出处：bootstrap-prompt.md.tmpl §2 + config.sh.tmpl 注释
4. **文档骨架落地**：ROADMAP（目标/可执行里程碑/非目标）、OWNERSHIP（目录归属）、AGENTS.md 项目红线——
   出处：bootstrap-prompt.md.tmpl §2
5. **跑 bootstrap**：`bash <teamsmith>/scripts/team bootstrap [--agents …]`（幂等；`--print` 先看计划）→
   `team doctor` 复检 → `openspec init --tools pi`（必需依赖，生成阶段命令）——出处：bootstrap.md +
   workflows.md §A
6. **交接**：「日常运转读 teamsmith」——PM loop / digest / pulse 从 `skills/teamsmith/SKILL.md` 开始——
   出处：SKILL.md §New project 的指路语义
