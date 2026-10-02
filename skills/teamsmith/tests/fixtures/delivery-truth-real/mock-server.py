#!/usr/bin/env python3
"""Deterministic loopback OpenAI SSE endpoint; no external model or credentials."""
import http.server, json, os, time
from pathlib import Path
out = Path(os.environ['P138_LOG'])
class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, *args): pass
    def do_POST(self):
        req = json.loads(self.rfile.read(int(self.headers['Content-Length'])))
        msgs = req.get('messages', [])
        with (out / 'requests.jsonl').open('a') as f:
            f.write(json.dumps({'ts':time.time(), 'model':req.get('model'), 'messages':msgs}, ensure_ascii=False)+'\n')
        users = [str(m.get('content','')) for m in msgs if m.get('role') == 'user']
        seed = users and 'P138-SEED-DIRTY' in users[-1]
        tool_done = msgs and msgs[-1].get('role') == 'tool'
        self.send_response(200); self.send_header('Content-Type','text/event-stream'); self.end_headers()
        def send(delta, finish=None):
            chunk = {'id':'p138', 'object':'chat.completion.chunk', 'created':int(time.time()), 'model':'p138',
                     'choices':[{'index':0,'delta':delta,'finish_reason':finish}]}
            self.wfile.write(('data: '+json.dumps(chunk)+'\n\n').encode()); self.wfile.flush()
        send({'role':'assistant'})
        if seed and not tool_done:
            send({'tool_calls':[{'index':0,'id':'dirty-write','type':'function','function':{
                'name':'write','arguments':json.dumps({'path':'README' if os.environ.get('P138_TRACKED') == '1' else 'leftover.txt','content':'P138 uncommitted evidence\n'})}}]})
            send({}, 'tool_calls')
        else:
            send({'content':'P138-ACK settled; no commit performed.'}); send({},'stop')
        self.wfile.write(b'data: [DONE]\n\n'); self.wfile.flush()
http.server.ThreadingHTTPServer(('127.0.0.1',18738), Handler).serve_forever()
