import type { Strings } from './strings/index.js'
import { sanitize } from './sanitize.js'

export interface LabelDefinition {
  name: string
  color: string
  weight: string
}
export const LABEL_FIELDS = ['name', 'color', 'weight'] as const
export type LabelField = (typeof LABEL_FIELDS)[number]
export type LabelWrite = { command: 'define'; value: LabelDefinition }
  | { command: 'edit'; name: string; changes: Partial<LabelDefinition> }
  | { command: 'delete'; name: string }
export type LabelOutcome = { result: 'ok' | 'unconfirmed' }
  | { result: 'rejected'; reason: 'duplicate' | 'not_found' | 'read_failed' | 'not_written' }
  | { result: 'rejected'; reason: 'invalid_field'; field: LabelField }
  | { result: 'rejected'; reason: 'in_use'; task_ids: string[] }
export type LabelCatalog = { state: 'loading' } | { state: 'failed' } | { state: 'ready'; rows: LabelDefinition[] }
export interface LabelSettings {
  catalog: LabelCatalog
  draft: { original: LabelDefinition | null; value: LabelDefinition } | null
  notice?: { command: LabelWrite['command']; outcome: LabelOutcome }
}

export const LABEL_COLORS = { blue: '#0969da', green: '#1a7f37', red: '#cf222e' } as const
export function labelColorName(s: Strings, color: string): string {
  switch (color) {
    case LABEL_COLORS.blue: return s.settingsLabelBlue
    case LABEL_COLORS.green: return s.settingsLabelGreen
    case LABEL_COLORS.red: return s.settingsLabelRed
    default: return color ? s.settingsLabelCustomColor : s.settingsUnfilled
  }
}
export function labelFieldName(s: Strings, field: LabelField): string {
  return field === 'name' ? s.settingsLabelName : field === 'color' ? s.settingsLabelColor : s.settingsLabelWeight
}

// The CLI is authoritative. Validate its output shape, not the draft's admissibility.
export function readLabelRows(output: string): LabelCatalog {
  if (!output) return { state: 'ready', rows: [] }
  if (!output.endsWith('\n')) return { state: 'failed' }
  const seen = new Set<string>()
  const rows: LabelDefinition[] = []
  for (const row of output.slice(0, -1).split('\n')) {
    const [name, color, weight, ...extra] = row.split('\t')
    if (!name || name.trim() !== name || sanitize(name) !== name || seen.has(name)
      || !/^#[\da-f]{6}$/.test(color ?? '') || !/^(?:0|-?[1-9]\d*)$/.test(weight ?? '') || extra.length) return { state: 'failed' }
    seen.add(name)
    rows.push({ name, color, weight })
  }
  return { state: 'ready', rows }
}

export function labelWriteArgs(write: LabelWrite): string[] {
  const args = [write.command, '--json']
  if (write.command === 'define') args.push('--color', write.value.color, '--weight', write.value.weight)
  if (write.command === 'edit') for (const field of LABEL_FIELDS) {
    const value = write.changes[field]
    if (value !== undefined) args.push(`--${field}`, value)
  }
  return [...args, '--', write.command === 'define' ? write.value.name : write.name]
}

export function labelOutcome(rc: number, output: string, completed: boolean): LabelOutcome {
  const unknown = { result: 'unconfirmed' } as const
  if (!completed) return unknown
  let value: Record<string, unknown>
  // No JSON, a partial result or extra stdout is not a receipt from the owning command.
  try { value = JSON.parse(output) } catch { return unknown }
  if (!value || typeof value !== 'object' || Array.isArray(value)) return unknown
  if (rc === 0 && value.result === 'ok' && Object.keys(value).length === 1) return { result: 'ok' }
  if (rc !== 1 && rc !== 2 || value.result !== 'rejected') return unknown
  switch (value.reason) {
    case 'duplicate': case 'not_found': case 'read_failed': case 'not_written':
      return Object.keys(value).length === 2 ? { result: 'rejected', reason: value.reason } : unknown
    case 'invalid_field':
      return LABEL_FIELDS.some((field) => field === value.field) && Object.keys(value).length === 3
        ? { result: 'rejected', reason: value.reason, field: value.field as LabelField } : unknown
    case 'in_use':
      return Array.isArray(value.task_ids) && value.task_ids.length > 0
        && value.task_ids.every((id) => typeof id === 'string' && id.length > 0) && Object.keys(value).length === 3
        ? { result: 'rejected', reason: value.reason, task_ids: value.task_ids } : unknown
    default: return unknown
  }
}

export function labelNotice(s: Strings, notice: NonNullable<LabelSettings['notice']>): string {
  const { command, outcome } = notice
  if (outcome.result !== 'rejected') return outcome.result === 'ok'
    ? command === 'delete' ? s.settingsLabelDeleted : s.settingsLabelSaved
    : command === 'delete' ? s.settingsLabelDeleteUnconfirmed : s.settingsLabelSaveUnconfirmed
  switch (outcome.reason) {
    case 'duplicate': return s.settingsLabelDuplicate
    case 'not_found': return s.settingsLabelNotFound
    case 'read_failed': return s.settingsLabelReadFailed
    case 'not_written': return s.settingsLabelNotWritten
    case 'in_use': return `${s.settingsLabelInUse} ${outcome.task_ids.map(sanitize).join(', ')}`
    case 'invalid_field': return outcome.field === 'weight' ? s.settingsLabelInvalidWeight
      : outcome.field === 'name' ? s.settingsLabelInvalidName : s.settingsLabelInvalidColor
  }
}
