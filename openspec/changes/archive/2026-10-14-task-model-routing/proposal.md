## Why

当前 worker 模型跟席位绑定，同任务恢复会重新解析配置并丢失显式模型和 fresh SID。把选择依据改为项目定义的任务类别，并把 Teamsmith 已选择的完整启动身份作为恢复来源，才能让强模型用于复杂判断和独立复验，而非所有实现任务。

## What Changes

- **BREAKING**：删除 worker default、席位模型策略及其写接口；新增项目类别映射和必填独立 PM 模型。不保留旧路由、自动迁移推断或静默兜底。
- brief 唯一 `category:` 声明；新任务按映射或显式 `--model` 选择，同任务恢复保留已选完整 category/model/SID/provenance，即使合法未来映射删除该类别也不重新选择。新任务、换模型（包括 thinking suffix）及明确 fresh 接管使用新会话。
- 完整 launch 记录原子发布；预览/拒绝无启动副作用；恢复、并发、窗口检查与 model/source/SID 展示使用同一身份源。
- 配置 CLI 的唯一 writer 提供显式模型策略升级事务；旧键仍可诊断和修正。设置页改为类别策略/独立 PM 编辑及只读实际 assignment 展示。
- 更新初始化、模板和 PM/worker 指引；活动、大小和死因读侧按记录 SID 关联。PM 复用原启动器并保留存活证明。
- 保留 worker 范围并发规则、安全守卫与独立验证；正限额下活 peer 的可信 model 身份不明时明确拒绝，不计为零或从 policy 猜；不处理 Pi 消息、思维链或 provider 兼容。

## Capabilities

### New Capabilities

无；不另建模型路由规格体系。

### Modified Capabilities

- `dispatch`：brief 类别、选择/恢复、完整启动事务、预检、并发与窗口输入、撤销注册时的席位模型语义。
- `memory-and-deps`：退休旧模型合同；映射/PM schema、唯一 writer/升级、JSON 策略与实际记录、模型形状。
- `panel`：退休席位模型编辑；类别与 PM 编辑、实际来源显示、关联 SID 活动。
- `agent-adapters`：独立 PM 解析、Teamsmith 参数所有权和保留 frozen seam。
- `pm-lifecycle`：原 PM 启动路径的模型身份与 fresh/continue 限制，不改变存活证明。
- `init-skill`：类别问卷、模板、破坏式升级指引与已有项目的显式授权边界。
- `watchdog`：不自动恢复 worker；当前 SID/launch 的死因归属、阻塞 PM 恢复的可见诊断。

## Impact

涉及 `skills/teamsmith/scripts/lib/{common,cmd-config,cmd-agents,cmd-watch,cmd-status,cmd-death,cmd-project,cmd-bootstrap,cmd-docs}.sh`、`scripts/monitor.mjs`、panel 源码/提交 bundle、模板、两技能及 references/README，以及既有 config/routes/smoke/panel/death 夹具。无需新增 provider、订阅、依赖、分类器或兼容矩阵。

本阶段只有规划工件；不改 canonical specs、运行配置、安装、进程或历史材料。后续 apply 等待记录在案的 PM proposal review 和用户看过工件后的明确执行请求。本机两条全局技能软链实际指向本仓主检出的对应 skills；改该源码即可能影响后续共享读取，无 installer 也不是隔离。未来切片只在非部署私有集成树交接/验证，不把 S1 部分实现先放共享 main，也不据私有集成提前标 apply done。完整源码在独立验证后，须另获稳定共享源隔离或明确共享影响授权及保护分支落地授权，才能进入共享 main。本仓配置切换/fresh 启动、共享来源采纳/链接/安装、其他项目采用分别授权；不承诺未知消费者不受影响，不新增自动扫描/部署系统。合并、推送与真正归档仍保持既有边界。
