# P105 · 名册写入返工（空白席位名不许改状态 / `--model` 的记录必须与配置同源）· **apply（返工）** · dev

agent: dev   status: **DONE**
time: 2026-09-28
branch: `task/P105-p105`（local 模式：**不 push**，分支留给 PM；基点 `main@5c7ece76` —— 按任务书先
`git merge main`，fast-forward `347da969..5c7ece76`；新增断言落在 `config-cli.sh` 的 roster 段，没有新建 smoke 段，
所以不碰已被 P95/P99 占用的 §50/§51）
change: `roster-writer-and-route-truth`（P104 独立验证 FAIL 的两条 finding → 本返工单；返工授权来自
`docs/team/tasks/P105-roster-rework.md`）
deltas: `memory-and-deps`（MODIFIED，补"add 的席位参数本身是一个 token"的前置规则）·
`dispatch`（ADDED，补"同一命令随后写的记录必须与刚写入的配置同源"与 teardown 的跨 token 名）
grant 内改动（4 处实现/测试 + 2 份 delta）：

- `skills/teamsmith/scripts/lib/cmd-config.sh`（`team_config_seat_violation` 新增；
  `team_config_write_roster` 的 present 判定与 add 前置校验；`team_cmd_config_set_agent_model` 的同进程刷新）
- `skills/teamsmith/scripts/lib/cmd-agents.sh`（`team_cmd_add_agent` ①′ 席位形状前置校验 + 两条路线；
  旧的 ③ 值规则检查被 ①′ 吸收）
- `skills/teamsmith/tests/config-cli.sh`（roster 段 append：⑫ 四种空白形状 / ⑬ teardown 跨 token / ⑭ `--model` 读回）
- `openspec/changes/roster-writer-and-route-truth/specs/{memory-and-deps,dispatch}/spec.md`（措辞，见 §5）

证据目录：`docs/team/reports/P105-dev/logs/`（13 份原始输出）

**总结论**：两条 finding 都在**第一条写盘指令之前**堵住了。F1：席位名先按单 token 规则校验（空/空白/`/`/`pm`/形状），
`api 1` 这类名字现在 **exit 4、名册字节不变、不写 `result=ok`**，并且 teardown 的 present 判定改成 token 精确匹配
（`api` + `1` 两个 token 不再让 `api 1` 冒充已入册）。F2：`set-agent-model` 写入成功后在同一进程里刷新
`TEAM_AGENT_MODELS`（与名册写入器的 `TEAM_AGENTS="$new"` 同一纪律），于是 `add-agent --model` 随后写的 state 记录
与它刚写入的配置同源，`config list --json` 的席位行不再"显示旧模型却说 override=true"。
**P104 验证包（就是判 FAIL 的那个包）原样重跑：146 ok / 0 finding / 0 bad**，两条 finding 的证伪器都转绿；
四条验收命令 + 全量门禁全绿（routes 第一次的收尾 flake 见 §6，紧接着重跑全绿）。

## 1 · F1 逐条兑现（brief 的 5 条）

| brief 要求 | 落点 | 证据 |
|---|---|---|
| 1 形状在**任何写入之前**校验并拒绝：空 · 空白（空格/tab）· `/` · 保留名 · 已在册 | `team_config_seat_violation()`（`cmd-config.sh`，紧邻 `team_config_list_violation`）：空名、含 `[[:space:]]` 直接拒；否则单 token 上跑同一份列表规则（斜杠/pm/形状/重复）。`team_cmd_add_agent` ①′ 与 `team_config_write_roster` 的 `add` 分支各调一次；"已在册"仍是规范里的**可见 no-op**（0/不写/不审计），不是拒绝——见 §6 口径 | ⑫ ×4 组各 5 条断言（rc=4 / 字节不变 / no ok / 点名形状 / 给路线）；config-cli ⑥⑦ 旧形状不回归 |
| 2 teardown 的 present 按 token 精确匹配 | `team_config_write_roster`：`for t in $old; do [ "$t" = "$seat" ] && { present=1; break; }; done`（替换 `case " $old " in *" $seat "*)`） | ⑬：名册 `dev api 1` 上 `teardown --agent 'api 1' --register` → 5、字节不变、无 ok 行；真席位 `api` 仍可删（0，名册变 `dev 1`） |
| 3 审计只在真正成功时写 `result=ok` | 席位形状拒绝**不写任何审计行**（可预测的参数错误，与坏模型形状同族）；remove 的"不在名册"仍写 `result=refused` | ⑫⑬ 都断言 `grep -c 'result=ok'` = 0 |
| 4 夹具补齐四种形状，每种断言三件事 | `config-cli.sh` roster ⑫：`api 1` · ` api` · `api ` · `api<TAB>1` | 每组：`rc=4` · sha 不变 · ok 行 0（另加形状与路线两条） |
| 5 拒绝时给两条**真实**出路 | `team_cmd_add_agent` ①′：`· 换成形状合法的名字再跑：team add-agent <名字> --register` · `· 或手改 .pi/team/config.sh 里的 TEAM_AGENTS（名字同样要匹配这个形状）` | ⑫ "给出手改路线" + "点名接受形状"；真实输出见 §3.3 |

