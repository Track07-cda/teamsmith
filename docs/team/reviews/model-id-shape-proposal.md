# model-id-shape · PM proposal review

time: 2026-09-28T16:2xZ · reviewer: pm · verdict: **ACCEPTED**

```
change:  model-id-shape（P102，propose=dev；用户已批准「3 可以」）
tip:     024f074a（task/P102-id-model-propose）· validate 16/16 ✓ · 它自带一次全量绿 ✓
```

## 与我任务书的对照

| 要求 | 提案 |
|---|---|
| provider = 第一段（非空、不含 `/`）；**model = 其余全部（可含 `/`）** | requirement 标题即「a single-segment provider plus a model that may contain `/`」✓ |
| `:思考档` 后缀继续工作 | **先剥后缀再判形状、值里保留** ✓（`provider/vendor/model:high` 也被覆盖 ✓） |
| 仍然拒绝：无 `/` · `/x` · `x/` · 空段 · 空白；**措辞点名是哪一段** | "the shape stays closed, and the message names the rejected segment" ✓ |
| **一处实现**（三处写入器共用一个判定） | "**One judgement, not one copy per write route**" ✓✓（正是我要求的 ✓） |
| 窗口解析 / `TEAM_MODEL_WINDOWS` 对多段 id 正确 | "the launch renderers split at **the first `/`, not the last**" ✓✓（我任务书没点明的那个坑它自己想到了 ✓）+ "window resolves from **both** sources" ✓ |
| 读面与选择器不崩 | "the read surfaces and the seat picker carry the whole id" ✓ |

## 结论

**ACCEPTED**。7 条场景把"接受什么 / 拒绝什么 / 拒绝时说什么 / 只有一处判定 / 前缀切分与窗口两条来源 / 读面不崩"
都变成可证伪的断言 ✓。apply = **P114**（可以仍由 dev 做——propose 与 apply 同人是允许的；**verify 阶段**再由第三方 ✓）。
