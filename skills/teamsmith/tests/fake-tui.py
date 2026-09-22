#!/usr/bin/env python3
"""teamsmith 测试夹具：一个「像 Pi 的」TUI pane（输入框 + 会回显提交的对话区）。

为什么需要它（D20 / E3 §1.1(e)）：真实事故是「自动化消息被 send-keys 打进一个已经写了草稿的
输入框，草稿被粘在消息前面一起提交」。要复现/证伪这条，夹具 pane 必须：

  - 画一个带上下边框的输入框（`─`×宽度），光标落在内容行上（守卫是光标锚定的）；
  - 把已经提交的消息画在框上方（这样 pane 指纹会变，投递确认才有意义）；
  - 理解 bracketed paste（`ESC[200~ … ESC[201~`）：真实 Pi 把粘贴当**一个输入内容**，
    没有这个语义，三行草稿会被拆成三条提交（E3 §3.2 实测）；
  - 把人打进框里的字符与已有草稿**拼接**（旧实现下这就是「草稿被粘走」的现场）；
  - 输入框是一个带**光标**的编辑器（不是尾部字符串）：M17 的收回键序 `ctrl+a` + `ctrl+k` 要
    无论光标停在哪一行哪一列都能清空，夹具就得按 Pi 0.85.1 的语义实现这些键
    （`ctrl+a` 行首 / `ctrl+k` 删到行尾、行尾并下一行 / `ctrl+u` 删到行首 / `ctrl+e` 行尾 /
    `backspace` 删光标前一个字符、行首并上一行）——否则夹具会把控制字节当普通字符插进框里，
    测出来的「已收回」是假的。

env：
  FAKE_TUI_DRAFT             输入框初始内容（可含 \n）
  FAKE_TUI_SUBMIT_LOG        每次提交追加一行 `SUBMIT:<payload，\n 转义成 \\n>`
  FAKE_TUI_CURSOR_TRAILING=1 光标放在最后一行草稿**后面**的空行（E3 §1.5 状态 8）
  FAKE_TUI_DRAFT_ON_PASTE    开始粘贴时把这段文字插到框里（模拟「检查与粘贴之间有人开始打字」）
  FAKE_TUI_CURSOR_TOP=1      光标放在内容区**第一行**（配一个以空行开头的 DRAFT，就造出
                             V7-F1 的形状：文字全部在光标行下方）
  FAKE_TUI_MARKER=<n>        超过 n 行的 bracketed paste 折叠成 `[paste #1 +K lines]` 占位符
                             （真实 Pi v0.85.1 实测形状；0 = 不折叠）
  FAKE_TUI_CHARS_MARKER=<n>  真实 pi 的**另一条**折叠路径（M24 实测）：行数不多但**字符数**超过 n 时，
                             pi 折叠成 `[paste #N <chars> chars]`（字符 = 码点，不是字节：3×400 个
                             中文字 = 3602 字节 → 报 `1202 chars`）；0 = 不折叠
  FAKE_TUI_KEY_LOG=<file>    每个控制键追加一行（`C-u`/`C-a`/`C-k`/`C-c`…）——给「收回到底发了哪些键」
                             留可审计的证据
  FAKE_TUI_BREAK_CTRL_U=1    让 ctrl+u 变成空操作（模拟「键位变了/清不动」）→ 用来测收回的升级路径
                             （只在框非空时补一记 ctrl+c，且全程最多一次）
  FAKE_TUI_PASTE_STALL_MS=<ms> 折叠占位符先画一半（`[paste #N +1`），ms 毫秒后才补全（V8-N3 中间帧）
  FAKE_TUI_STATIC_FOOTER=1   提交后 pane 尾部不变：不在对话区回显已提交消息（真实事故里
                             「页脚一动不动」的 TUI 让尾部 400 字节指纹失效，V7-F4）
  FAKE_TUI_EAT_ENTER=1       吞掉 Enter：清空输入框但不提交、不回显（V9-B5「清空未提交」事故形状）
  FAKE_TUI_COLS              绘制宽度（默认 80；测试按 pane 宽度显式给，避免依赖 pty 尺寸）
  FAKE_TUI_BANNER            M45：输入框**上方**画 pi 的更新横幅（默认不画）。取值：
                             'pi' 版本横幅｜'note' 版本横幅 + 一段 release note（任意 markdown，
                             含一行半成品占位符字样）｜'packages' 扩展包横幅｜'both' 两个都有
                             （真实顺序：包在上、版本在下）—— 横幅的 DynamicBorder 与输入框边框
                             同形等宽，旧判据就是在这里把空框读成 BUSY 的（真帧见 tests/frames/）

退出：stdin 关闭（pane 被杀）即退出。
"""
import codecs
import os
import select
import time
import unicodedata
import sys
import termios
import tty

