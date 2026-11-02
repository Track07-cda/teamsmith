# P396 · Implement marker-based Pi key replies

task: P396
agent: dev
phase: apply
category: analysis
change: pi-marker-key-replies
deltas: key-replies, pm-lifecycle, memory-and-deps, verification
branch: task/P396-mvp
deps: exact accepted proposal/report tip 0e557f47803ee75e2d7d951d93ef79d1a82245fc; formal proposal review ACCEPTED and V117 ACCEPT; D213–D216; P393 SKILL.md serialization

Launch note (PM, 2026-10-30): the first Apply launch selected the configured `cline-pass/deepseek-v4.1-flash-1017:max` and Pi exited with `Unknown provider "cline-pass"`. PM authorizes a one-launch `openai/gpt-6.1-sol:xhigh` override for this implementation; project config, category and task scope are unchanged.

## Start and scope

You are the implementation owner, not the proposal author or independent verifier. Work only in your own seat/worktree on `task/P396-mvp`, initially based on exact P395 final tip `0e557f47`. Read AGENTS, your thread, this brief, OWNERSHIP, `references/openspec.md`, the complete accepted change artifacts, formal review, V117's report (`git show 1a9892055124:docs/team/reports/V117-dev3.md`), and the relevant existing Pi/writer code. Use `openspec instructions apply --change pi-marker-key-replies --json` as the plan.

Implement the accepted proposal, not another reply framework. The 14 tasks are the checklist; your scope is implementation and author-owned evidence for 1.2–3.3, plus the controlled parts of 4.1 preparation. Do not mark independent verification, live adoption or archive complete. A different agent will independently Verify after your final candidate.

Make small reviewable commits with Conventional Commits + P396 + `Agent: dev`. Keep evidence on disk and write `docs/team/reports/P396-dev.md`. A fresh same-task recovery must continue from the branch/report/evidence, not your session memory.

## Mandatory ordering and boundaries

1. **Start with parser/source and PM injection (tasks 1.2–2.3).** These are independent of P393's SKILL.md edit and can proceed now.
2. **Do not edit `SKILL.md` or the shared guide until accepted P393 has landed on main and been merged into this task branch.** Then complete 3.1–3.3, preserving every say change. If P393 is still unmerged when you reach that point, stop with `BLOCKED:` naming that dependency and the completed candidate; do not recreate, overwrite or sneak in its say diff. P391 remains a later integration task, not yours.
3. No live-team marker test, PM restart/reload, state migration, protected merge/push, real-model autonomy call, real archive or release. Use only private projects, private tmux/HOME/state and loopback controlled models. Do not read or write credentials/model config.
4. No worker/ordinary-Pi capture, `/team` duplication, custom-adapter placeholder, provider rewrite, second reply store/page/numbering, daemon/scheduler/new config, automatic model retry, hash/current-page reconciliation or exactly-once claim. Manual CLI/backfill and identical explicit posts remain unchanged.
5. If a substantive contradiction with the accepted design appears, stop that path with a concrete `BLOCKED:` counterexample instead of silently rewriting the contract. Product code must not gain test-only fault switches; fault drivers belong in tests.

## Accepted behavior that must survive implementation

- Exact final control lines and titles, all-terminal cleanup independent of publication/eligibility/journal, partial prefixes literal, no normal-answer blocking or replacement.
- Narrow parser and original-offset mapping, including paired fences/inline spans, exact-length closers, cross-line/cross-block, unmatched openers, CRLF/Unicode/non-text preservation. No full Markdown AST.
- **Escaped-first-tick suffix:** outside code consume backslash escapes before forming opener runs; odd parity escapes only the first tick and leaves an unescaped suffix, even parity does not; never split an unescaped run; in-span backslashes are ordinary. V117's exact inline-only and inline+real cases plus whole-physical-run-ignore mutation are mandatory.
- End staging → turn_end actual entry binding → final settled eligibility, latest-assistant supersession, null first leaf, current branch/session witness. No pending/history/current-leaf/hash inference.
- One source tuple/record/attempt, durable attempting before spawn, real writer number/candidate number, no automatic retry on any uncertain outcome. Saved beyond the current page remains a barrier; identical bodies on different entries remain distinct.
- Directed PM-only injection with real project/state/session/tmux/PID/starttime/cwd/spawn evidence, one owner/generation plus source CAS, honest disk/launch/runtime fingerprints and doctor. Initial injection restart is different from already-loaded reload; no live action here.
- Existing `scripts/replies.mjs`/`cmd-reply.sh` remains the only writer and Pulse/CLI read only the existing numbered store. Operational journal is not a second reply store.

## Implementation write set

Only paths required by the accepted proposal/tasks:

- `openspec/changes/pi-marker-key-replies/**`: evidence-backed task checkoffs/report links only; no canonical spec edits and no unperformed independent/live verification marked done.
- `skills/teamsmith/extension/team-reply.ts`, a narrow `skills/teamsmith/scripts/reply-capture.mjs`, and minimal pure-validation export from existing `scripts/replies.mjs` while retaining its direct CLI entry.
- `skills/teamsmith/scripts/lib/{common,cmd-update,cmd-project}.sh` only for directed PM injection, fingerprint and doctor/identity integration.
- `skills/teamsmith/templates/pm-prompt.md.tmpl`, `skills/teamsmith/references/protocol.md` §4b, and `skills/teamsmith/SKILL.md`/related guide only after the P393 merge dependency above is satisfied.
- Product-behavior tests under `skills/teamsmith/tests/**` and minimal wiring into existing reply/smoke entries, with no independent health/process guard or new scheduler framework.
- `docs/team/reports/P396-dev.md` and host-side evidence outside Git.

