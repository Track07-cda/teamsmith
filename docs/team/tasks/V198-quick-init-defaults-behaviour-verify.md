---
id: V198
title: 独立验证新项目默认模型、任务类型及只读预览
agent: dev3
category: verify
phase: opsx-verify
change: quick-init-model-defaults
specs: init-skill
deltas: -
branch: task/V198-quick-init-defaults-behaviour-verify
---

# V198 · 在隔离项目实测首次初始化

实施者 dev-bob；冻结 `1a994aa545a3314dbf5b593eeeb303aa4b515c8a`，干净独立检出 `/var/tmp/p500-review-1a994aa5.fmLZnu`。先读 AGENTS、本人线程、OWNERSHIP、P500 与方案工件、候选交付报告。原生 2.1 是唯一行为验收；作者语法回执可引用，规划除实施勾选四处外未改，不重复全量结构/构建/安装。固定检出保持干净；任何可写的仓库、设置或脚本副本都在本人 `/var/tmp` 私有根。不能读个人 Pi 文件、接触项目真实配置、启动真实 Pi 或 Pulse、修改实际安装、启动或联系其他项目。

- **候选正常运行只一次。** `TMPDIR=/var/tmp TEAM_ROUTING_EVIDENCE=/var/tmp/<你的证据根>/init bash skills/teamsmith/tests/task-model-routing.sh --select init </dev/null`。给这次运行私有 `HOME` 与 `PI_CODING_AGENT_DIR`，unset 继承的团队、tmux、Pi 运行身份；确认既有 JS 能调用（若 `node` 是本机容器转发包装，先依据文件位置选真实本机二进制，不因准备错误重跑），实际 init 样本无 Pi on PATH、bootstrap 走原 `--no-pulse`。不跑 §61、§61b 或完整套件。保存实际配置 JSON/命令、退出值、未跑面。普通 `init` 不带模型参数要读到按序三类及 PM；核样本保存的完整模型字符串（含内嵌 `/` 和预期档位）。从原始数据比对 bootstrap 预览/写入四个值、预览无写入、两个单项与全显式覆盖、明确坏路径和坏模型不写入、已有合法/缺损/旧配置按原规则。无写入要覆盖新路径及链接，不只看文件哈希。
- **短源码审查。** 跟进 `team_load_config` 发现值、主检出 init 目标和配置显式路径；核正常可用链接不被拒，无法使用的选定路径不会在别处创建。跟进 bootstrap 的一次默认读取与现有两参数交接；复用校验不算再次默认读取，不因“零次”遗漏旧依赖检查。检查 help 的中英默认路径/失败下一步不再教新手升级，必要时在私有根通过 `team help init` / `team help bootstrap` 读取短实际输出，仅命令帮助不初始化。报告显示缺口时不要用说明文本代替运行证据。
- **一个生效的反例。** 从 `init-saved` 样本和作者报告取同样的私有 JSON 和隔离环境，用原 `init --no-skills` 的最短入口。私有副本只令 `team_init_saved_model_candidates` 不返回默认，让原命令实际退出 4、贴出本命令的缺值提示并验证无创建；恢复只在另一个等价干净小仓库运行这一个命令，实际读回预期三类与 PM。记录修改差异、同条件、命令输出和 Git/目录状态。不得以缺 JS/Pi、命令没启动或额外错误充作发现，且不为红绿重跑整个 init 组。旧 `init-legacy-proceeds` 的改动仅静态核为合法映射并留有原点名断言，不跑变异全组。

以专用 runner 通过 `TEAM_GATES='bash /var/tmp/<你的证据根>/<runner>' bash skills/teamsmith/scripts/team review P500 --dir /var/tmp/p500-review-1a994aa5.fmLZnu --branch 1a994aa545a3314dbf5b593eeeb303aa4b515c8a` 保存原生记录。有长命令用后台启动后结束回合，完成通知再收结果。中央只允许该工具写 `docs/team/reviews/P500.md` 与 `P500-verify.log`；其他主检出只读。若有实际失败，保留原件，点名原因及未完成项，不更改产品、测试或自行重跑。记录通过/失败/跳过和耗时是实测，不推断全套通过。

本人分支只提交 `docs/team/reports/V198-dev3.md`，先写可否接受、实际观察或阻塞，附正式记录、输出与证据根，Git 差异检查实际回执。小步本地提交（V198 / `Agent: dev3`）；不勾任务、不合并、推送、发布或归档。验收通过后由同一人仅在 PM 给的新固定合并检出做同一性和必要短核对；原件保留至 PM 确认。

## 合并后只做短核对

`da29a98b` 的候选 100/0 与坏/恢复证据已接受，中央原件已另存。固定合并版 `ef2e832c5eb746d0044ec553372df50c7d8b168b`，干净检出 `/var/tmp/p500-merged-ef2e832.EIU3Nq`。由同一 V198 会话追加报告。先比较 `32818d23..1a994aa5` 的 19 个候选变化文件在合并版逐字节相同；仅任取同样一个带私有 Pi 设置的新测试仓库，实际运行一次合并版 `team bootstrap --print`，查看四个值、无待补说明、无任何项目文件/链接变化。本轮不运行正式 init/bootstrap、全组、旧配置演练或反例。用 `TEAM_GATES` 指向这份短 runner、`team review P500 --dir /var/tmp/p500-merged-ef2e832.EIU3Nq --branch ef2e832c5eb746d0044ec553372df50c7d8b168b` 得原生记录，按后台作业规范交付。保留本轮证据，未核对不报通过；不部署、不改真实环境。