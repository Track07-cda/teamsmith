# P219 · P216 日志遮蔽独立复验

agent: verify   status: PASS   time: 2026-10-04
branch: `task/P219-verify`   PR/MR: -（local 模式）

## Deliverables

| Path | What |
|---|---|
| `docs/team/reports/P219-verify.md` | 可公开的复验结论与命令 |
| `docs/team/reports/P219-verify/` | 独立脚本、逐项 grep 计数、原始日志与夹具；D94 忽略，留给 PM 仓外归档 |

被验实现：`9157c8cf`（apply=dev2）；本席位任务起点 `03cd9b5f`。没有修改实现。扫描器 SHA-256：`007f3e4123beb1c258e6cb578a6748b46a7374c5f56eec57ed719f001decdd64`。

## Verification evidence (must have actually been run)

```text
$ python3 docs/team/reports/P219-verify/run_cases.py
PASS rc0-clean-no-false-positives
PASS rc3-missing
PASS rc3-empty
PASS rc3-unreadable
PASS rc2-bad-option
PASS rc2-bad-root
PASS rc2-missing-value
PASS rc4-internal-error
PASS rc3-unresolved-user
PASS product-source-unchanged
Cases=14 expected-shadow-red=28
Unexpected=0
exit=0
# 共 150 条断言：122 条绿 + 28 条预期影子红，没有非预期失败
```

独立脚本直接调用 CLI，不复用实现自检或其断言；运行时用户名由 `id -un` 获取，并与 `--print-user` 比对，不传 `--user`。

- P215 原现场逐条回归：同行四类、同行地址/账户/名单、同行两名单名、24 个家目录全部通过。
- 新现场：40 个地址、44 个名单名、31 个账户词；占位符与命中同处一行；相邻地址、地址紧邻家目录与名单名字；名单相互交叠，并与家目录/地址/账户区间交叠。各行输出与独立构造的预期全文精确一致。
- 超长行：700 个地址；原地址跨越 4096 字节截断处；4300 字符家目录遮蔽后缩短。前两条显式截断且不留原文/地址尾段，最后一条完整保留尾部 END，证明先遮蔽后截断，而非先截断原行。
- 对每个现场的每种原文执行 `grep -Fo -- <原文> <输出日志>`，断言计数为 0 且 grep rc=1；短地址尾段另有断言。原实现共 775 次 grep 全为零，恢复后 775 次仍全为零；影子检出 432 项非零。计数记录在 `redaction-audit.json`，不把原文贴进公开报告。
- 同一批 14 个现场在修复前 `e6ca8ef6` 的证据副本上重跑：退出码、命中行数、`file:line` 和首标签与当前实现完全一致，均 rc=1、hits=1、点名第 4 行。检测未因遮蔽返工削弱。
- 退出码五种均实跑：干净且名单配置 rc=0；命中 rc=1；参数/目录错误 rc=2；名单缺失、空、不可读及账户解析失败 rc=3；外部 awk 故障 rc=4。缺名单仍打印可见 SKIP。

## Flip evidence (required for defect-fix tasks)

```text
# 只改被忽略证据包中的副本：masked = span_render(line) → masked = line
PASS original-mixed-home-zero-originals
FAIL mask-off-mixed-home-zero-originals [expected red]
PASS restored-mixed-home-zero-originals
PASS original-many-home-zero-originals
FAIL mask-off-many-home-zero-originals [expected red]
PASS restored-many-home-zero-originals
PASS original-mixed-names-zero-originals
FAIL mask-off-mixed-names-zero-originals [expected red]
PASS restored-mixed-names-zero-originals
```

全部 14 个现场的零原文断言与全文渲染断言均在关闭遮蔽时红（28 条预期红），检测断言仍绿；随后重跑未改的产品文件，全部恢复绿。产品文件哈希不变。

## 真实 main 与容器门禁

从本工作树读 `main` ref，固定为 `67ddc647ec9d9157bab3810bd7fef087b100920c`，用 `git archive` 导出到证据包内 `.scratch/main-checkout`，初始化并提交为独立干净 Git 检出。没有进入或修改 main 工作树。运行前后 main ref 相同；两侧扫描器 SHA-256 相同。