Do not modify unrelated tasks/reviews/board/decisions/ownership, other changes, release files, CI schedules or P388–P395 records. No merge/push/retry public CI/publish.

## Required evidence

1. **Parser/product:** exact grammar/title/control cleanup, complete content/offset/raw bytes, all V117 escaped-suffix and adjacent parity/in-span cases, inline/fence/unmatched/cross-block/Unicode cases. Mutations removing inline protection, ignoring a whole physical run after an escaped first tick, ignoring parity, arbitrary run switching, unmatched-to-EOF and offset mapping must turn named assertions red; restoration green.
2. **Source state machine:** end/append/turn/settled order, queued/tool/retry/before-settle/abort supersession, null first leaf, no-binding, same-body distinct entries, repeated events/copies, saved outside page, one CAS attempt. Use the real writer, not fake receipts.
3. **Crash/fault matrix:** external drivers around staging, Pi append, binding, eligibility, attempting, spawn, writer commit/receipt/result journal. Real lock gives busy 5; existing `fail:index-fsync` gives unconfirmed 6/candidate; bad/missing receipt and result-journal failure never auto-retry. Preserve normal-answer cleanup through every fault.
4. **PM identity/loading:** private real PM launch with initial spawn proof and late final metadata; foreign cwd+inherited root/config/state, worker/ordinary Pi/custom template refusal; duplicate-path owner/generation, stale callback, dead/reused PID, dependency-only loaded hash, doctor read-only. No global tmux writes or `/team` duplication.
5. **Private real Pi:** controlled model demonstrates final transcript/print stdout/next provider history cleanup, raw-pty actual-marker positives and documented transient/partial boundaries, queued/terminal cases, no-entry reload versus already-loaded dependency replacement, session switch/tree/fork. Do not claim real-model compliance or zero/fixed-latency flash.
6. **Instruction/reply integration after P393 lands:** three surfaces agree on marked normal answer + extension publication + manual CLI/backfill, no daily temp/heredoc/post-repeat. Replace old guide default-double-write tests with marker behavior while retaining reader/duty negatives and real manual CLI/unknown flag checks. Existing UI/paging/atomic/receipt/read-only behavior remains.

Keep host-side full logs under `$HOME/.cache/P396/` or `/var/tmp` bind-mounted paths. Never use the live team as a fixture.

## Gates and delivery

Run focused tests per slice, not the full suite after each commit. On the final settled tree run:

```bash
openspec validate pi-marker-key-replies --strict
openspec validate --all --strict
bash skills/teamsmith/tests/spec-refs.sh --check
bash skills/teamsmith/tests/section-select.sh --check
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check
```

Run the accepted parser/source/private-Pi and existing reply/UI/pty selections with exact commands/output. Once the tree and report are settled, run the full `bash skills/teamsmith/tests/smoke.sh` once as a background delivery gate with complete host-side logs and an unchanged tree. Any red/timeout/missing required evidence is reported and fixed or returned BLOCKED, never converted to SKIP/pass or deleted coverage.

The report leads with implemented behavior and remaining boundaries; include exact commits, changed files, commands/counts, parser/mutation red-green, writer/crash evidence, private Pi identities/frames/history, P393 merge tip and instruction integration, full-gate fingerprint/result, and explicit not-run independent/live/real-model/public-CI scope. Commit the final report and leave the branch clean before notifying PM. Independent Verify is a separate task; no merge/push/archive/release.

## 追加切片（2026-11-02，P393 已合入 main 后）

P393（say 默认直达、退休 `--now`）与 P380/P381/P382/P384 已合入 main；此前"等 P393 落地再改共享指令"的阻塞已解除。本切片只做**指令迁移**，不重做已验收的解析器/捕获实现：

1. `skills/teamsmith/SKILL.md`、`skills/teamsmith/references/*.md`、`skills/teamsmith/templates/pm-prompt.md.tmpl` 里把"先 `team reply post` 再正常回复"的旧默认，换成**标记捕获**：正常在 Pi 里回答，完整回复末尾带约定标记，由插件捕获入关键回复页；`team reply post` 只作手工回填/恢复入口。
2. 标记语法、去重与失败恢复以已接受的 `openspec/changes/pi-marker-key-replies/` 为准，不得另立一套措辞。
3. 消除与 P393 的冲突面：say 的那部分指令保持已合入的样子，不覆盖。
4. 断言要能变红：文档契约测试里必须有一条"指令里重新出现'先 post 再回复'的默认步骤 → 红"，以及一条"标记约定被写入 SKILL 与 PM 模板 → 绿"。
5. 不跑全量 smoke；改完跑 `openspec validate --all --strict`、`bash skills/teamsmith/tests/spec-refs.sh --check`、相关选段（含 key-replies 段），提交推分支并写报告补充节。

边界不变：不改产品插件代码（已验收）、不动真实团队的回复存储、不做现场启用/归档/发布。
