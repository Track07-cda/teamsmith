## ADDED Requirements

### Requirement: Capture update evidence distinguishes disk content from loaded runtime

Teamsmith update fingerprints SHALL include the directed reply capture entry and its executable parser/journal dependencies, so an implementation-only change is not reported as unchanged. `team version --check` SHALL remain evidence of disk versus recorded skill state, not proof that the current PM has registered capture handlers. `team doctor` SHALL distinguish source present on disk, injection in the built-in launch path, and independently checkable current-PM runtime registration. A ready claim SHALL require a live matching PID/starttime/cwd/pane/session and current owner generation, with the module/dependency fingerprint retained when that code was loaded. Reading today's source hash during diagnosis MUST NOT masquerade as the fingerprint of already running code. Missing, dead, incomplete or stale registration SHALL be named unknown/stale/degraded rather than enabled; disk/install evidence alone MUST NOT imply capture support, and registration MUST NOT be treated as code-signature authentication.

The registration SHALL be local operational evidence, updated through existing lifecycle events without a heartbeat, daemon, scheduler, new project key, adapter placeholder or ordinary-Pi discovery. Doctor and version reads MUST remain observation-only and MUST NOT repair a journal, restart/reload the PM, rewrite registration or publish replies. The existing frozen worker-launch seam and adapter compatibility limits SHALL remain unchanged.

#### Scenario: A dependency-only edit invalidates the capture fingerprint
- **WHEN** only the capture parser/journal dependency changes after the PM loaded its earlier code
- **THEN** the skill update fingerprint changes and doctor distinguishes the running old fingerprint from the current disk fingerprint
- **AND** manually recording the current skill version does not turn the old loaded handler into the new one

#### Scenario: Disk presence is not a running handler
- **WHEN** source exists but the PM has no capture entry, its registration is absent/dead, or its PID/starttime/cwd/pane/session no longer matches
- **THEN** doctor reports source/launch and running evidence separately and does not claim capture ready
- **AND** filesystem and process snapshots show no writes, reload or restart from those diagnostic reads

#### Scenario: An already injected entry can prove replacement
- **WHEN** an explicitly authorized private PM reload replaces an already injected capture entry
- **THEN** the new live generation reports the fingerprint actually loaded and old-generation cleanup cannot erase it
- **AND** a fresh matching runtime can be reported ready without adding a new config key or changing adapter semantics
