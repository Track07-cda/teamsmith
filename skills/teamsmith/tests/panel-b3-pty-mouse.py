#!/usr/bin/env python3
"""Direct pty mouse driver for the pulse console (pulse-console B3, tasks.md 6.3).

The headless sibling of `panel-b3-pty-tmux-mouse.py`: the panel itself runs on the pty (no tmux in
the middle) and the click bytes are written straight to the master. It asserts the two properties
that do not need tmux's hit testing:

  * with the mouse preference on, the console emits the SGR enable sequence (`ESC[?1006h`);
  * a click on the page tabs switches the page (the page file changes) — the same effect the
    keyboard's `2` has.

  python3 panel-b3-pty-mouse.py --js node --panel panel.js --root DIR --state-dir DIR
      --team-cli STUB --out raw.bin [--click-col 12 --click-row 2] [--keys "hi"] [--expect-draft hi]

Exit: 0 assertions held, 2 the console never rendered, 3 usage/env failure.
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


def drain(fd, seconds, deadline=None):
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
        if deadline is not None and time.time() > deadline:
            break
    return buf


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--js", required=True)
    ap.add_argument("--panel", required=True)
    ap.add_argument("--root", required=True)
    ap.add_argument("--state-dir", required=True)
    ap.add_argument("--team-cli", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--click-col", type=int, default=12)
    ap.add_argument("--click-row", type=int, default=2)
    ap.add_argument("--click2-col", type=int, default=0, help="a second click after --send")
    ap.add_argument("--click2-row", type=int, default=0)
    ap.add_argument("--keys", default="")
    ap.add_argument("--expect-draft", default="")
    ap.add_argument("--expect-enable", choices=["yes", "no"], default="yes")
    ap.add_argument("--expect-page", default="")
    ap.add_argument("--toggle-mouse-off", action="store_true",
                    help="open the overlay, move to the mouse row and toggle it off before clicking")
    ap.add_argument("--no-click", action="store_true", help="inject only the wheel (if any), no press/release")
    ap.add_argument("--wheel", choices=["down", "up", "none"], default="none")
    ap.add_argument("--wheel-clicks", type=int, default=0)
    ap.add_argument("--out2", default="", help="the bytes written after the wheel injection")
    ap.add_argument("--send", default="", help="comma-separated key sequence before the dump (enter,esc,q,tab,up,down,left,right, or raw text)")
    ap.add_argument("--send2", default="", help="second key sequence; its bytes go to --out2 after --send")
    ap.add_argument("--cols", type=int, default=100)
    ap.add_argument("--rows", type=int, default=30)
    ap.add_argument("--wait", type=float, default=25.0)
    args = ap.parse_args()

    named = {
        "enter": b"\r",
        "esc": b"\x1b",
        "tab": b"\t",
        "up": b"\x1b[A",
        "down": b"\x1b[B",
        "right": b"\x1b[C",
        "left": b"\x1b[D",
    }

    def send_sequence(sequence, deadline):
        for token in sequence.split(","):
            if not token:
                continue
            os.write(master, named.get(token, token.encode()))
            time.sleep(0.35)
        return drain(master, 1.0, deadline)

    master, slave = pty.openpty()
    fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", args.rows, args.cols, 0, 0))
    env = dict(
        os.environ,
        TERM="xterm-256color",
        TEAM_MONITOR_UI="tui",
    )
    proc = subprocess.Popen(
        [
            args.js,
            args.panel,
            "--root",
            args.root,
            "--state-dir",
            args.state_dir,
            "--team-cli",
            args.team_cli,
            "--no-pulse",
            "--interval",
            "2",
        ],
        stdin=slave,
        stdout=slave,
        stderr=slave,
        env=env,
        close_fds=True,
    )
    os.close(slave)

    deadline = time.time() + args.wait
    boot = b""
    while time.time() < deadline and b"teamsmith pulse" not in boot:
        boot += drain(master, 0.3, deadline)
    if b"teamsmith pulse" not in boot:
        proc.kill()
        os.close(master)
        print("panel-b3-pty-mouse: the console never rendered", file=sys.stderr)
        return 2

    out = boot + drain(master, 0.5, deadline)

    toggled = b""
    if args.toggle_mouse_off:
        # `,` opens the overlay on the language row; three Downs reach the mouse row; Enter toggles.
        for key in [b",", b"\x1b[B", b"\x1b[B", b"\x1b[B", b"\r"]:
            os.write(master, key)
            time.sleep(0.3)
        toggled = drain(master, 1.0, deadline)
        out += toggled
        if b"\x1b[?1006l" not in toggled:
            print("panel-b3-pty-mouse: toggling the mouse off emitted no disable sequence", file=sys.stderr)
            proc.terminate()
            os.close(master)
            return 1
        if toggled.rfind(b"\x1b[?1006h") > toggled.rfind(b"\x1b[?1006l"):
            print("panel-b3-pty-mouse: an enable sequence arrived after the disable", file=sys.stderr)
            proc.terminate()
            os.close(master)
            return 1
        # Close the overlay so the tab click lands on the frame again.
        os.write(master, b"\x1b")
        time.sleep(0.3)
        out += drain(master, 0.5, deadline)

    if not args.no_click:
        os.write(master, f"\x1b[<0;{args.click_col};{args.click_row}M".encode())
        time.sleep(0.3)
        os.write(master, f"\x1b[<0;{args.click_col};{args.click_row}m".encode())
        out += drain(master, 1.0, deadline)

    # Everything after `--send` is the "after" segment: the wheel, the second click and `--send2`.
    # `--out2` gets exactly that segment, which is how a test sees a state change without scraping
    # the whole stream (the existing wheel fixtures rely on the same shape).
    after = b""

    if args.send:
        after += send_sequence(args.send, deadline)

    if args.wheel != "none" and args.wheel_clicks > 0:
        button = 65 if args.wheel == "down" else 64
        for _ in range(args.wheel_clicks):
            os.write(master, f"\x1b[<{button};{args.click_col};{args.click_row}M".encode())
            time.sleep(0.35)
        after += drain(master, 1.2, deadline)

    if args.keys:
        for ch in args.keys:
            os.write(master, ch.encode())
            time.sleep(0.12)
        out += drain(master, 1.0, deadline)

    if args.click2_col > 0:
        os.write(master, f"\x1b[<0;{args.click2_col};{args.click2_row}M".encode())
        time.sleep(0.3)
        os.write(master, f"\x1b[<0;{args.click2_col};{args.click2_row}m".encode())
        after += drain(master, 1.0, deadline)

    if args.send2:
        after += send_sequence(args.send2, deadline)

    out += after
    if args.out2:
        with open(args.out2, "wb") as dump2:
            dump2.write(after)

    with open(args.out, "wb") as dump:
        dump.write(out)

    proc.terminate()
    try:
        proc.wait(timeout=3)
    except subprocess.TimeoutExpired:
        proc.kill()
    os.close(master)

    enabled = b"\x1b[?1006h" in out
    ok = True
    if args.expect_enable == "yes" and not enabled:
        print("panel-b3-pty-mouse: the console never sent the SGR enable sequence", file=sys.stderr)
        ok = False
    if args.expect_enable == "no" and enabled:
        print("panel-b3-pty-mouse: mouse is off but the enable sequence was sent", file=sys.stderr)
        ok = False
    if args.expect_page:
        try:
            with open(os.path.join(args.state_dir, "panel-page")) as fh:
                page = fh.read().strip()
        except OSError:
            page = ""
        if page != args.expect_page:
            print(f"panel-b3-pty-mouse: panel-page is {page!r}, expected {args.expect_page!r}", file=sys.stderr)
            ok = False
    if args.expect_draft:
        try:
            with open(os.path.join(args.state_dir, "draft.md")) as fh:
                draft = fh.read()
        except OSError:
            draft = ""
        if draft != args.expect_draft:
            print(f"panel-b3-pty-mouse: draft is {draft!r}, expected {args.expect_draft!r}", file=sys.stderr)
            ok = False
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