**根因**（与 P104 验证包的观察一致）：`team_config_list_violation` 判的是**结果值**，`api 1` 追加后得到
`dev verify api 1` —— 四个各自合法的 token，值规则不会响；于是名册先被写脏并落一行 `result=ok`，命令随后才在
`team_worktree_add` 的 `team_require_agent` 里以"未知 agent：api 1"失败（rc=1）。写入侧与读取侧现在都在
"结果的 token 形状"之外多一层"参数本身是一个 token"。

## 2 · F2 兑现（`--model` 的记录与配置同源）

**根因**：`team_cmd_config_set_agent_model` 写盘后用 `team_config_write_checked` 直接返回，**没有**刷新进程内的
`TEAM_AGENT_MODELS`；同一条命令随后的 `team_worktree_add` 用 `team_agent_model`（读进程内旧值）写 state，于是：

```
TEAM_AGENT_MODELS='dev=vendor/m2'          # 配置 ✓（P104 复现）
model=opencode-go/deepseek-v4.1-flash      # ✗ 写盘前的值
model_src=config
dev  ... src=record  override=True          # ✗ 旧模型 + 自称有 override
```

**修法**（brief 给的第一条路线"更新成同源值"）：

```bash
team_config_write_checked TEAM_AGENT_MODELS "$newval" ... || rc=$?
# 同进程刷新（P105/F2）：add-agent --model 写完后走同一个进程的 worktree/state 记录步骤
if [ "$rc" -eq 0 ] && [ "$dry" != "1" ]; then TEAM_AGENT_MODELS="$newval"; fi
```

pm 席位同款刷新 `TEAM_PM_MODEL`。**为什么选"更新"而不是"不记"**：M14/M47 的三态口径（记录与配置解析不一致
→ `source=record` + 记录里的模型）是既有规格，不能动；要修的是**写路径自己制造的**不一致 —— 同一条命令改完配置
又写记录，记录必须来自它刚写入的配置。`set-agent-model` 单独改配置时，旧记录如实变成 `历史记录`（M14 的语义：
"下次派单会用新配置，不是它"），那不是本次缺陷的形状。

**形状覆盖**：⑭ 的夹具先埋 `model=old/legacy-model` + `model_src=config`（"记录里先有旧值"，上一版漏掉的形状），
写后断言 state 记录 = `vendor/m2` / `model_src=config`，且 `config list --json` 的席位行
`model=vendor/m2 · source=config · override=true`。

## 3 · 红/绿原始输出（flip evidence）

### 3.1 新断言在旧代码上会红（本轮新测试 + 未修的实现）

```
$ git show 5d1ab86b --stat        # test(P105) 提交（只加断言）
$ bash skills/teamsmith/tests/config-cli.sh roster          # 旧实现 + 新断言
✗ ⑫ space-inner：名册字节不变（期望 [2001d620…]，实际 [646ca6eb…]）
✗ ⑫ space-inner：审计里没有 ok 行（期望 [0]，实际 [1]）
✗ ⑫ space-lead：… ✗ ⑫ space-trail：… ✗ ⑫ tab：…（同两组）
✗ ⑬ 空白名 teardown：rc=0（跨 token 假命中）
✗ ⑬ 名册字节不变  ✗ ⑬ 审计里没有 ok 行
✗ ⑭ state 记录与配置同源（model=vendor/m2）（期望 [1]，实际 [0]）
✗ ⑭ 席位行显示配置生效的模型（不是写盘前的旧值）
✗ ⑭ 席位行来源 = config（记录与配置同源，不是历史记录）
== 结果 ==  ✓ 84  ✗ 22  SKIP 0
```

全文：`logs/red-roster-before-fix.log`。

### 3.2 破坏实现 → 守门断言必须红 → 还原 → 绿

