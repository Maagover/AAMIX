"""Import the exact published PC source before applying the tracked web/mobile overlay."""
from pathlib import Path
from urllib.request import urlopen
import hashlib
import subprocess
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parent.parent
URL = 'https://github.com/Maagover/AAMIX/releases/download/v1.11.1/AAMIX_Online_v1.3.1_Windows.zip'
SHA256 = '479fdfee8ac36778584906e078017efc281bce36c7df32b87d83533bd9f0b766'
PREFIX = 'AAMIX_Online_v1.3.1/proyecto/'

tracked = subprocess.check_output(['git', 'ls-files', '-z', 'proyecto'], cwd=ROOT).decode().split('\0')
overlay = {name: (ROOT/name).read_bytes() for name in tracked if name and (ROOT/name).is_file()}
with tempfile.TemporaryDirectory(prefix='aamix-source-') as directory:
    archive = Path(directory)/'published-pc.zip'
    digest = hashlib.sha256()
    with urlopen(URL, timeout=120) as incoming, archive.open('wb') as output:
        while chunk := incoming.read(1024*1024):
            digest.update(chunk)
            output.write(chunk)
    if digest.hexdigest() != SHA256:
        raise RuntimeError('Published PC archive failed its pinned SHA-256 check')
    with zipfile.ZipFile(archive) as source:
        for entry in source.infolist():
            if not entry.filename.startswith(PREFIX) or entry.is_dir():
                continue
            relative = entry.filename[len(PREFIX):]
            if relative.startswith('.godot/') or relative.startswith('tests/qa_') or relative.endswith('.err'):
                continue
            target = (ROOT/'proyecto'/relative).resolve()
            if not target.is_relative_to((ROOT/'proyecto').resolve()):
                raise RuntimeError('Archive path escapes project')
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(source.read(entry))
        for name in ['AAMIX.Session.exe', 'COPYRIGHT.txt', 'LICENSE.txt']:
            target = ROOT/'platform'/'windows'/name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(source.read('AAMIX_Online_v1.3.1/motor/'+name))
for name, content in overlay.items():
    (ROOT/name).write_bytes(content)
seed = ROOT/'AAMIX_portrait_source_overlay.zip'
seed_count = 0
if seed.is_file():
    with zipfile.ZipFile(seed) as changes:
        for entry in changes.infolist():
            if entry.is_dir() or entry.filename.startswith(('.git/', '.github/')):
                continue
            target = (ROOT/entry.filename).resolve()
            if not target.is_relative_to(ROOT):
                raise RuntimeError('Overlay path escapes repository')
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(changes.read(entry))
            seed_count += 1
print(f'Imported verified PC sources; restored {len(overlay)} tracked and {seed_count} seed files')
