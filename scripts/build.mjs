import fs from 'node:fs/promises';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
const root=path.resolve(import.meta.dirname,'..');
const project=path.join(root,'proyecto');
const engine=process.env.GODOT_BIN || JSON.parse(await fs.readFile(path.join(root,'.tools','local-toolchain.json'),'utf8')).engine;
const build=path.join(root,'build');
await fs.mkdir(build,{recursive:true});
const reports=[];
async function run(name,args) {
  const result=spawnSync(engine,['--headless','--path',project,'--log-file',path.join(build,`${name}.godot.log`),...args],{encoding:'utf8',maxBuffer:16*1024*1024});
  const output=(result.stdout||'')+(result.stderr||'');
  await fs.writeFile(path.join(build,`${name}.log`),output);
  if(result.error || result.status!==0 || /SCRIPT ERROR:|Parse Error:|Failed to load script|Project export .* failed/.test(output))throw new Error(`${name} failed; see build/${name}.log\n${output.slice(-2000)}`);
  const summary=output.split(/\r?\n/).filter(line=>line.startsWith('{')).at(-1);
  if(summary)reports.push(JSON.parse(summary));
  console.log(`${name}: passed${summary?' '+summary:''}`);
}
await run('import',['--editor','--import']);
const authResult=spawnSync(process.execPath,[path.join(root,'scripts/test-auth.mjs')],{env:{...process.env,GODOT_BIN:engine},encoding:'utf8',maxBuffer:1024*1024});
if(authResult.status!==0)throw new Error(authResult.stdout+authResult.stderr);
const authReport=JSON.parse(authResult.stdout.trim());reports.push(authReport);console.log('password-auth: passed '+JSON.stringify(authReport));
await run('input',['--script','res://tests/test_web_input.gd']);
await run('regression',['--script','res://tests/test_v111_release.gd']);
await run('interactions',['--script','res://tests/test_mobile_interactions.gd']);
await run('portrait',['--script','res://tests/test_mobile_portrait.gd']);
for(const [name,preset] of [['web','Web'],['windows','Windows Desktop']]){
  await fs.mkdir(path.join(build,name),{recursive:true});
  await run(`export-${name}`,['--export-release',preset]);
  await run(`assets-${name}`,['--main-pack',path.join(build,name,name==='web'?'index.pck':'AAMIX.pck'),'--script','res://export_checks.gd']);
}
await fs.copyFile(path.join(root,'platform','windows','AAMIX.Session.exe'),path.join(build,'windows','AAMIX.Session.exe'));
const metadata=JSON.parse(await fs.readFile(path.join(project,'VERSION.json'),'utf8'));
const report={built_at:new Date().toISOString(),source_commit:process.env.SOURCE_COMMIT||process.env.GITHUB_SHA||null,base_version:metadata.version,channel:'portrait-reference-password-preview',reports};
await fs.writeFile(path.join(build,'verification.json'),JSON.stringify(report,null,2));
await fs.writeFile(path.join(build,'web','build-info.json'),JSON.stringify(report,null,2));
await fs.copyFile(path.join(build,'verification.json'),path.join(build,'windows','verification.json'));
console.log('Both platforms were exported from the same source. No database migrations or releases were performed.');
