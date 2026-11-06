## 1. The landing-zone predicate

- [x] 1.1 One predicate resolves a discovered path to its real path (full link chain, bounded hops, `pwd -P` on the
  parent) and compares it with the boundary: the project root when the allowed root is inside the project, the allowed
  root itself when it is not (an absolute ledger or spec root outside the project has no outer trusted anchor).
  Discovery, the list blocks and the read path all use it; a failed resolution refuses rather than widens.
- [x] 1.2 Keep the read path atomic: the fd identity and the real path are read from the same open descriptor, and the
  non-regular-file check runs before the open (bash has no `O_NONBLOCK` open, so a type check is what keeps a FIFO from
  blocking the console).

## 2. What the block reports

- [x] 2.1 A served-through-link read carries the link segments it passed through (project-relative, deduplicated), so an
  operator can see the layout without reading the code.
- [x] 2.2 A refused read names both the real path and the boundary it left; a non-regular file is named with its kind
  (FIFO, device, directory, socket, broken link), and neither enters the discovered set — `--file` cannot select it.

## 3. Fixtures

- [x] 3.1 Pin the inside case (ledger root and change directory linked inside the project: served, links reported, no
  unavailable reason, list blocks still populate), the outside case (refused, real path and project root both named,
  nothing printed, exit still 0), and the non-regular case (FIFO directly and through a link: refused, named, and the
  reader returns inside a ten-second bound).
- [x] 3.2 Keep the pre-existing refusals green: `--file` outside the discovered set, an unknown source, an id that
  leaves its grammar, the archive addressed by its own path, the tree-outside list blocks, and the byte-for-byte machine
  exits.
