## ADDED Requirements

### Requirement: `team doctor` reports the temp root's headroom

`team doctor` SHALL print one line for the temp root the fixtures resolve to (`${TMPDIR:-/tmp}`), carrying that
resolved path, the free and total bytes **and** the free and total inodes of its filesystem, and a verdict. The
line MUST warn — without making `team doctor` exit non-zero — when the free bytes are below
`TEAM_TMP_MIN_FREE_MB` (default 1024) or the free inodes are below `TEAM_TMP_MIN_FREE_INODES` (default 100000; a
non-numeric value falls back to the default), and the warning MUST name the figures it measured, the threshold it
crossed and the remedy (`bash skills/teamsmith/tests/tmp-hygiene.sh --status`, then `--sweep`). When the path or a
figure cannot be read the line SHALL say so and MUST NOT report the headroom as fine. The check MUST read nothing
inside the temp root and MUST NOT delete anything; raising the headroom is an operator action (as with the inotify
quota, the sibling host-resource row). Why a full temp filesystem is a gate risk, and the measured floor behind the
defaults: the `test-tmp-hygiene` change's `design.md` and `references/troubleshooting.md`.

#### Scenario: A healthy temp root is reported with its numbers

- **WHEN** `team doctor` runs with both figures above their thresholds
- **THEN** exactly one line names the resolved temp root, the free/total bytes and the free/total inodes, and the check passes — and the doctor's exit status is unchanged by this check

#### Scenario: A low temp root warns with its remedy and does not fail the doctor

- **GIVEN** `TEAM_TMP_MIN_FREE_MB` set above the free bytes actually measured
- **WHEN** `team doctor` runs
- **THEN** the line is a warning naming the measured figures, the threshold it crossed and the `tmp-hygiene.sh` remedy, and `team doctor` still exits 0

#### Scenario: An unreadable temp root is never reported as healthy

- **GIVEN** a resolved temp root that does not exist
- **WHEN** `team doctor` runs
- **THEN** the line states that the figures could not be read and the check is a warning, not a pass, and it does not invent a number
