# AAMIX 0.14.0: contrato actual y antecedentes

El contrato vigente está en [CHALLENGES_AND_MISSIONS_v0.14.0.md](CHALLENGES_AND_MISSIONS_v0.14.0.md). El estado real de despliegue y las pruebas ejecutadas figuran en `APPLIED_MIGRATIONS.json` y `VERIFICATION_v0.14.0.json`. No repetir una migración registrada como aplicada.

Inventario mantiene todos los campos anteriores y añade `challenges`, cinco etapas ordenadas por cuenta: Papito → Flaan → Kajido → Maagover → Girabl. Primera victoria da 1/1/1/2/3 sobres y desbloquea la siguiente. Repeticiones y reintentos entregan cero premios adicionales. `aamix_begin_challenge_match(p_request_id uuid,p_deck_id text,p_stage integer)` registra etapa y rival fijo en el recibo. `aamix_finish_match` conserva firma y toma esa información del recibo, no de parámetros del cliente. El inicio aleatorio anterior queda compatible y su recibo nunca puede transformarse en desafío.

`missions` contiene `play_one` diaria de 1 sobre; `win_one` única de 1 sobre; `play_ten` única acumulativa de 3 sobres; `win_ten` única acumulativa de 5 sobres. Los recibos anteriores cuentan para el progreso. Cualquier reclamo antiguo de WIN1 la deja cobrada para siempre; los PLAY10 ya pagados conservan sus 5 sobres. La respuesta de un reintento de aquel PLAY10 informa el importe histórico de 5, y la fila de la misión muestra el premio actual de 3. PLAY1 conserva su alias `mission`, su RPC y reinicio a medianoche de Chile. Ningún cambio de definición concede o retira sobres automáticamente.

Todas las tablas de jugador tienen lectura del dueño con RLS y escritura del cliente revocada. Wrappers públicos invoker, funciones mutadoras privadas con UUID/correo confirmado y bloqueo común de la cartera. Pruebas nuevas en `test_challenges_and_missions_v0140_rollback.sql`; sólo fixtures sintéticas con rollback, sin cambios en recompensas reales. Los resultados de la IA local siguen declarados por el cliente.

## Antecedente 0.12.0

**Migración aplicada `20261018035100_aamix_missions_and_gifts_v0120`, 18-10-2026 03:51:00 UTC.** El contrato de esa entrega está en `MISSIONS_AND_GIFTS_v0.12.0.md` y su registro en `DEPLOYMENT_v0.12.0.json`. Introdujo `missions:[play_one,win_one,play_ten]` conservando PLAY1 singular y `aamix_claim_mission(p_mission_id text)`. En esa versión WIN1 era diaria y PLAY10 pagaba cinco sobres; esas dos definiciones están reemplazadas por las indicadas arriba en 0.14.0.

Canjes nuevos: `AAMIXTC` entrega 1 sobre y `M4Z0G1R4` entrega Girabl exacto 40/12. Los seis códigos anteriores conservan recompensa e historial; hay ocho definiciones. La respuesta de canje añade `reward_packs` y conserva el resto. Los dos tests reales de esta entrega pasaron con rollback integral y 2.000 sobres sorteados; no hubo cambios en recompensas reales ni usuarios de prueba restantes.

## Antecedente 0.11.0

**Ampliación 0.11.0 aplicada y verificada:** `20261018031742_aamix_gift_codes_and_avatar_lock_v0110`, el 18 de octubre de 2026 a las 03:17:42 UTC. La prueba real `test_gift_codes_v0110_rollback.sql` pasó, incluidos códigos, reintentos y 1.000 sobres sin promociones; se revirtió toda la QA sin usuarios ni recompensas de prueba guardados. Revisar `DEPLOYMENT_v0.11.0.json` y `GIFT_CODES_v0.11.0.md`. El índice adicional separado en `aamix_gift_codes_index_v0110.sql` quedó aplicado como **20261018032104_aamix_gift_codes_index_v0110**. No repetir la migración ya aplicada.

El RPC `aamix_redeem_code(p_code text)` conserva firma y devuelve el inventario completo más `already_redeemed`, `redeemed_code`, `reward_name`, `reward_deck_id` y `reward_cards`. `reward_deck_id` es `maago` para el mazo o `null` para cartas sueltas; `reward_cards` siempre contiene la lista exacta `[{codigo,cantidad}]`, también en reintentos. La interfaz debe mostrar estos campos genéricamente, sin asumir que todo canje entrega un mazo.

