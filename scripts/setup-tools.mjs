// Official Godot downloads only. Range reads avoid downloading templates for unused platforms.
import fs from 'node:fs/promises';
import path from 'node:path';
import zlib from 'node:zlib';
const root = path.resolve(import.meta.dirname, '..');
const {godot: version} = JSON.parse(await fs.readFile(path.join(root, 'toolchain.json'), 'utf8'));
const windows = process.platform === 'win32';
const release = await fetch(`https://api.github.com/repos/godotengine/godot/releases/tags/${version}-stable`);
if (!release.ok) throw new Error(`Godot release lookup: HTTP ${release.status}`);
const {assets} = await release.json();
async function readRange(asset, start, end) {
  const response = await fetch(asset.browser_download_url, {headers:{Range:`bytes=${start}-${end}`}});
  if (response.status !== 206) { await response.body?.cancel(); throw new Error(`Download requires ranges: HTTP ${response.status}`); }
  const data = Buffer.from(await response.arrayBuffer());
  if (data.length !== end - start + 1) throw new Error('Incomplete download range');
  return data;
}
async function extractSelected(asset, accept, destination) {
  if (!asset) throw new Error('Missing official download');
  const tail = await readRange(asset, Math.max(0, asset.size - 65557), asset.size - 1);
  let end = -1;
  for (let i = tail.length - 22; i >= 0; i--) if (tail.readUInt32LE(i) === 0x06054b50) {end=i;break;}
  if (end < 0) throw new Error('ZIP directory missing');
  const length = tail.readUInt32LE(end+12), offset = tail.readUInt32LE(end+16);
  const directory = await readRange(asset, offset, offset+length-1);
  const entries = [];
  for (let at=0; at<directory.length && directory.readUInt32LE(at)===0x02014b50;) {
    const nl=directory.readUInt16LE(at+28), el=directory.readUInt16LE(at+30), cl=directory.readUInt16LE(at+32);
    const name=directory.subarray(at+46,at+46+nl).toString();
    if (accept(name)) entries.push({name,method:directory.readUInt16LE(at+10),crc:directory.readUInt32LE(at+16),compressed:directory.readUInt32LE(at+20),size:directory.readUInt32LE(at+24),offset:directory.readUInt32LE(at+42)});
    at+=46+nl+el+cl;
  }
  if (!entries.length) throw new Error('Requested files absent from ZIP');
  await fs.mkdir(destination,{recursive:true});
  for (const entry of entries) {
    const header=await readRange(asset,entry.offset,entry.offset+29);
    if(header.readUInt32LE(0)!==0x04034b50)throw new Error('Invalid ZIP header');
    const start=entry.offset+30+header.readUInt16LE(26)+header.readUInt16LE(28);
    const compressed=await readRange(asset,start,start+entry.compressed-1);
    if (![0,8].includes(entry.method)) throw new Error('Unsupported ZIP compression');
    const data=entry.method===8?zlib.inflateRawSync(compressed):compressed;
    if(data.length!==entry.size || zlib.crc32(data)!==entry.crc)throw new Error(`Integrity check failed: ${entry.name}`);
    const file=path.join(destination,path.basename(entry.name));
    await fs.writeFile(file,data);
    console.log(`Prepared ${path.basename(entry.name)} (${data.length} bytes)`);
  }
  return entries;
}
const engineDir=path.join(root,'.tools','godot');
const engineAsset=assets.find(a=>a.name===`Godot_v${version}-stable_${windows?'win64.exe':'linux.x86_64'}.zip`);
const engineEntries=await extractSelected(engineAsset,name=>windows?name.endsWith('.exe')&&!name.endsWith('_console.exe'):!name.includes('/')&&name.includes('linux.x86_64'),engineDir);
const engine=path.join(engineDir,path.basename(engineEntries[0].name));
if(!windows)await fs.chmod(engine,0o755);
await fs.writeFile(path.join(engineDir,'._sc_'),'');
const templates=path.join(engineDir,'editor_data','export_templates',`${version}.stable`);
await extractSelected(assets.find(a=>a.name===`Godot_v${version}-stable_export_templates.tpz`),name=>/^templates\/(web_nothreads_(debug|release)\.zip|windows_(debug|release)_x86_64\.exe|version\.txt)$/.test(name),templates);
await fs.writeFile(path.join(root,'.tools','local-toolchain.json'),JSON.stringify({engine}));
