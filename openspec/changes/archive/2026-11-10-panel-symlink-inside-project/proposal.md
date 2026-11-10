## Why

The console's read-only previews refuse any discovered path that is a symbolic link, on the reading that a link is an
attack. That model is wrong for this tool: a project's own ledger is sometimes mounted through a link inside the same
project (the entry detail view then shows "source unavailable" for every task, report and review of that project), and
a link inside the project cannot reach anything a reader of that project could not reach directly. What actually has to
hold is one boundary — **nothing outside the project root is ever read** — and today's rule neither states that
boundary nor allows a legitimate layout inside it. The current spec also contradicts the shipped behavior, so the
contract has to change rather than be silently outgrown.

## What Changes

- Judge a discovered path by its **real path**, not by "any segment is a link": resolve the path, and serve it when the
  real path stays inside the reader's project root. A link inside the project is a legitimate layout, including one that
  crosses to another change or to the archive.
- Keep the boundary explicit: a real path that leaves the project root is refused, and the reason names **both** the real
  path and the project root, so an operator does not have to guess which segment was the alias.
- Report, do not hide: a block that served a file through one or more links carries the link segments it passed through.
- Refuse a discovered path that is not a regular file (FIFO, device, directory, socket, broken link) **by kind, without
  opening it** — a FIFO must not be able to hold the console in `open`, and a corrupt ledger entry must be named rather
  than silently skipped.
- The archive stays unreachable **by its own path**: only a link that resolves inside the project root can expose it.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `panel`: the detail view's refusal contract moves from "a symbolic link is refused" to "a real path outside the project
  root is refused", adds the served-through-link report and the non-regular-file refusal, and restates the archive /
  other-change limit as a limit on the path addressed rather than on the link.

## Impact

The change is confined to the detail reader in `scripts/lib/cmd-watch.sh` (one landing-zone predicate shared by
discovery, the read path and the three list blocks) and its fixtures in `tests/smoke.sh`. No panel layout, i18n string,
configuration key, storage format or runtime dependency changes. The read path keeps its single-open atomicity — the fd
identity and the real path are measured from the same descriptor — so the "discovery, then swap the path" race stays
closed. Behavior changes only where a path under the project root is reached through a link: those reads go from refused
to served, and their blocks gain one field naming the links. Outside-root links, non-regular files and every existing
grammar / discovery-set refusal behave as before.