RULE = "\u2500"


def _keylog(tui, name: str) -> None:
    """控制键审计（FAKE_TUI_KEY_LOG）：给「收回到底发了哪些键」留证据。"""
    if not getattr(tui, "key_log", ""):
        return
    try:
        with open(tui.key_log, "a", encoding="utf-8") as fh:
            fh.write(name + "\n")
    except OSError:
        pass


def _cell_width(ch: str) -> int:
    return 2 if unicodedata.east_asian_width(ch) in ("W", "F") else 1


def _clip(text: str, width: int) -> str:
    """按**显示宽度**裁剪：CJK 是双宽字符，按字符数裁会折行、打乱行号模型。"""
    out = []
    used = 0
    for ch in text:
        w = _cell_width(ch)
        if used + w > width:
            break
        out.append(ch)
        used += w
    return "".join(out)


def _wrap(text: str, width: int) -> list:
    """按显示宽度折行（真实 TUI 的行为）：超过宽度的内容出现在下一行，不是被裁掉。
    P6 返工时修：旧版 _clip 把超长行裁掉了，导致长指针在框里「看不见尾巴」、指纹误判成外来文字。"""
    if width <= 0:
        return [text]
    lines, cur, used = [], [], 0
    for ch in text:
        w = _cell_width(ch)
        if used + w > width:
            lines.append("".join(cur))
            cur, used = [], 0
        cur.append(ch)
        used += w
    lines.append("".join(cur))
    return lines


def _paste_text(raw: bytes) -> str:
    """粘贴内容：tmux 的 paste-buffer 默认把 LF 换成 CR，真实 TUI 把 CR 当换行 —— 夹具照样归一化。"""
    return raw.decode("utf-8", "replace").replace("\r\n", "\n").replace("\r", "\n")


