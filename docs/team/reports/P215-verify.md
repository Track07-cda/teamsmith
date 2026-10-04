# P215 · 账本禁令门禁独立复验

agent: verify   status: PARTIAL   time: 2026-10-04
branch: `task/P215-verify`   PR/MR: -（local 模式）

## Deliverables

| Path | What |
|---|---|
| `docs/team/reports/P215-verify.md` | 可公开的结论；不含敏感原文 |
| `docs/team/reports/P215-verify/` | 独立脚本、原始日志、scratch 与逐项结果；D94 下全部忽略，不提交，留给 PM 仓外归档 |

被验提交：`e6ca8ef6`（apply=dev2，本席位未参与实现）。独立脚本为 `docs/team/reports/P215-verify/run_cases.py`，通过 CLI 调用扫描器，不引用其 `--self-test` 断言或夹具，不传 `--user`，运行时账户来自 `id -un` 并与 `--print-user` 比对。

## Verification evidence (must have actually been run)

```text
$ python3 docs/team/reports/P215-verify/run_cases.py
PASS original-home scanner_rc=1
PASS original-net scanner_rc=1
PASS original-user scanner_rc=1
PASS original-names scanner_rc=1
PASS original-missing scanner_rc=3
PASS original-clean scanner_rc=0
FAIL mixed-home-safe-output scanner_rc=1
FAIL mixed-net-safe-output scanner_rc=1
FAIL mixed-names-safe-output scanner_rc=1
FAIL many-home-safe-output scanner_rc=1
EXPECTED shadow guard failures=5; unexpected product failures=4
Source unchanged=True
exit=1
```

- 四类单独植入都点名 `docs/team/reviews/probe.md:4: [形状]`；各单类命中日志的原文 `grep -Fq` 均 rc=1，即没泄漏。
- 名单先创建再删除：rc=3，包含 `SKIP names`、`这一项不是通过`、`names=missing`。
- 占位符、省略号家目录、相邻但不属私网的地址、更长的名字/账户词全部绿（rc=0、hits=0）。
- **组合与多次命中的日志安全不成立**，详情如下。原始日志只在被忽略的证据包内保存，报告不粘贴敏感原文。

### F1 · 同行多敏感项只遮蔽首个分支

位置：`skills/teamsmith/tests/ledger-ban.sh:183–190`。家目录、地址、账户分支打印后 `continue`；名单命中后 `break`。输出仍含该行的其他敏感原文。

| 自造现场（同一行） | 敏感原文 grep 结果 |
|---|---|
| 家目录 + 运行时账户 + 名单名字 + 私有地址 | 账户、名字、地址均 rc=0（泄漏） |
| 私有地址 + 运行时账户 + 名单名字 | 账户、名字均 rc=0（泄漏） |
| 两个不同的名单名字 | 第二个名字 rc=0（泄漏） |

扫描返回 rc=1 并点名不能弥补泄漏：门禁日志会被贴进公开账本，这违反任务书第 4 条。可核对 `logs/mixed-*.log` 与 `redaction-audit.json`（grep 状态，不含原文）。

### F2 · 遮蔽次数上限导致第 21 个起泄漏

位置：`skills/teamsmith/tests/ledger-ban.sh:161`，`mask_span()` 限制 `g < 20`。

同一行独立植入 24 个家目录，结果 rc=1、正确点名，但输出只遮蔽 20 个，剩下 4 个真实家目录与运行时用户名。`grep -Fq` 账户原文 rc=0。证据：`logs/many-home.log`、`redaction-audit.json`（masked-home-count=20、unmasked-home-count=4）。

## Flip evidence

```text
$ python3 docs/team/reports/P215-verify/run_cases.py
# 未改实现：四形状、缺名单、干净现场全部 PASS
# 影子一：只在证据包副本中让 ban_scan() 直接以零命中返回
FAIL always-pass-home scanner_rc=0
FAIL always-pass-net scanner_rc=0
FAIL always-pass-user scanner_rc=0
FAIL always-pass-names scanner_rc=0
PASS always-pass-shadow-caught
# 影子二：只在副本中把缺名单的 rc=3 改为 rc=0
FAIL missing-pass-missing scanner_rc=0
PASS missing-pass-shadow-caught
# 重新调用原实现，使用相同现场与判据
PASS restored-home scanner_rc=1
PASS restored-net scanner_rc=1
PASS restored-user scanner_rc=1
PASS restored-names scanner_rc=1
PASS restored-missing scanner_rc=3
PASS restored-clean scanner_rc=0
Source unchanged=True
```

