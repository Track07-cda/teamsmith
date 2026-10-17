# tmp-root-on-disk · tasks

阶段口径：**apply** 由收到本 change 的席位完成（每条可判声明都要有夹具与红侧，改前/改后各一次实测）；
**verify** 由**另一个**席位（与 apply 作者不同，dispatch 的自验守卫会拦）在独立克隆上重跑下表全部场景与三条红侧。
本文件不是规格；合同文本在 `specs/{verification,dispatch,watchdog}/spec.md`（4 MODIFIED + 1 ADDED）。

写集（apply 需要逐条明授；未授 → `BLOCKED:` 交回 PM）：

- `skills/teamsmith/scripts/lib/common.sh`（解析器 + `team_disk_label`/`team_disk_remedy`/`team_capacity_line` 改用解析器；
  inotify 探针与 `teamsmith-lock-*` 模板）
- `skills/teamsmith/scripts/lib/cmd-agents.sh`（地板判的路径 + 不可用根的阻塞项）
- `skills/teamsmith/scripts/lib/cmd-status.sh`（doctor 余量行）
- `skills/teamsmith/scripts/lib/cmd-watch.sh`（面板数据读）
- `skills/teamsmith/scripts/lib/cmd-review.sh`（队列标记 / 合并临时目录模板）
- `skills/teamsmith/scripts/lib/gate-lock.sh`（只读出去给医生行的发布路径；**路径与伴生锁不动**）
- `skills/teamsmith/scripts/lib/cmd-config.sh`（schema 行）、`skills/teamsmith/templates/config.sh.tmpl`（键行）
- `skills/teamsmith/scripts/panel/src/strings/{zh,en}.ts` + **重建** `skills/teamsmith/scripts/panel/panel.js`
- `skills/teamsmith/tests/lib/tmp-root.sh`、`skills/teamsmith/tests/tmp-hygiene.sh`、`skills/teamsmith/tests/smoke.sh`、
  `skills/teamsmith/tests/config-cli.sh`、`skills/teamsmith/tests/section-budgets.tsv`、新增翻转夹具
- `skills/teamsmith/references/{config,troubleshooting,migration}.md`、`skills/teamsmith/CHANGELOG.md`

不碰：门禁锁的发布路径/伴生锁/排队上限（P287 的合同）、`TEAM_SMOKE_FAST` 分层、清扫器的候选谓词与占用证明、
`team review` 的判定词表与退出码、`.github/workflows/gates.yml`（Out of scope）、`TEAM_NOTIFY_LOG` 的默认值（D9）。

## 0 冻结与投影

- [ ] 0.1 读 PM 的提案复核 `reviews/tmp-root-on-disk-proposal.md`，把裁定点 D1–D8 的结论摘进报告；与提案不同的裁定按其
  改写判定与场景（D1 若裁字面顺序，则先把 §1 的 84 处隔离站点与 12 处 scenario 的迁移列成清单再动手；D2/D3/D5/D6/D7 若改判，
  按裁定改 `design.md` §2–§7 与 delta 里对应的句子）。三条红侧的方向与「不可用根不回落」不变。
- [ ] 0.2 独立树投影自证：`cp -a openspec <scratch>/openspec && (cd <scratch> && openspec validate --all --strict
  && openspec archive -y tmp-root-on-disk && openspec validate --all --strict)` 必须绿；逐条核对 4 条 MODIFIED 的既有正文与
  既有 scenario **逐字保留**、ADDED 的标题与三条 scenario 齐全。
- [ ] 0.3 冻结**改动前**基线并抄进报告：`smoke.sh --select 40`、`--select 3,6b`、`--select 34,34c,34d` 的 ✓/✗ 计数与用时；
  `tmp-hygiene.sh --status` 的完整输出（解析出的根、家族目录数、无 marker 的根数）。

## 1 解析器（一处实现）

- [ ] 1.1 `team_tmp_root` / `team_tmp_root_source` / `team_tmp_root_default` / `team_tmp_root_stat_path` /
  `team_tmp_root_usable` 落在 `scripts/lib/common.sh`；顺序 `TMPDIR` → `TEAM_TMP_ROOT` → 默认；默认 `/var/tmp/teamsmith-<ns>`
  （`/var/tmp` 可写时）否则 `/tmp`；相对路径 / 空串 → 具名失败；纯函数、不创建。证据：四条顺序的实测（四种环境组合各一行输出）。
- [ ] 1.2 分歧行：两者都设且不同 → 一行「谁赢了、另一个没用」；同一进程只印一次。证据：两种组合的输出。
- [ ] 1.3 只读面的祖先判据：`team_tmp_root_stat_path` 在默认根不存在时给最近的存在的祖先，且**不创建**。证据：删掉默认目录
  后 `team doctor` / `--status` 的输出（目录仍不存在）。
- [ ] 1.4 调用点归口：`cmd-agents.sh`（地板路径）、`common.sh`（label/remedy/capacity/inotify 探针/`teamsmith-lock-*`）、
  `cmd-status.sh`、`cmd-watch.sh`、`cmd-review.sh`、`smoke.sh`、`tmp-hygiene.sh`、`tmp-root.sh` 全部改走解析器；
  `${TMPDIR:-/tmp}` 在 `scripts/**` 与 `tests/**` 里只剩解析器自己的定义（`--lint` 的第二条规则会钉住）。
  证据：`grep -rn 'TMPDIR:-/tmp' skills/teamsmith/scripts skills/teamsmith/tests` 的剩余清单（只允许解析器与创建者的转调）。

## 2 默认值与创建

