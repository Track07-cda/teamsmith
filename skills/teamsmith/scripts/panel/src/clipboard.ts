// The clipboard probe (P20/B4): one small, injectable module.
//
// The console's `C-v` turns a clipboard image into a temporary file path. Everything the probe
// touches is a subprocess, so the one test seam is the executable name on `PATH` (design §8) — the
// fixtures put fakes first, and the headless sibling drives `readClipboard` through an injected
// runner. The probe is bounded by construction (1 s / 3 s / 50 MiB), runs only on a `C-v` press, and
// never deletes the file it writes.

import { randomUUID } from 'node:crypto'
import { spawn } from 'node:child_process'
import { writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'

/** One bounded subprocess: rc plus the stdout bytes; `null` = the executable does not exist. */
export interface ClipRun {
  stdout: Buffer
  rc: number
}

export type ClipboardRunner = (cmd: string, args: string[], timeoutMs: number) => Promise<ClipRun | null>

export type ClipboardRead =
  | { kind: 'image'; bytes: Buffer; mime: string }
  | { kind: 'text'; text: string }
  | null

/** The offered-type list answers within 1 s, the byte read within 3 s and 50 MiB (design §8). */
export const CLIPBOARD_LIST_TIMEOUT_MS = 1000
export const CLIPBOARD_READ_TIMEOUT_MS = 3000
export const CLIPBOARD_MAX_BYTES = 50 * 1024 * 1024

/** The four MIME types the panel accepts, and the extension the temporary file gets. */
export const IMAGE_MIME_EXT: Readonly<Record<string, string>> = {
  'image/png': 'png',
  'image/jpeg': 'jpg',
  'image/webp': 'webp',
  'image/gif': 'gif',
}

/** The extension for an accepted image MIME, or null when it is outside the four. */
export function imageExt(mime: string): string | null {
  return IMAGE_MIME_EXT[String(mime ?? '').trim().toLowerCase()] ?? null
}

/** The first accepted image type in an offered-type list, in the list's own order. */
export function pickImageMime(list: string): string | null {
  for (const raw of String(list ?? '').split('\n')) {
    const mime = raw.split(';')[0].trim().toLowerCase()
    if (mime && imageExt(mime)) return mime
  }
  return null
}

/**
 * The probe order (wayland first, X11 second): `wl-paste` is the primary tool — when it answers,
 * `xclip` is never called — and `xclip` is the fallback when `wl-paste` is missing or fails. Inside
 * one tool the image type wins; with no image the tool's text read is the fallback.
 */
export async function readClipboard(run: ClipboardRunner): Promise<ClipboardRead> {
  const wlTypes = await run('wl-paste', ['--list-types'], CLIPBOARD_LIST_TIMEOUT_MS)
  if (wlTypes && wlTypes.rc === 0) {
    const mime = pickImageMime(wlTypes.stdout.toString('utf8'))
    if (mime) {
      const img = await run('wl-paste', ['--type', mime, '--no-newline'], CLIPBOARD_READ_TIMEOUT_MS)
      if (img && img.rc === 0 && img.stdout.length > 0 && img.stdout.length <= CLIPBOARD_MAX_BYTES) {
        return { kind: 'image', bytes: img.stdout, mime }
      }
    }
    const text = await run('wl-paste', ['--no-newline', '--type', 'text'], CLIPBOARD_READ_TIMEOUT_MS)
    if (text && text.rc === 0 && text.stdout.length > 0) return { kind: 'text', text: text.stdout.toString('utf8') }
    return null
  }
  const xTypes = await run('xclip', ['-selection', 'clipboard', '-t', 'TARGETS', '-o'], CLIPBOARD_LIST_TIMEOUT_MS)
  if (xTypes && xTypes.rc === 0) {
    const mime = pickImageMime(xTypes.stdout.toString('utf8'))
    if (mime) {
      const img = await run('xclip', ['-selection', 'clipboard', '-t', mime, '-o'], CLIPBOARD_READ_TIMEOUT_MS)
      if (img && img.rc === 0 && img.stdout.length > 0 && img.stdout.length <= CLIPBOARD_MAX_BYTES) {
        return { kind: 'image', bytes: img.stdout, mime }
      }
    }
    const text = await run('xclip', ['-selection', 'clipboard', '-o'], CLIPBOARD_READ_TIMEOUT_MS)
    if (text && text.rc === 0 && text.stdout.length > 0) return { kind: 'text', text: text.stdout.toString('utf8') }
  }
  return null
}

/** The temporary path the paste writes: `${TMPDIR:-/tmp}/teamsmith-paste-<uuid>.<ext>`. */
export function pasteFilePath(mime: string, dir = process.env.TMPDIR || tmpdir(), uuid?: string): string | null {
  const ext = imageExt(mime)
  if (!ext) return null
  return join(dir, `teamsmith-paste-${uuid ?? randomUUID()}.${ext}`)
}

/**
 * Write the clipboard image bytes to the temporary path and return it. The panel never deletes the
 * file (the requirement) and the path is the whole edit the console makes.
 */
export function writePasteFile(bytes: Buffer, mime: string, dir?: string, uuid?: string): string | null {
  const file = pasteFilePath(mime, dir, uuid)
  if (!file) return null
  writeFileSync(file, bytes)
  return file
}

/**
 * The real runner: `spawn` with a hard timeout and a stdout cap. A missing executable resolves
 * `null`; a timeout kills the child and resolves `rc = 124` (never a hang), so a clipboard tool that
 * never answers cannot hold the console.
 */
export function createClipboardRunner(): ClipboardRunner {
  return (cmd, args, timeoutMs) =>
    new Promise((resolve) => {
      let child: ReturnType<typeof spawn>
      try {
        child = spawn(cmd, args, { stdio: ['ignore', 'pipe', 'ignore'] })
      } catch {
        resolve(null)
        return
      }
      const chunks: Buffer[] = []
      let size = 0
      let settled = false
      const finish = (rc: number | null): void => {
        if (settled) return
        settled = true
        clearTimeout(timer)
        resolve(rc === null ? null : { stdout: Buffer.concat(chunks), rc })
      }
      const kill = (): void => {
        try {
          child.kill('SIGKILL')
        } catch {
          /* already gone */
        }
      }
      const timer = setTimeout(() => {
        kill()
        finish(124)
      }, Math.max(1, timeoutMs))
      child.on('error', () => finish(null))
      child.stdout?.on('data', (data: Buffer) => {
        size += data.length
        if (size > CLIPBOARD_MAX_BYTES) {
          kill()
          finish(125)
          return
        }
        chunks.push(data)
      })
      child.on('close', (code) => finish(code ?? 1))
    })
}
