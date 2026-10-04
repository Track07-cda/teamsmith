# P127 · 等待引擎的 `printf | grep -q` 假缺（长帧下 SIGPIPE → 命中被当成"没出现"）

```
task:   P127
agent:  dev                      # P94 也是 dev 做的（同一族：pipefail + 早退消费者）
issue:
change: -                        # 无 change：夹具/等待引擎的实现修复（anchor: none (infra)）
specs:  -
phase:  apply
anchor: none (infra) — 只改等待引擎的匹配实现与自检，不改等待语义/预算/归因
deltas: -
grant:  skills/teamsmith/tests/lib/pty-wait.sh · skills/teamsmith/tests/**（同族且生产者无界的写法）· skills/teamsmith/tests/smoke.sh（append-only 一段）· docs/team/reports/P127-dev.md · docs/team/reports/P127-dev/**
deps:   P124（独立验证报的 BLOCKED ✓ 它的最小复现在 `docs/team/reports/P124-verify/pkg/logs/pty-needle-pipefail.log`）· P94（同族：`SCENE_LINES=0` 的 `printf | grep -q` SIGPIPE ✓）
status: todo
budget: 小
priority: 高（它会**假报"没出现"** ✓ → 夹具假红/假绿 ✓；独立验证因此 BLOCKED ✓）
```

> 本地模式：不 push。**CI 不再作为判据**（D54）。

## 现场（PM 自己复现 ✓）

```bash
bash -c 'set -uo pipefail; c=$(python3 -c "print(\"MARKER\"); [print(\"x\"*100) for _ in range(1200)]"); printf "%s\n" "$c" | grep -qF -- MARKER; echo rc=$?'
# → rc=141 ✗（grep -q 命中即退 ✓ → 写端 SIGPIPE ✓ → 整条管道 rc=141 ✓ 被当成"没出现" ✗✗）
```
`lib/pty-wait.sh:120/121/133/134` 就是这个写法 ✓，帧可以很大 ✓（P124 造的合成帧 **120 607 字节** ✓；管道缓冲 64 KiB ✓ 之上必然触发 ✓）。
后果：**真出现的内容被判为"没出现"** ✗ → 等超时 → 假红 ✗（或该报缺的没报 ✓）。

## 要做

1. **改掉等待引擎里的这四处** ✓：用 **bash 内匹配**（`[[ $c == *"$n"* ]]` ✓）或 here-string ✓ ——
   **不存在写端** ✓ 就没有 SIGPIPE ✓；`!` 取反的语义照旧 ✓；
2. **扫同族** ✓：`tests/**` 里凡是「**生产者内容无界**（`printf '%s\n' "$大变量"` / `cat <大文件>` ✓）+ 消费者会早退（`grep -q` / `head` ✓）+ **rc 被用来判定** ✓」
   的地方，一并改成不产生 SIGPIPE 的写法 ✓（小输出、管道缓冲之内的可以留在原样 ✓ —— 在报告里**写清你按什么界判定** ✓）；
3. **自检要有长帧守卫** ✓✓：给等待引擎加一条**合成长帧**（> 128 KiB ✓，needle 在**最前面** ✓）断言**命中** ✓；
   反向：needle **不在**长帧里 → 必须正确报"缺" ✓（两个方向都要 ✓）；再补一条**红侧**（把实现影子回 `printf | grep -q` → 长帧命中那条必须红 ✓）；
4. `openspec validate --all --strict` ✓ + 相关段落 ✓ + **FAST 全绿** ✓（+ 一次**全量**，因为这是"假红"类缺陷 ✓）。
