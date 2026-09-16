#!/usr/bin/env python3
"""Full-chain mouse driver for the pulse console (pulse-console B3, tasks.md 6.3).

`tmux send-keys` cannot inject an `0x1b` byte (tmux's key layer eats it — E6's methodology note),
so the only honest way to test SGR mouse is a real-terminal pty: a python pty plays the user's
terminal, a tmux CLIENT is attached on it, and the click bytes are written to the pty master. tmux
hit-tests them and forwards SGR to the pane application, exactly as a real click would.

The script locates the click target itself from `tmux capture-pane`: it finds the row holding the
key-band hint text and the hint's column, so the click lands on the rendered target rather than on
hard-coded coordinates.

  python3 panel-b3-pty-tmux-mouse.py --sock S --session S --out raw.bin \
      [--pane SESSION:WINDOW] [--hint "m 写信"] [--offset 0] [--wheel down|up|none] [--rows N] [--cols N]

Exit: 0 the click was injected, 2 the hint row was never rendered (setup failure), 3 no tmux.
"""

import argparse
import fcntl
import os
import pty
import select
import struct
import subprocess
import sys
import termios
import time


def tmux(sock, *args):
    return subprocess.run(["tmux", "-L", sock, *args], capture_output=True, text=True).stdout


def drain(fd, seconds):
    end = time.time() + seconds
    buf = b""
    while time.time() < end:
        r, _, _ = select.select([fd], [], [], 0.05)
        if r:
            try:
                chunk = os.read(fd, 65536)
            except OSError:
                break
            if not chunk:
                break
            buf += chunk
        # keep reading until the window is quiet for a moment
        if buf:
            end = min(end, time.time() + 0.15)
    return buf


def find_hint(pane_text, hint):
    for i, line in enumerate(pane_text.splitlines()):
        col = line.find(hint)
        if col >= 0:
            return i + 1, col + 1  # 1-based row and column
    return None, None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--sock", required=True)
    ap.add_argument("--session", required=True)
    ap.add_argument("--pane", default="")
    ap.add_argument("--hint", default="m ")
    ap.add_argument("--offset", type=int, default=0)
    ap.add_argument("--wheel", choices=["down", "up", "none"], default="none")
    ap.add_argument("--clicks", type=int, default=1)
    ap.add_argument("--no-click", action="store_true", help="inject only the wheel (if any), no press/release")
    ap.add_argument("--rows", type=int, default=32)
    ap.add_argument("--cols", type=int, default=120)
    ap.add_argument("--wait", type=float, default=25.0)
    ap.add_argument("--out", required=True)
    ap.add_argument("--no-client", action="store_true", help="inject on the server's own tty (not used)")
    args = ap.parse_args()

    target = args.pane or f"{args.session}:"
    deadline = time.time() + args.wait
    row = col = None
    while time.time() < deadline:
        text = tmux(args.sock, "capture-pane", "-p", "-t", target)
        row, col = find_hint(text, args.hint)
        if row is not None:
            break
        time.sleep(0.3)
    if row is None:
        print(f"panel-b3-pty-tmux-mouse: hint {args.hint!r} never rendered in {target}", file=sys.stderr)
        return 2

    x = col + args.offset
    y = row

    master, slave = pty.openpty()
    fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", args.rows, args.cols, 0, 0))
    env = dict(os.environ, TERM="xterm-256color")
    client = subprocess.Popen(
        ["tmux", "-L", args.sock, "attach", "-t", target],
        stdin=slave,
        stdout=slave,
        stderr=slave,
        env=env,
        close_fds=True,
    )
    os.close(slave)
    boot = drain(master, 2.0)
    with open(args.out, "wb") as dump:
        dump.write(boot)

    for seq in [] if args.no_click else [f"\x1b[<0;{x};{y}M", f"\x1b[<0;{x};{y}m"]:
        os.write(master, seq.encode())
        time.sleep(0.35)
        drain(master, 0.2)
    if args.wheel != "none":
        button = 65 if args.wheel == "down" else 64
        for _ in range(args.clicks):
            os.write(master, f"\x1b[<{button};{x};{y}M".encode())
            time.sleep(0.35)
            drain(master, 0.2)
    drain(master, 0.4)

    client.terminate()
    try:
        client.wait(timeout=3)
    except subprocess.TimeoutExpired:
        client.kill()
    os.close(master)
    print(f"clicked ({x},{y}) on {target}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
