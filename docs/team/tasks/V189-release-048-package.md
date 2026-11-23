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

定点最终候选：见本席位最新 V189 线程，完整 SHA 和全新干净检出。只修 README 旧 HTTPS pin 和 P489 清单两行，+ 期间账本记录；未发布。保留首轮 27/3/0、旧 287 条包清单和旧原件；不重复已通过的三条安装路线。在最终候选对照前一轮实际源与包范围，重打包一次取最终 TGZ、逐成员比较并运行该确切包最短安装/帮助核对；再利用原 `release-check.sh --skip-install` 补最终公开面和版本（显示跳过安装不是说未已有证据）。tag 缺失回执原样留存，本席位不打标签、不暂存、不发布。

包已收取：`f2cf4d38`。仍在同一 `2201a79d` 固定检出一次完成发布清单原有 `release-check.sh --self-test`（无需 smoke 锁，使用本人隔离 HOME、prefix、缓存、临时根，不重复正常安装路线）及固定镜像参考性能（只有参考读数，不设阈值）。按 V161 已成功的做法，将固定源以 `git archive` 导出到本席位拥有且宿主可见的新证据目录，验证与固定提交同一，然后使用既有 `localhost/teamsmith-gate:local`，`distrobox-host-exec podman run --pull=never`、只读源挂载、容器内 `TMPDIR=/var/tmp`；不要重新拉、建镜像或碰环境配置。两项只后台执行、收取真实回执并追加报告；若镜像不存在或无法完成，写退出码和确因，不能拿宿主或上次读数替代。不要重打包、不重跑完整套件、不新增 PM 行为测试，不打标签、暂存或发布。