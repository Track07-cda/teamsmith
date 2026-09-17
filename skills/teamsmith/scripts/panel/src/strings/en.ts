// English interface strings.
//
// Every rendered string comes from a table; see zh.ts for the contract. The English table is a
// translation, never a second source of truth: the key set, placeholders and value shapes are
// asserted equal to the Chinese table by `tests/panel-strings.mjs`.

/** @type {import('./types.js').Strings} */
export const en = {
  // Title band and status banner
  appTitle: 'teamsmith pulse',
  patrolLabel: 'patrol',
  patrolSeconds: 'patrol {n}s',
  standbyLabel: 'standby',
  standbyOn: 'standby on (reason: {reason})',
  standbyOff: 'standby off',
  standbyDash: 'standby —',
  pmLabel: 'PM',
  pendingLabel: 'pending',
  pendingNone: 'none',
  outboxLabel: 'deferred',
  outboxHeldSuffix: ' (held {n})',
  capacityLabel: 'capacity',
  capacityRam: 'RAM {mb}',
  capacitySwap: 'swap {mb}',
  capacityAgents: '{n} more agents fit',
  dash: '—',

  // Project progress
  progressLabel: 'progress',
  progressTasks: 'tasks {parts}',
  taskTodo: 'todo',
  taskWip: 'wip',
  taskReview: 'review',
  taskBlocked: 'blocked',
  taskDone: 'done',
  progressChanges: 'changes {n}',
  progressSpecs: 'specs {specs} · {reqs} requirements',
  progressDecisions: 'decisions {n}',
  countPair: '{label} {n}',

  // Recent deliveries
  deliveriesLabel: 'recent deliveries',
  deliveryLine: '{id} · {agent} · {time}',
  deliveriesEmpty: '(no deliveries yet)',

  // Agent table
<<<<<<< HEAD
  agentsHeader: 'AGENT',
=======
  agentsHeader: 'agent',
>>>>>>> task/P14-apply-pulse-console-b3-i18n-
  tableState: 'state',
  tableTask: 'task',
  tableBranch: 'branch',
  tableSession: 'session',
  agentRunning: 'running',
  agentExited: 'exited',
  agentAbsent: 'no window',
  pmRunning: 'running',
  pmStarting: 'starting',
  pmAbsent: 'not running',
  pmForeign: 'another project holds it',
  pmUnknown: 'not a PM process',
  agentEmpty: '(no agents)',

  // Activity and recent actions
  activityHeading: 'activity (windows running in this session)',
  activitySource: 'source {path}',
  activityEmpty: '(no session activity)',
  recentHeading: 'recent actions',
  recentEmpty: '(no actions recorded yet)',

  // Pages and tabs
  pageOverview: 'overview',
  pageWork: 'work',
  pageMessages: 'messages & logs',
  pageTab: ' {name} ',
  pageTabActive: '▸{name}◂',

  // Board
  boardHeading: 'board',
  boardHeadingCount: 'board ({n})',
  boardCounts: '{todo} todo · {wip} wip · {review} review · {blocked} blocked · {done} done',
  boardDoneCollapsed: '… {n} older done/dropped rows folded',
  boardEmpty: '(board is empty)',

  // Changes and specs
  changesHeading: 'active changes',
  changesHeadingCount: 'active changes ({n})',
  changeLine: '{done}/{total} · {phase}',
  changePhaseExplore: 'explore',
  changePhasePropose: 'propose',
  changePhaseApply: 'apply',
  changePhaseVerify: 'verify',
  changePhaseArchive: 'archive',
  specsHeading: 'specs',
  specsCount: '{specs} specs · {reqs} requirements',
  specsLine: '{name}  {n}',

  // Decisions
  decisionsHeading: 'recent decisions',
  decisionsCountSuffix: '{n} total',
  decisionsEmpty: '(no decisions recorded)',

  // Deferred queue
  queueHeading: 'deferred queue',
  queueHeadingCount: 'deferred queue {queued} (held {held})',
  queueLine: '{index}. [{state}] {name} · {age}',
  queueStateQueued: 'queued',
  queueStateHeld: 'held',
  queueHeldReason: 'held reason: {reason}',
  queueViewHint: 'Enter to view the full text',
  queueBackHint: 'Esc back to the list',
  queueEmpty: '(queue is empty)',
  queueFullHeading: 'full text: {name}',
  queueMeta: 'kind={kind} target={target} from={from}',

  // Inbox and threads
  inboxHeading: 'inbox and threads',
  inboxLine: 'inbox {inbox} · thread {thread} · {age}',
  inboxEmpty: '(no inbox/thread files)',

  // Patrol log and capacity trend
  patrolHeading: 'patrol log',
  patrolEmpty: '(no patrol records yet)',
  trendHeading: 'capacity trend',
  trendLine: 'RAM {mb} · swap {swap}',

  // Health
  healthHeading: 'health',
  healthLine: 'skill {version} · doctor {doctor} · last gates {gates}',
  healthDoctorOk: 'ok',
  healthDoctorWarn: 'warn',
  healthDoctorFail: 'fail',
  healthDoctorNA: 'unavailable',

  // Settings overlay
  settingsTitle: 'settings',
  settingsCursor: '›',
  prefLang: 'language',
  prefDefaultPage: 'default page',
  prefActivity: 'activity column',
  prefMouse: 'mouse',
  prefDensity: 'density',
  toggleOn: 'on',
  toggleOff: 'off',
  langNameZh: '中文',
  langNameEn: 'English',
  densityComfortable: 'comfortable',
  densityCompact: 'compact',
  settingsHint: '↑/↓ select · Enter toggle · Esc/, close',

  // Global keys (footer)
  keyCompose: 'm compose',
  keyFlush: 'f flush',
  keyStandby: 's standby',
  keySettings: ', settings',
  keyPages: 'Tab/1-3 pages',
  keyScroll: '↑/↓ scroll',
  keyQuit: 'q collapse',

  // Input line and receipts
  composeHint: 'Enter send · Esc cancel (draft kept) · C-e editor',
  composeReasonHint: 'Enter standby · Esc cancel',
<<<<<<< HEAD
=======
  composeTitle: 'Message',
  composeStandbyTitle: 'Standby reason',
>>>>>>> task/P14-apply-pulse-console-b3-i18n-
  receiptDelivered: '✓ delivered to the PM · delivered',
  receiptQueued: '… queued (the PM is typing) · queued',
  receiptHeld: '! held (copy under state/outbox/held/) · held',
  receiptError: '✗ delivery unconfirmed · {detail}',
  flushOk: '✓ flush · {detail}',
  flushFail: '✗ flush failed · {detail}',
  standbyOkOn: '✓ standby on (reason: {reason})',
  standbyOkOff: '✓ standby off',
  standbyFail: '✗ standby failed · {detail}',
  busySend: 'sending…',
  busyAction: 'working…',
  editorClosed: 'editor closed: draft {n} chars',
  noTeamCli: 'teamsmith CLI not found',
  sendUnconfirmed: 'delivery unconfirmed (no result token)',
  queuePending: 'the queue still holds entries',
}
