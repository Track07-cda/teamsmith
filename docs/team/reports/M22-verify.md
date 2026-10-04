# M22 · 移除 `skills/pi-team` 兼容软链

agent: verify   status: DONE   time: 2026-09-18T06:30:00Z
branch: `task/M22-skills-pi-team`   PR/MR: -（本仓库 local 模式：不 push，分支留 `.worktrees/verify`，PM 复验后本地合并）

用户 2026-09-17 拍板**提前结束别名期**（<peer-d> 已全部转用 teamsmith 路径），把 v1.13.0 改名时留下的
`skills/pi-team → teamsmith` 兼容软链删掉。软链一删，钉住它的三处断言、安装器的历史别名清理、
以及散在文档里的「软链还在」承诺都要一起改 —— 而且**旧路径的清理承诺不能被静默丢掉**（见「Flip evidence」的 F3/F4 与「关键决策与偏差」：
门禁自己抓出了我第一版的漏洞）。

## Deliverables

| Path | What |
|---|---|
| `skills/pi-team` | **删除**（`git rm`，软链 mode 120000）。老项目若硬编码了 `skills/pi-team` 绝对路径，改成 `skills/teamsmith`；已装的 `~/.agents/skills/<name>` 链接不受影响 |
| `skills/teamsmith/tests/smoke.sh` | ①「兼容软链必须在位」→「旧路径必须不在（M22）」；②旧名扫描的豁免词表加上 M22 的兼容措辞（`removed`/`legacy`/`M22`/`旧路径`）；③M7.3 安装器段的「跳过 pi-team」断言改成**夹具**守「跳过 `skills/` 下软链」这条通用守卫（真 skill ×2 + 软链别名 ×1），守卫不再因为仓库里没有样本而变死代码；④卸载清理旧别名的断言照旧（并新增 install.sh 的显式清理，见下） |
| `install.sh` | M7.3 的注释改成通用规则（`skills/` 下的软链一律不装）；**卸载路径显式清掉历史别名 `pi-team`** —— 以前这个名字是被主循环「顺带」覆盖的，软链删了以后主循环再也看不到它（第一版没补这步，门禁的卸载夹具当场报红，F4 就是这个翻转） |
| `skills/teamsmith/SKILL.md` | `## Name and compatibility`：旧路径**已不存在**（硬编码绝对路径要改成 `skills/teamsmith`）；`/pi-team-reload` 命令别名与 `<!-- pi-team:begin -->` 标记迁移**保持不变**（命令名与路径是两回事） |
| `skills/teamsmith/references/migration.md` | §2 的表格行从「nothing」改成「change the path」；**新增 §2c**：旧路径可能还写在哪里（`settings.json`/自己的脚本/已装目录/标记/别名），每条各自怎么处理 |
| `skills/teamsmith/CHANGELOG.md` | 顶部**未发布**块加一条 M22（版号仍由 PM 定；块本身刻意不是 `##` 标题，版本解析取第一个 `##`） |
| `README.md` | skill 表格行 + Compatibility 段同步改写（不再声称软链可用） |
| `docs/team/reports/M22-verify/**` | 本报告 + 探针与全部日志（`logs/`、`pkg/flip-m22.sh`） |

## 验收（brief 的四条，全部实跑）

```
① $ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh
   Totals: 13 passed, 0 failed (13 items)                      （rc=0）
   == 结果 ==  ✓ 1942  ✗ 0                                     （full_rc=0，全量含真 tmux 段落）
   （全文 logs/gates-full.log）

② $ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
   == 结果 ==  ✓ 1511  ✗ 0                                     （fast_rc=0）
   （全文 logs/gates-fast.log）

③ $ test ! -e skills/pi-team && echo removed
   removed

④ $ grep -rn "skills/pi-team" skills/teamsmith/SKILL.md README.md skills/teamsmith/scripts/ \
       skills/teamsmith/extension/ skills/teamsmith/templates/
   skills/teamsmith/SKILL.md:35: … The old path `skills/pi-team` **no longer exists**: the compatibility
                                 symlink was removed (M22 …) …            ← 说明性提及（见下）
   README.md:27: … Former name: `pi-team` (the `skills/pi-team` compatibility symlink was removed …)  ← 说明性提及
   （scripts/、extension/、templates/ 三处**零命中**；全文 logs/acceptance-greps.log）
```

**最终 tip 复核**（四个翻转全部还原、报告与日志就位后再跑一次，`logs/gates-final.log`）：

