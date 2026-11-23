---
id: V189
title: 独立核对 0.4.8 版本、公开文件和安装包
agent: dev3
category: verify
phase: verify
change: -
specs: verification
anchor: none (infra) — 冻结候选的常规发布准备，不是 PM 指导行为测试
branch: task/V189-release-048-package
---

# V189 · 发布包只取固定候选，不碰用户安装

你没有实施发布版本落点。PM 冻结检出和完整 SHA 见 V189 线程。参照 `docs/team/RELEASE-PUBLIC.md`、`docs/team/tools/release-check.sh` 和 V161 原有发布收据，只在固定源上独立验版本、公开面和三种安装路线，明确标签尚未创建的预期失败，余项如有失败报告根因，不能总称 PASS。使用现有真实仓外公开名单路径但不读/打印名单内容，所有运行/包/安装/缓存用本次 `/var/tmp` 私有目录、私有 HOME/prefix，不更新全局 npm、Pi、shell 配置、凭据或任何实际项目。启动短发布检查用本席位后台，完成通知后收取，和 V186 的发布测试自检不争用 smoke 执行锁。

用 `team version --check`、原 `release-check.sh --root <固定检出> --names-file <主仓既有名单文件>` 及所需短静态核对，记每个实码。保留要提交给 npm 暂存的包原件（可沿 V161 用 `npm pack --json` 在该干净固定源导出）及 npm 文件清单、SHA-256 与 npm integrity。对准备保留的具体包也真实做一次临时 prefix 下载包安装/`team help`（若能原样保留发布脚本那次安装的同一 tarball，直接采用，勿再装）；不得靠自报同版本推断两包相同。最终 tag 绑定验证版本，由 PM 后续记录，无权打/推任何标签、上架或改配置。

仅运行常规发布包装/安装；不为 PM 文字新增初始化检查、读取会话试验或启动真实模型，不重做已通过的 P488 审阅。不得跑 smoke、全量、元套件、容器性能或实际 npm 发布；V186 和后续专门发布路径负责其余项。写 `docs/team/reports/V189-dev3.md`，包含固定 SHA、实际命令、退出码、仅标签预期失败是否成立、可暂存的唯一文件及哈希/文件数和原件目录。只本地提交，原件等 PM 收取再清。