Códigos una vez por UUID: `M4Z0M44G0` conserva Maagover exacto; `P3RI` entrega Peri 01a×3; `B1G0T3S`, Bigotes 01b×3; `SI2TYA`, Tsuki y Akira 01c×1; `CHANCHULINES`, Granjita de Chanchuus 01d×1; `TORNEOAAMIX1`, Dragón Tee K.O 01e×1. Las cartas sueltas no entregan mazos ni sobres ni consumen el regalo inicial. Las definiciones residen en una tabla privada sin lectura/escritura del cliente.

`aamix_set_avatar` rechaza todas las promocionales aunque se posean; sólo admite Aliados no promocionales. Los futuros desbloqueos están pendientes. No cambia automáticamente perfiles ya guardados. Inspección agregada previa: un perfil, avatar 0108, ninguno promocional.

**Corrección de sobres 0.10.1 ya vigente:** 35 elegibles (25 normales, 9 Especiales y 1 Recurso); las 6 promocionales quedan fuera en todas las posiciones. La migración 0.11.0 no modifica el sorteo ni las aperturas históricas. Los porcentajes Especiales, misión y persistencia se conservan. Las referencias a 41 elegibles y todos los Aliados en el texto histórico siguiente están superadas.

## Antecedente histórico 0.10.0: recompensas y perfiles

`aamix_rewards.sql` amplía el backend 0.9.0. `build_rewards.py` lo genera desde el catálogo y la lista histórica Maagover sin conectarse a la base. No cambia Auth, SMTP, cuentas, sesiones, colección ni regalos anteriores. No aplicar el archivo `rewards_template.sql` directamente.

Aplicado el 17 de octubre de 2026 con la migración `20261017194519_aamix_profiles_rewards_v0100`. El registro `APPLIED_MIGRATIONS.json` contiene su verificación. Antes y después permanecieron 2 usuarios, 1 regalo inicial, 1 mazo y 40 cartas en 12 filas de colección. Las pruebas no dejaron usuarios ni recompensas de prueba guardados.

Todas las escrituras requieren la sesión de una cuenta con correo confirmado. El UUID se obtiene exclusivamente con `auth.uid()`. Las tablas públicas sólo permiten SELECT del dueño con RLS; los privilegios de INSERT/UPDATE/DELETE están revocados. La escritura ocurre en funciones privadas con identidad comprobada y `search_path=''`, mediante envoltorios públicos `SECURITY INVOKER`.

## Reglas confirmadas

- Código `M4Z0M44G0`: Mazo Maagover histórico exacto, 40 cartas con 15 Restos, portada 0108, id `maago`. Un canje por UUID; no consume ni reemplaza el regalo inicial.
- Avatares: cualquier carta de clase Aliado del catálogo, asociada al UUID. No requiere poseer esa carta.
- Misión: terminar una partida con victoria o derrota, una recompensa de 1 sobre por UUID y día. El día cambia a las 00:00 en `America/Santiago`, con horario de verano resuelto por PostgreSQL. No depende del reloj del jugador. Se reclama expresamente después de completar.
- Sobres: 5 cartas ordenadas. Posición 1 Recurso; posiciones 2–4 normales uniformes con repetición; posición 5 normal 70% o especial 30%. Nunca hay recursos en posiciones 2–5. Las 41 cartas son obtenibles, aunque una carta aún no tenga sus efectos programados.
- Dentro del grupo especial: Kajido 0105, SoyFlaan 0103, Papito 0115 y Transmisión Caída 0119 tienen 5% cada uno (1,5% cada uno por sobre). Guitarramala 0134, HNyko 0128, Chanchuus 0125, Escuela de Vuelo 0131 y Serandimini 0130 tienen 16% cada uno (4,8% cada uno por sobre).

## Contrato de los RPC

Cada RPC devuelve el inventario completo compatible con 0.9.0: `user_id`, `gift`, `collection`, `decks`. Añade `profile:{avatar_code}`, `packs:int`, `mission:{id,title,day,timezone,progress,target,claimed,reward_packs}`, `pending_opening` y `redeemed_codes`.

