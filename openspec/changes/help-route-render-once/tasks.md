# Tasks

以下均为未来工作；本轮只有提案，不勾选。规范映射均指本 change 的 `verification#Normal help entry verification renders its canonical page once`。实现与实际行为验证按 P461 的分工分开，不让作者/审阅者重复跑同一批。

## 1. 实现者：最小替换及静态交付

- [x] 1.1 仅改 `help-surface.sh` 的单命令比较和同文件最小共用函数：三入口 stdout 直接写当次文件、逐入口收 rc、两次原字节比较、同 shell finding/循环消费；退休每命令第二个 canonical 调用，保留原成功行及其它代码。以 `bash -n`、diff 和当前 manifest 静态核账证明 4N→3N、断言未退休，在作者报告记录实际写集；不运行行为样本。（三入口/字节/失败/接线四场景；design Decisions 1–3。）
- [x] 1.2 跑本 change 严格校验、`spec-refs.sh --check` 和 `section-select.sh --paths skills/teamsmith/tests/help-surface.sh` 静态登记；核未改 helper/page/manifest/其它组与产品依赖以及 51 的 HS_RC 消费分支，把输入版本、可复用原件身份及未测行为写入报告后冻结。无新段/needs/产品开关，不跑 51/全量/性能。（三入口场景的保留边界及接线场景；design Migration A/B。）

## 2. 非作者：唯一行为批次及合并后短补验

- [ ] 2.1 在 PM 准备的冻结独立检出上统一运行一次正常 `help-surface.sh --select route`（完整当前 manifest）；再用候选实际函数/循环/finding/最终出口做正常、两别名错页/尾换行、三个入口同字节非零（含全空）及一次丢失 FIND 的调用点破坏/恢复短样本。保留 argv/原字节输入、具名 finding、真实退出码与恢复原件；所有坏样本不带完整帮助检查。不重跑未改组/locale/routes/51，以源码与输入同一性和适用已有原件说明复用边界，不把缺证项报通过。（四场景；design Decisions 3、Migration B。）
- [ ] 2.2 同一非作者在合并后固定检出记录 SHA、函数/调用点/出口/输入及依赖字节同一性；相同则复用 2.1，只补一条正常及一条损坏/恢复的同判定短样本。有相关差异仅补受影响入口；报告实际复用、补跑及未验范围，PM 接受后才完成。（三入口场景的输入边界及接线场景；design Migration C。）

## Workflow follow-up

- 非作者审阅规划、PM 正式 proposal review 为 ACCEPTED 后才另派 apply；本清单不授权当前席位实现。
- 独立验证/合并后证据获接受且满足既有确认要求后，另派非实现者 archive；其授权阶段再原生试归档和同步。归档不属于上述实现进度，不在本轮执行。
