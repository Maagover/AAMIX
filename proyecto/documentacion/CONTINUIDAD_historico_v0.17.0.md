# CONTINUIDAD · AAMIX 0.17.0

19 de octubre de 2026, Chile. Continuar sobre AAMIX_Prototipo_Local_v0.17.0 completo, sin reconstruir versiones anteriores. Leer README, VERSION.json, la sección 25 de BASE_DEL_PROYECTO_v1.13.md y los registros de despliegue. Las aclaraciones posteriores del autor prevalecen. La instrucción histórica de no avanzar multijugador fue reemplazada por su solicitud explícita de esta versión.

## Cambios de presentación y códigos

RestosArt utiliza `assets/estetica_v017/restos.png`, copia byte a byte de `D:/Maago/streams/item_0234.png`, 160 × 160, SHA-256 `7a78a265fe62649581728d660a00cc774f5791fe8a592d4f29aed827d3d15aac`. La imagen anterior permanece en estetica_v016. No generar ni retocar la imagen suministrada para actualizar esta referencia.

Inicio principal: Partida individual, Multijugador, Mi Colección, Misiones. Tienda está arriba junto a Código de regalo y Configuración. Tienda ordena por precio ascendente y, dentro de cada precio, número de carta ascendente; 30 cartas a 150 y cuatro Singulares a 500, sin Recurso/promociones. Saldo, confirmación, UUID de compra y economía anteriores se conservan.

Hay 12 códigos: ocho anteriores y AAMIX50=50 Restos, AAMIX100=100, AAMIX1000=1000, AAMIXNAVIDAD=1 TC+50 Restos+1 sobre de Carta aleatoria. El popup usa imágenes y cantidades de todos los componentes. La configuración del servidor añade restos y normal_packs con cero por defecto; premios de mazo/cartas mantienen su exclusividad. El bloqueo de cartera y la bienvenida de 100 se comparten con compras y misiones. El canje no concede un mazo inicial oculto.

## Multijugador vigente

Beta entre amigos mediante HTTPS RPC de Supabase ya existente, sin nuevo servidor contratado ni puertos entrantes. Dos cuentas confirmadas, mazos propios de 40 cartas, sala privada con código de ocho caracteres, una sala por UUID, ocho salas activas como máximo. El anfitrión debe mantener el programa abierto. Plazo de reconexión: 180 segundos; TTL de sala: dos horas. No incluye ranking, emparejamiento público ni draft.

El motor local del anfitrión ejecuta las mismas reglas de game.gd. No existe una simulación competitiva autoritativa en SQL; se acepta anfitrión de confianza. Tres tablas privadas con RLS y sin acceso directo guardan sala, ocupación y comandos. Wrappers públicos invoker llaman a operaciones privadas con comprobación de identidad, pertenencia y revisiones. El invitado recibe una instantánea filtrada, sin manos rivales, contenido real de mazos, colas ni RNG. El anfitrión recibe estado completo para recuperar la partida.

Cada comando usa UUID, revisión esperada y actor. Sólo una acción queda pendiente por revisión; el commit del anfitrión consume esa acción una vez. Un error permanente se recupera con poll, sin reintentar indefinidamente un commit obsoleto. El pago pendiente del anfitrión se oculta al invitado mientras la carta sigue en su mano. El resultado terminal genera un recibo por jugador, válido para misiones; no se vuelve a enviar por la cola de partidas individuales. Salas completadas se retienen siete días; sus recibos permanecen.

La cuota gratuita es un límite externo, no una garantía de capacidad. Decisión y restricciones en backend/MULTIPLAYER_v0.17.0.md; [precios de Supabase](https://supabase.com/pricing) y [API segura](https://supabase.com/docs/guides/api/securing-your-api). No sustituir por infraestructura de pago sin solicitud del autor.

## Backend y pruebas

Migraciones nuevas aplicadas: **20261019123235**, códigos con Restos, y **20261019124033**, multijugador privado. Consultar APPLIED_MIGRATIONS.json y DEPLOYMENT_v0.17.0.json antes de operar. No repetir migraciones, modificar Auth/SMTP ni exponer claves administrativas.

SQL: 12 casos de regalos y 25 de multijugador aprobados con rollback. Cliente: 21 casos de instantáneas MP, uno de regalos y ocho de interfaz aprobados. Prueba HTTPS real con dos procesos nativos y dos cuentas sintéticas sin correo: 12 comandos, turno 5, pago del anfitrión privado, reconexión del invitado y abandono que creó dos recibos únicos. No fue una partida IA completa ni prueba entre computadores remotos.

Cierre administrativo confirmado: las dos cuentas sintéticas se eliminaron mediante DELETE con doble guarda por correo y qa_run exactos en la interfaz oficial autenticada de Supabase, después de tres fallos Invalid or expired requestState del conector. Una lectura MCP posterior confirmó idénticos los hashes de campos originales de 14 tablas antes y después; sólo se excluyó la nueva columna online_room_id de aamix_match_receipts. No se alteraron datos originales de jugadores.

La fuente tiene 77 casos aprobados: 37 SQL, 21 de instantáneas MP, uno de regalos, ocho UI y diez escenarios nativos. Los seis casos adicionales del paquete portátil y el total final de 83 se registran en el informe de cierre; esta nota no acredita por anticipado su ejecución. No sumar casos históricos ni contar reintentos como casos nuevos. Mantener pruebas acotadas; el autor pidió evitar matrices y ensayos masivos.

## Elementos conservados

100 Restos de bienvenida por cuenta, misiones 0.16, ambos sobres e idempotencia, cinco niveles y premios únicos, temas, audio, reglas, IA y originales. Las diarias siguen en America/Santiago. No borrar pagos históricos ni volver a pagar logros únicos. Música de menú suministrada y pistas de batalla anteriores sin cambios. El ZIP 0.16.0 y documentos históricos se conservan. Entregar versiones completas con motor, recursos, fuente y documentación; no editar sources/.