```
$ openspec validate --all --strict          → Totals: 13 passed, 0 failed   （openspec_rc=0）
$ TEAM_SMOKE_FAST=1 … smoke.sh              → == 结果 ==  ✓ 1511  ✗ 0        （fast_rc=0）
$ test ! -e skills/pi-team && echo removed  → removed
```

**④ 的口径说明（brief 只豁免了 migration.md/CHANGELOG，这两处需要交代）**：命中只剩 `SKILL.md` 与
`README.md` 各一处，且两处都在**兼容段里说明「软链已被移除、旧绝对路径要改」** —— 不写出旧路径本身，
读者反而无法 grep 到自己项目里的残留。所以我把 brief 的验收口径读成「功能面零命中 + 说明性提及逐条列出」，
并把三类逐个列出：

| 位置 | 性质 | 处置 |
|---|---|---|
| `scripts/`、`extension/`、`templates/` | **功能面** | **零命中** ✓（extension 里的 `/pi-team-reload` 是命令名，不是路径，brief 明确要求保留） |
| `SKILL.md`、`README.md` 的兼容段 | 说明性提及 | 保留（只出现在「已移除、怎么改」的句子里）；如需更严的口径，可改成 `pi-team`（不带 `skills/` 前缀），但那会让「复制这段去 grep」失效 —— 交 PM 定 |
| `references/migration.md` §2/§2c、`CHANGELOG.md` | 说明性提及 | brief 明确豁免 ✓ |

## Flip evidence（改坏 → 门禁必须红且点名 → 还原）

脚本 `pkg/flip-m22.sh`，实录 `logs/flip-m22.out` + 每个翻转的门禁全文 `logs/flip-<case>.log`：
每个 case 只改真树里的一处 → 跑 `TEAM_SMOKE_FAST=1 smoke.sh` → 要求（a）非 0、（b）红行点名被打坏的目标 →
`git checkout` 还原 → 断言 `skills/ install.sh README.md` 逐字节干净（还原失败立刻中止，不让脏树污染后续判定）。

| case | 注入的变异 | 门禁的红行（原文） | 还原 |
|---|---|---|---|
| 基线 | 无（未变异的树） | `== 结果 ==  ✓ 1511  ✗ 0`（绿，作为对照） | — |
| **F1** alias-back | `ln -s teamsmith skills/pi-team`（旧路径回来） | `✗ skills/pi-team 还在（M22 已移除兼容软链：老项目改绝对路径，而不是靠别名）` + `✗ 仓库里又出现了 skills/pi-team（M22 已移除：老项目改路径，不靠别名）` | ✓ 干净 |
| **F2** functional-ref | 往 `skills/teamsmith/SKILL.md` 追加一行功能引用 ``Config and state live under `skills/pi-team/config.sh`.`` | `✗ 还有旧名 pi-team 的残留：…/skills/teamsmith/SKILL.md:267:Config and state live under `skills/pi-team/config.sh`.` | ✓ 干净 |
| **F3** skip-guard-dropped | 删掉 `install.sh` 里「跳过 `skills/` 下软链」的分支 | `✗ install.sh 说明了为什么跳过 skills/ 下的软链（M22 后由这个夹具守着）（…/m22-install.log 中找不到 [跳过 alias-to-teamsmith]）`（另有「目标里没有软链别名入口」与条目数两条同时红） | ✓ 干净 |
| **F4** legacy-cleanup-off | 删掉 `install.sh` 卸载路径里清历史别名的那段 | `✗ 卸载后 pi-team 入口还在（旧版装出来的副本没人清）` | ✓ 干净 |

四个 case 结束时：`四个翻转全部按预期红，且都点名了自己的目标；还原后树干净`（RC=0）。

**F1 的第二次复现**（`logs/flip-alias-back-repro.log`）：重新建软链 → 恰好 **2 条红**、就是上面那两条 M22 断言；
那次运行里**没有**别的红 → 说明第一次 F1 里多出来的那条 `✗ D：roster 把 squash 合并与真领先分开显示`
与本变异无关（见下）。

## 一条与本任务无关的观察（M43D 断言闪烁）

第一轮 F1（软链在场）那次 FAST 门禁里，除了两条 M22 断言，还多了一条
`✗ D：roster 把 squash 合并与真领先分开显示（… m43d-roster.log 中没有匹配 [^m43d.*已合并]）`。
**复现实验（软链在场、再跑一次）里它没有出现**（那次恰好只有 2 条 M22 红），基准运行（未变异的树）也是
`✓ 1511 ✗ 0` —— 所以它是**既有的偶发红**，与 M22 无关（本任务没碰 M43D 的任何代码路径）。
我把它列在这里而不是咽下去：这条断言在 6 次 FAST 运行里只红过 1 次，看形态像负载/时序引起的（M43D 用真 git
夹具），值得 PM 在别的任务里盯一眼。我的翻转判定因此**只认「点名的模式」**（`grep -F` 期望的红行），
不受这类无关红影响 —— 但它也意味着「有别的红」不会被翻转脚本吃掉，而是留在日志里。

