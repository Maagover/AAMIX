"""Prepare informational JSON only and verify the Girabl SQL seed. No connection."""
from pathlib import Path
import json
import re

root = Path(__file__).resolve().parent.parent
path = root / 'data/codigos_regalo.json'
data = json.loads(path.read_text(encoding='utf-8'))
data['version'] = '0.12.0'
data['codigos'] = [c for c in data['codigos'] if c['codigo'] not in ('AAMIXTC', 'M4Z0G1R4')]
data['codigos'] += [
    {'codigo': 'AAMIXTC', 'nombre': '1 sobre', 'tipo': 'sobres', 'sobres': 1},
    {'codigo': 'M4Z0G1R4', 'nombre': 'Mazo Girabl', 'tipo': 'mazo', 'mazo_id': 'girabl',
     'total_cartas': 40, 'recursos': 12, 'fuente_lista': 'tests/fixtures/mazos_legacy.json:usuario_girabl'}
]
data['restricciones'][1] = 'Los códigos no consumen ni reemplazan el regalo inicial; cada recompensa sólo se entrega una vez por UUID y código.'
path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
missions = {
    'formato': 'aamix.misiones', 'version': '0.12.0', 'fecha': '2026-10-18',
    'autoridad': 'Servidor; progreso de recibos terminados, incluidos anteriores. El juego local declara el resultado. Reclamar explícitamente.',
    'timezone': 'America/Santiago', 'reinicio_diarias': '00:00',
    'misiones': [
        {'id': 'play_one', 'nombre': 'Juega 1 partida', 'frecuencia': 'diaria', 'objetivo': 1,
         'resultados': ['victory', 'defeat'], 'recompensa_sobres': 1, 'conserva_registro_anterior': True},
        {'id': 'win_one', 'nombre': 'Gana 1 partida', 'frecuencia': 'diaria', 'objetivo': 1,
         'resultados': ['victory'], 'recompensa_sobres': 1},
        {'id': 'play_ten', 'nombre': 'Juega 10 partidas', 'frecuencia': 'una_vez_por_UUID', 'objetivo': 10,
         'resultados': ['victory', 'defeat'], 'recompensa_sobres': 5, 'acumulativa': True}
    ]
}
(root / 'data/misiones.json').write_text(json.dumps(missions, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
girabl = next(d['cartas'] for d in json.loads((root / 'tests/fixtures/mazos_legacy.json').read_text(encoding='utf-8'))['mazos'] if d['id'] == 'usuario_girabl')
sql = (root / 'backend/aamix_missions_and_gifts_v0120.sql').read_text(encoding='utf-8')
seeded = json.loads(re.search(r"Mazo Girabl','0127','([^']+)'", sql).group(1))
assert seeded == girabl
assert sum(c['cantidad'] for c in seeded) == 40
assert next(c['cantidad'] for c in seeded if c['codigo'] == '0100') == 12
assert len(data['codigos']) == 8
print('PASS: 8 gift definitions, 3 missions, SQL Girabl exactly matches legacy fixture 40/12.')
