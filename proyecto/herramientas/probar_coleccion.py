"""Loopback contract fixture only. No real accounts, emails or credentials."""
import json
import subprocess
import sys
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

project = Path(__file__).resolve().parent.parent
templates = {d['id']: d for d in json.loads((project/'data/mazos_prueba.json').read_text(encoding='utf-8'))['mazos']}
users, inventories = {}, {}
lock = threading.Lock()
lost_response = True

class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_): pass
    def reply(self, code, payload):
        body = json.dumps(payload).encode()
        self.send_response(code)
        self.send_header('Content-Type','application/json')
        self.send_header('Content-Length',str(len(body)))
        self.end_headers()
        self.wfile.write(body)
    def do_POST(self):
        global lost_response
        data = json.loads(self.rfile.read(int(self.headers.get('Content-Length',0))))
        if self.headers.get('apikey') != 'sb_publishable_contract_fixture': return self.reply(401,{})
        email = data.get('email','')
        if self.path == '/auth/v1/otp':
            if email not in users:
                users[email] = {'id':f'00000000-0000-4000-8000-{len(users)+1:012d}','email':email,'user_metadata':data.get('data',{})}
            return self.reply(200,{})
        if self.path == '/auth/v1/verify':
            if data.get('token') != '123456': return self.reply(403,{})
            u=users[email]
            return self.reply(200,{'user':u,'access_token':'fixture-'+u['id'],'refresh_token':'refresh-'+u['id'],'expires_in':3600})
        if self.path == '/auth/v1/logout?scope=local': return self.reply(200,{})
        if self.path.startswith('/rest/v1/rpc/'):
            uid=self.headers.get('Authorization','').removeprefix('Bearer fixture-')
            if uid not in [u['id'] for u in users.values()]: return self.reply(401,{})
            with lock:
                inv=inventories.setdefault(uid,{'user_id':uid,'collection':{},'decks':[],'gift':None})
                if self.path.endswith('/aamix_claim_starter'):
                    old=inv['gift'] is not None
                    if not old:
                        d=templates[data['p_deck_id']]
                        inv['collection']={e['codigo']:e['cantidad'] for e in d['cartas']}
                        inv['decks']=[d]
                        inv['gift']={'deck_id':d['id']}
                    if lost_response:
                        lost_response=False
                        return self.reply(503,{})
                    return self.reply(200,dict(inv,already_claimed=old))
                return self.reply(200,inv)
        return self.reply(404,{})

server=ThreadingHTTPServer(('127.0.0.1',0),Handler)
threading.Thread(target=server.serve_forever,daemon=True).start()
command=[sys.argv[1],'--path',str(project),'--audio-driver','Dummy']
command+=['--rendering-method','gl_compatibility'] if '--gui' in sys.argv else ['--headless']
command+=['--script','res://tests/test_v09.gd','--log-file',str(project.parent.parent/'collection-test.log'),'--',f'--auth-test-url=http://127.0.0.1:{server.server_port}']
command += [a for a in sys.argv if a.startswith('--screenshots=')]
try:
    result=subprocess.run(command,timeout=120)
    print(json.dumps({'contract_only':True,'real_emails_sent':0,'return_code':result.returncode}))
    raise SystemExit(result.returncode)
finally:
    server.shutdown()
    server.server_close()
