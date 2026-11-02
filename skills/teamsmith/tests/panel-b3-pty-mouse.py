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
import errno
import fcntl
import os
import pty
import re
import select
import struct
import subprocess
import sys
import termios
import time


FRAME_START = b"\x1b[?2026h"
FRAME_END = b"\x1b[?2026l"

# These are failure detectors, not timing assertions. A round reads for up to 0.3 s;
# 10,000 rounds leave the existing shared 25 s deadline in charge even during fast redraws.
# Host focused mouse run (2026-10-28, 3/40 wheels): successful wait-only latencies
# were 0–71 ms, including frame polling but excluding initial panel startup. The cap
# and deadline detect missing progress; neither is a performance pass/fail threshold.
FRAME_WAIT_CAP = 10000
FRAME_WAIT_POLL = 0.3


def last_complete_frame(data):
    end = data.rfind(FRAME_END)
    start = data.rfind(FRAME_START, 0, end) if end >= 0 else -1
    if start < 0 or data.rfind(FRAME_START) > end:
        return b""
    tail = data[end + len(FRAME_END):]
    if any(tail.endswith(FRAME_START[:n]) for n in range(1, len(FRAME_START))):
        return b""
    return data[start + len(FRAME_START):end]


def drain(fd, seconds, deadline=None, until_frame=False):
    # Zero seconds drains everything immediately available, without waiting for new output.
    end = time.monotonic() + seconds if seconds else float("inf")
    if deadline is not None:
        end = min(end, deadline)
    buf = b""
    while (remaining := end - time.monotonic()) > 0:
        r, _, _ = select.select([fd], [], [], min(0.05, remaining) if seconds else 0)
        if not r and not seconds:
            break
        if r:
            try:
                chunk = os.read(fd, 65536)
            except OSError as exc:
                if exc.errno == errno.EIO:  # A closed pty slave reports EIO on the master.
                    break
                raise
            if not chunk:
                break
            buf += chunk
            if until_frame and last_complete_frame(buf):
                break
    return buf


def frame_reading(data, previous=b""):
    frame = last_complete_frame(data)
    source = "current"
    if not frame:
        frame = last_complete_frame(previous)
        source = "previous"
    if not frame:
        return f"no complete frame (current_bytes={len(data)}, previous_bytes={len(previous)})"
    text = frame.decode("utf-8", errors="replace")
    text = re.sub(r"\x1b\][^\x07\x1b]*(?:\x07|\x1b\\\\)", "", text)
    text = re.sub(r"\x1b\[[0-9;?]*[a-zA-Z]", "", text)
    lines = [line.strip() for line in text.splitlines() if line.strip()]
    # Include the first rows, where the list's newest entry or the overlay appears.
    summary = " | ".join(lines[:8])[:1000]
    return f"{source} complete frame (current_bytes={len(data)}): {summary!r}"


def wait_frame(fd, proc, deadline, name, expected, data, predicate, previous=b"", cap=FRAME_WAIT_CAP):
    """Observe a complete frame in counted rounds, publishing each actual reading."""
    start = time.monotonic()
    round_no = 0
    reading = "no observation"
    progress_fd = os.environ.get("TEAM_PTY_PROGRESS_FD")
    while round_no < cap:
        round_no += 1
        frame = last_complete_frame(data)
        reading = frame_reading(data, previous)
        elapsed_ms = round((time.monotonic() - start) * 1000)
        progress = (f"P383 wait={name} round={round_no}/{cap} elapsed_ms={elapsed_ms} "
                    f"expected={expected} last={reading}")
        print(progress, file=sys.stderr, flush=True)
        if progress_fd is not None:
            os.write(int(progress_fd), (progress + "\n").encode())
        if frame and predicate(frame):
            return data, None
        if proc.poll() is not None or time.monotonic() >= deadline or round_no == cap:
            break
        data += drain(fd, FRAME_WAIT_POLL, deadline, until_frame=True)
    return data, (f"wait={name} {round_no}/{cap} expected={expected}; last={reading}; "
                  f"process_status={proc.poll()}")


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
    ap.add_argument("--wheel-ready", default="", help="wait for this text in a complete frame before scrolling")
    ap.add_argument("--wheel-barrier", default="", help="overlay text used to acknowledge the wheel input")
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

    def fail(message, data, after=None):
        # Keep the observed bytes even on failure: an empty or interrupted frame is evidence.
        with open(args.out, "wb") as dump:
            dump.write(data)
        if args.out2 and after is not None:
            with open(args.out2, "wb") as dump2:
                dump2.write(after)
        print(f"panel-b3-pty-mouse: {message}", file=sys.stderr)
        proc.terminate()
        try:
            proc.wait(timeout=3)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait()
        os.close(master)
        return 2

    deadline = time.monotonic() + args.wait
    boot = b""
    while time.monotonic() < deadline and b"teamsmith pulse" not in boot:
        boot += drain(master, 0.3, deadline)
        if proc.poll() is not None:
            break
    if b"teamsmith pulse" not in boot:
        return fail(f"the console never rendered (process status {proc.poll()})", boot)

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
        if args.wheel_ready:
            # The list is loaded asynchronously. Do not count its initial frame as a scroll frame.
            ready = args.wheel_ready.encode()
            observed, error = wait_frame(
                master, proc, deadline, "wheel-ready", f"complete frame contains {args.wheel_ready!r}",
                out + after, lambda frame: ready in frame)
            after = observed[len(out):]
            if error:
                return fail(error, observed, after)
            out = observed
            after = b""
        button = 65 if args.wheel == "down" else 64
        event = f"\x1b[<{button};{args.click_col};{args.click_row}M".encode()
        if args.wheel_barrier:
            # Ink splits consecutive SGR sequences into separate inputs. The overlay is queued
            # after the last wheel: seeing it proves the input stream has been handled, including
            # no-op notches at the clamp. Closing it leaves the page and viewport unchanged.
            for _ in range(args.wheel_clicks):
                if time.monotonic() >= deadline:
                    return fail("deadline expired while sending wheel events", out + after, after)
                if os.write(master, event) != len(event):
                    return fail("short write while sending wheel events", out + after, after)
                after += drain(master, 0, deadline)
            if os.write(master, b",") != 1:
                return fail("short write while sending wheel barrier", out + after, after)
            marker = args.wheel_barrier.encode()
            after, error = wait_frame(
                master, proc, deadline, "wheel-barrier-open", f"complete frame contains {args.wheel_barrier!r}",
                after, lambda frame: marker in frame, previous=out)
            if error:
                return fail(error, out + after, after)
            os.write(master, b"\x1b")
            closed, error = wait_frame(
                master, proc, deadline, "wheel-barrier-close", f"new complete frame without {args.wheel_barrier!r}",
                b"", lambda frame: marker not in frame, previous=after)
            after += closed
            if error:
                return fail(error, out + after, after)
        else:
            for _ in range(args.wheel_clicks):
                if time.monotonic() >= deadline:
                    return fail("deadline expired while sending wheel events", out + after, after)
                os.write(master, event)
                # Read while the panel writes; advance on a complete redraw or at the old bound.
                after += drain(master, 0.35, deadline, until_frame=True)
        after += drain(master, 1.2, deadline)
        if time.monotonic() >= deadline:
            return fail("deadline expired while collecting wheel output", out + after, after)

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

    if proc.poll() is not None:
        return fail(f"console exited during interaction (status {proc.returncode})", out + after, after)
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
