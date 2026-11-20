# CONTINUIDAD · AAMIX 0.10.0

Fecha: 17 de octubre de 2026. Entrega actual: **AAMIX_Prototipo_Local_Windows_v0.10.0.zip**. Base vigente: **BASE_DEL_PROYECTO_v1.5.md**, sección 17. Prompt vigente: **PROMPT_CONTINUIDAD.md**. Totales de comprobaciones del juego y verificación final del paquete: **1050 comprobaciones y 214 partidas simuladas aprobadas nativamente en Windows; extracción, manifiesto y arranque del paquete portátil verificados**.

## Estado del juego

Juego individual contra IA local, Godot 4.7.2 oficial para Windows x86_64 incluido. Se conservan las reglas, IA, arrastres, mesa, imágenes, música y datos originales. Hay 41 cartas catalogadas; 31 tienen efectos soportados y diez todavía no. Poder obtener una carta en colección o sobre no significa que su efecto esté implementado. No hay multijugador, constructor, intercambios ni guardado de partidas.

Se mantienen el acceso por correo/código, invitado, colección remota por UUID, regalo inicial único y Mis Mazos de 0.9.0. El invitado y la IA continúan con Kajido, Papito y Flaan. Una cuenta sólo juega con mazos obtenidos; el nuevo Mazo Maagover también aparece al adquirirlo por código. El regalo inicial real ya elegido por el autor se conserva. No se vuelve a prometer que está pendiente para su cuenta.

## Cambios de esta entrega

- Salir sólo en el inicio; confirmación «¿Seguro que quieres salir?» y Confirmar/Cancelar, también al cerrar la ventana.
- Avisos breves Tu turno / Turno rival al pasar el turno después del robo; Pasar daño en el lugar de Pasar prioridad; cartas obtenidas en lugar de códigos obtenidos.
- Mi cuenta permite escoger entre 27 retratos circulares de Aliados, sin textos de carta; se guardan por UUID.
- Regalo inicial con icono y sonidos; Victoria/Derrota centrado con Revancha/Inicio debajo; se elimina Ver mesa final. Elecciones de cartas centradas.
- Inicio con cartas flotantes y Transmisión Caída girando lentamente para mostrar frente/dorso. Nuevos sonidos de turno, regalo, resultado y sobre; controles de sonido conservados.
- Código de regalo separado a la derecha: **M4Z0M44G0** entrega una vez por UUID el **Mazo Maagover histórico**, exactamente 40 cartas con 15 Restos. No consume el regalo inicial.
- Misiones: terminar una partida, victoria o derrota; reclamar un sobre una vez por día y UUID. Reinicio a las **00:00 America/Santiago** según el servidor.
- Mis sobres: abrir con el mouse y deslizar las cinco cartas lateralmente. Sorteo, consumo, cantidades y resultado ordenado se guardan juntos en el servidor. Una apertura pendiente se recupera tras reingresar, sin gastar otro sobre.

## Probabilidades confirmadas

Posición 1: un Recurso, nunca repetido en posiciones 2–5. Posiciones 2–4: normales uniformes entre 31, con repetición. Posición 5: normal uniforme 70% / Especial 30%.

Dentro de las Especiales, Kajido 0105, SoyFlaan 0103, Papito 0115 y Transmisión Caída 0119 tienen **5% cada uno**: 1,5% total por sobre cada uno. Guitarramala 0134, HNyko 0128, Chanchuus 0125, Escuela de Vuelo 0131 y Serandimini 0130 tienen **16% cada uno** dentro del grupo: 4,8% total cada uno. Son decisiones confirmadas, no preguntas pendientes. Las 41 cartas pueden obtenerse.

## Archivos principales

