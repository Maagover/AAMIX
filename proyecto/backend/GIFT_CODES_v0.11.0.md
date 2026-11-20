# Códigos y avatares · backend 0.11.0

Estado: **aplicado y verificado en la base real**. El responsable de la entrega aplicó `aamix_gift_codes_v0110.sql` mediante la migración **20261018031742_aamix_gift_codes_and_avatar_lock_v0110**, el **18 de octubre de 2026 a las 03:17:42 UTC**, después de `20261017221142_aamix_packs_exclude_promotional_v0101`. No ejecutar de nuevo migraciones anteriores. El índice adicional de soporte de clave foránea está separado en `aamix_gift_codes_index_v0110.sql` y quedó aplicado como **20261018032104_aamix_gift_codes_index_v0110**; no modifica datos de jugadores.

| Código exacto | Recompensa una vez por UUID |
| --- | --- |
| M4Z0M44G0 | Mazo Maagover histórico, 40 cartas / 15 Restos |
| P3RI | 3 Peri (01a) |
| B1G0T3S | 3 Bigotes (01b) |
| SI2TYA | 1 Tsuki y Akira (01c) |
| CHANCHULINES | 1 Granjita de Chanchuus (01d) |
| TORNEOAAMIX1 | 1 Dragón Tee K.O (01e) |

Se normalizan espacios exteriores y mayúsculas. `P3RI` no lleva cero al final. Los nuevos códigos conceden sólo cantidades de colección: no un mazo, un sobre ni un desbloqueo de avatar. El límite usa la clave existente `(user_id,gift_code)`; no se reinicia el historial anterior de Maagover.

La configuración vive en `aamix_private.gift_code_rewards`, con RLS habilitada y sin políticas ni SELECT concedido al cliente. Se conserva el wrapper público invoker y el contrato de autenticación: la función privada usa `lock_rewards()`, que verifica el UUID real y correo confirmado y bloquea su cartera. Canje, colección y mazo (sólo para Maagover) ocurren dentro de una única transacción. Un error al conceder cantidades revierte también el registro de canje. No cambia Auth, SMTP ni datos existentes.

Respuesta del RPC existente `aamix_redeem_code(p_code)`:

- Todo el inventario actual, sin eliminar claves anteriores.
- `already_redeemed`: `false` en el primer canje; `true` en los reintentos, sin repetir cantidades.
- `redeemed_code` y `reward_name`: código normalizado y nombre visible.
- `reward_deck_id`: `maago` o `null` para cartas sueltas.
- `reward_cards`: lista exacta `[{codigo,cantidad}]`, también para Maagover y en reintentos.

El archivo `data/codigos_regalo.json` es informativo. No concede nada localmente ni reemplaza la configuración del servidor. Los clientes no eligen cantidades ni UUID del dueño.

La selección de avatar exige `card_class='Aliado' AND NOT is_promotional`; rechaza las promocionales incluso poseídas. Los futuros desbloqueos no están implementados. No se borra ni cambia un avatar guardado por esta migración. La consulta agregada previa encontró un perfil 0108 y ninguno promocional; no se leyeron datos identificadores de jugadores.

Los sobres conservan la corrección 0.10.1: 25 normales, 9 Especiales y 1 Recurso; las 6 promocionales no entran en ninguna posición. La nueva migración no reemplaza `draw_pack` ni cambia sus probabilidades. Obtener promociones por estos códigos no las añade al grupo de sorteos.

`test_gift_codes_v0110_rollback.sql` usa cinco cuentas sintéticas de UUID aleatorio en una transacción. Comprueba cantidades, 20 reintentos por código, Maagover 40/15, regalo inicial independiente, UUIDs aislados, correo confirmado, usuarios anónimos/rechazados, escrituras denegadas, rollback atómico por desbordamiento, rechazo de avatares promocionales poseídos y 1.000 sobres sin promociones. **La ejecución en la base real pasó**. Todo se revirtió: no hizo COMMIT de usuarios o recompensas de prueba ni envió correos. No se incluyen identificadores de cuentas en esta documentación.

Para ejecutar pruebas antiguas de recompensas en 0.11.0, el bucle que intenta asignar todos los Aliados debe restringirse a `not is_promotional`; su expectativa histórica de permitir los avatares promocionales fue reemplazada. El test nuevo comprueba ambos casos expresamente. No presentar una prueba secuencial como carrera simultánea real entre dos clientes.
