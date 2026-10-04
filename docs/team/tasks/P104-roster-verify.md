# P104 · `roster-writer-and-route-truth` 独立验证（换人）

```
task:   P104
agent:  dev-bob
issue:
change: roster-writer-and-route-truth      # 内容已在 main（apply=P99 dev）；你与 propose/apply 作者都不是同一人
specs:  memory-and-deps#（名册的唯一授权写入路径）· dispatch#（用法诚实性）· init-skill#
phase:  verify
anchor: change
deltas: -                                   # verify 不改 delta；只写报告
grant:  docs/team/reports/P104-dev-bob.md · docs/team/reports/P104-dev-bob/**（只写报告与证据）
deps:   P99（apply，已合并）· P46（propose）· `tests/routes.sh`（新走查）· `tests/config-cli.sh roster`
status: todo
budget: 一个验证包
```

> 本地模式：不 push。**验证对象 = main 上已合并的实现**（不是某个分支）。

## 要求（**自造**夹具，不许只跑它自带的翻转）

1. **写入路径的边界**（用**临时项目**，绝不碰真名册）：
   - `add-agent X --register` 正常路径：名册真的变了 + **恰好一行审计**（`state/config.log`）；
   - **拒绝路径**：不加 `--register` → 非零 + 打印的**两条出路必须真的能用**（**照着做一遍**：手改 config.sh 后 `add-agent` 成功 ✓）；
   - 怪名字：空、带空格、带 `/`、`pm`/`verify` 这种保留名、已在名册里的名字 → 各自**明确拒绝**且**名册字节不变**；
   - 非 git 项目 / 名册为空 → 明确报错，不是静默。
2. **对称移除**：移除路径同样要审计一行；移除不存在的席位 → 明确拒绝。
3. **`set-agent-model` 对"尚未入册的名字"**：给出的是**可执行的**答案（不是死胡同）——把它跑通。
4. **`--model`**：要么真的支持（跑一次），要么在 help 与所有提及处都不存在（**两侧都查**）。
5. **走查本身可证伪**：你自己**造一个谎言**（例如在某条 schema 注释里点名一个不存在的命令，或把 help 的用法行改成解析器不接受的形状）→ `tests/routes.sh` 必须**红且点名**；再还原 → 绿。**不许**只引用它的 7 条翻转。
6. **零回归**：`openspec validate --all --strict` + FAST + 受影响段（`routes.sh`、`config-cli.sh list validate roster`）。
7. 报告里写清"哪些是你自己的证据、哪些是引用"；附**原始输出**。
