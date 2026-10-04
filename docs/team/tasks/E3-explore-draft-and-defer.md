# E3 · Explore: the human draft entry and deferred delivery (D20)

```
task:   E3
agent:  dev2
phase:  explore
deps:   D20 (user requirement, recorded); M9.3 delivered; v1.30.0
```

> **User-confirmed mechanism (2026-09-15, verbatim):** automatic messages are typed into the PM's input box and
> **sent immediately** (`send-keys` + Enter). If the user is mid-typing, the auto message is *appended to the draft
> and the combined text is sent at once* — so a notification doesn't just pollute a draft, it **forces the half-written
> draft out the door**. Deferral must therefore trigger on *any* non-empty input region, before any keys are sent.

> Phase 1 of the pipeline for the user's requirement (DECISIONS D20): (1) a human gets an **uninterruptible** place to
> type — write the message in a separate window/editor, save it, and the system forwards it to the PM; (2) automatic
> notifications/wake-ups **defer** when the PM's input box is non-empty, instead of gluing themselves onto a
> half-typed draft. Explore *how*, not whether. Report only — no code, no specs, no change artifacts.

## Questions to answer with evidence

1. **Detecting "the PM is typing".** What can actually be observed in a Pi TUI pane? Measure, don't assume:
   - `tmux capture-pane -p` bottom lines: what does the input region look like when empty vs holding a draft
     (prompt glyph, borders, placeholder text)? Paste real captured samples (empty vs mid-draft) into the report.
   - tmux format variables (`cursor_x`, `cursor_y`, `pane_cursor_*`, `alternate_on`…): which exist on this tmux and
     what do they report for a Pi pane? Any that reliably distinguish "input holds text"?
   - Pi-side signals: does the running TUI write any state (socket, file, IPC) that says the input is non-empty?
     (Check the Pi package under `~/.bun/install/global/node_modules/@earendil-works/pi-coding-agent/` and
     `@oh-my-pi/pi-coding-agent/` for an input-state surface before concluding "no".)
   - Failure modes of each candidate: what makes it say "typing" when the user is not (false positive → messages
     stuck), and "empty" when the user is typing (false negative → the exact bug returns)?
2. **The deferral mechanism.** Where do held messages live (`state/`? an outbox queue per target?), who retries and
   when (a bounded in-sender retry loop vs the watchdog tick vs a tmux `pane-focus`/hook — tmux has no "input changed"
   hook, so likely polling), what the sender is told (exit code + "queued, will deliver when the input box clears"),
   ordering and dedup of a backlog, and a TTL/escape hatch (a message must not wait forever — what happens on
   timeout: deliver anyway? drop with a log line? fall back to the inbox file only?). Which existing send paths must
   go through it: `team say`/`notify` delivery, the watchdog's PM nudge, the meeting knock, `dispatch`'s own send?
   And which must **not** defer (a human's own explicit `team say` from a terminal — should it get a `--now`
   override?). Given the confirmed mechanism above, also answer: should `say` defer by default too (with `--now` to
   override), and does the watchdog's nudge path (`team watch`'s wake) go through the same guarded send?
3. **The human draft entry.** Shape options: (a) `team draft pm` opens `$EDITOR` on `state/draft-pm.md` (in a
   dedicated tmux window `teamsmith:draft` the human owns) and on save delivers through the deferring send path;
   (b) a drop-file convention (write the file, then `team draft send`); (c) reuse `meeting say`-style storage. How is
   multi-line text delivered without becoming one garbled line (`tmux load-buffer` + `paste-buffer`, then Enter —
   test this against a real Pi pane and paste the result), and how is "the draft was delivered" acknowledged to the
   human (printed where?). What happens if the human starts a second draft while the first is queued?
4. **Interaction with what exists**: the pane-fingerprint delivery check (does deferral break it — a queued message
   has no pane change yet?), the watchdog nudge cadence (a nudge deferred is a nudge skipped?), the M4.3-E lifecycle
   silence (extension notifications are a separate channel — do they need the same deferral? they don't type into the
   pane… confirm), and the future TUI dashboard (D19): should "N messages held because the PM is typing" be visible
   there? (Note it; do not design the dashboard here.)
5. **Options + recommendation**: 2–3 coherent designs (e.g. minimal: defer-only, no draft window; full: draft window +
   deferral; split: deferral now, draft window after the TUI rewrite), each with risks and what the verify phase would
   attack. Recommend one and name the task split (phase/owner/deps).

## Boundaries

- Write only `docs/team/reports/E3-dev2.md`. No code, no specs, no `openspec/changes/**`, no dispatching.
- You may create throwaway tmux sessions for the measurements (kill them afterwards); never send keys into
  `teamsmith:*` panes.
- Cite the commands and paste the captured output you based each claim on.

## Acceptance

```sh
git status --porcelain   # only your report
```