## 关键决策与偏差

- **没有 bump 版本**：CHANGELOG 顶部的「未发布（版号由 PM 定）」块就是为这种改动准备的，M22 的条目加在
  该块顶部；`TEAM_VERSION`/两个 `metadata.version`/CHANGELOG 顶部标题四处仍然相等（1.40.0）。发布号由 PM 定。
- **安装器的卸载清理不能靠仓库里的软链**（偏差 + 修复）：M7.3 的「卸载顺手清掉旧版装出来的 `pi-team` 入口」
  以前是靠主循环遍历 `skills/*/` 时看到 `pi-team` 这个名字实现的；软链删掉后主循环再也看不到它，于是旧副本
  会永远留在目标目录。我在 `install.sh` 的**卸载路径**加了一段显式清 `pi-team` 名字的代码（安装路径绝不重建
  别名）。这是本次改动唯一超出 brief 字面的功能性修改，由门禁的卸载夹具抓出来（F4 翻转即它的守护）。
- **「跳过软链」守卫改用夹具守**（偏差）：仓库里不再有软链样本后，若不换夹具，这条 M7.3 守卫就变成死代码。
  brief 允许「改为不测（说明理由）」，我选择了**保留覆盖**（夹具 = 两个真 skill + 一个软链别名），因为
  「有人往 `skills/` 里加软链」正是最容易悄悄回来的那类问题。
- **任务书里的两处过期信息**：brief 的 `agent:` 行与报告路径写的是 `M22-dev2.md`（派单时已改由我执行，
  PM 的 dispatch 提示里报告路径是 `M22-verify.md`，我按后者写）；工作树写的是 `.worktrees/dev2`，实际在
  `.worktrees/verify`。两处都只是文字过期，不影响交付内容。
- **`.gitignore` 顶部的 `# pi-team` 注释**：那是忽略清单的分组注释（旧名遗留），改它不属于本次验收面；
  我**没有动**，留给 PM（一行决定）。
- **`docs/alignment-<peer>-reply.md`** 里的历史提及（<peer-c> 对齐回信，v1.7.0 时代）：属历史文档，brief 明确不改 ✓。

## 未验证 / 风险

- **别的老项目**：本次证明的是「本仓库 + 本机安装形态」自洽；任何**外部项目**若把 `skills/pi-team` 的绝对
  路径写进 `settings.json` 或 config，删除后它们的 `team` 调用会断 —— 用户已知悉并拍板，迁移指引 §2c 给了
  逐条改法。我没有去扫别的仓库（越界）。
- **本机安装目录**（PM 属地，我只读）：`~/.agents/skills/` 下现有 `teamsmith` 与 `teamsmith-init` 两条
  指向本仓库的软链；`pi-team` 那条**已经不在了**（PM 已按 brief 前置处理）→ 本次删除不会让本机安装悬空。
- **copy 模式安装的旧目标**：若目标目录里有一份 `--copy` 装出来的 `pi-team` 副本，`./install.sh --uninstall`
  会删掉它（有夹具守着）；但**不会**自动重新装成新名字 —— 需要重跑一次 `./install.sh`（§2c 已写）。
- 命令别名 `/pi-team-reload` 与 `AGENTS.md` 旧标记迁移**未动**（按 brief 保留），它们的既有断言照旧全绿。

## Suggested next steps

1. PM：复验 `bash docs/team/reports/M22-verify/pkg/flip-m22.sh`（约 10 分钟；期望四红 + RC=0）或直接看
   `logs/flip-m22.out`；然后本地合并并决定发布号（未发布块里的 M22 条目随发布改写为版本标题）。
2. 发布时顺手把 `CHANGELOG.md` 顶部那块「未发布（M3.2…）」的历史遗留整理一次（P16 报告也提过）。
3. 若要更严的文档口径（`SKILL.md`/`README.md` 里连 `skills/pi-team` 字样都不留），那是一次纯文案改动，
   改完记得同步 §2c 的措辞；当前我按「说明性提及保留」处理并逐条列出。
4. 其它老项目：按 `references/migration.md` §2c 逐条核对绝对路径（本仓库无法替它们改）。
