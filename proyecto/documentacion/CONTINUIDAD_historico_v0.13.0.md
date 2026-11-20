# CONTINUIDAD · AAMIX 0.13.0

18 de octubre de 2026, Chile. Entrega actual: **AAMIX_Prototipo_Local_Windows_v0.13.0.zip**, carpeta **AAMIX_Prototipo_Local_v0.13.0/**. Base **BASE_DEL_PROYECTO_v1.9.md**, sección 21; prompt **PROMPT_CONTINUIDAD.md**. Nueva estética clara y envoltorio real de Transmisión Caída. **Verificación 0.13.0: 376 comprobaciones aprobadas en Windows, cero fallos; capturas revisadas.** Consultar VALIDACION_v0.13.0.md; la comprobación del ZIP final se registra en INFORME_ENTREGA. No hay backend ni migraciones nuevas en esta etapa.

La base 1.8 y la continuidad, prompt, README y LEEME de 0.12.0 quedan conservados como historia. La sección 21 reemplaza el fondo global de cuero y los controles oscuros, e integra los nueve originales del autor y el sobre real. Se conservan colección 35+6, 22 retratos, tres misiones, ocho códigos y las probabilidades/exclusión promocional de sobres.

## Decisiones más recientes del autor

**Estética 0.13.0:** fondo global blanco y tonos claros. Botones y paneles usan las imágenes blanca/dorada/café aportadas por el autor, con oro #fcdb7f/#cfb56b y café #956f4b/#7d5f42 como referencias. Textos, campos, estados, indicadores, avisos y confirmación de salida deben conservar contraste. La madera se usa en la partida, presentada opaca conservando RGB y sin editar el PNG. Las zonas, controles, arrastres y reglas de la mesa se conservan.

La expansión N.º 1 se llama **Transmisión Caída**. Su sobre mantiene el conjunto de 35 cartas no promocionales. El nombre no añade una segunda edición ni cambia cantidades, efectos o probabilidades.

Inicio: el sobre cerrado real de Transmisión Caída flota detrás del logo junto a las dos cartas existentes, Transmisión Caída y Restos. El logo sigue delante, con movimiento menor; el conjunto queda a la derecha. No hay giro ni cambio de frente/dorso. Sin el subtítulo antiguo, se usa «AAMIX · versión 0.13.0» en pie/título. Se conservan accesos y confirmación de salida.

Mi Colección separa 35 regulares en flujo centrado y seis promocionales al final en una sola fila centrada, con divisor visible. Conserva cantidades, faltantes y doble clic. Mis Mazos muestra «Obtenido · 40 cartas» y Ver lista, sin «guardado en tu cuenta».

Misiones y Mis sobres usan filas alineadas a la izquierda. La misión reúne estado de completada, imagen, título y recompensa, con progreso y acción a la derecha. El sobre muestra la expansión, cantidad y apertura. La apertura y las cartas reveladas siguen centradas; la colección y la selección de mazo centran sus grupos de cartas.

Código de regalo es un formulario mínimo con entrada y Canjear. No añadir a esa pantalla una tabla de códigos, instrucciones técnicas o un catálogo de recompensas. La confirmación debe usar los datos del regalo realmente canjeado, incluidas cartas sueltas.

## Recursos y apertura 0.13.0

Los nueve PNG originales se conservan byte por byte en assets/estetica/: tres botones, tres paneles, mesa_madera.png, sobre_cerrado.png y sobre_abierto.png. PROCEDENCIA.json registra dimensiones/hashes y RECURSOS_GRAFICOS.md explica su integración actual. Los recortes, escalas y opacidad pertenecen a la presentación; no editar ni regenerar esos bitmaps.

Misiones y Mis sobres muestran el sobre cerrado real. Al abrir, el gesto pasa del cerrado al abierto con fundido, destello y sonido; luego se deslizan cinco cartas. Cambiar arte, actualizar o volver durante la transición debe conservar el estado local de apertura y el resultado ordenado ya guardado. La animación no concede ni sortea, no consume otro sobre y conserva peticiones/confirmaciones idempotentes.

## Fotos de perfil

**22 Aliados no promocionales** disponibles sin requerir posesión. El selector y la previsualización muestran sólo imágenes, sin nombres debajo; tooltips conservan los nombres. Se retiró la etiqueta «Tu foto de perfil» de Mi cuenta. Dicky, Maagover y Girabl tienen encuadres revisados del rostro desde las imágenes originales.

**Las promocionales no están disponibles como foto**, aunque estén en la colección. Se reservan para futuros desbloqueos aún no implementados. Cliente y servidor rechazan nuevas selecciones promocionales; el cliente muestra silueta si recibe una foto promocional histórica. No se resetean perfiles guardados ni se borran cartas de colección. Los recortes no modifican los archivos de las cartas.

## Códigos confirmados

Una vez por cuenta/UUID y código, independientemente de los otros canjes y del regalo inicial. No son diarios. Se normalizan mayúsculas y espacios exteriores.

| Código exacto | Recompensa |
| --- | --- |
| M4Z0M44G0 | Mazo Maagover histórico exacto: 40 cartas y 15 Restos; conserva la promoción legítima 01c. |
| P3RI | 3 Peri (01a); sin cero al final. |
| B1G0T3S | 3 Bigotes (01b). |
| SI2TYA | 1 Tsuki y Akira (01c). |
| CHANCHULINES | 1 Granjita de Chanchuus (01d). |
| TORNEOAAMIX1 | 1 Dragón Tee K.O (01e). |
| AAMIXTC | 1 sobre Transmisión Caída, guardado en Mis sobres. |
| M4Z0G1R4 | Mazo Girabl histórico exacto, 40 cartas / 12 Restos; id girabl, portada 0127. |

Los cinco códigos promocionales de 0.11.0 siguen añadiendo sólo sus cartas. AAMIXTC suma un sobre sin abrirlo automáticamente; M4Z0G1R4 añade el mazo y sus cantidades exactas. Girabl conserva la lista `usuario_girabl` de tests/fixtures/mazos_legacy.json: 40/12, incluidas 3 Peri, 2 Bigotes y 1 Tsuki y Akira. Las promociones son válidas en ese mazo; no entran por ello en sobres ni desbloquean retratos. El regalo no añade Girabl al invitado o a la IA. No reiniciar el canje histórico de Maagover ni el regalo inicial. El regalo inicial real elegido previamente por el autor se conserva; no afirmar que continúa sin reclamar.

## Sobres conservados y tres misiones

Catálogo de 41 cartas, seis promociones fuera de sobres en cualquier posición. Elegibles: **35 cartas, 1 Recurso, 25 normales y 9 Especiales**. Posición 1: Recurso no promocional garantizado, actualmente Restos 0100. Posiciones 2–4: normales uniformes y repetibles. Posición 5: normal 70% / Especial 30%. Nunca hay Recursos en las posiciones 2–5. La exclusión promocional prevalece incluso ante cambios de tipo/rareza.

Dentro de Especiales: Kajido 0105, SoyFlaan 0103, Papito 0115 y Transmisión Caída 0119 tienen 5% cada uno; Guitarramala 0134, HNyko 0128, Chanchuus 0125, Escuela de Vuelo 0131 y Serandimini 0130 tienen 16% cada uno. Equivalen a 1,5% o 4,8% total por sobre por carta. Son decisiones confirmadas, no preguntas pendientes.

Juega 1 partida mantiene un sobre diario por terminar, con victoria o derrota. Gana 1 partida concede otro sobre diario por victoria. Juega 10 partidas concede cinco sobres una vez por cuenta, con progreso acumulativo de por vida. Las diarias se reinician **00:00 America/Santiago** según servidor; la acumulativa no. Una victoria puede completar ambas diarias, con reclamos separados. El progreso usa recibos finalizados, incluidos los anteriores; se conserva el registro histórico de Juega 1 partida. El resultado de la IA local lo declara el cliente; no hay historial de jugadas validado en el servicio. La cola de resultados no enviados vive sólo en memoria: conservar el juego abierto y reintentar. Cerrar/cambiar cuenta antes de enviarlos los pierde.

La apertura ya guardada sí persiste: sorteo, consumo de sobre, cantidades y orden se confirman en una transacción antes de animar. Reingresar recupera el mismo resultado pendiente sin consumir otro sobre. Confirmar tras revelar las cinco cartas.

## Backend vigente: sin despliegue nuevo en 0.13.0

**La estética no modifica el servicio.** Se conservan firmas de RPC, inventario, concesiones, sorteos, persistencia e idempotencia. No aplicar SQL ni repetir pruebas que consuman recompensas reales para cambiar imágenes. Lo siguiente documenta el backend ya aplicado en etapas anteriores; sus cifras son históricas.

Se conserva el Supabase **drpsedaiqyowwikhjugs**, Auth y Brevo SMTP. La integración histórica de 0.12.0 usa `aamix_missions_and_gifts_v0120.sql` y `test_missions_and_gifts_v0120_rollback.sql`; añade tres misiones, premio de sobre por código y el Girabl exacto sin recrear el servicio. La migración **20261018035100_aamix_missions_and_gifts_v0120** está aplicada y su prueba real pasó con rollback. Se verificaron las tres misiones, progreso anterior, reclamos independientes/históricos, medianoche Chile con sesión Honolulu, reintentos, los ocho códigos y autorización/RLS. La prueba nueva y una prueba compatible de 0.11.0 adaptada sumaron 2.000 sobres sin promociones, todos revertidos. Girabl del servidor coincidió con la lista 40/12; cero cuentas QA y datos reales: 85 cartas/dos mazos/un canje/un recibo conservados. Consultar DEPLOYMENT_v0.12.0.json y APPLIED_MIGRATIONS.json. Lo siguiente describe las migraciones históricas verificadas de 0.11.0. **20261018031742_aamix_gift_codes_and_avatar_lock_v0110** está aplicada. Añade configuración privada de códigos y restricción de fotos no promocionales, conservando firmas de RPC. No cambia el sorteo ni recrea usuarios/SMTP; los canjes y cantidades legítimas permanecen.

`test_gift_codes_v0110_rollback.sql` pasó en el servicio real con cuentas sintéticas: cinco códigos nuevos y cantidades exactas, 20 reintentos por código, Maagover 40/15 y canje histórico, separación por UUID, correo confirmado y rechazo de acceso no autorizado, rollback atómico por desbordamiento, rechazo de retratos promocionales poseídos y 1.000 sobres sin promociones. Todo el ensayo se revirtió. No es una prueba de correo real ni de dos clientes simultáneos.

El índice posterior **20261018032104_aamix_gift_codes_index_v0110** también está aplicado. Consultar **backend/APPLIED_MIGRATIONS.json** para el historial exacto de ambas migraciones y **backend/DEPLOYMENT_v0.11.0.json** para el despliegue completo. La comprobación posterior confirmó cero cuentas de QA y la colección real existente conservó sus 85 cartas. No repetir las migraciones de 0.9.0, 0.10.0, 0.10.1 ni la nueva de 0.11.0. La corrección histórica de una promoción de sobre se documenta en la base 1.6; ya fue aplicada y no autoriza nuevas reparaciones.

RLS y funciones privadas verifican el UUID real y correo confirmado; el cliente no escribe cantidades ni elige el sorteo. URL y clave publicable son la configuración pública; nunca incluir service_role, SMTP secreto, códigos reales ni tokens. Sesiones y datos privados de acceso viven sólo en memoria.

## Estado del juego y archivos

Godot 4.7.2 oficial Windows x86_64 incluido. Partidas individuales contra IA local. Reglas, mesa, arrastres, textos de cartas y recursos originales se conservan. Hay 31 efectos soportados y diez pendientes entre las 41 cartas; obtener una carta no programa su efecto.

Invitado e IA conservan Kajido, Papito y Flaan; cuentas sólo usan mazos obtenidos. Se mantienen Salir sólo en Inicio con confirmación, Tu turno/Turno rival tras robo, Pasar daño, cartas obtenidas, regalo con sonido y Victoria/Derrota centrado con Revancha/Inicio y sin Ver mesa.

main.gd integra pantallas; game.gd reglas; ai.gd rival; account.gd Auth; collection.gd inventario/RPC. profile_ui.gd y avatar_view.gd retratos; home_cards.gd inicio; rewards_ui.gd recompensas; pack_reveal.gd apertura; sound.gd audio. SQL aditivo y pruebas de canjes en backend/aamix_gift_codes_v0110.sql y test_gift_codes_v0110_rollback.sql. data/codigos_regalo.json es informativo; no concede premios localmente.

## Validación, entrega y continuación

**Verificación 0.13.0: 376 comprobaciones aprobadas en Windows, cero fallos; capturas revisadas.** Ver VALIDACION_v0.13.0.md para originales, carga runtime, contraste, madera, sobre flotante y apertura/reanudación sin mutar inventario. El test focalizado tests/test_aesthetic_v013.gd utiliza datos ficticios y no hace HTTP, Auth ni SQL. La extracción/integridad/arranque del ZIP final se registra en INFORME_ENTREGA.

**Historia 0.12.0:** 582 comprobaciones únicas, 48 partidas completas contra IA y 2.000 sobres SQL con rollback. No se consideran reejecutados en 0.13.0 ni se suman a sus resultados.

0.11.0 tuvo 336 comprobaciones y 21 partidas; no se suman a 0.13.0. 0.10.1 tuvo 155 comprobaciones y 21 partidas; 0.10.0 tuvo 1.050 y 214. Sus informes y capturas son historia. La concurrencia real de dos clientes, una nueva entrega/reingreso por correo, multijugador, constructor, intercambios, diez efectos, guardado de partidas y desbloqueos promocionales permanecen pendientes salvo nueva evidencia registrada.

La entrega debe incluir motor, fuentes, assets, lanzador, base 1.9 y continuidad. Probar extracción, manifiesto e inicio en carpeta nueva sin caché; no incluir temporales ni credenciales. Continuar desde la próxima indicación del autor, conservando las decisiones ya confirmadas y distinguiendo implementación, pruebas y pendientes.
