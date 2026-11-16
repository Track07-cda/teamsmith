# Spec Delta

## ADDED Requirements

### Requirement: Normal help entry verification renders its canonical page once
For each manifest command, normal help-route verification SHALL render `help <command>` once and compare its raw stdout bytes with both real `--help` and `-h` entries. Reuse SHALL be limited to that command's current check and environment. Byte differences or a non-zero entry status MUST produce a command/entry-named finding and fail the existing fixture result through the same judgement used by short controls.

#### Scenario: Three real entries retain both byte comparisons
- **GIVEN** a fixed manifest with N command rows and a fixed language, locale and width
- **WHEN** its normal command-entry comparison loop runs
- **THEN** it makes 3N real CLI calls, one per entry per command, instead of 4N, and compares both alias outputs with that command's single canonical output including every trailing newline
- **AND** equal successful entries preserve the existing normal success assertion; reuse does not cross commands, invocations, languages, locales or widths, and all other route checks and help groups keep their existing inputs, assertions and result paths

#### Scenario: Either alias returning different bytes fails by name
- **GIVEN** successful canonical output and either `--help` or `-h` returning another page, or differing only by one trailing newline
- **WHEN** the short control invokes the same command-entry judgement that the normal loop uses
- **THEN** each damaged alias is rejected with a finding naming its command and entry; the other alias is still checked and unchanged equal-byte controls have no finding
- **AND** restoring the damaged bytes on the same control restores the successful outcome without a complete help run for each control

#### Scenario: Matching output cannot hide an entry execution failure
- **GIVEN** canonical, `--help` and `-h` outputs whose bytes match, including an all-empty case, and each entry independently returning a non-zero status
- **WHEN** the same command-entry judgement checks each failure and its successful restoration
- **THEN** each failure produces a finding naming the command, failed entry and status even though bytes match, all three entries are attempted once, and each restored control passes

#### Scenario: Findings reach the real route result rather than a helper-only log
- **GIVEN** an isolated short driver using the candidate's actual command-entry function, normal loop call site, finding accumulator and final result code
- **WHEN** an alias differs or fails, and then is restored on the same copy
- **THEN** the damaged run emits the intended command/entry-named finding, withholds the all-equal success assertion and exits 1 through the existing result; the restored run has no such finding and exits 0
- **AND** a disposable change that discards findings at the loop call site fails this wiring check; short drivers provide controlled input only, never their own comparison or expected-log verdict, and do not claim complete route or smoke execution