- [ ] 2.1 创建者：默认腿按需 `mkdir -p` + `0700`（并打印它建了什么）；显式根必须已存在且可写，否则 exit 3 + 路径 + 原因 +
  `修法：`；**任何一条失败路径都不许退回 `/tmp`**。证据：三种失败形状（不存在 / 不是目录 / 不可写）的 rc 与输出，
  以及失败后 `/tmp` 与默认目录下都没有新条目。
- [ ] 2.2 根名不变：默认腿里的根仍是 `teamsmith-<kind>-<ns>.XXXXXX`；`tmp_root_path_ok`、`--lint`、`--sweep` 的谓词一个字不改。
  证据：`--status` 在默认腿下的输出（路径 + 标记 + 台账都在）。
- [ ] 2.3 `--status` 表头印解析出的路径与来源；旧默认根残留段（计数 + 一条命令，只读）。证据：两个基准存在时的完整输出 +
  「打印的命令确实能回收」的一次实测（`--dry-run` 与真跑各一次）。

## 3 地板与医生行绑定到选定根

- [ ] 3.1 地板判解析出的根（`team_disk_guard "$(team_tmp_root)" …`），拒绝文案带**路径 + 来源 + 读数 + 阈值 + 修法**；
  `team_disk_label`/`team_disk_remedy` 用同一根比较（临时根不再被说成工作树、修法不再指错）。证据：§6b 的矩阵里
  临时根低于底线的拒绝输出（含 `来源` 字样）。
- [ ] 3.2 不可用的显式根 = 阻塞项（不进「读不到 → 不判」的沉默分支），给修法与 `TEAM_TMP_ROOT` 的写法。证据：`--print` 的拒绝
  输出 + rc。
- [ ] 3.3 未创建的默认根：地板按祖先判、容量行说明；不拒绝、不创建。证据：删掉默认目录后的 `--print` 输出。
- [ ] 3.4 `team doctor`：临时根行带来源；未创建的默认根按祖先判并说出来；锁所在的文件系统（未被别的行覆盖时）一条**只警告**
  行，`team doctor` 仍 exit 0，派单不因此被拒。证据：两个场景的 doctor 输出 + rc。
- [ ] 3.5 面板数据读走解析器（`__panel-data` 的余量条目路径）。证据：面板读的 JSON 里那条路径。

## 4 契约键

- [ ] 4.1 schema 行 `TEAM_TMP_ROOT|refuse|path|dir,opt|plain||-|…|identity`；`templates/config.sh.tmpl` 的位置键区块加一行；
  `references/config.md` 按位置键家族写一行（含解析顺序与「环境里的 TMPDIR 会盖过它」）。证据：`team config list` 的人读表 +
  `team config set TEAM_TMP_ROOT /tmp` 的退出码（5）。
- [ ] 4.2 控制台标签 `label_TEAM_TMP_ROOT`（zh/en）+ 用钉住的工具链重建 `panel.js`（`bun install --frozen-lockfile && bash build.sh`）。
  证据：`tests/panel-strings.mjs` 绿；重建后的 `panel.js` 与沙盒重建逐字节一致。

## 5 红侧（三条）

- [ ] 5.1 ①「各处自己算」：`--lint` 新规则 + 第三条红侧副本（自己算根的产品调用点 → `<file>:<line>`、rc=1）；动态那半：
  fixture-mode 影子让清扫器/门禁自算，断言两个基准对不上并点名分歧的面，撤掉即绿。证据：两份输出（红/绿）。
- [ ] 5.2 ②「地板绑回 `/tmp`」：`TEAM_DISK_STATS_FILE`（解析出的根很空 + `/tmp` 很满）下派单**不拒**、容量行点名解析出的根；
  `--break=fixed-floor` 下同一输入拒绝并点名 `/tmp`。证据：两份 `--print` 输出 + rc。
- [ ] 5.3 ③「不可用时静默回落」：`--self-test --break=missing-root` 把回落放回去必须红，撤掉必须绿；正常路径的具名失败
  （路径 + 原因 + 修法）与「`/tmp` 下没有新条目」的断言。证据：三份输出 + rc。
- [ ] 5.4 §40 的 band 复测（`section-budgets.tsv` 的 provenance 必须写实测值，不许沿用旧值）；`--select 0e` 绿。

## 6 门禁与文档

- [ ] 6.1 `smoke.sh`：工作根与事故诊断走解析器（诊断落在解析出的基准下、仍在 `$TMP` 之外），开跑行印来源；锁块**不动**。
  证据：`--select 34,34c,34d` 的 ✓/✗ 计数零回退。
- [ ] 6.2 `references/troubleshooting.md`：ENOSPC / 临时根一节改写（默认值、来源、旧根残留、回滚、inode 腿在磁盘上不适用的
  诚实退化）；`references/migration.md` §5 加一行、§6 Step 5 的检查项、§7 的回滚条目；`CHANGELOG.md` 新版本段落写清默认行为
  变化与回滚。证据：三份文档的 diff 摘要。
- [ ] 6.3 全量门禁（`smoke.sh`，后台跑、下一次唤醒收割）＋ `openspec validate --all --strict`。证据：✓/✗ 计数与用时。

## 7 交付

- [ ] 7.1 报告 `reports/P306-dev2.md` 按模板写：解析顺序、默认值、地板绑定、清扫器、迁移/回滚、三条红侧（各带红/绿两份输出）。
- [ ] 7.2 分支留在本地（local 模式），小步提交（Conventional Commits + 任务 ID + `Agent:` trailer），通知 PM。
