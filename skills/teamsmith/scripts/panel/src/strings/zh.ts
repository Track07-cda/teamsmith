// 中文界面字符串表（默认语言）。
//
// 所有上屏文本都必须从这里取：`tests/panel-strings.mjs` 会断言两张表的键集合、占位符集合与
// 非空值完全一致，并扫描 `src/**`（strings/ 除外）确保没有残留的中文正文。
// 本文件是纯 ESM（只有注释与 JSDoc），断言脚本会把它复制成 .mjs 用任意 JS 运行时导入。

/** @type {import('./types.js').Strings} */
export const zh = {
  // 标题与状态横幅
  appTitle: 'teamsmith pulse',
  patrolLabel: '巡检',
  patrolSeconds: '巡检 {n}s',
  standbyLabel: '待命',
  standbyOn: '待命 on（原因：{reason}）',
  standbyOff: '待命 off',
  standbyDash: '待命 —',
  pmLabel: 'PM',
  pendingLabel: '待办',
  pendingNone: '无',
  outboxLabel: '延后投递',
  outboxHeldSuffix: '（扣住 {n}）',
  capacityLabel: '容量',
  capacityRam: 'RAM {mb}',
  capacitySwap: 'swap {mb}',
  capacityAgents: '可再加 {n} 个 agent',
  dash: '—',

  // 项目进度
  progressLabel: '项目进度',
  progressTasks: '任务 {parts}',
  taskTodo: '待办',
  taskWip: '进行',
  taskReview: '待复验',
  taskBlocked: '阻塞',
  taskDone: '完成',
  progressChanges: '变更 {n}',
  progressSpecs: '规格 {specs} 项 · {reqs} 条需求',
  progressDecisions: '决策 {n}',
  countPair: '{label} {n}',

  // 最近交付
  deliveriesLabel: '最近交付',
  deliveryLine: '{id} · {agent} · {time}',
  deliveriesEmpty: '（还没有交付记录）',

  // agent 表
  agentsHeader: 'AGENT',
  tableState: '状态',
  tableTask: '任务',
  tableBranch: '分支',
  tableSession: '会话',
  agentRunning: '在跑',
  agentExited: '已退出',
  agentAbsent: '无窗口',
  pmRunning: '在运行',
  pmStarting: '正在启动',
  pmAbsent: '未在跑',
  pmForeign: '别的项目占着',
  pmUnknown: '非 PM 进程',
  agentEmpty: '（没有 agent）',

  // 活动与最近动作
  activityHeading: '活动（仅本 session 在跑的窗口）',
  activitySource: '源 {path}',
  activityEmpty: '（没有会话活动）',
  recentHeading: '最近动作',
  recentEmpty: '（还没有动作记录）',

  // 页面与页签
  pageOverview: '总览',
  pageWork: '工作',
  pageMessages: '消息与日志',
  pageTab: ' {name} ',
  pageTabActive: '▸{name}◂',

  // 看板
  boardHeading: '任务看板',
  boardHeadingCount: '任务看板 ({n})',
  boardCounts: '{todo} 待办 · {wip} 进行 · {review} 待复验 · {blocked} 阻塞 · {done} 完成',
  boardDoneCollapsed: '… 其余 {n} 条 done/dropped 收起',
  boardEmpty: '（看板为空）',

  // 变更与规格
  changesHeading: '活动变更',
  changesHeadingCount: '活动变更 ({n})',
  changeLine: '{done}/{total} · {phase}',
  changePhaseExplore: '探索',
  changePhasePropose: '提案',
  changePhaseApply: '实施',
  changePhaseVerify: '验证',
  changePhaseArchive: '归档',
  specsHeading: '规格',
  specsCount: '{specs} 项 · {reqs} 条需求',
  specsLine: '{name}  {n}',

  // 决策
  decisionsHeading: '最近决策',
  decisionsCountSuffix: '共 {n} 条',
  decisionsEmpty: '（没有决策记录）',

  // 延后队列
  queueHeading: '延后队列',
  queueHeadingCount: '延后队列 {queued}（扣住 {held}）',
  queueLine: '{index}. [{state}] {name} · {age}',
  queueStateQueued: '排队',
  queueStateHeld: '滞留',
  queueHeldReason: '扣住原因：{reason}',
  queueViewHint: 'Enter 看全文',
  queueBackHint: 'Esc 返回列表',
  queueEmpty: '（队列为空）',
  queueFullHeading: '条目全文：{name}',
  queueMeta: 'kind={kind} target={target} from={from}',

  // 收件箱与线程
  inboxHeading: '收件箱与线程',
  inboxLine: '收件箱 {inbox} 条 · 线程 {thread} 条 · {age}',
  inboxEmpty: '（没有收件箱/线程记录）',

  // 巡检日志与容量趋势
  patrolHeading: '巡检日志',
  patrolEmpty: '（还没有巡检记录）',
  trendHeading: '容量趋势',
  trendLine: 'RAM {mb} · swap {swap}',

  // 健康
  healthHeading: '健康',
  healthLine: '技能 {version} · doctor {doctor} · 上次门禁 {gates}',
  healthDoctorOk: 'ok',
  healthDoctorWarn: 'warn',
  healthDoctorFail: 'fail',
  healthDoctorNA: '不可用',

  // 设置浮层
  settingsTitle: '设置',
  settingsCursor: '›',
  prefLang: '语言',
  prefDefaultPage: '默认页面',
  prefActivity: '活动列',
  prefMouse: '鼠标',
  prefDensity: '密度',
  toggleOn: '开',
  toggleOff: '关',
  langNameZh: '中文',
  langNameEn: 'English',
  densityComfortable: '舒适',
  densityCompact: '紧凑',
  settingsHint: '↑/↓ 选择 · Enter 切换 · Esc/, 关闭',

  // 全局键位（页脚）
  keyCompose: 'm 写信',
  keyFlush: 'f 冲刷',
  keyStandby: 's 待命',
  keySettings: ', 设置',
  keyPages: 'Tab/1-3 翻页',
  keyScroll: '↑/↓ 滚动',
  keyQuit: 'q 收起',

  // 输入行与回执
  composeHint: 'Enter 发送 · Esc 取消（保留草稿）· C-e 编辑器',
  composeReasonHint: 'Enter 进入待命 · Esc 取消',
  receiptDelivered: '✓ 已送达 PM · delivered',
  receiptQueued: '… 已入队（PM 的输入框在忙）· queued',
  receiptHeld: '! 滞留（副本在 state/outbox/held/）· held',
  receiptError: '✗ 投递未确认 · {detail}',
  flushOk: '✓ 冲刷 · {detail}',
  flushFail: '✗ 冲刷失败 · {detail}',
  standbyOkOn: '✓ 待命 on（原因：{reason}）',
  standbyOkOff: '✓ 待命 off',
  standbyFail: '✗ 待命失败 · {detail}',
  busySend: '发送中…',
  busyAction: '执行中…',
  editorClosed: '编辑器已关闭：草稿 {n} 字符',
  noTeamCli: '找不到 teamsmith CLI',
  sendUnconfirmed: '投递未确认（没有拿到结果码）',
  queuePending: '队列仍有条目未投递',
}
