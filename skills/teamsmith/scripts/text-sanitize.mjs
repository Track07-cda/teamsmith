// Shared terminal text sanitization; keep visible text around removed control bytes.
const OSC_RE = /\u001B\][^\u0007\u001B]*(?:\u0007|\u001B\\)/g
const CSI_RE = /\u001B\[[0-?]*[ -/]*[@-~]/g
const C1_CSI_RE = /\u009B[0-?]*[ -/]*[@-~]/g
const ESC2_RE = /\u001B[@-Z\\-_]/g
const CTRL_RE =
  /[\u0000-\u0008\u000B-\u001F\u007F-\u009F\u200B\u200E\u200F\u202A-\u202E\u2060\u2066-\u2069\uFEFF]/g

/** Strip control sequences but keep the text around them. */
export function sanitize(value) {
  return String(value ?? '')
    .replace(OSC_RE, '')
    .replace(CSI_RE, '')
    .replace(C1_CSI_RE, '')
    .replace(ESC2_RE, '')
    .replace(CTRL_RE, '')
}
