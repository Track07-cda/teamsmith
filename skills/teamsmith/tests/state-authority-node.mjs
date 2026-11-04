// state-authority-node.mjs — P406 夹具的 Node 侧写入者。
// 生产 API 就是 scripts/state-authority.mjs 的 request()：Node 与 Bash 走同一条实现、同一把 flock、
// 同一套身份规则（项目由 cwd 解析）。这里只负责两件事：
//   <project-root> <state-root> <count>   并发分配 count 个序号并打印
//   --foreign <main-root> <state-root>    用「继承来的主根」调用一次（身份拒绝用例）
// STATE_AUTHORITY_HELPER 让红侧夹具用同一份写入者驱动**变异副本**（默认就是产品实现）。
const { request } = await import(process.env.STATE_AUTHORITY_HELPER ?? '../scripts/state-authority.mjs');

const argv = process.argv.slice(2);
if (argv[0] === '--foreign') {
  const [, mainRoot, stateRoot] = argv;
  if (!mainRoot || !stateRoot) {
    process.stderr.write('usage: --foreign <main-root> <state-root>\n');
    process.exit(2);
  }
  try {
    await request({ mainRoot, stateRoot }, { op: 'read' });
  } catch (e) {
    process.stderr.write(String(e.message) + '\n');
    process.exit(1);
  }
  process.exit(0);
}

const [mainRoot, stateRoot, count] = argv;
if (!mainRoot || !stateRoot || !count) {
  process.stderr.write('usage: state-authority-node.mjs <project-root> <state-root> <count>\n');
  process.exit(2);
}
// 红侧判据要的是「同一瞬间开始写」：夹具用一个 go 文件把 N 个写入者对齐到同一微秒，
// 否则 Node 冷启动的抖动足以把竞态窗口错开（那会让缺锁的变异体偶尔看不出来）。
if (process.env.STATE_AUTHORITY_BARRIER) {
  const sleep = ms => Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, ms);
  const { existsSync } = await import('node:fs');
  while (!existsSync(process.env.STATE_AUTHORITY_BARRIER)) sleep(1);
}
const values = [];
for (let i = 0; i < Number(count); i++) {
  const result = await request({ mainRoot, stateRoot }, { op: 'allocate', kind: 'reminder' });
  values.push(result.value);
}
process.stdout.write(values.join('\n') + '\n');
