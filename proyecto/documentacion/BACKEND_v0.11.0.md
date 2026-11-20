# Backend AAMIX 0.11.0 · códigos y retratos promocionales

18 de octubre de 2026, Chile. Migración **20261018031742_aamix_gift_codes_and_avatar_lock_v0110** aplicada en el Supabase existente `drpsedaiqyowwikhjugs`. Se conservan Auth, Brevo SMTP, UUIDs, catálogo, colección, mazos y canjes legítimos. No repetir las migraciones anteriores ni esta migración. El índice **20261018032104_aamix_gift_codes_index_v0110** también está aplicado y registrado por separado. Consultar `backend/APPLIED_MIGRATIONS.json` para el historial exacto y `backend/DEPLOYMENT_v0.11.0.json` para el cierre del despliegue, marcado completo.

## Contrato conservado

`aamix_redeem_code(p_code)` conserva su firma pública y valida el UUID/correo real mediante la función privada existente. Configuración de recompensas privada, sin lectura/escritura directa del cliente; clave única `(user_id,gift_code)`. Normaliza mayúsculas y espacios exteriores. Primer canje y cantidades se confirman en una transacción; los reintentos devuelven la misma recompensa con `already_redeemed`, sin repetir cantidades.

La respuesta añade `redeemed_code`, `reward_name`, `reward_deck_id` y `reward_cards` junto al inventario existente. La interfaz puede distinguir mazo de cartas sueltas sin codificar un mensaje fijo de Maagover. `data/codigos_regalo.json` es informativo; no concede premios ni permite que el cliente elija cantidades.

| Código | Recompensa una vez por UUID |
| --- | --- |
| M4Z0M44G0 | Maagover histórico: 40 cartas, 15 Restos y promoción legítima 01c; mazo id maago. |
| P3RI | 3 Peri (01a); sin cero final. |
| B1G0T3S | 3 Bigotes (01b). |
| SI2TYA | 1 Tsuki y Akira (01c). |
| CHANCHULINES | 1 Granjita de Chanchuus (01d). |
| TORNEOAAMIX1 | 1 Dragón Tee K.O (01e). |

Los cinco códigos nuevos sólo conceden cartas de colección. No entregan un mazo/sobre ni desbloquean fotos; no consumen o reinician el regalo inicial, otros códigos o canjes históricos.

## Fotos y sobres

`aamix_set_avatar(p_code)` mantiene su firma y exige Aliado **no promocional**, aun si el jugador posee la promoción. El cliente ofrece 22 retratos; los desbloqueos promocionales futuros no están implementados. La migración no borra ni resetea perfiles guardados. La lectura previa agregada encontró un perfil no promocional 0108 y ninguno promocional, sin consultar identificadores de jugadores.

La expansión N.º 1 se denomina Transmisión Caída. El nombre no modifica el sorteo. Se conserva la corrección de 0.10.1: 35 elegibles, un Recurso primero, 25 normales y nueve Especiales; promociones excluidas de las cinco posiciones, con pesos y restricciones anteriores. La migración nueva no reemplaza `draw_pack`. Canjear una promoción no la añade al grupo de sobres.

## Prueba real confirmada

**PASS: `test_gift_codes_v0110_rollback.sql`** contra el esquema desplegado. Cuentas sintéticas y rollback: cinco códigos/cantidades, 20 reintentos por código, Maagover 40/15 y canje previo, UUIDs aislados, acceso/correo confirmado, rechazo no autorizado, rollback atómico ante desbordamiento, rechazo de avatar promocional poseído y 1.000 sobres sin promociones. No se enviaron correos ni se acreditó concurrencia simultánea real.

Fuente SQL: `backend/aamix_gift_codes_v0110.sql`. No aplicar generadores históricos sobre este servicio existente. La corrección histórica de un sobre documentada en BACKEND_v0.10.1.md ya fue aplicada y queda fuera de esta migración.

La revisión posterior encontró cero cuentas de QA y la colección real existente conservó sus 85 cartas. La revisión de seguridad no encontró problemas de RLS en tablas públicas; las cinco tablas privadas sin políticas mantienen su cierre intencional al cliente. Auth y SMTP permanecen iguales.

Cliente e interfaz: 336 comprobaciones y 21 partidas simuladas aprobadas en Windows, cero fallos; importación aprobada. Consultar VALIDACION_v0.11.0.md para el desglose e INFORME_ENTREGA para la extracción, integridad y arranque del ZIP final; no anticipar ese cierre portátil.
