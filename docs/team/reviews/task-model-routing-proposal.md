# task-model-routing · Proposal review

时间: 2026-10-08
verdict: **ACCEPTED**
任务: E14（任务模型路由提案）
作者: verify；评审: pm
受检分支: `task/E14-task-model-routing-propose`
受检 HEAD: `1ea1ba61a48b2a698c491db26790826818a2a70f`

## 修订复核与当前结论

R1–R4 已在 proposal/design/tasks、相关 deltas 和作者追加报告中闭合：

- R1：合法删除未来类别映射不使完整、匹配的同任务身份失效；新任务仍须合法映射，整体非法配置、身份变化和换模型守卫保留。配置/读面/恢复规划已一致。
- R2：正限额目标遇到其他 proven-live 但模型身份不可判定的 worker，不能按零占用放行；预览/force、无副作用、显式本项目修复及 dead/PM/unlimited 对照齐全。
- R3：旧的 never-behavior、不可编辑测试文件及冻结旧模型字节表述已限定或修正；允许合法夹具适配，不允许削弱或跳过通知、Pi版本、插件、占位符及 PID/nonce 安全断言。
- R4：切片依赖和文件交接在私有非部署源码树进行，不将部分实现放共享 main，不提前标 apply done。完整源码的共享源隔离或明确共享影响、保护分支落地、本项目配置/fresh 和其他项目采纳分别授权；不承诺未知消费者零影响，不新增自动部署器。

PM 逐份复核修订 diff。独立冻结副本重跑官方 context/status、change strict、all strict（14/14）、spec-refs、ledger-ban、diff-check；另在 disposable projection 执行官方试归档后 all strict（13/13）与 spec-refs，均 exit 0。27 个实施项仍未勾，试归档告警保留。独立记录检查的选段为 NONE；收录覆盖 OpenSpec 路径后另实跑 `0 0b 0c 0d 18c`：46 通过、0 失败、0 跳过，其他 120 段未跑，命令与摘录在独立证据目录 `collection-smoke-receipt.txt`。没有全量 smoke、真实归档、产品实现反例翻转、TUI 或 provider 质量测试。

独立证据：`../pm-skills-ledger/team/reviews/E14/revision-1ea1ba6/`。检查前后共享产品字节、实际配置、worker launch record 和全局技能链接快照一致；没有用户真实会话读取、安装、配置迁移或链接替换。

十项审核均闭合：批准范围一致、可观察场景、双向任务覆盖、职责边界、现有规划命令实跑与未来接口明确标注、反例控制、正确 MODIFIED/REMOVED、切片及串行所有权、单一 change 绑定、七个 capability 与 brief anchor 可解析。

**仅批准提案，不是实现或上线验收。** 当前恢复缺陷尚未修复。收录只增加规划工件与团队记录，不改 canonical specs 或产品代码。用户明确批准隔离实现后，PM 再写 apply briefs；协调使用既有控制 CLI，被测私有 CLI 只指向授权夹具，避免误用真实团队配置。完整实现由非 apply 作者验证，main 落地、共享采纳、配置/fresh 和真正归档仍守原授权门槛。Pulse 关键回复页不纳入本变更。

## 初审历史（NEEDS-CHANGES，修订后已关闭）

初审提交：`357c88c8872bee7aa4cef7e722828f4c7c9acab5`。以下保留当时证据与返工要求，不代表当前判定。

### Independent checks and their limit

PM 从自己的 main 建独立干净 clone，再从受检提交提取 11 份 OpenSpec 工件和原报告；未复用作者的执行脚本，也未写入其证据目录。逐份阅读 proposal/design/tasks 和七份 delta。

独立执行现有 Bun/OpenSpec CLI 的 context、status、change strict validation、all strict validation，引用检查、隐私检查和 diff 检查，均 rc=0。变更加现有规格为 **14/14**；当前与投影引用检查各 **104 references、undeclared 0**；隐私检查 **1305 files、hits 0**。在另一份私有 OpenSpec 副本试归档后，投影规格 **13/13**。试归档保留了 0/27 未完成任务的告警和超过十个 delta 的非阻断告警；没有假勾任务或归档真变更。独立原始 clone 检查后仍干净。

证据: `../pm-skills-ledger/team/reviews/E14/`，含 `run-independent.sh`、独立 `checkout/`、`projected/` 和各命令日志。源提交与原报告未改写。

这些结果只验证结构、引用、隐私和试归档可应用性。未跑产品 smoke、真实 TUI、真实 Pi/provider 或模型质量评测；尚不存在新功能实现。结构检查不能证明以下语义问题已经解决。

## 初审要求（R1–R4 已关闭）

### R1 · Configuration edits must not invalidate an otherwise complete same-task assignment

位置: `specs/dispatch/spec.md` 的 `A committed assignment is the authority for same-task recovery and fresh takeover` 及其 invalid-identity scenario；`design.md` §2、`specs/memory-and-deps/spec.md` 对删除类别的描述。

