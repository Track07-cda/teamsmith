# P493 · 提醒诊断为何把仍在运行的 PM 报为未运行

agent: dev-bob   status: DELIVERED（只读诊断）   time: 2026-11-24 UTC

branch: `task/P493-ci-reminder-pm-recognition-explore`   PR/MR: -

**结论：先修 §67 的启动夹具，不改提醒产品。** 同一个 Pi 1.6.0，夹具启动的 `pm` 和 `noentry` 都实际在运行，但两层 shell 把 Pi 放到了窗口进程的孙进程，夹具又没有走正式 PID 登记，因此 `doctor` 两例都报了 `not-running (unknown:sh)`。让正式启动流程登记后，同两例分别报告 `ready` 和 `unknown evidence:ENOENT`；真正停止后仍报告 `not-running`。两种启动中，产品的进程判据都认得 npm Pi 本身；不是 npm 路径误判，也没有发现这两例的提醒发送失败。

## 证据与判定

GitHub run `45318204605` 的原件优先：只读 s1 日志 `138190141568.log:3755–3772`，并从已保存 `s1.zip` 读取 `p442-remind-tool-real.log:3,54,102` 及两份 `doctor-*.txt`。原批 `8/2`；失败两例的 `session-start` 与 `pm.pid.spawn` 分别同为 `523430`、`530843`，均无 `pm.pid`，两个诊断同报 `unknown:sh`。原制品未保存当时的进程树，以下树是本次独立复现，不冒充 CI 当时的读数。

| 本次场景 | 诊断前后不变的窗口进程 → Pi；PID 回执 | 实际 `doctor` 提醒诊断 |
|---|---|---|
| 原 `pm`，11 次本地应答请求 | pane `428`（`sh -c …`）→ `429`（`bash …/launch.sh`）→ Pi `430`；`pm.pid.spawn=430`，无 `pm.pid`；扩展证据 `registered` | `not-running：PM 未在运行（unknown:sh）`，原 `ready` 断言失败 |
| 原 `noentry`，1 次请求 | pane `2751`（`sh -c …`）→ `2752`（`bash …/launch.sh`）→ Pi `2753`；`pm.pid.spawn=2753`，无 `pm.pid`；无扩展证据 | `not-running：PM 未在运行（unknown:sh）`，原 `unknown evidence:ENOENT` 断言失败 |
| 正式 `pm`，11 次请求 | pane 就是 Pi `4760`（父 `4532` 是私有 tmux server）；`pm.pid.spawn=pm.pid=4760`、`pm.pid.proof=argv`；扩展证据 `registered` | `ready extension reported registered/active`；保留同一原断言，通过 |
| 正式 `noentry`，1 次请求 | pane 就是 Pi `7947`（父 `7715` 是私有 tmux server）；`pm.pid.spawn=pm.pid=7947`、`pm.pid.proof=argv`；无扩展证据 | `unknown evidence:ENOENT`；保留同一原断言，通过 |
| 正式 `pm` 正常停止后（原场景已有的停止检查） | Pi `4760` 已退出、pane 及扩展证据均消失；旧 `pm.pid` 尚在，但 spawn 活进程核对 `rc=1` | `not-running：PM 未在运行（missing）`；通过，没有把旧 PID 当活进程 |

- **进程实际不在搜索范围内，而非启动名不匹配。** 四个 Pi 的 `session-start` PID 均等于 spawn 回执；`/proc/<pid>/exe` 都是 `/usr/local/bin/node`，稳定期 `argv[0]=pi`，`cwd` 都是对应私有项目根。原样本在同一次 `doctor` 前后分别对每层调用冻结的 `team_proc_is_pm_bin`：两层 shell 都返回 `1`，直接验孙进程 Pi 则返回 `0`，而 `team_pm_pane_agent_pid` 返回 `1`。`common.sh:2727–2785` 的兜底只看 pane 本身和直接子进程，不读孤立的 spawn 回执；两个原样本的 `team_pm_spawn_pid` 各能读到真 PID，但 `team_pm_recorded_pid` 都返回 `1`。不能靠认 `sh`、无条件收下 `.spawn` 或放宽归属判定来改绿。
- **正式启动不再有那层包装，且产出了正式登记，并非手工补 PID。** `team_pm_start` 两例都返回 `outcome=started rc=0`，写入 `pm.pid`、`pm.pid.proof=argv`、`pm-launch.env`；`team_pm_pane_agent_pid` 与三处回执 PID 同值。`common.sh:3822–3852` 允许 `argv` 或 `spawn` 作为正式启动的证据，本次两例实际走的是 `argv`，未实测 `proof=spawn` 分支。启动时提示替换的 `sh` 是夹具事先建的 `sleep 600` 私有占位窗，不是在替换已运行的 PM。
- **识别失败不等于提醒发送失败。** 原 `pm` 的 9 个 `team_remind` 工具回执均无错误，`custom_start` 到达原场景的 `observed` 断言，继而通过同 key 续期及无 key 的不同 ID 断言，才在 `doctor` 处失败；原 `noentry` 则确实无工具注册。`cmd-project.sh:809–834` 在非 `running` 时优先报未运行（有已验证的明确扩展错误时例外），所以两原样本的提醒诊断看起来相同。五次 `doctor` 进程总退出码均为 `1`，另有私有环境缺 magic-context、无 `openspec/` 两项一般失败；不是提醒状态断言的退出码。

## 实跑命令与原始收据

