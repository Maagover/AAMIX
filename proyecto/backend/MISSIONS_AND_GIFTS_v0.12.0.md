# Misiones y regalos · backend 0.12.0

**Aplicado y verificado** en el proyecto existente `drpsedaiqyowwikhjugs`: migración **20261018035100_aamix_missions_and_gifts_v0120**, el 18 de octubre de 2026 a las 03:51:00 UTC. El origen exacto es `aamix_missions_and_gifts_v0120.sql`; está congelado como se aplicó, incluido su comentario inicial de preparación. Ese comentario histórico no cambia el estado aplicado de este registro. No ejecutar de nuevo la migración.

## Misiones y progreso

| ID | Nombre | Alcance | Condición | Recompensa |
| --- | --- | --- | --- | --- |
| `play_one` | Juega 1 partida | Diaria | Terminar con victoria o derrota | 1 sobre |
| `win_one` | Gana 1 partida | Diaria | Terminar con victoria | 1 sobre |
| `play_ten` | Juega 10 partidas | Acumulativa, una vez por UUID | Diez partidas terminadas, victoria o derrota | 5 sobres |

Las dos diarias cambian a las **00:00 de America/Santiago**, con horario de verano resuelto por PostgreSQL. Se usa el día de `finished_at`, no el inicio de la partida, el reloj del cliente ni la zona de la sesión SQL. La acumulativa cuenta todas las terminadas y no se reinicia al reclamar ni por cambiar de día. Su progreso visible se limita a diez.

Se cuentan también los recibos válidos anteriores a 0.12.0: resultado `victory` o `defeat` y `finished_at` no nulo. Una misma victoria puede avanzar las tres misiones. Completar no concede automáticamente los sobres: se reclaman expresamente. Reclamar una no consume ni reinicia las otras. Reintentar el mismo final no crea otro recibo ni mueve su fecha; un recibo de ayer no completa la victoria diaria de hoy al repetirse.

**PLAY1 conserva el registro anterior** `public.aamix_daily_missions`, incluido un premio ya reclamado. La compatibilidad no duplica esa recompensa. Además puede reconocer recibos terminados del día aunque falte una fila antigua de progreso. Las nuevas victorias diarias y la acumulativa usan `public.aamix_mission_claims`, con clave única por UUID, misión y período; la acumulativa usa siempre el período `lifetime`.

## RPC y respuestas

`aamix_inventory()` conserva todas sus claves anteriores. `mission` sigue siendo el objeto de PLAY1, con `id`, `title`, `day`, `timezone`, `progress`, `target`, `claimed` y `reward_packs`.

Añade `missions`, un arreglo ordenado `play_one`, `win_one`, `play_ten`. Cada objeto incluye los mismos campos y `scope: 'daily' o 'lifetime'`. `day` es la fecha chilena actual para las diarias y `null` para la acumulativa. Recompensas: 1, 1 y 5 sobres; objetivos: 1, 1 y 10.

El RPC nuevo es **`aamix_claim_mission(p_mission_id text)`**. Devuelve todo el inventario más:

- `already_claimed`: `false` al conceder; `true` al reintentar una recompensa ya reclamada.
- `mission_id`: identificador solicitado.
- `reward_packs`: recompensa definida, incluso si `already_claimed=true`; este campo no indica un segundo incremento.

El RPC anterior `aamix_claim_daily_mission()` continúa funcionando y delega en `play_one`, usando exactamente su mismo registro de reclamo. Ambos caminos pueden alternarse sin cobrar dos veces. Identificador desconocido: `AAMIX_INVALID_MISSION`; objetivo sin completar: `AAMIX_MISSION_NOT_READY`, SQLSTATE 22023. Las sesiones sin UUID/correo confirmado se rechazan con SQLSTATE 28000.

## Regalos nuevos y compatibilidad

| Código | Entrega una vez por UUID |
| --- | --- |
| `AAMIXTC` | 1 sobre, sin cartas sueltas ni mazo |
| `M4Z0G1R4` | Mazo Girabl histórico exacto: 40 cartas, 12 Restos |

