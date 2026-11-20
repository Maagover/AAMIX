"""Run shipped regressions with included Windows engine; no live email sends."""
from pathlib import Path
import json
import subprocess
import sys

project=Path(__file__).resolve().parent.parent
engine=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else project.parent/'motor/AAMIX.exe'
logs=Path(sys.argv[2]).resolve() if len(sys.argv)>2 else project.parent/'validacion_local'
logs.mkdir(parents=True,exist_ok=True)
results=json.loads((logs/'summary.json').read_text(encoding='utf-8')) if len(sys.argv)>3 and (logs/'summary.json').exists() else []
scripts=sys.argv[3:] or ['test_game','test_v02','test_ui_v02','test_v03','test_v04','test_v05','test_v07']
for name in scripts:
    logfile=logs/(name+'.log')
    command=[str(engine),'--path',str(project),'--script',f'res://tests/{name}.gd','--log-file',str(logfile)]
    command+=['--headless'] if name in ['test_game','test_v02'] else ['--rendering-method','gl_compatibility']
    if name!='test_v04': command+=['--audio-driver','Dummy']
    r=subprocess.run(command,timeout=100)
    text=logfile.read_text(encoding='utf-8')
    jsonlines=[json.loads(line) for line in text.splitlines() if line.startswith('{')]
    item={'script':name,'exit_code':r.returncode,'results':jsonlines}
    results=[x for x in results if x['script']!=name]+[item]
    print(json.dumps(item,ensure_ascii=True),flush=True)
    if r.returncode or not jsonlines or any(j.get('failures') for j in jsonlines):
        (logs/'summary.json').write_text(json.dumps(results,indent=2),encoding='utf-8')
        raise SystemExit(1)
(logs/'summary.json').write_text(json.dumps(results,indent=2),encoding='utf-8')
