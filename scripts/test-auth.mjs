import http from 'node:http';
import {spawn} from 'node:child_process';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
const root=path.resolve(import.meta.dirname,'..');
const engine=process.env.GODOT_BIN || JSON.parse(await fs.readFile(path.join(root,'.tools/local-toolchain.json'),'utf8')).engine;
const requests=[];
const user={id:'00000000-0000-4000-8000-000000000001',email:'qa@example.invalid',user_metadata:{display_name:'Prueba'}};
const session={user,access_token:'local-fixture-access',refresh_token:'local-fixture-refresh',expires_in:3600};
const server=http.createServer(async(req,res)=>{
  const chunks=[];for await(const chunk of req)chunks.push(chunk);
  const body=JSON.parse(Buffer.concat(chunks).toString()||'{}');
  requests.push({url:req.url,method:req.method,body,authorized:req.headers.authorization==='Bearer local-fixture-access'});
  res.setHeader('Content-Type','application/json');
  if(req.url==='/auth/v1/token?grant_type=password'){
    assert.equal(body.email,user.email);
    if(body.password!=='FixturePass_9'){res.writeHead(400);res.end(JSON.stringify({error_code:'invalid_credentials'}));return;}
    res.end(JSON.stringify(session));
  }else if(req.url?.startsWith('/auth/v1/signup?')){
    assert.equal(body.password,'FixturePass_9');assert.equal(body.data.display_name,'Prueba');res.end(JSON.stringify({user}));
  }else if(req.url?.startsWith('/auth/v1/recover?'))res.end('{}');
  else if(req.url==='/auth/v1/user' && req.method==='PUT'){
    assert.equal(req.headers.authorization,'Bearer local-fixture-access');assert.equal(body.password,'NewFixturePass_9');res.end(JSON.stringify(user));
  }else if(req.url==='/auth/v1/token?grant_type=refresh_token'){
    assert.equal(body.refresh_token,'local-fixture-refresh');res.end(JSON.stringify(session));
  }else if(req.url==='/auth/v1/logout?scope=local'){res.writeHead(204);res.end();}
  else{res.writeHead(404);res.end('{}');}
});
await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
try{
  const output=await new Promise((resolve,reject)=>{
    const p=spawn(engine,['--headless','--path',path.join(root,'proyecto'),'--log-file',path.join(root,'build/auth.godot.log'),'--script','res://tests/test_password_auth.gd'],{env:{...process.env,AAMIX_TEST_AUTH_URL:`http://127.0.0.1:${server.address().port}`}});
    let output='';p.stdout.on('data',x=>output+=x);p.stderr.on('data',x=>output+=x);
    const timer=setTimeout(()=>{p.kill();reject(new Error('Auth fixture timeout'));},30000);
    p.on('error',reject);p.on('close',code=>{clearTimeout(timer);code===0?resolve(output):reject(new Error(output));});
  });
  assert.equal(requests.length,8,'Only the expected Auth requests were sent');
  const summary=output.split(/\r?\n/).find(x=>x.startsWith('{"password_auth"'));
  assert(summary,'Password test report missing');console.log(summary);
}finally{server.close();}