把两处守卫分别改回旧形状（`①′` 换成 `if false`、present 换回 `case` 跨 token、刷新那行换成 `:`），roster 段：

```
✗ ⑦ 无旗标的脏席位 → 4（不再带着非法名走到 state 写盘）（期望 [4]，实际 [1]）
✗ ⑫ space-inner：没给路线（✗ TEAM_AGENTS：席位名 api 1 非法：…）
✗ ⑫ space-lead/space-trail/tab：没给路线
✗ ⑬ 空白名 teardown：5（名册里没有这个席位）（期望 [5]，实际 [0]）
✗ ⑬ 名册字节不变  ✗ ⑬ 审计里没有 ok 行
✗ ⑭ state 记录与配置同源  ✗ ⑭ 席位行显示配置生效的模型  ✗ ⑭ 席位行来源 = config
== 结果 ==  ✓ 95  ✗ 11  SKIP 0
```

`git checkout --` 还原后与损坏前的备份逐字节相同（`diff -q` 无输出），再跑：

```
== 结果 ==  ✓ 106  ✗ 0  SKIP 0
```

全文：`logs/flip-break-guards-off.log` · `logs/flip-restore-after.log`。

### 3.3 手工复现（PM 原文的 after）

```
$ team add-agent 'api 1' --register
✗ add-agent：席位名 api 1 非法：席位名是一个 token，不能含空白（空格/制表符）；接受 [A-Za-z0-9][A-Za-z0-9._-]*
  席位名要能当工作树目录名/窗口名/state 文件名，接受形状 [A-Za-z0-9][A-Za-z0-9._-]*（一个 token）。两条真能用的路线：
    · 换成形状合法的名字再跑：team add-agent <名字> --register
    · 或手改 .pi/team/config.sh 里的 TEAM_AGENTS（名字同样要匹配这个形状）
rc=4 · TEAM_AGENTS="dev verify"（字节不变）· ok 审计 0 行（审计文件根本没建）

$ team add-agent dev --model vendor/m2 --no-install
rc=0 · TEAM_AGENT_MODELS='dev=vendor/m2' · dev.env: model=vendor/m2 model_src=config
席位行：{'agent': 'dev', 'model': 'vendor/m2', 'source': 'config', 'override': True}
```

全文：`logs/repro-after.txt`（P104 验证包的 `lib.sh` 自建 scratch 夹具；真名册未被动）。

## 4 · 验收命令与结果

| 命令 | 结果 | 原始日志 |
|---|---|---|
| `openspec validate --all --strict` | **17 passed / 0 failed** | `logs/openspec-final.log` |
| `bash skills/teamsmith/tests/config-cli.sh list validate roster models seats` | **✓ 178 ✗ 0** | `logs/configcli-sections.log` |
| `bash skills/teamsmith/tests/config-cli.sh`（全段） | **✓ 255 ✗ 0**（rc=0） | `logs/configcli-full.log` |
| `bash skills/teamsmith/tests/routes.sh`（第一次） | 169 ✓ / 1 ✗：唯一红是 flips 收尾"留下 1 个嵌套临时根"（见 §6 观察） | `logs/routes-run1-cleanup-flake.log` |
| `bash skills/teamsmith/tests/routes.sh`（紧接着重跑） | **✓ 170 ✗ 0**（rc=0；含七条翻转全绿） | `logs/routes-run2-green.log` |
| `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh` | **✓ 2876 ✗ 0**（rc=0；678s，机器同期有其它负载） | `logs/fast.log` |
| 全量门禁 `openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh` | **✓ 3541 ✗ 0**（rc=0；`smoke 全绿`，1869s） | `logs/full-gate.log` |
| P104 验证包原样重跑 `bash docs/team/reports/P104-dev-bob/pkg/run.sh` | **ok=146 · finding=0 · bad=0**（分节失败=0；30-hostile 与 60-model-flag 都 finding=0） | `logs/p104-verify-package.log` |

## 5 · delta 措辞改动与理由（改动仅限两条实现缺陷让原措辞失效的地方）

1. `memory-and-deps`（MODIFIED 需求段 + "violating value" 场景）：
   原措辞只规定**结果值**是合法的 token 列表；`api 1` 追加后的结果值合法，所以规则放行了它。补：add 的席位
   参数本身必须是一个 token，**任何写入之前**校验，违规 → exit 4 + 契约字节不变 + 无 `result=ok`；场景 WHEN
   加上 `'api 1'`（含 tab 变体），并注明旧的 `result=ok` + 后续失败就是红侧。
