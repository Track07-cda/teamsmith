import { readFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';

// One line per candidate, in preference order. Bash validates the fields each candidate would fill.
function singleLine(value) {
  return typeof value === 'string' && value !== '' && !/[\0\n\r\v\f\u0085\u2028\u2029\p{Cs}]/u.test(value);
}

function savedModels() {
  const home = homedir();
  const dir = process.env.PI_CODING_AGENT_DIR || join(home, '.pi', 'agent');
  const userDir = dir === '~' ? home : dir.startsWith('~/') ? join(home, dir.slice(2)) : dir;
  let settings;
  try {
    settings = JSON.parse(readFileSync(join(userDir, 'settings.json'), 'utf8'));
  } catch {
    // An unreadable or invalid settings file supplies no default; never print its contents or parser error.
    return [];
  }
  const { defaultProvider: provider, defaultModel: model, modelThinkingLevels, defaultThinkingLevel } = settings ?? {};
  if (!singleLine(provider) || provider.includes('/') || !singleLine(model)) return [];
  const base = `${provider}/${model}`;
  if (model.includes(':')) return [base];
  const levels = new Set([modelThinkingLevels?.[base], defaultThinkingLevel]);
  return [...levels].filter(level => singleLine(level) && !level.includes(':'))
    .map(level => `${base}:${level}`).concat(base);
}

for (const candidate of savedModels()) console.log(candidate);
