import { appendFileSync } from 'node:fs';
export default function (pi: any) {
  const file = process.env.P138_EVENTS!;
  const log = (event: string, ctx: any, extra: any = {}) => appendFileSync(file, JSON.stringify({
    ts: new Date().toISOString(), event, cwd: ctx.cwd, idle: ctx.isIdle(),
    editor: ctx.hasUI ? ctx.ui.getEditorText() : null, ...extra,
  }) + '\n');
  let timer: any; let last: string | undefined;
  pi.on('session_start', (_e: any, ctx: any) => {
    log('session_start', ctx);
    timer = setInterval(() => {
      const text = ctx.ui.getEditorText();
      if (text !== last) { last = text; log('editor', ctx); }
    }, 100);
  });
  pi.on('before_agent_start', (e: any, ctx: any) => log('before_agent_start', ctx, {prompt:e.prompt}));
  pi.on('message_end', (e: any, ctx: any) => log('message_end', ctx, {message:e.message}));
  pi.on('agent_settled', (_e: any, ctx: any) => log('agent_settled', ctx));
  pi.on('session_shutdown', (_e: any, ctx: any) => { clearInterval(timer); log('session_shutdown', ctx); });
}
