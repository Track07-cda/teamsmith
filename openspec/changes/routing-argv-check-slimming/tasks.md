# 实施清单

本清单属于 `routing-argv-check-slimming`，尚未授权执行；全部框保持未勾。一个 apply 批次，由非提案作者实施；独立 verify 由非实现者承担。规格定位均为 `verification#A gate that cannot judge says so` 下本批具名场景，不创建第二份需求清单。

## 1. 两个短 argv 入口

- [ ] 1.1 在已有 `model-routing-expansion.sh` 和 suite 的早期分流处实现 `--select argv-worker` / `--select argv-pm`；保持默认 16 组与正常 boundary 源码不变，只用私有 HOME/config/cwd/state，沿用 tmp-root/check/RESULT。验证两个短入口正常退出 0，没有 git init、长活 recording-pi、tmux 或 dispatch；将 expansion helper 登记到 section-paths.tsv 的 61b 行，原 61 行不变。（场景：Routing argv replacements detect the original resplitting errors；Only the two routing boundary repeats and original-tree second CORE retire）
- [ ] 1.2 用独立固定期望检查实际 Bash argv，包括完整 provider/model、literal extra 和 PM 显式 resume SID；保留真实 PM guard/publisher/loader，不更改产品函数，不拿 lexer 输出自比。用原变异器在各自副本取得健康 0、原变异 1 和原三条 FAIL 名字；PM 必须执行完 extra/resume 两项，renderer/setup 错误不能充当目标失败。命令/输出及 setup 直接写本批报告，不新增永久验测试层。（场景：Routing argv replacements detect the original resplitting errors）

## 2. 在现有 flip 父级替换并删除旧执行

- [ ] 2.1 仅把两条 resplit 臂的 boundary 分组换为对应短入口，在变异前及脚本恢复后分别调用同一入口；保留原 matched/shape/child rc/具名失败/字节恢复检查。验证两臂均在同一副本取得 0→1→0 和恢复字节相同；健康/恢复各由父级实际 check 计数，不能只打印 helper 结果。（场景：Routing restoration observes the same mutated copy；Routing short outcomes reach the existing flip parent）
- [ ] 2.2 真删末尾原树第二 CORE 和 flip-restored-all-green，不留 slow 分支；保留首个完整 CORE、其他 29 臂及其组列表/失败名/恢复行为。用源码差异和执行清单列出旧退休项、新父级检查和保留调用点，注释去掉“整组恢复证明”误述；明确无关坏树观察被舍弃、§61 未减覆盖。（场景：Only the two routing boundary repeats and original-tree second CORE retire；Routing evidence reports actual scope instead of padding totals）
- [ ] 2.3 在一次性测试副本按 design 收窄执行范围为两条 resplit 和两个短组，不改 flip_run/check/最终出口；分别制造非预期 child rc、缺具名 FAIL、健康/恢复失败，确认对应父级 FAIL 与进程非零；恢复后通过。报告明确这是接线样本而非完整矩阵，不提交过滤入口或额外验测试套件。（场景：Routing short outcomes reach the existing flip parent）

## 3. 最终集成和独立验证

- [ ] 3.1 冻结最终可执行字节后，后台执行一次 `TEAM_META=1 TEAM_SMOKE_FAST=0 bash skills/teamsmith/tests/smoke.sh --select 61b --keep </dev/null`，保留实际日志及 revision；核首个正常 CORE（含原真实 worker/PM 调用）、全部 31 条变异、两条同副本恢复以及最终父级 RESULT/进程退出。按实际新旧清单解释计数，不固定 203 或目标秒数；不另跑相同全分组作重复交付，也不把本次选段称 full smoke。（场景：Only the two routing boundary repeats and original-tree second CORE retire；Routing evidence reports actual scope instead of padding totals）
- [ ] 3.2 执行 `openspec validate routing-argv-check-slimming --type change --strict`、`bash skills/teamsmith/tests/spec-refs.sh --check`、`bash skills/teamsmith/tests/section-select.sh --check`、`bash skills/teamsmith/tests/section-guard.sh --loop-check`、ledger-ban 与 diff-check，报告列真实结果及未测范围；不得为账本补提交再跑小时级矩阵。（场景：Routing evidence reports actual scope instead of padding totals；既有 internal coverage 场景的非退休部分）
- [ ] 3.3 非实现者核对固定候选的差异、各场景/计数、原始日志，独立跑两个短入口和有区分力的父级接线反例，完成 OpenSpec assessment；长矩阵只在实际差异/缺证据使既有完整集成结果不能复用时补跑并说明原因。合并后同一 verifier 固定合并 SHA，核执行文件同一性与索引/关键正常调用点并补适用短检查；有行为差异按差异补验，不把先前 receipt 改写为本次执行。（场景：Routing evidence reports actual scope instead of padding totals；沿用独立及 merged-revision verification 的既有要求）

## Workflow follow-up

- PM 接受独立证据后再按既有授权合并、关闭；本提案不进入 0.4.7 冻结发布对象。
- 归档仍另派非实现者并取得既有用户确认或合格 PM 代理确认；本清单不授权实施、归档、发布或真实团队状态操作。