Girabl usa id `girabl`, nombre **Mazo Girabl** y portada 0127. Su lista coincide con `tests/fixtures/mazos_legacy.json`, entrada `usuario_girabl`. Las promociones legítimas de esa lista se entregan como parte del mazo; no se incorporan al grupo de sorteos ni desbloquean avatares. El mazo es obtenido/utilizable por esa cuenta; invitado, IA y regalo inicial mantienen los tres mazos base originales. Girabl no puede reclamarse mediante el RPC de regalo inicial.

`aamix_redeem_code(p_code text)` conserva firma y respuesta y añade **`reward_packs`**: 1 para AAMIXTC y 0 para los otros códigos. Los campos `reward_name`, `reward_deck_id`, `reward_cards`, `redeemed_code` y `already_redeemed` se mantienen. AAMIXTC devuelve `reward_deck_id=null` y `reward_cards=[]`; Girabl devuelve su lista completa y `reward_deck_id='girabl'`.

Los seis códigos anteriores y todos sus registros de canje se conservan: M4Z0M44G0, P3RI, B1G0T3S, SI2TYA, CHANCHULINES y TORNEOAAMIX1. La misma clave existente `(user_id,gift_code)` impide un nuevo cobro de cualquiera de ellos. Los códigos normalizan espacios exteriores y mayúsculas. Las definiciones privadas aceptan exactamente una clase de recompensa: mazo, cartas sueltas o sobres; no permiten mezclas accidentales.

## Seguridad y atomicidad

Las mutaciones conservan `lock_rewards()`, que verifica UUID/correo confirmado y bloquea la cartera de esa cuenta. Reclamo, registro único y suma de sobres son una sola transacción; también lo son canje, cantidades y mazo. Un desbordamiento o fallo revierte el registro de cobro y la recompensa completa. Ningún RPC recibe el dueño, fecha del día, cantidad de premio ni progreso desde el cliente.

La nueva tabla pública permite sólo SELECT del UUID propio mediante RLS; INSERT/UPDATE/DELETE del cliente están revocados. Los RPC públicos son invoker; las escrituras privilegiadas quedan en funciones privadas con `search_path=''`. El ayudante privado `missions_status()` es invoker de sólo lectura, sin parámetros de dueño o fecha. Auth, SMTP y cuentas no se reconfiguraron.

Las partidas contra IA siguen siendo locales y su resultado es declarado por el cliente. Contar recibos no valida las jugadas ni demuestra una partida honesta. La cola de resultados no enviados sigue sólo en memoria; el resultado puede perderse al cerrar antes de notificarlo. El sorteo de sobres continúa en el servidor y una apertura ya guardada sí se recupera.

## Verificación realizada

`test_missions_and_gifts_v0120_rollback.sql` **pasó en la base real**, incluidas misiones retroactivas, independencia de los tres reclamos, conservación del premio PLAY1 anterior, 20 reintentos por operación, acumulativa en partidas 9→10→11, medianoche chilena con sesión SQL en Honolulu, cantidades Girabl exactas, AAMIXTC, canjes antiguos, UUIDs aislados, rechazos de Auth, RLS y desbordamientos provocados. Se sortearon **1.000 sobres sin promocionales**. Toda la transacción se revirtió.

También pasó `test_gift_codes_v0110_rollback.sql`, adaptado por el responsable para esperar ocho definiciones en lugar de seis, con otros **1.000 sobres**. Son **2.000 sorteos verificados en esta entrega**, además de las comprobaciones de premios. La lista Girabl del servidor se comparó independientemente con el fixture histórico: coincidencia exacta, 40/12.

Antes y después de QA se mantuvieron **85 cartas, 2 mazos, 1 canje y 1 recibo terminado** en las cuentas reales. Quedaron cero nuevos reclamos de misión y cero usuarios de prueba. No se consumieron recompensas reales ni se enviaron códigos de correo de prueba. No se verificó una carrera simultánea real entre dos clientes; los reintentos y bloqueos revisados no equivalen a esa prueba.

El asesor no reportó problemas públicos de RLS. Cinco tablas privadas con RLS sin políticas corresponden a denegación intencional sin acceso del cliente. La advertencia previa de [protección de contraseñas filtradas desactivada](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection) se conserva; Auth no se modificó. El registro de despliegue y resultados está en `DEPLOYMENT_v0.12.0.json`.
