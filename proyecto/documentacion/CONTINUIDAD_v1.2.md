# Continuidad · AAMIX 1.2.0

Base exacta: ZIP oficial publicado 1.1.0, que continúa el ZIP oficial 1.0. Desarrollo editable: work/AAMIX_v1.2. No reconstruir desde prototipos. No modificar sources/, versiones anteriores ni sus entregas.

## Cambios vigentes

La pantalla Multijugador muestra el icono de espadas centrado encima del título. Se conservan las salas privadas, revisiones, UUID, ocultamiento rival, protocolo 3 y velocidad normal de animación.

El constructor tiene un solo botón Elegir diseño, una miniatura y el nombre de la portada elegida. Guardar y usar y Guardar borrador abren la galería antes de persistir. Cancelar o Escape conserva el formulario. Elegir mientras se construye cambia sólo la selección local. Los guardados ambiguos mantienen su UUID y payload congelados: el reintento no vuelve a preguntar diseño ni duplica el mazo.

Diez PNG nuevos en assets/estetica_v120, generados con image_gen integrado a partir de las ilustraciones y las cinco portadas originales. Los originales permanecen intactos. Todos usan caja oscura mate texturada, borde bronce y el mismo encuadre. deck_art.gd aplica AtlasTexture con FRAME Rect2(236,115,800,1060) para excluir márgenes casi transparentes residuales sin editar los PNG. La geometría visible se revisó para las diez imágenes. Prompts completos: assets/estetica_v120/PROMPTS.json.

Los cinco mazos base conservan su portada fija renovada y siguen siendo inmutables. Para personalizados hay dos diseños gratuitos: custom_transmision y custom_restos. Tres diseños adicionales se desbloquean sólo por código: SI2MAZO → custom_tsuki_akira, CHANCHUMAZO → custom_chanchuus, VIBMAZO → custom_viborin. No exigen poseer la carta ilustrada. Los códigos no entregan cartas, sobres ni Restos. La galería sólo muestra diseños disponibles para la cuenta.

## Backend aplicado

Migración nueva 20261020033149 aamix_deck_designs_v120, posterior a 20261020022913. No repetir ninguna. Leer backend/DEPLOYMENT_v1.2.json y aamix_deck_designs_v120.sql. No ejecutar admin_reset_progress_v100.sql: no hubo otro reinicio de progreso.

gift_code_rewards.deck_design configura premios exclusivamente cosméticos. aamix_code_redemptions.deck_design guarda el diseño concedido como snapshot permanente por UUID y código. Cambiar o retirar la definición del código no revoca ni cambia un diseño ya obtenido. Las filas históricas quedan con NULL, sin cambiar recompensas previas. No hay escritura directa del cliente sobre este registro.

La función privada deck_designs_inventory() deriva exclusivamente auth.uid(), sin aceptar UUID ajeno. aamix_inventory añade available_custom_covers y unlocked_deck_designs; los campos antiguos conservan sus contratos. save_custom_deck valida el desbloqueo incluso para borradores y devuelve AAMIX_DECK_COVER_LOCKED si falta. Se mantienen transacciones, idempotencia, revisión optimista y listas congeladas al comenzar partidas.

Se conservaron las cuatro cuentas existentes. Dos cuentas del ensayo SQL se revirtieron por ROLLBACK. Una cuenta sintética para HTTPS se eliminó junto con sesiones, mazos y registros de prueba; sus credenciales no se distribuyen. No se enviaron correos ni se probaron accesos de jugadores reales.

## Reglas y distribución

Exactamente 40 cartas para jugar, incluyendo al menos un Restos como Recurso inicial. Borradores de 0 a 40 no jugables. Máximo 3 copias por carta, Singular 1 incluso promocionales, Recursos sin ese límite pero sujetos a cantidad poseída y total 40. Guardar no consume cartas. Mis Mazos conserva elementos cuadrados centrados, Ver Mazo, creación y edición sólo de personalizados. No cambiar listas base, economía, sobres, misiones, reglas ni efectos históricos.

Juego 1.2.0, presentación 1.2, Godot 4.7.2 incluido, user://AAMIX estable. Se conservan byte por byte los ejecutables de 1.1: el iniciador blanco sigue con versión de archivo 1.1.0.0; el juego indica 1.2.0 en su proyecto e interfaz. El motor conserva su firma original válida. El instalador amarillo y los auxiliares propios siguen sin firma digital. minimum_launcher 1 y protocolo de actualización 1. Consultar SEGURIDAD_WINDOWS_v1.2.md: SmartScreen puede seguir mostrando editor desconocido, aunque el análisis local de Defender de los cuatro ejecutables no detectó amenazas.

Publicación autorizada: v1.2.0 con ZIP completo nuevo, AAMIX_Instalador.exe estable, aamix-update.json y SHA256SUMS.txt. Conservar v1.0.0 y v1.1.0 intactas. Enlaces permanentes mediante releases/latest/download. Incluir siempre motor/ y proyecto/ junto al iniciador.

## Validación de esta versión

23 comprobaciones funcionales de interfaz, 6 capturas revisadas en Claro/Oscuro, 10 portadas revisadas y validadas, 17 grupos SQL en transacción revertida y 10 comprobaciones HTTPS reales con una cuenta sintética. Cero sorteos repetidos. Los resultados de 1.1 son históricos y no se suman a estos. La prueba visual aislada del sandbox mostró un aviso de almacén de certificados; la prueba HTTPS fuera de ese aislamiento pasó sin aviso ni errores. No se cambiaron verificaciones TLS.

La validación del ZIP, publicación y actualización real desde 1.1 con el instalador estable se registra por separado en entregas/AAMIX_v1.2_publicacion. No se probó con dos PCs remotos ni se midió latencia; no se repitió la batería de WebSocket. El anfitrión sigue ejecutando reglas y debe mantener abierto el juego.

Pendientes conservados: diez efectos de cartas catalogadas, intercambios, reanudar individuales, ranking, emparejamiento público y arbitraje competitivo independiente.
