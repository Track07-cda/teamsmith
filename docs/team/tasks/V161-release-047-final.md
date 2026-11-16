---
id: V161
title: 0.4.7 冻结版本最终发布验证
agent: verify
category: verify
phase: verify
change: -
specs: verification
anchor: none (infra) — 已合并修复后的发布全量、元套件与安装验证
deltas: -
branch: task/V161-release-047-final
---

# V161 · 0.4.7 最终发布验证

## 对象与边界

PM 准备独立干净检出 `/var/tmp/rel47-review-222458cd`，固定 HEAD `222458cd5d9371c847b2aa5846ac9569e2d61727`，含 0.4.7 六处版本落点、P452/P453 已合并修复及独立 merged-SHA 接受记录。你未参与实现，只执行验证，不修改产品、规格或测试。

原一阶 `/var/tmp/rel47-first-order.log` 为 5139/2（停止恢复夹具与过期元记录）；P452/V159 已关闭停止恢复错误。原元套件记录 `2026-11-13T03-25-59Z.log` 为 212/5；P453/V160 已关闭三处错误。

2026-11-13 用户明确确认本次发布采用“原完整一阶结果＋修复后的独立复验＋新完整元套件 GREEN”，取消第二轮完整一阶。原两轮不得冒充最终提交上一次全量全绿；发布记录必须披露这个边界（D244）。

## 顺序与命令

长命令在本席位 team_bg_run 中顺序执行，每个命令分别留退出码，启动后结束回合；完成唤醒后收割。不轮询窗口、不在回合里 sleep、不另起并行全量、不调用 PM 代跑。

1. 在独立检出运行完整元套件，不再仅跑 0e/36/40：

```bash
cd /var/tmp/rel47-review-222458cd
bash skills/teamsmith/tests/meta-suite.sh --snapshot=222458cd5d9371c847b2aa5846ac9569e2d61727 </dev/null
```

授权原生入口把真实本轮记录追加到本仓共享 `.pi/team/state/meta-suite/`；这是唯一额外运行记录写入，不手工编辑 history、不使用 --judge 造绿。确认六个元段均实际执行，记录 GREEN、有日期、判据 SHA、冻结 SHA、逐段用时和总时长。若 RED，保留日志与现场、点名错误后通知 PM，不盲目重跑。

2. 元套件 GREEN 后，审阅原完整一阶结果和 V159/V160 的已提交独立证据，不再启动第二轮完整一阶，也不重复已经通过的 67/68 或 0e/36/40。对照 `572856a3..222458cd` 的差异确认各修复、版本及文档变化均有对应证据；如存在未覆盖产品行为变化，先点名通知 PM，不自行展开全量。

在同一冻结检出补当前 OpenSpec 1.16 普通 `openspec validate --all` 和 `bash skills/teamsmith/tests/smoke.sh --select 14d </dev/null`，验证新元 GREEN 记录能被实际读取；不是旧文档里的全仓 strict。`team review REL-0.4.7 --dir /var/tmp/rel47-review-222458cd --branch 222458cd5d9371c847b2aa5846ac9569e2d61727 --no-gates` 只记录本次人工证据审查，不能把 --no-gates 写成全量执行证据。执行前后 HEAD、受版本管理文件与未跟踪文件不变；除中央 review 例外，其余写入仅在自己的工作树/私有临时目录。

中央工具写入例外仅 `docs/team/reviews/REL-0.4.7.md` 和 `docs/team/reviews/REL-0.4.7-verify.log`，实际执行者写 verify；完整一阶是先前 572856a3 上的运行，不能归给本席位或最终 SHA。PM 的发布接受记录也不冒充执行证据。

3. 上述证据核对与短检查通过后，版本、打包与安装检查：

```bash
bash skills/teamsmith/scripts/team version --check
bash docs/team/tools/release-check.sh --names-file <主仓已有的仓外 forbidden-names.txt>
bash docs/team/tools/release-check.sh --self-test
```