两条影子均由独立断言抓住，预期的五条红不计作产品缺陷；日志安全四条红来自未改的实现，尚无修复后的绿侧。

## 当前 main 的真实素材与门禁

从本席位工作树读取 Git `main` ref，固定为 `5a902c33440028d5125ed59f259846f105708b51`，用 `git archive` 导出到证据包内 `.scratch/main-checkout`，初始化成独立 Git 检出。没有进入、修改 main 工作树，也没携带其忽略配置。运行后 main ref 未变。两侧扫描器 SHA-256 相同：`0092ddbc7895fb9ff81222cf74127a561d5f1caf297e671ea83456e09f9c15e5`。

```text
$ timeout 60 bash skills/teamsmith/tests/ledger-ban.sh --root <独立main检出>
ledger-ban: SKIP names —— 禁令名单未配置（<名单路径> 不存在；这一项不是通过）
ledger-ban: root=<独立main检出> scope=published files=1229 hits=0 names=missing user=resolved
exit=3
```

真实公开素材没有命中；真实名单未随 Git 导出，**他项目名字这一项没查，不能称四类全绿**。报告 `main-revision.txt`、`main-scan.log` 与 `.rc` 可以对账；独立检出中的 1229 个 Markdown 均在扫描范围。

```bash
pkg="$PWD/docs/team/reports/P215-verify"
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
§60: ✓11 ✗0 SKIP1（名单缺失，可见跳过）
选段总计: ✓32 ✗0 SKIP1; exit=0
```

**全部是本席位实际运行**：独立 CLI 夹具、两条影子、真实 main 扫描、容器 OpenSpec、第 60 段。仅引用实现提交与文档口径，没有引用 dev2 或 PM 的测试结果代替实跑。门禁原有自检不覆盖 F1/F2，故它绿而独立日志安全断言红，不能以此判 PASS。

**没跑全套**，也没跑全量 FAST、性能门禁。选段实际只跑 `0,0b,0c,0d,60`；其余 120 个段均没跑：

```text
0e 0f 0g 0h 0i 1 1b 1c 2 3 4 4b 4c 5 3b 6 6b 6c 6d 6e 6f 6g 6h 6i 6j 6k 7 7b 8 9 10 10b 10c 11 11b 11b2 11b3 11b4 11c 11d 11e 11e2 11f 11g 11h 11i 11j 14b 15b 15c 12 13 13b 13c 12b 12b-h0 12b-h0b 12b-h0d 12b-h0c 12b-pi 12b-pi2 12b-pi3 14 14c 54 14d 17 18 18b 18c 19 20 21 22 23 24 25 26 27 28 29 30 31 31c 32 33 12e 12f 12g 12h 12i 12j 12k 34 34b 35 36 37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 57 58 15 55 56 59
```

另跑一次本分支公开账本扫描（`bash skills/teamsmith/tests/ledger-ban.sh --root "$PWD"`）：files=1229、hits=0、names=missing、user=resolved，rc=3；新报告没有触发禁令命中。证据包 `public-report-scan.log`。

## Decisions and deviations

- 无实现改动，无跨目录写入，无 push/PR（local 模式）。证据包不进 Git。
- 本工作环境没有宿主 `openspec` 可执行文件；在现成门禁镜像里对同一独立 main 检出执行要求的严格校验，没有跳过验证。

## Suggested next steps

- **Verdict: NEEDS-CHANGES。BLOCKED:** 请 PM 派实现 owner（dev2 或另一个 apply agent）修正 F1/F2：输出前遮蔽整行所有敏感项，且不因固定次数上限留下原文；修复后另行复验。verify 无实现修改权限。