- `main.gd`: pantallas, mesa e integración; `collection.gd`: lectura y RPC remotos con la sesión de Auth.
- `profile_ui.gd` y `avatar_view.gd`: selector y retratos de Aliados.
- `home_cards.gd` y `gift_badge.gd`: animación de inicio y regalo.
- `rewards_ui.gd` y `pack_reveal.gd`: código, misión, cola de resultados y apertura interactiva.
- `sound.gd`: audio previo y efectos nuevos. `game.gd`, `ai.gd`, `account.gd`, `drop_surface.gd`, `card_image.gd`, `motion.gd` y los datos originales se conservan.
- `backend/aamix_rewards.sql`, `REWARDS_API.md`, `APPLIED_MIGRATIONS.json` y `test_rewards_rollback.sql`: backend actual y prueba real reversible. El generador sólo prepara SQL, no despliega.
- `tests/test_rewards_v010.gd`, `test_presentation_v010.gd` y `test_profiles.gd`: pruebas nuevas. Las pruebas locales con identidades ficticias no prueban correo real.

## Servicio y seguridad

Supabase existente **drpsedaiqyowwikhjugs**, Auth por correo y código y Brevo SMTP conservados. Migraciones ya aplicadas: `20261017185851_aamix_collection_starter_v090` y `20261017194519_aamix_profiles_rewards_v0100`. Inspeccionar antes de cualquier cambio; no reaplicarlas. No se borraron ni recrearon cuentas.

Las tablas públicas tienen RLS de lectura por UUID, sin escritura directa del cliente. Las funciones privilegiadas están en esquema privado; los RPC públicos son invoker y comprueban identidad/correo confirmado. Cartera bloqueada por UUID, claves únicas y correspondencia permanente de cada petición de apertura evitan duplicados. El cliente sólo incluye la URL y clave publicable.

Correo, códigos, sesión y tokens viven en memoria. Al cerrar sesión se descarta la información privada local; al reingresar se recupera del servicio con el mismo UUID. La animación no entrega cartas por sí misma. Se guarda el resultado exacto antes de mostrarlo y se confirma después de revelar las cinco.

## Validación confirmada y límites

Backend: recompensas aprobadas dos veces, **20.000 sobres** sorteados en total, todo revertido; regresión de colección 0.9.0 aprobada. En la última muestra de 10.000 salieron 3.029 Especiales (30,29%) y 602 de las cuatro con peso 5% (6,02% conjunto); aparecieron las 31 normales. Se probaron UUIDs aislados, cantidades exactas, reintentos, recuperación, escrituras denegadas y rollback completo ante un fallo forzado.

Antes y después: 2 usuarios, 1 regalo inicial, 1 mazo y 40 cartas en 12 filas; cero usuarios de prueba y cero recompensas reales consumidas. No se enviaron códigos de correo reales. No se validó una carrera real entre dos clientes simultáneos: las pruebas secuenciales y la revisión de los bloqueos no equivalen a esa prueba.

**La misión recibe el resultado declarado por el cliente de una partida local contra IA. No hay servidor que valide el historial de jugadas.** La cola de notificaciones fallidas sólo vive en memoria; mantener abierto y reintentar en Misiones si falla la red. Cerrar/cambiar sesión antes de registrar el final pierde ese resultado no enviado. Una apertura de sobre ya confirmada en el servidor sí persiste y puede retomarse.

La advertencia previa de protección de contraseñas filtradas en Auth sigue sin cambiar. Los avisos informativos de tablas privadas sin políticas corresponden a denegación intencional sin SELECT al cliente. Detalle en el registro del backend.

**Pruebas del juego, capturas, totales actuales y extracción/integridad/arranque del ZIP: 1050 comprobaciones y 214 partidas simuladas aprobadas nativamente en Windows; extracción, manifiesto y arranque del paquete portátil verificados.** Los documentos y cifras de 0.9.0 y anteriores se conservan como historial, no acreditan la verificación final de esta entrega.

## Continuación

La entrega está completa y verificada. Seguir la próxima indicación del autor; el desarrollo de multijugador privado por sala continúa pendiente, con privacidad de manos/orden del Mazo y validación de jugadas en el servicio. Acordar alojamiento y costos antes de contratar. Mantener constructor, intercambios y efectos restantes como pendientes. No volver a tratar como abiertas las probabilidades de sobres ya confirmadas.
