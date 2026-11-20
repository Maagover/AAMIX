# Desafío AAMIX y misiones · 0.14.0

Fuente preparada: `aamix_challenges_and_missions_v0140.sql`. La identidad y el estado aplicado se registran en `APPLIED_MIGRATIONS.json` y `VERIFICATION_v0.14.0.json`; la cabecera del SQL identifica la fuente revisada, no acredita un despliegue.

## Misiones y conservación de premios

| ID | Objetivo | Frecuencia | Sobres |
| --- | --- | --- | --- |
| `play_one` | Juega 1 partida | Diaria, medianoche de Chile | 1 |
| `win_one` | Gana 1 partida | Una vez por UUID | 1 |
| `play_ten` | Juega 10 partidas | Acumulativa, una vez por UUID | 3 |
| `win_ten` | Gana 10 partidas | Acumulativa, una vez por UUID | 5 |

El progreso incluye recibos terminados anteriores a esta versión, tanto partidas aleatorias como desafíos. Una derrota aumenta Juega, pero no Gana. Los premios se reclaman por misión; terminar una partida no cobra estas cuatro misiones automáticamente. El alias antiguo `mission` mantiene la forma de Juega 1 partida, y `aamix_claim_daily_mission()` conserva su firma y su registro anterior.

Gana 1 partida pasa de diaria a única: cualquier reclamo anterior de `win_one`, aunque tenga una fecha antigua, la deja cobrada para siempre. No se eliminan ni se sustituyen esas filas. Juega 10 partidas entrega tres sobres a los nuevos reclamos; quienes ya recibieron cinco conservan los cinco. La nueva columna `aamix_mission_claims.reward_packs` registra el importe histórico pagado y los reintentos responden ese importe; la fila de misión muestra el premio vigente de tres. La migración no suma ni resta sobres a ninguna cuenta.

## Desafíos

| Etapa | Rival fijo | Sobres, sólo primera victoria |
| --- | --- | --- |
| 1 | Mazo Papito | 1 |
| 2 | Mazo Flaan | 1 |
| 3 | Mazo Kajido | 1 |
| 4 | Mazo Maagover | 2 |
| 5 | Mazo Girabl | 3 |

El servidor deriva los desbloqueos de `aamix_challenge_completions`: primero Papito; cada victoria confirmada habilita la siguiente etapa. Se pueden repetir las etapas abiertas. La primera victoria de una etapa entrega su premio automáticamente; todas las siguientes entregan cero sobres de desafío. Una derrota no entrega ese premio ni desbloquea la etapa siguiente.

`aamix_begin_challenge_match(p_request_id uuid, p_deck_id text, p_stage integer)` exige un mazo obtenido por el UUID autenticado y una etapa desbloqueada. El recibo guarda etapa y copia exacta del rival, obtenida de las plantillas históricas del servidor. El cliente no envía el rival ni la cantidad del premio. La firma anterior `aamix_begin_match(uuid,text)` queda para partidas aleatorias. Un UUID de petición no puede cambiar de modo, etapa ni mazo.

`aamix_finish_match(p_match_id uuid,p_result text)` conserva su firma. No recibe etapa ni recompensa: ambas proceden del recibo original. El resultado terminado es inmutable. `victory` y `defeat` son los únicos resultados válidos. Un recibo aleatorio no puede transformarse en un desafío al terminarlo.

Respuestas de inicio: inventario, `match_id`, `match_result`, `challenge_stage` y, para desafíos, `challenge_opponent` con `id/nombre/portada/recurso_inicial/cartas`. Respuestas de término: inventario, `match_id`, `match_result`, `challenge_stage`, `challenge_reward_packs` y `challenge_already_completed`. `challenge_reward_packs` indica lo concedido en esa llamada; es cero en derrotas, repeticiones y reintentos de un término ya confirmado. El inventario conserva siempre el premio, aunque se haya perdido la primera respuesta.

`inventory.challenges` es una lista ordenada de cinco objetos con `stage`, `deck_id`, `title`, `reward_packs`, `unlocked`, `completed` y `reward_claimed`. `inventory.missions` tiene cuatro entradas. El cliente borra ambas listas al cerrar/cambiar sesión. La selección de rivales aleatorios y el regalo inicial siguen usando los tres mazos base originales; los cinco rivales históricos están habilitados en Desafío AAMIX.

## Autenticación, RLS y atomicidad

Las funciones públicas son wrappers `SECURITY INVOKER`, sin ejecución para `anon`/`PUBLIC`, y `search_path` vacío. Los lectores de estado también son invoker. Las mutaciones privadas conservan el guardián que exige un UUID real, cuenta no anónima y correo confirmado. La cuenta se obtiene de `auth.uid()`, nunca de parámetros ni metadatos editables.

`aamix_challenge_completions` tiene RLS, lectura sólo del dueño e índices por su clave `(user_id,stage)` y su recibo ganador único. El cliente no tiene permisos de escritura en esa tabla, en recibos ni en reclamos de misiones. Cada mutación bloquea la misma cartera de recompensas de esa cuenta. Recibo terminado, progreso diario, primera victoria, desbloqueo y premio son una transacción: un desbordamiento revierte todo el intento. Dos intentos iniciados antes de una victoria se pueden terminar, pero sólo uno entrega el premio de esa etapa.

No se alteran Auth, SMTP, los ocho códigos de regalo, las plantillas de los mazos ni las probabilidades de los sobres. Las promocionales siguen excluidas de todos los sobres y de las fotos de perfil.

## Validación

`test_challenges_and_missions_v0140_rollback.sql` usa sólo cuentas sintéticas con dominio `.invalid`, UUID aleatorios y rollback final. Cubre orden de las cinco etapas, bloqueos, derrota, rival fijo de 40 cartas, dos intentos iniciados, repeticiones, veinte reintentos por inicio/término/reclamo, incompatibilidad entre modos para una petición, separación entre UUID, misiones históricas, premios anteriores de cinco sobres, límites de medianoche de Chile con sesión en Honolulu, autenticación, RLS/ACL, desbordamientos y mil sobres sin promocionales. No equivale a simular una partida completa del motor ni a probar dos sesiones realmente concurrentes.

El resultado ejecutado, la migración aplicada y las sumas reales antes/después se registran en `VERIFICATION_v0.14.0.json`. Nunca se reclaman recompensas de personas reales durante la validación.

## Límites conservados

El juego local declara el resultado de la IA. El servidor valida identidad, propiedad, etapa, orden, unicidad y premios, pero no reproduce la partida. Esto no es suficiente para partidas multijugador competitivas: éstas requieren un servidor que valide acciones y determine el resultado. La cola de un resultado aún no enviado vive en memoria; cerrar el juego antes de confirmarlo no guarda la partida ni garantiza su envío posterior.
