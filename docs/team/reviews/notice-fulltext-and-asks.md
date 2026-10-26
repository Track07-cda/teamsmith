# Verification record · notice-fulltext-and-asks

- Verdict: **PASS**
- Change: `notice-fulltext-and-asks`
- Independent reviewer: `verify`, task V100, second round
- Reviewer record: `docs/team/reports/V100-verify.md`; PM adoption record: `docs/team/reviews/V100.md`
- Candidate accepted: `b53c2d23`; product merge commit recorded in `docs/team/reviews/P370.md`

## Evidence accepted

The reviewer constructed its own inputs and compared bytes rather than trusting the implementation report:

- A 4 KiB completion is stored as **4096 bytes** in both the inbox record and the `state/notify.log` event, byte-identical to the original. The `full=` locator resolves to that exact record.
- Only the preview is cut. A real cut carries `truncated=preview:<shown>/<total>B full=<path>[:<line>]`; an uncut short message gains no marker at all.
- A 71680-byte pathological message is bounded at 65536 bytes and marked `truncated=hard-limit:65536/71680B`, with **no `full=` field**. That absence is the signal that the original exists nowhere.
- Four independent `asks=` cases read `1 / 2 / absent / absent`, proving the closed marker set and the 400-character tail window. Digest names the questions without adding them to the wake count.
- `turn-notice-in-pm-inbox` and its A1/A2 contracts were unchanged.

The first review was PARTIAL for two reasons, both closed in the second round:

1. The new shape comparison compared only two real samples because the spool sample name was inconsistent and the loop skipped missing samples. It now requires three real samples and fails if any is missing.
2. `TEAM_INBOX_MAX_CHARS` had changed meaning from inbox-record truncation to preview length. The schema, template, configuration reference and both panel language tables now say so, and `panel.js` was rebuilt with the pinned toolchain.

The reviewer also demonstrated that its new assertions fail on the old tree (`152B ≠ 4096B`), so the full-text checks are not a rubber stamp.

## Archive boundary

The change is additive at the specification level. It deliberately does not modify the older turn-notice requirements, because two pending MODIFIED deltas for one title would make archive order significant. `turn-notice-in-pm-inbox` has already been accepted independently; its archive may therefore proceed before this one without relying on this change's additive text.
