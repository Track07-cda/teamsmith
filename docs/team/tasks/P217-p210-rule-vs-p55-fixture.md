# P217 · P210 的判据与 §41 的夹具互相矛盾（真缺陷）

```
task:   P217
agent:  dev
issue:
change: -
specs:  -
phase:  apply
anchor: none (infra) — 修判据或夹具，二选一但必须说清理由
deltas: -
grant:  skills/teamsmith/scripts/lib/common.sh · skills/teamsmith/tests/** · skills/teamsmith/references/** · docs/team/reports/P217-dev.md · docs/team/reports/P217-dev/**
deps:   P214（dev）的现场：tip 上 §41 两条红（`P55 ④：roster 四态 ① running（证明成立）` 与机器面 `state=exited`），
        它把**四种启动形状**在容器里逐一量了出来（见 `docs/team/reports/P214-dev.md` 的三.③ 与证据 `probe-p55-shapes.out`）
status: todo
budget: 中
priority: 高（**我们自己的套件抓到了自己的回归**；且这条判据管"席位到底在不在跑"，判错会让人静默漏掉交付）
```

## 现场（P214 实测，你要自己复现一遍）

| 形状 | pane_pid 的 argv | 直接子进程 | P210 判成 |
|---|---|---|---|
| ① §41 夹具现状：pane 命令 = agent 脚本 | `bash /tmp/…/p55-agent`（argv[1] 就是 agent） | `sleep 300` | **exited** |
| ② 外面套一层 `bash -lc <agent>` | `bash /tmp/…/p55-agent`（**逐项与①相同** —— bash 对 `-c` 的最后一条命令会 `exec`） | `sleep 300` | **exited** |
| ③ `bash -lc '<agent> & wait'` | `bash -lc … & wait` | `bash /tmp/…/p55-agent` ✓ | running |
| ④ 生产 harness 的形状 | `bash -lc '<agent>; :'` | `bash /tmp/…/p55-agent` ✓ | running |

**生产里 agent 永远是 pane_pid 的直接子进程**（dispatch 走 `respawn-pane … bash -lc <harness>`，harness 末尾还 `exec bash`），所以 ① 那种形状在生产里不会出现；能出现它的是**人工在座位窗口里直接起 agent**。

## 要做的（先复现四种形状，再裁）

1. **复现**：把四种形状在容器里各跑一遍（自己写夹具，不要只引用 P214 的输出），给出每种形状下判据的结论。
2. **裁定并实现**：二选一，必须写明理由 ——
   - **A**：判据收紧到"argv[1] 就是 agent（= 真的在执行它）也算在跑，只有'argv 里只是提到它'不算"（P214 指出这两者可分开），并**同时**把 §41 的夹具改成生产形状（③/④）；
   - **B**：判据不动，只把 §41 的夹具改成生产形状。
   无论选哪个，**P103 的洞必须仍然堵着**：`flip-p210.sh` 里那条"`bash --noprofile --norc -s "$AGENT"`（agent 路径在 argv[4]）"的假活**必须仍然红**。
3. **可证伪**：① 四种形状各自的期望结论各一条断言；② 夹具改成生产形状后 §41 全绿；③ 影子：把判据改回"pane_pid 的 argv 提到 agent 就算活" → P103 那条红侧必须红。
4. **门禁**：`openspec validate --all --strict` + 容器内 `--select 2,41`（**单独 `--select 41` 会级联**，`needs` 的坑由 P218 修）+ 你改动到的其它段；报告点名"哪些自己跑、哪些引用 P214"；**换人复验**。
