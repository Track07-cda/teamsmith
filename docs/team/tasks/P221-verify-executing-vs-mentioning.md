# P221 · P217 的换人独立验证（"正在执行" vs "只是提到"）

```
task:   P221
agent:  verify
issue:
change: -
specs:  -
phase:  verify
anchor: none (infra) — 验证 P217
deltas: -
grant:  docs/team/reports/P221-verify.md · docs/team/reports/P221-verify/**
deps:   被验实现**已并入 main**（`085713e2`）；apply=dev；你没写过它 —— 合规。
        **注意**：这条判据管的是"席位到底在不在跑"，判错的两个方向都贵 —— 假活会让你漏掉交付（P103：我 26 小时没被叫醒），
        假死会让 `team resume` 的 respawn **杀掉一个正在干活的 agent**。
status: todo
budget: 中
priority: 高（两条真缺陷里的一条；另一条 §39 已由 P218 修好）
```

## 要验什么（自己造形状，别只引用 flip-p217）

1. **两个方向各一组形状**（用**你自己的**假 agent 脚本，不要用 `p55-agent`）：
   - 应当算**在跑**：① pane 命令 = agent 脚本（`bash <agent>`）；② `bash -lc <agent>`；③ `bash -lc '<agent> & wait'`；④ 生产 harness 形状（`respawn-pane … bash -lc '<agent>; :'`）；
   - 应当算**不在跑**：⑤ **只是提到**它（`bash --noprofile --norc -s <agent>` 这类启动壳/派单 harness 形状）；⑥ 命令行里根本没有 agent；⑦ pane 已死（`remain-on-exit` 的遗体）。
2. **端到端**（不要只调函数）：对 ① 与 ⑤ 各造一个席位，看 `team resume --dry-run` / `team status` 的结论 —— ① **不许**被列成可续跑（列了就会 respawn 掉一个活着的 agent），⑤ **必须**被列成可续跑（那是 P103 要堵的假活）。
3. **影子（≥2 条）**：① 把"正在执行"的判据放宽成"命令行里提到就算在跑" → ⑤ 必须**红**（洞被放回来）；② 把判据收紧回"只看直接子进程" → ① 必须**红**（假死回归）。
4. **夹具与生产一致**：指出 §41 夹具现在的启动形状，并**自己证明**它与生产路径（`cmd-agents.sh` 的 respawn/harness）同形；若不同形，如实报出差异。
5. **门禁**：`openspec validate --all --strict` + 容器内 **live（非 FAST）** `--select 41`（`needs` 会带 §2；**如果你在树上看到级联，先确认 `needs` 是不是 `2`**）；报告点名"哪些自己跑、哪些引用"；证据包按 D94 留在工作树。