此时尚未打 v0.4.7 tag，release-check 的 tag/版本不匹配是预期未完成步骤，必须原样列出，不能将整条命令记 PASS。除 tag 相关行外其它失败必须点名；三条安装路线必须真实执行，私有 HOME/npm prefix，不碰全局安装、认证文件、实际用户配置、不访问凭据。

4. 按 `docs/team/RELEASE-PUBLIC.md` 与 workflows §E3 取一次参考性能读数（非通过/失败阈值）。Podman 只能经 `distrobox-host-exec podman`，不新建/升级共享环境；如固定镜像不可用，明确记录未测量与原因，不把 host 数字冒充容器读数。

## 交付

`docs/team/reports/V161-verify.md` 首行给可发布/不可发布、真实命令与 rc、原全量断言/段数/跳过原因与源提交、新元 GREEN 日期及源提交、各修复的独立复验证据、安装与包清单、原始日志和性能读数。明确 D244 授权与“没有在最终提交上再跑一次完整一阶”的边界。按 CRITICAL/WARNING/SUGGESTION/Final assessment 分节，未验证范围如实列出。

不修改实现，不合并，不建/推 tag，不推 main，不暂存/发布 npm。把结果提交到自己的任务分支并通知 PM。任何新失败由 PM 裁决返修，不吞错、不加跳过、不延长超时。

## 2026-11-16 · P456定点补验

原BLOCKED报告edbe3384保留，其后仅因P456作补验，不重跑元套件、完整一阶、14d或参考性能。候选为5eafd5f4，PM独立干净检出 `/var/tmp/p456-review-5eafd5f4`。P456由dev实现，你不是实现者。

- 读取P456源码差异/报告及原始窄测runner，独立执行已有初始化P440/P456子块与28-i3子用例，覆盖自托管、普通项目主检出/worker真实生成命令、--no-skills、受管块外和config/BOARD不变、旧AGENTS生成参数改回则原断言红。复用原断言，不自行扩成完整17/28段；原初始化红侧是替换而非新增永久自证层。新参数表达式必须真实能运行，不以grep文字代替命令可用。
- 新增功能变化只有AGENTS路径生成；cmd-watch仅注释、28-i3目录名中性化、80份证据取消跟踪，分别核对逻辑不变和主报告仍在。核80份取消跟踪清单与主仓被忽略备份 `.pi/team/state/release-0.4.7/legacy-evidence/manifest.json` 一致，不删除或改写原证据。
- 在新检出执行公开扫描、ledger-ban、普通OpenSpec、索引自检、版本与release-check（三条安装路线含本次新生成逻辑），不重复release自测（工具未变）。尚未tag的2条失败原样列出，其余必须关闭。只输出前5项的旧日志不能当总清单。
- 主仓已有80份本地备份；worker曾有未跟踪空的旧change目录，已rmdir而非改spec。独立干净检出不应有这个目录，不把该工作树遗留写成真实规格缺失。

中央额外工具写入例外为 `docs/team/reviews/P456.md` 与 `P456-verify.log`，可以 `team review P456 --dir /var/tmp/p456-review-5eafd5f4 --branch 5eafd5f4 --no-gates` 留真实执行者与候选；no-gates仍不是全量PASS依据。结论写回自己的V161报告并通知PM。候选通过后等待PM合并，再由同一你在PM准备的merged-SHA检出核文件同一性、补适用短检查；不机械重复已完成的大套/安装/性能。不提前勾done。

## 本地标签最终核对（不触发外部发布）

合并165119c7已经同一你独立复核通过。PM会把接受记录/报告提交后创建仅本地的v0.4.7标签，并提供`/var/tmp/rel47-tag-final`干净独立检出。只核：tag确实指该HEAD、与165119c7的全部产品/包文件同一性、普通OpenSpec、公开/账本扫描、版本及`release-check --skip-install --names-file <既有名单>`。预计标签两项转绿，安装跳过依旧引用你已经实际验证且同字节的三路线证据；不用重跑行为、安装、自测、性能或长测试。完成后补最终报告，记录标签SHA与实际rc。该标签还没推送，用户未授权公开main/tag/npm前任何人不得执行这些外部步骤。