冻结源是 `c34e1468ea2ab76bdff9cd2bbef0db650604d151`。从本工作树导出 `git archive c34e1468 skills/teamsmith` 到自建临时目录。用无账号的独立 HOME、两份空 npm 配置、私有缓存和前缀执行 `npm install -g --prefix "$r/prefix" --cache "$r/cache" --userconfig "$HOME/empty-user.npmrc" --globalconfig "$HOME/empty-global.npmrc" --registry https://registry.npmjs.org --no-fund --no-audit --ignore-scripts --fetch-retries=0 '@earendil-works/pi-coding-agent@1.6.0'`，成功安装 123 个包。CI 制品已在磁盘，未重下。现有容器镜像内用只读挂载换入私有 npm 包目录，沿用 `/usr/local/bin/pi → ../lib/node_modules/@earendil-works/pi-coding-agent/dist/bundle/cli.js`；没有重建或改共享镜像。

```bash
h=/var/tmp/p493-bob.ECoUS5
distrobox-host-exec podman run --rm --pull=never --network=none --userns=keep-id \
  -v "$h:/p493" -v "$h/src:/work:ro" \
  -v "$h/prefix/lib/node_modules/@earendil-works:/usr/local/lib/node_modules/@earendil-works:ro" \
  -w /work localhost/teamsmith-gates:ci env -i PATH=/usr/local/bin:/usr/bin:/bin \
  HOME=/p493/home TMPDIR=/p493/tmp LANG=C.UTF-8 TERM=xterm-256color bash /p493/run.sh </dev/null
# run.sh 顺序执行 original、formal，各自仅执行：
# P493_LAUNCH="$mode" P442_EVIDENCE="/p493/evidence/$mode" P442_KEEP=1 P442_PI=/usr/local/bin/pi \
#   bash /work/skills/teamsmith/tests/remind-tool-real.sh --select=pm,noentry
```

临时副本只改驱动：把 `noentry` 从包含其它三例的 `doctor` 组单独选出；在每次实际 `doctor` 前后记录 pane、`/proc` 父子/argv/cwd/start tick、正式 PID、spawn、启动及扩展证据。原模式不改任何产品调用和原断言。正式模式用同一个私有项目布置和 loopback 响应序列，通过未改的产品 `team_pm_start` 启动，取消原夹具手工发布的启动信息；正式 `noentry` 只在试验的命令拼装函数中省去一个 `-e …/team-remind.ts`，与原 `noentry` 的条件一致。没有伪造 PID、注册证据或 `doctor` 输出。容器私有 PID 命名空间及无外网区别于公开 CI；重现了相同的 npm 路径、Node/Pi/tmux 版本、非 root 运行和默认 `/bin/sh`，不声称逐项重造 runner。

```text
node=v24.22.1 npm=11.19.1 pi=1.6.0 tmux=tmux 3.7b
/usr/local/lib/node_modules/@earendil-works/pi-coding-agent/dist/bundle/cli.js
mode=original rc=1
FAIL real Pi PM add/list/show/cancel, retry, observed same-key renewal and no-key IDs
FAIL real Pi running PM with no entry is unknown, not a load failure
remind-tool-real: passed=0 failed=2 evidence=/p493/evidence/original
mode=formal rc=0
PASS real Pi PM add/list/show/cancel, retry, observed same-key renewal and no-key IDs
PASS real Pi running PM with no entry is unknown, not a load failure
remind-tool-real: passed=2 failed=0 evidence=/p493/evidence/formal
```

原始证据包：宿主 `/var/tmp/p493-bob.ECoUS5/P493-evidence.tar.gz`，distrobox 中加 `/run/host` 前缀；SHA-256 `dd4ccb196c0a14baff66836dfff0e7f2d980aa74318a507d5bb51f9602e9b87f`。包内 `evidence/{original,formal}/{pm,noentry}/doctor-*-{before,after}.json` 对应同名 `.txt` 和 `.rc`；另有启动收据、会话事件、loopback 请求和完整观测差异 `evidence/instrument.diff`。只保留此原件包供收件，私有安装和运行目录已回收；重做须按上方准备步骤恢复所列文件。逐组对照前后快照，pane、实际 Pi 启动刻度与 PID/启动记录稳定一致。作业 `p493-pm-recognition` 26.3 秒；外层 `rc=0` 仅说明两轮均完成收集，样本结果以上述分组退出码为准。

## 建议与未验证范围

- 让 §67 的这两例经正式 PM 启动登记运行，保留 `ready`、无入口 `unknown`、停止 `not-running` 的原断言；在验收时对齐 pane 里的真实 Pi、正式 PID 和 spawn 回执。保留私有 tmux、受控 loopback、定点停机与回收；不为本次夹具引入通用递归查找或改变 `doctor` 语义。
- 只跑原 `pm`、`noentry` 和它们的正式启动对照（含 `pm` 原有停止检查）。未测试另外八例、递归手工启动、外来窗口、错误证据、`proof=spawn` 实际分支或其它 Pi 版本；未跑完整 §67、其它 smoke 段、OpenSpec 全量或 GitHub CI。若可支持的正式或人工启动另有独立失败，再按同一身份记录查产品，不把本报告外推成所有启动形态通过。
- 唯一仓内交付是本报告。OpenSpec 锚点 `agent-self-reminder#PM tool availability is honestly diagnosed` 已核，本单是 `opsx-explore`，不是实现或独立验收。不改代码、测试、规格、CI、用户安装、实际项目/待命/会话、发布标签或 npm 包；无远端写入。

### 账本检查

```text
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=/home/<user>/Documents/syncthing/Work/Projects/pm-skills/.worktrees/dev-bob scope=published files=3024 hits=0 names=ok user=resolved
ledger-ban rc=0
```
