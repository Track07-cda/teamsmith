## ADDED Requirements

### Requirement: Clipboard condition changes reuse the panel without replacing live evidence

The clipboard fixture SHALL share one live panel across its first five input conditions, replacing four preparation-only relaunches with real draft editing. It SHALL retain all original behavioural assertions, eight subcases and four distinct panel starts. Seven active-paste subcases SHALL use real C-v and fresh tool/file/draft evidence; the unpressed-key subcase SHALL use zero C-v. Cached outcomes, model-only results or disk-only live-draft resets MUST NOT substitute.

#### Scenario: Changed tool input is observed by the same live panel

- **GIVEN** the clipboard fixture starts a panel with fake tools whose outputs are controlled by ordinary files inside its own temporary root
- **WHEN** it completes the Wayland-image condition and switches to Wayland-failure/X11-image after the first probe and subsequent typing have completed
- **THEN** the two conditions use the same panel process and separate real C-v presses, the first writes PNGDATA8 with no X11 invocation, and the second writes XCLIPDATA with Wayland logged before X11
- **AND** each condition's own path is inserted between a and d; the first condition's subsequent Z lands after that path, and no prior image or call log substitutes for the next result

#### Scenario: A reused panel receives its next seed through real keys

- **GIVEN** the live panel contains the preceding condition's draft and insertion point
- **WHEN** the fixture prepares the next of the first five conditions
- **THEN** real compose editing replaces the preceding text with the next seed and the fixture observes that exact draft before applying the original insertion-point and C-v actions
- **AND** writing only the on-disk draft cannot satisfy the preparation; an exhausted preparation wait names the expected state and fails the scenario rather than continuing as green

#### Scenario: All original clipboard outcomes still execute

- **WHEN** the ordinary `bash skills/teamsmith/tests/panel-b2.sh clipboard` entry executes on the project's normal default long disk path, with TMPDIR and TEAM_TMP_ROOT unset only for that child after confirming the resolved root remains under /var/tmp
- **THEN** Wayland image, X11 image fallback, text fallback, no data, a hanging tool, standby reason, the alternate team-cli interface and unpressed C-v observations all retain their original real interactions, assertions and verdicts
- **AND** the text case produces afrom the clipboardd without an image file or X11 call, no-data and hanging-tool cases preserve the draft and allow subsequent typing, and the hanging-tool observation remains five seconds
- **AND** the three existing image waits observe the actual image and corresponding message-draft or reason state through the existing wait engine, not an unbroken screen filename token; default-path wrapping cannot turn a completed paste into a false timeout, and missing state still fails
- **AND** those three local observation replacements precede the four preparation replacements in the same apply; the single complete clipboard run covers both without a separate short-path run or changes to the wait library, timing, width or path layout
- **AND** the first five conditions share one panel; the reason, alternate team-cli and unpressed-key preparations retain separate starts, for four panel starts in total without changing project/server/PM setup or other scenarios

#### Scenario: Idle observation and recovery coverage do not become setup savings

- **WHEN** the clipboard execution inventory and surrounding fixture sources are reviewed
- **THEN** both original five-second unpressed-key observations remain, one with compose closed and one open, alongside the original no-tool/hanging-tool interactions and Esc behaviour
- **AND** the existing draft persistence, send-settlement recovery, other scenarios, key pacing, wait-engine settling and limits, and invocation/section-selection interfaces are unchanged; no retained behaviour moves to an optional or nightly entry

#### Scenario: A broken C-v and its failed child cannot look successful

- **GIVEN** a disposable bundle whose real C-v handler is a no-op and the existing first image condition driven through the real terminal
- **WHEN** that condition is observed and its actual failed log and status are consumed by the existing section verdict function
- **THEN** the original image-file or file-content assertion fails, the clipboard child exits non-zero, and the consuming section records failure rather than success
- **AND** a setup error or timeout alone does not substitute for the named intended assertion, and byte restoration plus the necessary short restored check is recorded separately from the single normal complete clipboard run

#### Scenario: Evidence distinguishes preparation reduction from runtime improvement

- **WHEN** delivery evidence for this change is read
- **THEN** it separately states actual launches, real seed-reset actions, tool-input writes, assertions and wait errors; eight-to-four is not claimed as a measured elapsed saving
- **AND** a non-author supplies one ordinary complete clipboard run and the necessary focused bad-leg/failure-consumption evidence; the implementer does not repeat the full entry, and merged-byte identity with necessary short checks does not masquerade as another complete clipboard or b2/section-38 run
