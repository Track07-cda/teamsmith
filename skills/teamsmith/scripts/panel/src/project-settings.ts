import type { SettingsKey, SettingsPage, LimitsDraft } from './types.js'
import type { Strings } from './strings/index.js'

// Presentation references only. Values, permissions and validation remain in the command read.
export const MODEL_SETTINGS = ['TEAM_PM_MODEL', 'TEAM_MODEL_LIMITS'] as const
export const CHECK_SETTINGS = ['TEAM_PULSE_INTERVAL', 'TEAM_PULSE_MAX_RESTARTS', 'TEAM_UPDATE_CHECK'] as const
export const COMMAND_SETTINGS = ['TEAM_INSTALL_CMD', 'TEAM_GATES', 'TEAM_REVIEW_TIMEOUT'] as const
export const SELECTED_SETTINGS = [...MODEL_SETTINGS, ...CHECK_SETTINGS, ...COMMAND_SETTINGS]
export const effectiveSetting = (key: SettingsKey): string => key.set ? key.value : key.value || key.default
export const settingLabel = (s: Strings, key: string): string => s[`label_${key}`] || key
export const isSecondsSetting = (key: string): boolean => key === 'TEAM_PULSE_INTERVAL' || key === 'TEAM_REVIEW_TIMEOUT'
export function settingTiming(s: Strings, key: string, category?: string): string {
  if (category) return s.settingsNewTasks
  if (key === 'TEAM_PM_MODEL') return `${s.settingsAfterPmRestart} · team up --fresh-pm`
  if (key === 'TEAM_PULSE_INTERVAL') return `${s.settingsAfterPulseRestart} · team pulse restart`
  return ''
}
export function settingsPageTitle(s: Strings, page: SettingsPage): string {
  return page === 'commands' ? s.settingsCommands : page === 'records' ? s.settingsRecords
    : page === 'labels' ? s.settingsLabelTitle : page === 'label-form' ? s.settingsLabelEdit : page === 'label-delete' ? s.settingsLabelConfirmDelete
    : page === 'limits' ? s.label_TEAM_MODEL_LIMITS : page === 'rule' ? s.settingsRuleEdit : s.settingsViewTitle
}
// Keep every token, including repeated expressions, in its original position. The writer owns
// accepted patterns; this shape check only decides whether field editing can represent the source.
export function limitsTokens(value: string): string[] | null {
  const tokens = value.match(/\S+/g) ?? []
  return tokens.every((t) => /^\S+=\d+$/.test(t)) ? tokens : null
}
export function limitFields(token: string): [string, string] {
  const at = token.lastIndexOf('=')
  return [token.slice(0, at), token.slice(at + 1)]
}
export function withLimitsTokens(draft: LimitsDraft, tokens: string[]): LimitsDraft {
  return { ...draft, tokens, changed: tokens.join(' ') !== (limitsTokens(draft.original) ?? []).join(' ') }
}
export function limitsValue(draft: LimitsDraft): string {
  return draft.changed ? draft.tokens.join(' ') : draft.original
}
export function limitsDisplay(value: string, s: Strings): string[] {
  const tokens = limitsTokens(value)
  if (!tokens) return [value]
  if (!tokens.length) return [s.settingsUnfilled]
  return tokens.map((t) => {
    const [model, count] = limitFields(t)
    return `${s.settingsRuleModel}: ${model} · ${s.settingsRuleCount}: ${count === '0' ? s.settingsRuleUnlimited : count}`
  })
}