2. `dispatch`（ADDED 需求段 + `--model` 场景 + teardown 场景）：
   - 原需求说 `--model` 走同一写入器，但没说**同一命令随后写的记录**必须来自刚写入的配置 → 补一句
     "Whatever that same command records about the seat's model afterwards SHALL be read from the configuration
     the write just produced"；场景 THEN 补"命令留下的 state 记录（若有）与配置一致"。
   - teardown 场景补：两个 token 拼出来的名字（`api 1`）不是席位 —— exit 5、字节不变、无 `result=ok`
     （旧实现的成员判定跨 token 命中，把"什么都没删"报成成功）。
   - 需求段同时点名"席位名不合法 → 写入前 exit 4"，让 F1 的退出码与两处守卫在规格里有落点。

`openspec validate --all --strict` 在改措辞后通过（§4）。除此之外没有改任何 delta 语句。

## 6 · 口径与取舍

- **保留名 = 只有 `pm`**：沿用 `team_config_list_violation` 的既有唯一规则（"一条规则，读写同一份"）。
  `verify` 在本项目是普通席位名（P104 包 30⑥ 实测"名册无它 → 作为普通席位注册"），不设为保留名。
- **"已在册"仍是可见 no-op（0/不写/不审计），不是拒绝**：这是本 change 的规范（R2
  "Re-registering is a no-op"、§P104 包 30⑤），与 brief F1 第 1 条并列时按更具体的规范执行；"已在册"
  且旧值非法时仍 exit 4（既有第三条路径）。§4 的 ④⑥⑦ 断言都在。
- **teardown 的空白名退 5、不是 4**：remove 路径不查形状（移掉手改出来的非法 token 是合法的，见
  `team_config_write_roster` 注释与 P99 规格），present 精确匹配之后自然落到"名册里没有这个席位"。
  这正是 F1 第 2 条要的行为。
- **无旗标的 `team add-agent 'api 1'` 现在退 4（以前退 5）**：形状判定在"未知席位 → 退 5 + 两条路线"之前；
  名字本身不合法时，4（invalid）比 5（refuse）更精确，也保证它不会走到任何写入。合法名字的无旗标路径仍是 5
  （②的 20-refusal 与 config-cli ① 都未回归）。
- **F2 写的是 `model_src=config`，不是 `explicit`**：M14 把 `explicit` 留给"上次派单 `--model` 指定"，
  把一次配置改写标成 explicit 会把两个语义混掉；同源之后 `team_agent_model_src` 自然把它归为"配置"
  （⑭ 断言 `source=config`）。brief 给的"或更新成 vendor/m2 + model_src=explicit"里，前半个值做到了，
  来源标签按既有语义取 config。
- **`set-agent-model` 单独改配置时**，既有记录会如实变"历史记录"（M14 的设计语义："下次派单会用新配置，
  不是它"）—— 那不是本次缺陷的形状（记录不是同一条命令写的）；本次修的是"同一命令改完配置又写记录"时
  记录必须读刚写入的配置。
- **席位形状拒绝不写任何审计行**：与"坏模型形状"同族 —— 可预测的参数错误不落盘（brief 第 3 条允许
  "要么不写，要么写明确的结果"）。对比：remove 的"不在名册"写 `result=refused`（既有行为）。
- **routes.sh 第一次的收尾红是夹具清理 flake，不是实现红**：第一次 169✓/1✗，唯一红是 flips 结束时
  `find /tmp -name 'teamsmith-routes.*' -newer "$tmp"` 数到一个嵌套 run 的临时根；紧接着重跑 170✓/0✗ 全绿，
  残留根也已不在（tmp-root 台账会回收 owner 已死的根）。我没有改任何 `tests/lib/tmp-root.sh` 或 flips 代码，
  两份日志都原样留档（`logs/routes-run1-cleanup-flake.log` / `logs/routes-run2-green.log`），交 PM 判断。
- **全量门禁**：交付前跑完整套件（`openspec validate --all --strict` 17/0 + full smoke **✓ 3541 ✗ 0**，1869s，
  机器同期有其它 team 负载），原始输出 `logs/full-gate.log`；上表的 FAST 与全量都在本 tip 上。

## 7 · 提交

```
5d1ab86b test(P105): pin the two roster-writer defects the P104 verification confirmed
1d59c7c2 fix(P105): reject a physical seat name before any write, and keep the model record same-source
ed9ca23a docs(P105): carry the two fixed shapes into the deltas where the wording stopped short
```

BLOCKED：无。跨目录改动：无（全部在 grant 内）。
