# P107 · `roster-writer-and-route-truth` 返工后的**换人重验**（对 P105 的修复）

```
task:   P107
agent:  verify
issue:
change: roster-writer-and-route-truth      # 内容已在 main（apply=P99 dev，返工=P105 dev）；你与两次 apply 都不是同一人
specs:  memory-and-deps#（名册的唯一授权写入路径）· dispatch#（用法诚实性）
phase:  verify
anchor: change
deltas: -
grant:  docs/team/reports/P107-verify.md · docs/team/reports/P107-verify/**（只写报告与证据）
deps:   P104（上一轮独立验证：FAIL，两条 finding）· P105（返工）· `tests/routes.sh` · `tests/config-cli.sh roster`
status: todo
budget: 一个验证包
priority: 中（这是 `roster-writer-and-route-truth` 归档前的最后一道门）
```

> 本地模式：不 push。**验证对象 = main 上已合并的实现**。

## 必须自己动手（**不要**只跑 P104/P105 的夹具）

1. **F1 复核（P104 的两条已修，但要你自己造）**：在**你自己的 scratch 项目**里，对
   `api 1` · ` api` · `api ` · `api<TAB>1` · 空串 各自断言**三件事**：非零 · 名册**字节不变**（前后哈希）·
   **审计里没有 `result=ok`**；再对照一条**合法**名字（`api1`）必须**成功**且审计**恰好一行**；
2. **`teardown` 的 token 精确性**：`--agent 'dev verify'` → 拒绝且名册不变；`--agent dev` → 真的移除且审计一行；
3. **F2 复核**：`add-agent <合法席位> --model vendor/m2 --no-install` 之后，
   配置 / `state/<seat>.env` / `config list --json` 的**席位行**三者必须**同源**（写清你比对了哪三个值）；
   再验一次 `-`（清覆写）的方向；
4. **走查本身仍可证伪**：自己造一个谎言（改一条 schema 注释点名不存在的命令，或把 help 用法行改成解析器不接受的形状）
   → `tests/routes.sh` 必须**红并点名**；还原 → 绿；
5. **零回归**：`openspec validate --all --strict` + FAST +（一次）全量 smoke（CI 现在被账号层挡着，
   **本地全量就是决定性证据**，请把结论行与数字写进报告）；
6. 报告写清"哪些是你自己的证据、哪些是引用"，附**原始输出**。
