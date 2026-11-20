"""Local UI/HTTP contract fixture. Never sends real email or changes Supabase."""
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from datetime import date, timedelta
import json
import subprocess
import sys
import threading
import uuid

project=Path(__file__).resolve().parent.parent
templates={d['id']:d for d in json.loads((project/'data/mazos_prueba.json').read_text(encoding='utf-8'))['mazos']}
maago=json.loads((project/'tests/fixtures/mazos_legacy.json').read_text(encoding='utf-8'))['mazos'][0]
templates['maago']=dict(maago,id='maago',nombre='Mazo Maagover',portada='0108')
girabl=next(d for d in json.loads((project/'tests/fixtures/mazos_legacy.json').read_text(encoding='utf-8'))['mazos'] if d['id']=='usuario_girabl')
templates['girabl']=dict(girabl,id='girabl',nombre='Mazo Girabl',portada='0104')
catalog={c['codigo']:c for c in json.loads((project/'data/catalogo_edicion_1.json').read_text(encoding='utf-8'))['cartas']}
promo_codes={'P3RI':('01a',3),'B1G0T3S':('01b',3),'SI2TYA':('01c',1),'CHANCHULINES':('01d',1),'TORNEOAAMIX1':('01e',1)}
users={}
states={}
receipts={}
openings={}
aliases={}
mission_awards={}
lock=threading.Lock()
lose_open_reply=True
lose_redeem_reply=True
lose_avatar_reply=True
lose_ack_reply=True

def state(uid):
    if uid not in states:
        missions=[{'id':id,'title':title,'scope':scope,'day':date.today().isoformat() if scope=='daily' else None,'timezone':'America/Santiago','progress':0,'target':target,'claimed':False,'reward_packs':packs} for id,title,scope,target,packs in [('play_one','Juega 1 partida','daily',1,1),('win_one','Gana 1 partida','lifetime',1,1),('play_ten','Juega 10 partidas','lifetime',10,3),('win_ten','Gana 10 partidas','lifetime',10,5)]]
        challenges=[{'stage':i+1,'deck_id':id,'title':templates[id]['nombre'],'reward_packs':packs,'unlocked':i==0,'completed':False,'reward_claimed':False} for i,(id,packs) in enumerate([('papito',1),('flaan',1),('kajido',1),('maago',2),('girabl',3)])]
        states[uid]={'user_id':uid,'collection':{},'decks':[],'gift':None,'profile':{'avatar_code':None},'packs':0,'mission':missions[0],'missions':missions,'challenges':challenges,'pending_opening':None,'redeemed_codes':[]}
    return states[uid]
def award(inv, deck):
    inv['decks'].append(templates[deck])
    for e in templates[deck]['cartas']:
        inv['collection'][e['codigo']]=inv['collection'].get(e['codigo'],0)+e['cantidad']