```text
$ timeout 60 bash skills/teamsmith/tests/ledger-ban.sh --root <独立main检出>
ledger-ban: SKIP names —— 禁令名单未配置（<名单路径> 不存在；这一项不是通过）
ledger-ban: root=<独立main检出> scope=published files=1242 hits=0 names=missing user=resolved
exit=3
```

当前公开账本无命中。真实名单没有随 Git 导出，名字这一项未查，**不是四类全绿**；名单检测与遮蔽能力由独立植入夹具实证。

```bash
# 完整驱动：bash docs/team/reports/P219-verify/run_gate.sh
pkg="$PWD/docs/team/reports/P219-verify"
distrobox-host-exec podman run --rm --pid=host --cgroups=enabled --userns=keep-id \
  -e HOME=/tmp -v "$pkg/.scratch/main-checkout:/work" -v "$pkg:/evidence" -w /work \
  localhost/teamsmith-gate:local bash -c '
    git config --global --add safe.directory /work
    openspec validate --all --strict >/evidence/openspec.log 2>&1
    spec_rc=$?; printf "%s\n" "$spec_rc" >/evidence/openspec.rc
    timeout 300 bash skills/teamsmith/tests/smoke.sh --select 60 </dev/null >/evidence/section60.log 2>&1
    gate_rc=$?; printf "%s\n" "$gate_rc" >/evidence/section60.rc
    [ "$spec_rc" = 0 ] && [ "$gate_rc" = 0 ]
  '
```

```text
OpenSpec: Totals: 13 passed, 0 failed (13 items); exit=0
#5 60 · 账本禁令 · 用时 1s · ✓17 ✗0 SKIP1 · ticks 18
选段结果: ✓38 ✗0 SKIP1; exit=0
```

全部为本席位实跑：独立 CLI、遮蔽影子、修复前后检测对照、五种退出码、真实 main 扫描、容器严格 OpenSpec、第 60 段及其内部自检。仅引用 P215 的原始 finding 和实现提交身份，没有用 dev2/PM 的测试结果替代实跑。

另对本分支最终报告运行 `bash skills/teamsmith/tests/ledger-ban.sh --root "$PWD"`：files=1242、hits=0、names=missing、user=resolved，rc=3。公开报告不触发禁令；日志在 `public-report-scan.*`。

**没跑全套、全量 FAST 或性能门禁**。选段实际运行 `0,0b,0c,0d,60`；其余 120 段没跑，点名如下：

```text
0e 0f 0g 0h 0i 1 1b 1c 2 3 4 4b 4c 5 3b 6 6b 6c 6d 6e 6f 6g 6h 6i 6j 6k 7 7b 8 9 10 10b 10c 11 11b 11b2 11b3 11b4 11c 11d 11e 11e2 11f 11g 11h 11i 11j 14b 15b 15c 12 13 13b 13c 12b 12b-h0 12b-h0b 12b-h0d 12b-h0c 12b-pi 12b-pi2 12b-pi3 14 14c 54 14d 17 18 18b 18c 19 20 21 22 23 24 25 26 27 28 29 30 31 31c 32 33 12e 12f 12g 12h 12i 12j 12k 34 34b 35 36 37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 57 58 15 55 56 59
```

## Decisions and deviations

- 首次探针出现两条验证侧错误，已保留 `independent-initial.log` 和 `results-initial.json`：超长单词的完整原文被截断，影子需同时查其原文前缀；账户解析失败夹具的 HOME 位于家目录下，正确触发了 HOME 尾段回退，需清空 HOME 才能制造解析失败。修正独立夹具后全部通过；没有为换绿修改产品。
- 本机没有宿主 OpenSpec 命令；在现成门禁镜像内对独立 main 检出运行严格校验。任务书要求的两项门禁均执行，没有跳过。
- 可重建的 main 导出检出不随证据归档，保留固定 revision、生成脚本、哈希、日志与所有植入夹具。
- 本地模式不 push、不建 PR/MR，证据包不提交 Git。

## Suggested next steps

- **Verdict: PASS（任务范围）**，P215 三条遮蔽 finding 均回归通过，新增边界通过，无实现返工项。
- 请 PM 收取本地报告提交，并将 `docs/team/reports/P219-verify/` 原始证据包按 D94 仓外归档。
