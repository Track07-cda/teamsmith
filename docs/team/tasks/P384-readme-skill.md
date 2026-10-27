# P384 · Align README install wording with the three bundled skills

task: P384
agent: dev3
phase: apply
category: code
change: -
anchor: none (infra) — user-facing README wording only; no product contract or spec delta
deltas: -
branch: task/P384-readme-skill

## Evidence

The supplied v0.3.4 external incremental review correctly notes that README's Included table lists `teamsmith`, `teamsmith-init` and `handover`, while the install text still says `both skills` and `two skills`. The same drift exists on current main and in tag `v0.3.4`.

Current product evidence:

- `package.json` has `pi.skills: ["./skills"]` and the package has three skill directories.
- `skills/teamsmith/scripts/lib/cmd-init.sh:45` declares exactly `teamsmith teamsmith-init handover`.
- `install.sh` installs every real skill directory under `skills/`.

## Required change

Edit **only `README.md` and `docs/team/reports/P384-dev3.md`**. PM temporarily delegates README for this task; return ownership after independent acceptance.

Correct the whole same-class wording drift, not just the two tokens quoted in the review:

1. Install comment: `both skills` must describe all three bundled skills.
2. The following `team init installs teamsmith and teamsmith-init` sentence also omits `handover`; make the actual three-skill set explicit.
3. The manifest paragraph's `two skills` and its two-name parenthetical must match the three skills loaded from `./skills`.

Use concise natural English. Do not claim that Teamsmith installs unrelated skills from a user's global `~/.agents/skills`; the source is the package/checkout's own `skills/` directory. Do not change behavior, package metadata, skills, tests, specs or release files.

## Acceptance

Run from the final candidate and paste actual output:

```bash
rg -n 'both skills|two skills|installs `teamsmith` and `teamsmith-init`' README.md
# Expected: rc=1, no remaining stale wording. This is a checked absence, not a swallowed error.

rg -n 'all three|three bundled|handover' README.md
# Show the corrected install and manifest lines and the existing Included entry.

bash skills/teamsmith/tests/section-select.sh --check
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check
```

Also inspect `git diff -- README.md` and confirm that only the three intended wording areas changed. Do not run the full gate, merge, push, retry CI or publish.

## Delivery

Commit the README correction and `docs/team/reports/P384-dev3.md` with the before/after lines and exact checks. State that this fixes current-main documentation only; the already-published v0.3.4 tag and npm package remain unchanged until a separately authorized release.
