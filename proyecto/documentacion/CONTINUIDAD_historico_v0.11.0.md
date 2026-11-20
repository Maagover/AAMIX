# CONTINUIDAD · AAMIX 0.11.0

18 de octubre de 2026, Chile. Entrega actual: **AAMIX_Prototipo_Local_Windows_v0.11.0.zip**; carpeta **AAMIX_Prototipo_Local_v0.11.0/**. Base vigente: **BASE_DEL_PROYECTO_v1.7.md**, sección 19. Prompt: **PROMPT_CONTINUIDAD.md**. Backend nuevo aplicado y probado con rollback. **336 comprobaciones y 21 partidas simuladas aprobadas en Windows, cero fallos**; importación e interfaz real verificadas. Consultar VALIDACION_v0.11.0.md para el desglose e INFORME_ENTREGA para la extracción, integridad y arranque del ZIP final.

La base 1.6 y la continuidad, prompt, README y LEEME de 0.10.1 quedan conservados como historia. La sección 19 prevalece sobre la disponibilidad histórica de 27 retratos y sobre el inicio giratorio. La exclusión absoluta de promociones y las probabilidades de la sección 18 siguen vigentes.

## Decisiones más recientes del autor

La expansión N.º 1 se llama **Transmisión Caída**. Su sobre mantiene el conjunto de 35 cartas no promocionales. El nombre no añade una segunda edición ni cambia cantidades, efectos o probabilidades.

Inicio: dos cartas de frente, Transmisión Caída y Restos, flotan suavemente detrás del logo AAMIX fijo; el conjunto gráfico queda a la derecha. No hay giro frente/dorso del logo ni de esas cartas. El resto de accesos y la confirmación de salida se conservan.

Misiones y Mis sobres usan filas alineadas a la izquierda. La misión reúne estado de completada, imagen, título y recompensa, con progreso y acción a la derecha. El sobre muestra la expansión, cantidad y apertura. La apertura y las cartas reveladas siguen centradas; la colección y la selección de mazo centran sus grupos de cartas.

Código de regalo es un formulario mínimo con entrada y Canjear. No añadir a esa pantalla una tabla de códigos, instrucciones técnicas o un catálogo de recompensas. La confirmación debe usar los datos del regalo realmente canjeado, incluidas cartas sueltas.

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

Los cinco nuevos códigos añaden sólo sus cartas a la colección: no un mazo, un sobre ni un desbloqueo de foto. La promoción obtenida no entra por ello al grupo de sobres. No reiniciar el canje histórico de Maagover ni el regalo inicial. El regalo inicial real elegido previamente por el autor se conserva; no afirmar que continúa sin reclamar.

## Sobres y misión conservados

Catálogo de 41 cartas, seis promociones fuera de sobres en cualquier posición. Elegibles: **35 cartas, 1 Recurso, 25 normales y 9 Especiales**. Posición 1: Recurso no promocional garantizado, actualmente Restos 0100. Posiciones 2–4: normales uniformes y repetibles. Posición 5: normal 70% / Especial 30%. Nunca hay Recursos en las posiciones 2–5. La exclusión promocional prevalece incluso ante cambios de tipo/rareza.

Dentro de Especiales: Kajido 0105, SoyFlaan 0103, Papito 0115 y Transmisión Caída 0119 tienen 5% cada uno; Guitarramala 0134, HNyko 0128, Chanchuus 0125, Escuela de Vuelo 0131 y Serandimini 0130 tienen 16% cada uno. Equivalen a 1,5% o 4,8% total por sobre por carta. Son decisiones confirmadas, no preguntas pendientes.

Juega 1 partida requiere terminar contra la IA con victoria o derrota; reclamar concede un sobre por cuenta/día, reinicio **00:00 America/Santiago** según servidor. El resultado de la IA local lo declara el cliente; no hay historial de jugadas validado en el servicio. La cola de resultados no enviados vive sólo en memoria: conservar el juego abierto y reintentar. Cerrar/cambiar cuenta antes de enviarlos los pierde.

La apertura ya guardada sí persiste: sorteo, consumo de sobre, cantidades y orden se confirman en una transacción antes de animar. Reingresar recupera el mismo resultado pendiente sin consumir otro sobre. Confirmar tras revelar las cinco cartas.

## Backend y aplicación real

Se conserva el Supabase **drpsedaiqyowwikhjugs**, Auth y Brevo SMTP. **20261018031742_aamix_gift_codes_and_avatar_lock_v0110** está aplicada. Añade configuración privada de códigos y restricción de fotos no promocionales, conservando firmas de RPC. No cambia el sorteo ni recrea usuarios/SMTP; los canjes y cantidades legítimas permanecen.

`test_gift_codes_v0110_rollback.sql` pasó en el servicio real con cuentas sintéticas: cinco códigos nuevos y cantidades exactas, 20 reintentos por código, Maagover 40/15 y canje histórico, separación por UUID, correo confirmado y rechazo de acceso no autorizado, rollback atómico por desbordamiento, rechazo de retratos promocionales poseídos y 1.000 sobres sin promociones. Todo el ensayo se revirtió. No es una prueba de correo real ni de dos clientes simultáneos.

El índice posterior **20261018032104_aamix_gift_codes_index_v0110** también está aplicado. Consultar **backend/APPLIED_MIGRATIONS.json** para el historial exacto de ambas migraciones y **backend/DEPLOYMENT_v0.11.0.json** para el despliegue completo. La comprobación posterior confirmó cero cuentas de QA y la colección real existente conservó sus 85 cartas. No repetir las migraciones de 0.9.0, 0.10.0, 0.10.1 ni la nueva de 0.11.0. La corrección histórica de una promoción de sobre se documenta en la base 1.6; ya fue aplicada y no autoriza nuevas reparaciones.

RLS y funciones privadas verifican el UUID real y correo confirmado; el cliente no escribe cantidades ni elige el sorteo. URL y clave publicable son la configuración pública; nunca incluir service_role, SMTP secreto, códigos reales ni tokens. Sesiones y datos privados de acceso viven sólo en memoria.

## Estado del juego y archivos

Godot 4.7.2 oficial Windows x86_64 incluido. Partidas individuales contra IA local. Reglas, mesa, arrastres, textos de cartas y recursos originales se conservan. Hay 31 efectos soportados y diez pendientes entre las 41 cartas; obtener una carta no programa su efecto.

Invitado e IA conservan Kajido, Papito y Flaan; cuentas sólo usan mazos obtenidos. Se mantienen Salir sólo en Inicio con confirmación, Tu turno/Turno rival tras robo, Pasar daño, cartas obtenidas, regalo con sonido y Victoria/Derrota centrado con Revancha/Inicio y sin Ver mesa.

main.gd integra pantallas; game.gd reglas; ai.gd rival; account.gd Auth; collection.gd inventario/RPC. profile_ui.gd y avatar_view.gd retratos; home_cards.gd inicio; rewards_ui.gd recompensas; pack_reveal.gd apertura; sound.gd audio. SQL aditivo y pruebas de canjes en backend/aamix_gift_codes_v0110.sql y test_gift_codes_v0110_rollback.sql. data/codigos_regalo.json es informativo; no concede premios localmente.

## Validación, entrega y continuación

**Verificación 0.11.0: 336 comprobaciones, cero fallos y 21 partidas simuladas** con el motor Windows incluido. UI nueva 61, perfiles 48, presentación 40, Maagover 64, recompensas nuevas 71 y flujo anterior de recompensas 52. La importación pasó; las interfaces nuevas y los retratos se verificaron en ventana real. La repetición sin interfaz de las 71 de recompensas se registra aparte y no se suma. Detalle en VALIDACION_v0.11.0.md; el cierre portátil se consulta en INFORME_ENTREGA, sin anticipar la extracción/arranque del ZIP final.

0.10.1 tuvo 155 comprobaciones y 21 partidas; 0.10.0 tuvo 1.050 y 214. Sus informes y capturas son historia. La concurrencia real de dos clientes, una nueva entrega/reingreso por correo, multijugador, constructor, intercambios, diez efectos, guardado de partidas y desbloqueos promocionales permanecen pendientes salvo nueva evidencia registrada.

La entrega debe incluir motor, fuentes, assets, lanzador, base 1.7 y continuidad. Probar extracción, manifiesto e inicio en carpeta nueva sin caché; no incluir temporales ni credenciales. Continuar desde la próxima indicación del autor, conservando las decisiones ya confirmadas y distinguiendo implementación, pruebas y pendientes.
