# Tasks

以下清单属于后续 apply / 非作者 verify，P460 只交规划，所有实现项保持未勾选。requirement 与场景见 `specs/verification/spec.md`；命令和坏/恢复对照见 `design.md` 的 Migration Plan。

## 1. 配置唯一执行点

- [ ] 1.1 正常完整运行保留33无参数配置入口一次，删除51重复配置子进程及汇总/缺文件分支并同步段内说明；独立选中33才执行其完整入口，单选51/12e–12k不因该约定带33。核对config-cli/routes/help-surface三脚本相对接受基线逐字节不变，对应“Normal configuration checks have one execution site”的前两场景。
- [ ] 1.2 调整两行既有路径声明：33补cmd-config、51移除config-cli而保留cmd-config与routes/help；运行三个受影响路径及未知路径的选择计划，确认33/51归属与FULL，运行既有 `section-select.sh --check`，对应同requirement的 changed-path 场景。
- [ ] 1.3 在独立环境仅运行一次正常 `smoke.sh --select 33 --keep`，核真实child默认组及嵌套日志完整；51剩余调用/汇总/输入与三脚本用design指定原日志、SHA及接受基线到实现的字节/消费源码差异审查取证，不默认再跑完整51。validate/writer坏恢复复用同轮33原件；roster仅补缺的假成功坏腿，正常/恢复复用33和字节还原证明；父级仅用原通用非零分支字节比较加真实短setup失败接线，不跑完整坏树默认集合。日志缺具名证据时只补缺的一腿，不新增检查器，对应前两场景的真实行为及失败传播。

## 2. 准备从配置执行解开

- [ ] 2.1 原样把路径/shim/十四个p24函数准备块移到已有公共前导，七行needs从33改为-并更新依据，其他消费者正文/needs不改；运行 `section-select.sh --self-sufficient` 与 `section-guard.sh --loop-check`，对应“Change-workflow preparation does not schedule configuration execution”。
- [ ] 2.2 分别对12e/12f/12g/12h/12i/12j/12k执行选择计划与单独smoke，每次新TMP；保留实际命令、退出码、具名检查和适用live分支/缺前提披露，确认无33/配置child连带执行。scratch只删p24_brief定义，保留p24_project/p24_change及真实路径准备，坏腿单选12e须非零、点名缺定义并有具名行为失败；定义字节恢复后复用正常独立12e，不重跑七键，对应该requirement的两个场景。

## 3. 独立证据与交付

- [ ] 3.1 非实现者在PM准备的固定检出核对上述两requirement全部场景、实际退休的一个调用/七条边及路径归属；按1.3/2.2与design的最小表复用同轮33、七个独立键及绑定来源的51原日志/字节证据，不重复完整51、validate/writer、坏树默认集合或全量/meta/61b。使用OpenSpec1.16对本change严格结构校验、spec-refs及暂存后ledger-ban/diff-check；报告区分实际运行、具名跳过、原局部日志复用、静态次数与未实测节省，不作完整套件通过声明。
- [ ] 3.2 按项目既有独立复验流程记录候选与合并后的受验SHA及适用补验结果，披露全部未验证分支；PM接受前不把实现/验证项标为完成，对应两个requirement的整体接线与既有合并复验约定。

## Workflow follow-up

- 提案先交非作者审阅，PM正式接受后才分派apply；提案者不实施，实施者不自验。
- 同一独立验证者的合并版本证据被PM接受并取得有效确认后，由非实现者另行执行archive；P460不归档、不合并、不发布。
