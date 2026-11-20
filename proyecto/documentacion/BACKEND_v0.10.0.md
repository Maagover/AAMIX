# Backend AAMIX 0.10.0

Proyecto existente `drpsedaiqyowwikhjugs`. Migración aplicada **20261017194519_aamix_profiles_rewards_v0100** sobre **20261017185851_aamix_collection_starter_v090**. El jugador no debe instalar ni ejecutar SQL. No reaplicar las migraciones. Auth, Brevo SMTP y las cuentas existentes se conservaron.

El contrato exacto, SQL y pruebas están en `backend/REWARDS_API.md`, `aamix_rewards.sql`, `test_rewards_rollback.sql` y `APPLIED_MIGRATIONS.json`. Se añaden tablas de perfil/cartera, canje por UUID, recibos de partida, misión por fecha chilena, aperturas persistentes y correspondencia de peticiones. Las tablas públicas sólo permiten lectura del dueño por RLS; el cliente no puede escribir cantidades, mazos o recompensas directamente. Los RPC públicos invoker llaman funciones privadas que validan UUID y correo confirmado.

RPC nuevos: `aamix_set_avatar`, `aamix_redeem_code`, `aamix_begin_match`, `aamix_finish_match`, `aamix_claim_daily_mission`, `aamix_open_pack` y `aamix_acknowledge_opening`. `aamix_inventory` conserva sus claves anteriores y añade perfil, sobres, misión, códigos ya canjeados y apertura pendiente. El regalo inicial sólo admite las tres plantillas originales; Maagover se entrega mediante su código independiente.

Los sorteos y cantidades se resuelven en el servidor, en una transacción junto con el consumo. La cartera bloqueada por UUID y las claves únicas serializan operaciones. Cada UUID de petición de apertura, incluso si sólo retoma una apertura ya existente, queda vinculado permanentemente a esas cinco cartas; un reintento posterior a la confirmación no consume otro sobre.

La misión se reinicia a las 00:00 `America/Santiago`. Victoria o derrota completan el día actual y el sobre se reclama expresamente. Un recibo finalizado no se reutiliza para completar otro día. **Las jugadas contra IA son locales; el resultado es declarado por el cliente. Los recibos no validan una partida autoritativa.** Las notificaciones de resultado aún no enviadas se conservan sólo en memoria del juego.

Verificación real: dos ejecuciones de la prueba de recompensas, 20.000 sobres en total y regresión 0.9.0 aprobadas, todo con rollback. Antes/después: 2 usuarios, 1 regalo inicial, 1 mazo, 12 filas y 40 cartas; cero usuarios de prueba y recompensas nuevas guardadas. No se enviaron correos reales. La concurrencia simultánea real entre dos clientes no se verificó; los reintentos secuenciales y revisión de bloqueos no son esa prueba.

El asesor no reportó problemas públicos de RLS. Las tres tablas privadas con RLS sin políticas son de denegación intencional y no conceden SELECT al cliente; los índices sin uso son informativos por el pequeño volumen. Se conservó el aviso previo de [protección de contraseñas filtradas desactivada](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection), sin modificar Auth.

Totales de pruebas del juego y verificación del paquete: **pendiente cierre QA**.