当前文本一方面说 policy change affects new tasks only，另一方面把从映射中删除已选类别当成 brief 失效，强制改合法类别并 fresh。这会使一次未来任务配置清理打断已经固定模型/SID 的同任务恢复，甚至经 changed-identity 路径重新选择模型。

明确区分首次选择与已提交身份的恢复。当前配置本身合法、完整记录与 task/brief/category/branch/worktree 匹配且未请求换模型时，修改或删除某类别的未来映射，不应迫使该已有任务重新选择或 fresh；记录保留原类别/model/SID/provenance。新任务引用已删除类别仍须拒绝；修改 brief 类别、换任务/分支/工作树或显式换模型，仍按身份与 fresh 守卫办理。不要恢复旧席位/default 路由。

补正反场景: 保存 routine 任务的显式强模型与 SID A → 将合法项目映射改成仅 analysis/verify → 同任务 resume 仍用原模型/SID A；另一个新 routine 任务拒绝。整体配置缺失或非法仍不能当作有效配置。

### R2 · A live peer with unjudgeable model identity cannot silently disappear from quota admission

位置: `specs/dispatch/spec.md` 的 model concurrency / accumulated guards，`design.md` §2 和 tasks 的并发翻转证据。

目前覆盖 target resolution 和 live/stopped peer，但没有定义已证明在跑、却只有 legacy/incomplete/malformed assignment 的 peer 如何计入模型配额。不能因无法取得可信 model 字段就把这个活席位当成零占用，也不能从未来类别/旧席位配置猜当前模型。

对受限 admission 明确保守规则与可恢复诊断：相关模型占用无法判定时，不得报告配额检查通过或悄悄放行。可明确拒绝并给出只处理本项目相关席位的修复途径；不要用 PM 或 dead/exited/absent pane 凑数，也不要扩成订阅全局预算。preview 与真实调用一致，force 不绕过；仍保持合法赋值的 exact/wildcard/0 与换自己一次计数语义。

补反例: 目标为限额 1 的 strong 模型，另一个 worker 已由 PID/nonce 证明存活，但其模型身份不可判定；不得把计数当成 0 再起目标。对照证明清楚的 stopped/dead peer 不占位。记录桩即可，不调用实际 provider。

### R3 · Remove inherited wording that contradicts this change's observable behavior

位置: `specs/agent-adapters/spec.md` 的 `The shipped instructions describe Pi only and leave the adapter seam opaque` 仍保留 “This change rewords documentation ... never behaviour”；其 scenario 仍说 doc/engine scans 无 test edit。`specs/init-skill/spec.md` 有同类无 test edit 表述。

当前提案明确改变模型/SID 参数、额外参数拒绝和 PM fresh/continue 行为。把旧变更的 “this change ... never behaviour” 留作新 MODIFIED 正文，无法同时兑现。

保留真正不变的 seam/placeholders/extension set/通知与 PID 安全契约；明确本变更允许的模型/身份参数与守卫变化。旧安全断言继续有效，不可弱化、跳过；必要的合法新模型配置和赋值 fixture 输入更新可以做，不能承诺所有相关测试文件字节不改。检查其他 MODIFIED 正文是否有同类未限定的历史变更语句；不改真实历史报告。

### R4 · Source integration is not isolated from the shared installation on this machine

位置: `design.md` §7、tasks §8 的集成/采纳次序和 ownership handoff。

PM 只读核对发现：本机 `~/.agents/skills/teamsmith` 和 `~/.agents/skills/teamsmith-init` 都是软链接，目标正是本仓对应 `skills/`。不是只有执行 install 才会改变共享来源。产品代码合入这个 main，就可能被其他项目后续读取。当前未做产品合并、配置升级、链接更改或重启，其他项目仍未改变。

补上这个现实前提，不能把 S1 “集成后”默认理解为先入被共享的 main，再让 S2/S3 开工。规定私有非部署集成树上的串行依赖/文件交接与验证；没有安全采纳授权前不要将部分实现挂到共享源，也不要把只进集成分支的 apply 任务提前标 done。

正式 source/main 采纳之前，说明共享源隔离或明确批准共享影响所需的额外授权/前置步骤；本轮不得自行改全局链接/安装或其他项目。区分源代码验证、保护分支落地、本项目配置切换、共享来源采纳；不能以“不调用 installer”证明“共享安装无影响”。在本设计与相关 rollout 场景中限定能实际保证的范围，不另造自动扫描/部署系统。

## 初审返工交接（已完成，保留原文）

退回原 propose 作者，只修规划工件与自己的报告，补跑原 brief 的规划检查和私有试归档。可在报告追加更正与新证据，保留已提交原版本供对照。全部实现任务仍未勾选，不改产品代码/当前配置、规范基线或共享链接。修订报告再次交 PM 审核；现在不收录为获批方案，不关单，不派 apply。Pulse 关键回复页是另外的方向，不纳入本变更。
