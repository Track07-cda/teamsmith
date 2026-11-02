#!/usr/bin/env node
// P380 · print the path of pi's own skill parser inside an installed package tree.
//
//   node ci/pi-skills-path.mjs <installed-package-root>
//
// The gate image points PI_DIST at this module because `tests/skill-load.mjs` imports pi's parser
// (a global install is not resolvable from the mounted checkout). The module lived at
// `dist/core/skills.js` when the image was pinned to 0.86.0; hardcoding that path would make a
// future layout move look like "pi's parser is missing" and degrade the fixture to a skip. So the
// build walks the installed package, imports every `skills.js` it finds, and prints the one that
// exports the two functions the fixture uses. A release that stops exporting them fails the image
// build here, naming the candidates, instead of silently stopping the check.
import { readdirSync } from 'node:fs'
import { join } from 'node:path'
import { pathToFileURL } from 'node:url'

const root = process.argv[2]
if (!root) {
  console.error('usage: pi-skills-path.mjs <installed-package-root>')
  process.exit(2)
}
const want = ['loadSkillsFromDir', 'formatSkillsForPrompt']
const found = []
;(function walk(dir) {
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const p = join(dir, entry.name)
    if (entry.isDirectory()) walk(p)
    else if (entry.name === 'skills.js') found.push(p)
  }
})(root)
for (const p of found) {
  try {
    const mod = await import(pathToFileURL(p).href)
    if (want.every((k) => typeof mod[k] === 'function')) {
      console.log(p)
      process.exit(0)
    }
  } catch (err) {
    // An import error on a candidate is expected while searching (other skills.js files may need a
    // runtime context); it is printed so a total failure is never reported without the reasons.
    console.error(`${p}: ${err.message}`)
  }
}
console.error(`no module under ${root} exports ${want.join(' + ')}; candidates: ${found.join(', ') || 'none'}`)
process.exit(1)