class Handler(BaseHTTPRequestHandler):
    def log_message(self,*_): pass
    def reply(self,code,payload):
        body=json.dumps(payload).encode()
        self.send_response(code)
        self.send_header('Content-Type','application/json')
        self.send_header('Content-Length',str(len(body)))
        self.end_headers()
        self.wfile.write(body)
    def do_POST(self):
        global lose_open_reply,lose_redeem_reply,lose_avatar_reply,lose_ack_reply
        data=json.loads(self.rfile.read(int(self.headers.get('Content-Length',0))))
        if self.headers.get('apikey')!='sb_publishable_contract_fixture':return self.reply(401,{})
        email=data.get('email','')
        if self.path=='/auth/v1/otp':
            users.setdefault(email,{'id':str(uuid.uuid4()),'email':email,'user_metadata':data.get('data',{})})
            return self.reply(200,{})
        if self.path=='/auth/v1/verify':
            if email not in users or data.get('token')!='123456': return self.reply(403,{})
            u=users[email]
            return self.reply(200,{'user':u,'access_token':'fixture-'+u['id'],'refresh_token':'refresh-'+u['id'],'expires_in':3600})
        if self.path=='/auth/v1/logout?scope=local':return self.reply(200,{})
        uid=self.headers.get('Authorization','').removeprefix('Bearer fixture-')
        if uid not in [u['id'] for u in users.values()]:return self.reply(401,{})
        with lock:
            inv=state(uid)
            method=self.path.rsplit('/',1)[-1]
            extra={}
            if method=='aamix_claim_starter':
                extra['already_claimed']=inv['gift'] is not None
                if inv['gift'] is None:
                    award(inv,data['p_deck_id'])
                    inv['gift']={'deck_id':data['p_deck_id']}
            elif method=='aamix_set_avatar':
                if data['p_code'] not in ['0105','0108']:return self.reply(400,{'message':'AAMIX_INVALID_AVATAR'})
                if lose_avatar_reply:
                    lose_avatar_reply=False
                    return self.reply(503,{})
                inv['profile']['avatar_code']=data['p_code']
            elif method=='aamix_redeem_code':
                code=data.get('p_code','')
                deck_codes={'M4Z0M44G0':'maago','M4Z0G1R4':'girabl'}
                if code not in deck_codes and code!='AAMIXTC' and code not in promo_codes:return self.reply(400,{'message':'AAMIX_INVALID_CODE'})
                extra['already_redeemed']=code in inv['redeemed_codes']
                extra['redeemed_code']=code
                deck_id=deck_codes.get(code)
                extra['reward_deck_id']=deck_id
                extra['reward_packs']=1 if code=='AAMIXTC' else 0
                extra['reward_cards']=templates[deck_id]['cartas'] if deck_id else ([] if code=='AAMIXTC' else [{'codigo':promo_codes[code][0],'cantidad':promo_codes[code][1]}])
                extra['reward_name']=templates[deck_id]['nombre'] if deck_id else ('Sobre Transmisión Caída' if code=='AAMIXTC' else catalog[promo_codes[code][0]]['nombre'])
                if not extra['already_redeemed']:
                    inv['redeemed_codes'].append(code)
                    if deck_id:award(inv,deck_id)
                    elif code=='AAMIXTC':inv['packs']+=1
                    else:
                        card,quantity=promo_codes[code]
                        inv['collection'][card]=inv['collection'].get(card,0)+quantity
                if code=='M4Z0M44G0' and lose_redeem_reply:
                    lose_redeem_reply=False
                    return self.reply(503,{})
            elif method in ['aamix_begin_match','aamix_begin_challenge_match']:
                if data['p_deck_id'] not in [d['id'] for d in inv['decks']]:return self.reply(400,{'message':'AAMIX_UNOWNED_DECK'})
                stage=int(data.get('p_stage',0)) if method=='aamix_begin_challenge_match' else 0
                if method=='aamix_begin_challenge_match' and not 1<=stage<=5:return self.reply(400,{'message':'AAMIX_INVALID_CHALLENGE'})
                if stage and not inv['challenges'][stage-1]['unlocked']:return self.reply(400,{'message':'AAMIX_CHALLENGE_LOCKED'})
                key=(uid,data['p_request_id'])
                r=receipts.setdefault(key,{'id':str(uuid.uuid4()),'result':None,'challenge_stage':stage,'deck_id':data['p_deck_id']})
                if r['challenge_stage']!=stage or r['deck_id']!=data['p_deck_id']:return self.reply(400,{'message':'AAMIX_INVALID_CHALLENGE'})
                extra['match_id']=r['id']
                extra['challenge_stage']=stage
                if stage:extra['challenge_opponent']=templates[inv['challenges'][stage-1]['deck_id']]
            elif method=='aamix_finish_match':
                rows=[r for (who,_),r in receipts.items() if who==uid and r['id']==data['p_match_id']]
                if not rows:return self.reply(400,{'message':'Unknown match receipt'})
                if rows[0]['result'] is None:
                    rows[0]['result']=data['p_result']
                    for mission in inv['missions']:
                        if mission['id'] not in ['win_one','win_ten'] or data['p_result']=='victory':
                            mission['progress']=min(mission['target'],mission['progress']+1)
                    stage=rows[0]['challenge_stage']
                    prize=0
                    already=bool(stage and inv['challenges'][stage-1]['completed'])
                    if stage and data['p_result']=='victory' and not already:
                        challenge=inv['challenges'][stage-1]
                        challenge.update(completed=True,reward_claimed=True)
                        prize=challenge['reward_packs']
                        inv['packs']+=prize
                        if stage<5:inv['challenges'][stage]['unlocked']=True
                    extra.update(challenge_stage=stage,challenge_reward_packs=prize,challenge_already_completed=already)
                else:
                    stage=rows[0]['challenge_stage']
                    extra.update(challenge_stage=stage,challenge_reward_packs=0,challenge_already_completed=bool(stage and inv['challenges'][stage-1]['completed']))
                extra['match_id']=data['p_match_id']
            elif method in ['aamix_claim_daily_mission','aamix_claim_mission']:
                mission_id='play_one' if method=='aamix_claim_daily_mission' else data.get('p_mission_id')
                mission=next((m for m in inv['missions'] if m['id']==mission_id),None)
                if mission is None:return self.reply(400,{'message':'AAMIX_INVALID_MISSION'})
                if mission['progress']<mission['target']:return self.reply(400,{'message':'AAMIX_MISSION_NOT_READY'})
                key=(uid,mission_id,mission['day'] if mission['scope']=='daily' else 'lifetime')
                extra.update(already_claimed=mission['claimed'],mission_id=mission_id,reward_packs=mission_awards.get(key,mission['reward_packs']))
                if not mission['claimed']:
                    mission['claimed']=True
                    inv['packs']+=mission['reward_packs']
                    mission_awards[key]=mission['reward_packs']
            elif method=='aamix_fixture_next_day':
                # Loopback-only test clock. Not a production endpoint.
                for mission in inv['missions']:
                    if mission['scope']=='daily':
                        mission.update(day=(date.fromisoformat(mission['day'])+timedelta(days=1)).isoformat(),progress=0,claimed=False)
            elif method=='aamix_fixture_legacy_claims':
                # Preserve a historical one-win claim and the old five-pack PLAY10.
                for mission in inv['missions']:
                    if mission['id'] in ['win_one','play_ten']:
                        mission.update(progress=mission['target'],claimed=True)
                        mission_awards[(uid,mission['id'],'lifetime')]=5 if mission['id']=='play_ten' else 1
                inv['packs']=6
            elif method=='aamix_open_pack':
                request=(uid,data['p_request_id'])
                opening=aliases.get(request) or inv['pending_opening']
                if opening is None:
                    if inv['packs']<1:return self.reply(400,{'message':'AAMIX_NO_PACKS'})
                    inv['packs']-=1
                    opening={'opening_id':str(uuid.uuid4()),'cards':['0100','0104','0104','0120','0119'],'opened_at':'2026-10-17T00:00:00Z','revealed_at':None}
                    inv['pending_opening']=opening
                    openings[(uid,opening['opening_id'])]=opening
                    for code in opening['cards']:inv['collection'][code]=inv['collection'].get(code,0)+1
                aliases[request]=opening
                extra['opening']=opening
                if lose_open_reply:
                    lose_open_reply=False
                    return self.reply(503,{})
            elif method=='aamix_acknowledge_opening':
                opening=openings.get((uid,data['p_opening_id']))
                if opening is None:return self.reply(400,{})
                opening['revealed_at']='2026-10-17T00:00:01Z'
                inv['pending_opening']=None
                if lose_ack_reply:
                    lose_ack_reply=False
                    return self.reply(503,{})
            elif method!='aamix_inventory':return self.reply(404,{})
            return self.reply(200,dict(inv,**extra))

server=ThreadingHTTPServer(('127.0.0.1',0),Handler)
threading.Thread(target=server.serve_forever,daemon=True).start()
logfile=next((a.split('=',1)[1] for a in sys.argv if a.startswith('--log-file=')),str(project.parent.parent/'rewards-ui.log'))
command=[sys.argv[1],'--path',str(project),'--audio-driver','Dummy','--log-file',logfile]
command+=['--rendering-method','gl_compatibility'] if '--gui' in sys.argv else ['--headless']
test_script=next((a.split('=',1)[1] for a in sys.argv if a.startswith('--test-script=')),'res://tests/test_rewards_v010.gd')
command+=['--script',test_script,'--',f'--auth-test-url=http://127.0.0.1:{server.server_port}']
command += [a for a in sys.argv if a.startswith('--screenshots=')]
try:
    result=subprocess.run(command,timeout=180)
    print(json.dumps({'contract_only':True,'real_emails_sent':0,'return_code':result.returncode}))
    raise SystemExit(result.returncode)
finally:
    server.shutdown()
    server.server_close()
