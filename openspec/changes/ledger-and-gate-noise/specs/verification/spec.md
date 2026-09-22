## ADDED Requirements

### Requirement: The container self-test's host fingerprint is stable state, and only a real host change moves it

`bash skills/teamsmith/tests/container-tmux.sh --selftest` SHALL decide that the container touched nothing on the
host by comparing a fingerprint of the host's tmux state taken before and after the container run, and that
fingerprint MUST be built only from facts that a real host change moves: for each socket in scope — the caller's
socket and the host's default socket paths — the socket's on-disk identity, the server's own session table for
that socket, and, when a server answers there, that server's process id. No other process may be able to move the
value: running `tmux` clients, the gate shim, a `team` command, or any process whose command line merely mentions
tmux SHALL leave the value byte-identical, and servers, sessions and processes outside the sockets in scope (for
instance another project's private fixture server on this host) MUST NOT enter it. Reading the fingerprint MUST
be read-only — it MUST NOT start a server — and the self-test SHALL print both values and MUST exit non-zero when
they differ.

`container-tmux.sh --fingerprint` SHALL print the fingerprint for the current environment (honouring `TMUX` and
`TMUX_TMPDIR`) without starting a container, and `container-tmux.sh --fingerprint-check` SHALL run the fixture of
the scenarios below and exit 0 only when the client storm left the value byte-identical **and** killing a server
on an in-scope socket changed it.

#### Scenario: A client storm is not a false red

- **GIVEN** a live private server on an in-scope socket (`TMUX_TMPDIR` and `TMUX` pinned to a private directory)
- **WHEN** `container-tmux.sh --fingerprint` runs, a bounded storm of `tmux list-sessions`/`display-message`
  clients and shells whose command line names the tmux binary runs, and the command runs again
- **THEN** the two values are byte-identical and `container-tmux.sh --fingerprint-check` exits 0 — on the
  pre-change fingerprint the same storm moves the value (that red side is in the delivery report)

#### Scenario: Killing a server on an in-scope socket is red

- **GIVEN** the same fixture with the server alive and the first fingerprint recorded
- **WHEN** the server is killed and `container-tmux.sh --fingerprint` runs again
- **THEN** the two values differ, and `container-tmux.sh --fingerprint-check` exits non-zero naming both values
  while the same fixture with the server left alive exits 0

#### Scenario: A real session change is red by contract

- **GIVEN** a live server on an in-scope socket and the first fingerprint recorded
- **WHEN** a session is created on that server and the fingerprint is read again
- **THEN** the two values differ — the premise is host tmux state, so a genuine host-side change is a change

#### Scenario: The read never starts a server

- **GIVEN** a private `TMUX_TMPDIR` with no server running
- **WHEN** `container-tmux.sh --fingerprint` runs twice
- **THEN** both runs exit 0, print the same value, and no socket file appears under that directory
