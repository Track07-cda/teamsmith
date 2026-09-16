#!/usr/bin/env python3
"""pty driver for the keystroke probe (pulse-console B1, tasks.md 1.4).

`tmux send-keys` cannot be used here: it coalesces the bytes into one write. A real terminal
delivers one keystroke per read, which is exactly the property the fixture asserts — so the probe
runs on a pty and the keys are written to the master side with a human-sized gap (E6 §1.1's
methodology note).

  python3 panel-keyprobe-pty.py --log FILE --timeout 20 -- <runner> <probe.js> [args...]

Prints the child's output and exits with the child's status.
"""
import argparse
import errno
import os
import pty
import select
import signal
import sys
import time

KEYS = [b"m", b"h", b"e", b"l", b"l", b"o", b"\r"]
GAP = 0.12
FIRST_DELAY = 0.6


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--log", required=True)
    ap.add_argument("--timeout", type=float, default=20.0)
    ap.add_argument("cmd", nargs=argparse.REMAINDER)
    args = ap.parse_args()
    cmd = args.cmd
    if cmd and cmd[0] == "--":
        cmd = cmd[1:]
    if not cmd:
        print("no command", file=sys.stderr)
        return 64

    pid, fd = pty.fork()
    if pid == 0:  # child
        os.execvp(cmd[0], cmd)
        os._exit(127)

    deadline = time.time() + args.timeout
    # Wait until the probe has started and opened its log, so the keys land during the refresh.
    started = False
    while time.time() < deadline and not started:
        try:
            with open(args.log) as fh:
                started = '"kind":"start"' in fh.read()
        except OSError:
            pass
        time.sleep(0.05)
    time.sleep(FIRST_DELAY)

    out = b""
    sent = 0
    status = None
    while True:
        if sent < len(KEYS):
            try:
                os.write(fd, KEYS[sent])
            except OSError as exc:
                if exc.errno != errno.EIO:
                    raise
            sent += 1
            time.sleep(GAP)
        r, _, _ = select.select([fd], [], [], 0.1)
        if fd in r:
            try:
                chunk = os.read(fd, 65536)
            except OSError:
                chunk = b""
            if not chunk:
                break
            out += chunk
        done, st = os.waitpid(pid, os.WNOHANG)
        if done == pid:
            status = st
            break
        if time.time() > deadline:
            os.kill(pid, signal.SIGKILL)
            _, st = os.waitpid(pid, 0)
            status = st
            break

    if status is None:
        _, status = os.waitpid(pid, 0)
    try:
        os.close(fd)
    except OSError:
        pass
    sys.stdout.write(out.decode("utf-8", "replace"))
    return os.waitstatus_to_exitcode(status)


if __name__ == "__main__":
    sys.exit(main())
