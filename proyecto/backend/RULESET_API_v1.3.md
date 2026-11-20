# AAMIX 1.3 — compatibilidad de reglas en salas

Estado: APLICADO Y VERIFICADO en Supabase mediante `20261020123723_aamix_ruleset_v130`. Root completó el ensayo transaccional de 24 grupos con dos cuentas sintéticas revertidas. Integración completó 13 comprobaciones nativas por HTTPS, sin fallos, y root confirmó la limpieza de las dos cuentas sintéticas usadas por el cliente.

La versión de transporte continúa en 3 y el formato de snapshot en 1. La propiedad adicional `ruleset_version` identifica las reglas ejecutadas por el anfitrión: `1.2` para clientes anteriores y `1.3` para esta actualización. No incorpora arbitraje competitivo ni demuestra que un cliente modificado respete las reglas.

## Entrada a salas

- `aamix_mp_create_room` y `aamix_mp_join_room` mantienen exactamente sus firmas y operan con reglas 1.2.
- `aamix_mp_create_room_v130(p_request_id uuid,p_deck_id text)` crea salas con reglas 1.3.
- `aamix_mp_join_room_v130(p_code text,p_deck_id text,p_request_id uuid)` sólo admite salas 1.3.
- Un cruce de versiones produce `AAMIX_RULESET_MISMATCH` (SQLSTATE 22023), antes de escribir la membresía. También se rechaza reutilizar el UUID de creación/entrada mediante la otra versión.
- Los mazos continúan siendo copias congeladas en el servidor y las respuestas conservan ocultamiento, revisiones, room_version y protocolo.

## Operaciones y reconexión

Los clientes 1.3 usan los nuevos `aamix_mp_poll_v130`, `aamix_mp_active_v130`, `aamix_mp_confirm_v130`, `aamix_mp_submit_v130`, `aamix_mp_commit_v130` y `aamix_mp_host_action_v130`, con los mismos parámetros, valores predeterminados y semántica de sus versiones anteriores.

Los endpoints anteriores rechazan salas 1.3. Los nuevos rechazan salas 1.2. Así, reabrir una sala 1.3 con un cliente anterior no permite obtener o modificar su snapshot a través de los RPC anteriores.

La excepción de consulta es `aamix_mp_active_v130`: si la cuenta conserva una sala 1.2, devuelve sólo `protocol, room_id, code, status, ruleset_version, incompatible, revision, room_version, slot`. No devuelve estado, listas de mazos, jugadores ni cola. El cliente debe ofrecer cerrar/abandonar esa sala y no restaurarla como una partida 1.3.

`aamix_mp_leave` permanece común a ambas versiones para permitir cancelación o abandono. Conserva la lógica existente de recibos únicos.

Los commits y las acciones del anfitrión comprueban además las reglas de ambos snapshots. El cliente 1.3 debe enviar `ruleset_version:"1.3"` en el snapshot privado y la vista del invitado. En salas anteriores se acepta ausencia del campo como 1.2.

## Privacidad y alcance

Las tablas continúan privadas y con RLS. Los wrappers públicos son SECURITY INVOKER; los helpers privilegiados verifican identidad y pertenencia. No cambian cuentas, colección, economía, resultados, datos anteriores ni reglas de premios. El nuevo campo de sala tiene valor predeterminado 1.2 para preservar las salas existentes.

La separación evita mezclas accidentales de versiones oficiales. Un programa modificado puede llamar al endpoint de otra versión; el anfitrión sigue siendo la autoridad del juego.

## Verificación dirigida

`test_ruleset_v130_rollback.sql` pasó los 24 grupos en el ensayo transaccional ejecutado por root: entrada compatible/incompatible, UUID e idempotencia, firmas anteriores, privacidad, reconexión sin estado de reglas distintas, rechazo de operaciones tras downgrade, versión explícita de snapshots y conservación de revisiones/cola. Las dos cuentas sintéticas y todas las escrituras del ensayo se revirtieron. No se sortearon cartas ni se ejecutaron partidas completas.

Root comparó la definición viva de `mp_response`: su cambio es únicamente el campo adicional `ruleset_version`. El asesor de seguridad conserva los mismos avisos anteriores y permanecen cuatro cuentas existentes; no se ejecutó reinicio de progreso. El registro específico está en `DEPLOYMENT_v1.3.json`.

La prueba nativa por HTTPS pasó 13 comprobaciones, sin fallos, con dos clientes en un proceso y una partida preparada de 80 cartas. Se verificó el uso real de los endpoints v130. Root eliminó los dos UUID sintéticos exactos con comprobación de correo y limpió sus sesiones, salas, mazos personalizados y registros auxiliares. Quedaron cuatro cuentas existentes y cero usuarios, sesiones, mazos o salas de QA. El archivo privado local de credenciales de prueba también se eliminó.

Esta prueba no verificó Realtime por WebSocket, una partida completa entre dos PCs remotos ni nuevas mediciones de latencia. No amplía la autoridad del servidor: el anfitrión sigue ejecutando las reglas.