class Tui:
    def __init__(self) -> None:
        # 宽度不能靠 pty（tmux 的 -x/-y 与实际 pty 尺寸可能不一致，长短行会被折行、行号模型就错了）：
        # 显式给宽度，并且规则行用固定长度 —— 守卫只要求「整行都是 ─」/「以 ── 开头」。
        self.cols = int(os.environ.get("FAKE_TUI_COLS") or 80)
        self.committed = os.environ.get("FAKE_TUI_DRAFT", "")
        self.typed = ""
        # 光标 = text() 里的字符下标（Python 字符，不是显示列）。默认在末尾；编辑器键会移动它。
        # M17：收回键序的夹具判据必须能分辨「光标在哪」而不是只认尾部。
        self.cursor = len(self.committed)
        self.trailing = os.environ.get("FAKE_TUI_CURSOR_TRAILING", "0") == "1"
        self.cursor_top = os.environ.get("FAKE_TUI_CURSOR_TOP", "0") == "1"
        self.draft_on_paste = os.environ.get("FAKE_TUI_DRAFT_ON_PASTE", "")
        self.marker = int(os.environ.get("FAKE_TUI_MARKER") or 0)
        self.chars_marker = int(os.environ.get("FAKE_TUI_CHARS_MARKER") or 0)
        self.key_log = os.environ.get("FAKE_TUI_KEY_LOG") or ""
        self.break_ctrl_u = os.environ.get("FAKE_TUI_BREAK_CTRL_U", "0") == "1"
        self.stall_ms = int(os.environ.get("FAKE_TUI_PASTE_STALL_MS") or 0)
        self._stall = None   # (deadline, paste_n, k, idx)：半成品占位符的补全计划
        self.paste_n = 0
        self.static_footer = os.environ.get("FAKE_TUI_STATIC_FOOTER", "0") == "1"
        # V9-B5：TUI 吞掉 Enter（覆盖层/转义处理/重绘吞键）——输入框被清空，但消息从没进过
        # 对话区。「清空未提交」形状：旧判据（框空=已送达）在这里把消息报成已送达并删条目。
        self.eat_enter = os.environ.get("FAKE_TUI_EAT_ENTER", "0") == "1"
        self.log = os.environ.get("FAKE_TUI_SUBMIT_LOG", "/tmp/teamsmith-fake-tui.log")
        self.conversation: list[str] = []
        # 不支持 bracketed paste 的目标 TUI（规格里的 fallback 分支）：不发 DECSET 2004
        self.bracketed = os.environ.get("FAKE_TUI_NO_BRACKETED_PASTE", "0") != "1"
        # 逐字节读入时不能按字节 decode（多字节 UTF-8 会被拆成替换字符）：用增量解码器
        self.decoder = codecs.getincrementaldecoder("utf-8")("replace")

    # ------------------------------------------------------------------ 渲染
    def text(self) -> str:
        return self.committed + self.typed

    # ------------------------------------------------------------------ 编辑器模型
    def _set_text(self, s: str) -> None:
        """整体替换框内容；committed/typed 的旧切分只用于兼容（显示/提交都走 text()）。
        不碰光标：调用方在替换后自行把光标放到新位置（不变式 0 <= cursor <= len(text)）。"""
        k = min(len(self.committed), len(s))
        self.committed, self.typed = s[:k], s[k:]

    def _insert(self, s: str) -> None:
        """在光标处插入（打字/粘贴的模拟：真实编辑器就是插在光标前）。"""
        t = self.text()
        self._set_text(t[: self.cursor] + s + t[self.cursor :])
        self.cursor += len(s)

    def _line_start(self) -> int:
        return self.text().rfind("\n", 0, self.cursor) + 1

    def _line_end(self) -> int:
        e = self.text().find("\n", self.cursor)
        return len(self.text()) if e == -1 else e

    def _cursor_visual(self) -> tuple:
        """光标在**折行后的显示坐标** (行号, 显示列)。守卫是光标锚定的，夹具必须把光标画在真实
        编辑器会画的位置（长行折行后光标落到下一显示行）。"""
        s = self.text()
        before = s[: self.cursor]
        line_idx = before.count("\n")
        col = len(before) - (before.rfind("\n") + 1)
        lines = s.split("\n")
        row_idx = 0
        for i, line in enumerate(lines):
            if i >= line_idx:
                break
            row_idx += len(_wrap(line, self.cols))
        prefix = lines[line_idx][:col] if line_idx < len(lines) else ""
        vcol = sum(_cell_width(ch) for ch in prefix)
        return row_idx, vcol

    # ------------------------------------------------------------------ 更新横幅（M45）
    def banner_lines(self) -> list:
        """画在输入框上方的 pi 更新横幅（FAKE_TUI_BANNER）。形状取自真实现场帧
        （tests/frames/pi-0.85.1-update-banner.txt，真 pi 0.85.1）：
          整行 ─ 的 DynamicBorder → 两行配对头 → [release note：任意 markdown] → 尾行 → 整行 ─
        两个横幅都用**整行 ─、与输入框边框等宽** —— 这正是把旧判据带偏的地方。"""
        v = os.environ.get("FAKE_TUI_BANNER", "").strip().lower()
        if v in ("", "0", "no", "off"):
            return []
        rule = RULE * self.cols
        blocks = []
        if v in ("packages", "both"):
            blocks.append([rule, " Package Updates Available",
                           " Package updates are available. Run pi update --extensions",
                           " Packages:", " - pi-web-access", rule])
        if v in ("1", "pi", "note", "both"):
            b = [rule, " Update Available", " New version 0.86.0 is available. Run pi update"]
            if v in ("note", "both"):
                # release note 是任意 markdown：故意放一行「像半成品折叠占位符」的文字，
                # 证明判据不是靠内容白名单活着（真 note 可能更花）。
                b += ["", " - fixed a thing", " - [paste #1 +9", ""]
            b += [" Changelog: https://pi.dev/changelog", rule]
            blocks.append(b)
        if not blocks:   # 认不出来的取值：按版本横幅画（宁可画错也不要静默什么都不画）
            blocks = [[rule, " Update Available", " New version 0.86.0 is available. Run pi update",
                       " Changelog: https://pi.dev/changelog", rule]]
        lines = [""]
        for b in blocks:
            lines += b + [""]
        return lines

    def draw(self) -> None:
        body = self.text().split("\n")
        # 像真实 TUI 一样折行（不裁字）：超长行的尾巴出现在下一个可见行上
        shown = [r for line in body for r in _wrap(line, self.cols)]
        shown = shown[:3] + [""] * max(0, 3 - len(shown[:3]))
        # 像真实 TUI 一样打开 bracketed paste（DECSET 2004）：tmux 的 paste-buffer -p
        # 只有在 pane 请求过这个模式时才会真正加包装（tmux 3.7 手册）。没有它，
        # 三行粘贴就会被拆成三条提交 —— 这正是要拿它当证伪器的那条差异。
        out = [("\x1b[?2004h" if self.bracketed else ""), "\x1b[2J\x1b[H"]
        row = 1
        head = ["fixture TUI \u00b7 idle"]
        if not self.static_footer:
            for m in self.conversation[-3:]:
                head.append("> " + m.replace("\n", " \u23ce "))
        head.append("")
        blines = self.banner_lines()
        if blines and head and head[-1] == "":
            head.pop()   # 横幅自带前导空行（真帧：对话区/横幅/框之间各一行空行）
        for line in head:
            out.append(_clip(line, self.cols) + "\r\n")
            row += 1
        for line in blines:
            out.append(_clip(line, self.cols) + "\r\n")
            row += 1
        out.append(RULE * self.cols + "\r\n")
        row += 1
        rows = []
        for c in shown:
            rows.append(row)
            out.append(_clip(c, self.cols) + "\r\n")
            row += 1
        out.append(" fake-pi  Fake Pi  max ".ljust(self.cols) + "\r\n")
        out.append(RULE * self.cols + "\r\n")
        out.append("footer".ljust(self.cols) + "\r\n")
        n = len(body)
        if self.cursor_top:
            # V7-F1：光标停在内容区第一行（真实 Pi 里 Up 键把光标移到草稿上方的空行）
            crow, ccol = rows[0], 1
        elif self.text() == "":
            crow, ccol = rows[0], 1
        elif self.trailing:
            crow, ccol = rows[min(n, 3) - 1], 1
        else:
            vrow, vcol = self._cursor_visual()
            crow, ccol = rows[min(vrow, 2)], min(vcol, self.cols - 1) + 1
        out.append("\x1b[%d;%dH" % (crow, ccol))
        sys.stdout.write("".join(out))
        sys.stdout.flush()

    def submit(self) -> None:
        payload = self.text()
        with open(self.log, "a") as fh:
            fh.write("SUBMIT:" + payload.replace("\\", "\\\\").replace("\n", "\\n").replace("\r", "\\r") + "\n")
        self.conversation.append(payload)
        self._set_text("")
        self.cursor = 0

    # ------------------------------------------------------------------ 事件循环
    def _accept_paste(self, raw: bytes, final: bool = True) -> None:
        """一块 bracketed-paste 内容进框。FAKE_TUI_MARKER 打开时，整次粘贴超过阈值行数就
        折叠成一行占位符（真实 Pi v0.85.1：14 行文件 → `[paste #1 +15 lines]`，K = 换行数+1）。"""
        if not hasattr(self, "_paste_buf"):
            self._paste_buf = b""
        self._paste_buf += raw
        if not final:
            return
        text = _paste_text(self._paste_buf)
        self._paste_buf = b""
        nlines = text.count("\n")
        if self.chars_marker and len(text) > self.chars_marker and (not self.marker or nlines <= self.marker):
            # M24：真实 pi 的另一条折叠路径 —— 行数不多但字符多时按**字符数**折叠
            # （`[paste #N <chars> chars]`，字符 = 码点）。现场事故的敲门摘要正是这种形状：
            # 旧代码只认 `+K lines`，于是把我们的粘贴判成「混了别人的字」→ 不按 Enter。
            self.paste_n += 1
            self._insert(f"[paste #{self.paste_n} {len(text)} chars]")
        elif self.marker and nlines > self.marker:
            self.paste_n += 1
            if self.stall_ms:
                # V8-N3：真实 TUI 是异步渲染的——折叠占位符不是一帧画完的。先画一半
                # （`[paste #N +1`），stall_ms 之后才补全成完整占位符。
                idx = self.cursor
                self._insert(f"[paste #{self.paste_n} +1")
                self._stall = (time.monotonic() + self.stall_ms / 1000.0, self.paste_n, nlines + 1, idx)
            else:
                self._insert(f"[paste #{self.paste_n} +{nlines + 1} lines]")
        else:
            self._insert(text)

    TERM = b"\x1b[201~"

    @staticmethod
    def _prefix_len(buf: bytes, term: bytes) -> int:
        """buf 的末尾有多少字节可能是 term 的开头（终止符被拆包时不能吞掉它）。"""
        for k in range(min(len(buf), len(term) - 1), 0, -1):
            if buf[-k:] == term[:k]:
                return k
        return 0

    def run(self) -> None:
        self.draw()
        base = termios.tcgetattr(0)
        tty.setraw(0)
        paste = False
        pending = b""
        need_more = False
        try:
            while True:
                if self._stall is not None:
                    timeout = max(0.0, self._stall[0] - time.monotonic())
                    ready, _, _ = select.select([0], [], [], timeout)
                    if not ready:
                        # 补全半成品占位符（期间到达的键接在占位符后面，与真实 TUI 一致）。
                        # M17：收回路径可能在半成品还没画完时就把它删了（ctrl+a/ctrl+k 清空了框）
                        # ——那时不再补全，否则「已收回」的框会自己长出文字来。
                        _, n, k, idx = self._stall
                        partial = f"[paste #{n} +1"
                        t = self.text()
                        if t[idx : idx + len(partial)] == partial:
                            completed = f"[paste #{n} +{k} lines]"
                            delta = len(completed) - len(partial)
                            new_cursor = self.cursor + delta if self.cursor > idx else self.cursor
                            self._set_text(t[:idx] + completed + t[idx + len(partial) :])
                            self.cursor = max(0, min(new_cursor, len(self.text())))
                        else:
                            self.cursor = min(self.cursor, len(self.text()))
                        self._stall = None
                        self.draw()
                        continue
                data = os.read(0, 4096)
                if not data:
                    return
                pending += data
                need_more = False
                while pending and not need_more:
                    if paste:
                        end = pending.find(self.TERM)
                        if end != -1:
                            self._accept_paste(pending[:end])
                            pending = pending[end + len(self.TERM) :]
                            paste = False
                            self.draw()
                            continue
                        keep = self._prefix_len(pending, self.TERM)
                        if keep >= len(pending):
                            need_more = True
                            continue
                        chunk = pending[: len(pending) - keep]
                        pending = pending[len(pending) - keep :]
                        self._accept_paste(chunk, final=False)
                        self.draw()
                        continue
                    if pending.startswith(b"\x1b[200~"):
                        pending = pending[6:]
                        paste = True
                        if self.draft_on_paste:
                            # 「检查 → 粘贴」之间有人开始打字：人的字落在光标处（= 我们粘贴的落点
                            # 之前），随后我们的粘贴内容接在它后面
                            self._insert(self.draft_on_paste)
                            self.draft_on_paste = ""
                        continue
                    if pending[0:1] == b"\x1b":
                        # 其它控制序列：吞掉 ESC 加后续字节（夹具不解释它们）
                        pending = pending[2:] if len(pending) >= 2 else b""
                        continue
                    ch = pending[0:1]
                    pending = pending[1:]
                    if ch in (b"\r", b"\n"):
                        if self.text() != "":
                            if self.eat_enter:
                                # 吞掉 Enter：框清了，没有提交（对话区永远不会有这条）
                                self._set_text("")
                                self.cursor = 0
                            else:
                                self.submit()
                        self.draw()
                        continue
                    if ch == b"\x7f":
                        # backspace：删光标前一个字符；已在行首则把上一行并上来（Pi handleBackspace）
                        t = self.text()
                        ls = self._line_start()
                        if self.cursor > ls:
                            self._set_text(t[: self.cursor - 1] + t[self.cursor :])
                            self.cursor -= 1
                        elif ls > 0:
                            self._set_text(t[: ls - 1] + t[ls:])
                            self.cursor = ls - 1
                        self.draw()
                        continue
                    if ch == b"\x15":
                        _keylog(self, "C-u")
                        if self.break_ctrl_u:
                            continue
                        # ctrl+u = deleteToStartOfLine（Pi 0.85.1 默认键位；不是「清空整个框」）
                        # —— M24 实测：这是真实 pi 上**确实有效**的逐行清框键（收回用它）。
                        t = self.text()
                        ls = self._line_start()
                        if self.cursor > ls:
                            self._set_text(t[:ls] + t[self.cursor :])
                            self.cursor = ls
                        elif ls > 0:
                            self._set_text(t[: ls - 1] + t[ls:])
                            self.cursor = ls - 1
                        self.draw()
                        continue
                    if ch == b"\x01":
                        # M24 实测（真实 pi 0.85.1）：ctrl+a **不是**「光标到行首」——旧模型写错了。
                        # 产品不再用它；这里故意做成空操作：任何回退到旧键序的改动都会在夹具上现形。
                        _keylog(self, "C-a")
                        continue
                    if ch == b"\x0b":
                        # M24 实测：真实 pi 的 ctrl+k **不删到行尾**（旧模型写错了）：3 行展开的粘贴上
                        # 按 24 对 C-a/C-k 只掉最后一行、另两行仍留在框里。同样做成空操作。
                        _keylog(self, "C-k")
                        continue
                    if ch == b"\x05":
                        # ctrl+e = 光标到行尾
                        self.cursor = self._line_end()
                        self.draw()
                        continue
                    if ch == b"\x03":
                        # ctrl+c（M24 实测真实 pi）：框非空 → 一次性清空整个输入框；
                        # 框已空 → **退出**（题面写着 clear/exit）。这条危险语义留在夹具里：
                        # 任何「往空框发 C-c」的实现都会在这里把窗格打死，被断言抓住。
                        _keylog(self, "C-c")
                        if self.text():
                            self._set_text("")
                            self.cursor = 0
                            self.draw()
                        else:
                            break
                        continue
                    self._insert(self.decoder.decode(ch))
                    self.draw()
        finally:
            termios.tcsetattr(0, termios.TCSADRAIN, base)


if __name__ == "__main__":
    Tui().run()
