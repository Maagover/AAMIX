# Contrato vigente · AAMIX 0.17.0

Las migraciones **20261019123235** (códigos con Restos) y **20261019124033** (salas multijugador) están aplicadas y verificadas. Sus identidades completas y evidencias se registran en APPLIED_MIGRATIONS.json y DEPLOYMENT_v0.17.0.json. No repetirlas. El contrato económico de 0.16 y las probabilidades de sobres permanecen vigentes.

## Códigos combinados

`aamix_redeem_code(p_code)` conserva su firma y normaliza espacios y mayúsculas. Los ocho códigos anteriores y su historial permanecen. Añade AAMIX50=50 Restos, AAMIX100=100, AAMIX1000=1000 y AAMIXNAVIDAD=1 TC+50 Restos+1 sobre Carta aleatoria. Devuelve inventario completo y las claves anteriores, más `reward_restos` y `reward_normal_packs`; `reward_packs` continúa significando TC. Los valores son cero donde no corresponden.

Todos los premios y su registro `(user_id,gift_code)` comparten una transacción y el bloqueo de cartera. Antes de un código válido se garantiza la bienvenida de 100 Restos con su registro existente, sin repetirla ni conceder mazos iniciales. Los reintentos conservan cantidades y responden `already_redeemed=true`. La configuración privada permite combinar componentes de cartera; los premios de mazo/cartas sueltas siguen siendo exclusivos. Detalle en WALLET_GIFTS_v0.17.0.md. Los 12 casos de rollback pasaron.

## Multijugador privado

RPC públicos `aamix_mp_create_room`, `aamix_mp_join_room`, `aamix_mp_active`, `aamix_mp_poll`, `aamix_mp_submit`, `aamix_mp_commit` y `aamix_mp_leave`, con wrappers invoker y acceso sólo a cuentas confirmadas. No se conceden lecturas o escrituras directas sobre las tres tablas privadas con RLS. UUID del dueño se deriva del token; nunca se acepta uno elegido por el cliente como autoridad.

El anfitrión ejecuta reglas en Godot y confirma instantáneas; el servidor comprueba pertenencia, turno, revisión, orden, tamaño y privacidad básica de la vista invitada. Esta arquitectura requiere anfitrión de confianza y no es un motor competitivo autoritativo. Se usa el HTTPS existente, sin abrir puertos ni contratar otro servicio. Máximo dos jugadores por sala, una sala por cuenta, ocho salas activas, TTL dos horas, reconexión 180 segundos y retención de salas terminadas siete días.

Crear, unir y enviar acciones usan UUID y payload inmutable. Sólo una acción queda pendiente por revisión. Un resultado final genera un recibo único por sala y jugador para las misiones; no se vuelve a enviar por la cola de partidas individuales. Los recibos sobreviven a la limpieza de salas. Abandonar después de empezar entrega derrota/victoria; antes de empezar cancela sin recibo. El contrato completo está en MULTIPLAYER_v0.17.0.md. Los 25 casos SQL de rollback pasaron.

La prueba HTTPS empleó dos procesos nativos con dos cuentas sintéticas y sin correo. Cubrió 12 comandos hasta turno 5, privacidad del pago del anfitrión, reconexión y abandono con dos recibos únicos. No acredita dos computadores remotos ni una partida IA completa. Los dos fixtures se eliminaron con doble guarda por correo y qa_run exactos en la interfaz oficial autenticada de Supabase tras tres fallos del conector. Una lectura MCP posterior confirmó idénticos los hashes de campos originales de 14 tablas antes y después; sólo se excluyó la nueva columna online_room_id de los recibos. Pruebas locales: 21 casos de instantáneas MP, uno de regalos y ocho de interfaz. El total y arranque final del paquete constan en la validación de entrega.

No se modifican Auth, SMTP, claves publicables, reglas, IA, economía anterior ni premios históricos. No exponer claves administrativas. Los resultados de IA local siguen declarados por el cliente; los de salas privadas dependen de su anfitrión. No incluye ranking, emparejamiento ni draft.

Fuentes de la decisión: [plan gratuito y cuotas de Supabase](https://supabase.com/pricing), [API segura](https://supabase.com/docs/guides/api/securing-your-api), [funciones de base de datos](https://supabase.com/docs/guides/database/functions). La conexión HTTPS aprovecha el servicio disponible y evita requerir puertos entrantes o un servidor de juego adicional; no promete disponibilidad ilimitada.