| RPC | Parámetros JSON | Resultado adicional |
| --- | --- | --- |
| `aamix_inventory` | `{}` | Ninguno; lectura |
| `aamix_set_avatar` | `p_code:text` | Perfil actualizado |
| `aamix_redeem_code` | `p_code:text` | `already_redeemed:bool`, `reward_deck_id:'maago'` |
| `aamix_begin_match` | `p_request_id:UUID`, `p_deck_id:text` | `match_id:UUID`, `match_result:null o texto` |
| `aamix_finish_match` | `p_match_id:UUID`, `p_result:'victory' o 'defeat'` | `match_id`, `match_result` |
| `aamix_claim_daily_mission` | `{}` | `already_claimed:bool` |
| `aamix_open_pack` | `p_request_id:UUID` | `opening:{opening_id,cards:[5 códigos],opened_at,revealed_at}` |
| `aamix_acknowledge_opening` | `p_opening_id:UUID` | Inventario; quita la apertura pendiente |

`mission.id='play_one'`; el registro mostrado siempre corresponde al día actual en Chile. `pending_opening` es el mismo objeto que `opening`, o `null`. La colección ya contiene las 5 cartas cuando se devuelve la apertura. Animar no concede cantidades ni vuelve a sortear.

Conservar el UUID de cada petición al reintentar. Un nuevo cliente con otro UUID que encuentre un sobre pendiente recibe la apertura existente y su UUID también queda vinculado permanentemente a ese resultado; así sus reintentos posteriores a la confirmación no gastan un segundo sobre. Se conserva todo el historial de aperturas. Las cantidades, consumo, sorteo, guardado y recuperación son una sola transacción y están serializados por UUID.

Un recibo de partida ya terminado nunca completa la misión de otro día al reintentarlo. Otro UUID no puede utilizarlo. El mazo debe pertenecer a la cuenta. Las partidas locales contra IA se notifican desde el cliente: los recibos evitan duplicados y confusión accidental, pero **no prueban que la partida se jugó honestamente**. No hay simulación autoritativa ni validación de un historial de jugadas en el servidor. Un cliente modificado puede declarar que terminó. Si el cliente pierde un resultado local antes de notificarlo, ese resultado no se puede reconstruir en el servidor.

Errores de interfaz estables: `AAMIX_INVALID_CODE`, `AAMIX_NO_PACKS`, `AAMIX_MISSION_NOT_READY`, `AAMIX_UNOWNED_DECK`, `AAMIX_INVALID_AVATAR` (SQLSTATE 22023). Los canjes/reclamaciones ya realizados se devuelven como éxito idempotente. Las sesiones sin correo confirmado devuelven SQLSTATE 28000.

## Verificación

`test_rewards_rollback.sql` crea UUIDs aleatorios de prueba dentro de una transacción y revierte TODO al final. No borra ni modifica cuentas reales ni manda correos. Comprueba canje exacto, regalo original independiente, victoria/derrota, reintentos, día previo, avatares, RLS, escrituras denegadas, consumo atómico ante un desbordamiento provocado, apertura pendiente y 10.000 sobres sorteados por el servidor. El muestreo comprueba tolerancias amplias; las probabilidades exactas están además verificadas por los pesos del catálogo.

Las pruebas de recompensas pasaron dos veces: 20.000 sorteos en total. En la última muestra de 10.000, hubo 3.029 especiales (30,29%); los cuatro especiales del grupo de 5% sumaron 602 (6,02% de todos los sobres). También pasó la prueba anterior de colección/regalo 0.9.0 contra el backend ampliado. Las 31 cartas normales aparecieron en la posición 5. Los avisos del asesor se limitaron a tablas privadas con RLS sin políticas (denegación intencional), índices sin uso por el pequeño volumen y el aviso previo de protección de contraseñas filtradas desactivada; Auth se conservó.

La concurrencia real entre conexiones requiere una prueba aparte: dos peticiones simultáneas con la misma cuenta sintética deben dejar un único canje/reclamo y una sola apertura pendiente. La serialización está implementada con bloqueo de fila de la cartera e índices únicos; una prueba secuencial de reintentos no equivale a comprobar conexiones concurrentes.
