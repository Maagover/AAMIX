# CONTINUIDAD · AAMIX 0.10.1

Fecha: 17 de octubre de 2026. Entrega actual: **AAMIX_Prototipo_Local_Windows_v0.10.1.zip**. Base vigente: **BASE_DEL_PROYECTO_v1.6.md**, sección 18. Prompt vigente: **PROMPT_CONTINUIDAD.md**. Verificación de esta entrega: **155 comprobaciones y 21 partidas simuladas aprobadas en Windows, cero fallos**. La verificación portátil se registra en **INFORME_ENTREGA**. La continuidad, el prompt, la base 1.5 y las pruebas de 0.10.0 quedan conservados como historia.

## Corrección confirmada por el autor

**Las cartas promocionales no deben aparecer en sobres, nunca.** Las seis promociones `01a`–`01f` se excluyen de las cinco posiciones, incluidas las ramas de Recurso y Especial. Esa condición tiene prioridad sobre rareza, tipo y Singular, incluso si una carta cambia de clasificación. La corrección reemplaza la inclusión de 31 normales y de las 41 cartas en sobres descrita en 0.10.0.

El conjunto vigente contiene **35 cartas elegibles: 1 Recurso, 25 normales y 9 Especiales**. El catálogo sigue teniendo 41 cartas. Las promociones conservan imágenes, identificadores, espacio de colección, retratos de Aliados y validez en los mazos que las incluyen. **M4Z0M44G0 mantiene el Mazo Maagover histórico exacto, incluida `01c`**: un regalo de mazo no es un sobre.

**Reparación histórica autorizada y aplicada:** una copia de **Dragón Tee K.O (01e)** en la **posición 2** del sobre anterior se sustituyó por **El conflicto de Maagover (0116)**. Se conserva el total de **85 cartas** y la copia legítima **01c** del Mazo Maagover. Hay un registro privado de auditoría antes/después; los reintentos son idempotentes. No incluir UUIDs reales de cuenta/apertura en documentación compartida ni extender esa autorización a otras cartas o cuentas.

## Sobres: probabilidades conservadas

Posición 1: un Recurso no promocional garantizado, actualmente Restos 0100; nunca Recursos en posiciones 2–5. Posiciones 2–4: normales uniformes entre las **25 no promocionales**, con repetición. Posición 5: normal uniforme 70% / Especial 30%, siempre sin promociones.

Dentro de las Especiales, Kajido 0105, SoyFlaan 0103, Papito 0115 y Transmisión Caída 0119 tienen **5% cada uno dentro del grupo**: 1,5% total por sobre cada uno. Guitarramala 0134, HNyko 0128, Chanchuus 0125, Escuela de Vuelo 0131 y Serandimini 0130 tienen **16% cada uno** dentro del grupo: 4,8% total cada uno. Son decisiones confirmadas y no preguntas pendientes.

## Estado del juego que se conserva

Juego individual contra IA local, Godot 4.7.2 oficial para Windows x86_64 incluido. Reglas, IA, mesa, arrastres, imágenes, animaciones y audio se conservan. Hay 41 cartas catalogadas; 31 tienen efectos soportados y diez todavía no. Una carta obtenida no implica efecto programado. No hay multijugador, constructor, intercambios ni guardado de partidas.

Acceso por correo/código, invitado, colección por UUID, regalo inicial único y Mis Mazos disponibles. El invitado y la IA siguen con Kajido, Papito y Flaan. Las cuentas sólo juegan con mazos obtenidos. El regalo inicial real ya elegido por el autor se conserva; no prometer que sigue sin reclamar.

Salir sólo en Inicio y con confirmación; Tu turno/Turno rival tras robo; Pasar daño; cartas obtenidas; retratos circulares de 27 Aliados; regalo con sonido; Victoria/Derrota centrado con Revancha/Inicio y sin Ver mesa; inicio con flotación y giro frente/dorso. No rediseñar esas interfaces por la corrección de sobres.

M4Z0M44G0 entrega una vez por UUID las 40 cartas y 15 Restos del Mazo Maagover; no consume regalo inicial ni cambia los tres mazos de invitado/IA. La misión Juega 1 partida se completa al terminar con victoria o derrota y permite reclamar un sobre por UUID/día; reinicio **00:00 America/Santiago** según el servidor.

Mis sobres conserva la apertura con mouse y el deslizamiento de cinco cartas. Sorteo, consumo, cantidades y orden se guardan en una transacción antes de la animación. Una apertura pendiente puede retomarse tras reingresar sin gastar otro sobre. Las peticiones de reintento quedan vinculadas permanentemente al mismo resultado.

## Backend y archivos

Se reutiliza el Supabase **drpsedaiqyowwikhjugs**, con Auth y Brevo SMTP existentes. El catálogo añade `is_promotional`; las tres ramas del sorteo filtran promociones y una restricción privada impide nuevos resultados con ellas. La migración **20261017221142_aamix_packs_exclude_promotional_v0101** está aplicada y verificada mediante el panel SQL autenticado y registrada en el historial. El conector había fallado con Invalid requestState; ese intento no se contó como aplicación. La corrección del servidor protege nuevas aperturas de clientes anteriores.

Consulta `backend/APPLIED_MIGRATIONS.json` para todas las migraciones aplicadas y sus resultados. Se mantienen las de 0.9.0 y 0.10.0; no repetirlas. `BACKEND_v0.10.1.md` describe esta corrección; `BACKEND_v0.10.0.md` es histórico. No recrear usuarios ni volver a configurar SMTP. El cliente sólo contiene URL y clave publicable.

RLS de lectura por UUID, sin escritura directa del cliente; RPC públicos invoker llaman funciones privilegiadas privadas con comprobación de identidad y correo. Bloqueo de cartera, claves únicas y peticiones persistentes protegen duplicados. Las promociones se excluyen en servidor, no mediante la animación.

Pantallas e integración: main.gd, collection.gd, profile_ui.gd, avatar_view.gd, home_cards.gd, gift_badge.gd, rewards_ui.gd, pack_reveal.gd y sound.gd. Reglas y rival: game.gd y ai.gd. Auth: account.gd. La configuración del sorteo, SQL, pruebas y metadatos correspondientes están en backend/ y data/.

## Validación y límites

**Verificación nueva 0.10.1:** perfiles 40, Maagover 64 y flujo de recompensas 51: **155 comprobaciones, cero fallos y 21 partidas simuladas** en Windows. Importación y arranque aprobados. Backend real: **10.000 sobres de regresión** (3.025 Especiales, 624 del conjunto de cuatro con peso 5%) y **1.000 adicionales** (300 quintas Especiales/700 normales) con reclasificaciones sintéticas; todos revertidos y restricciones restauradas. La prueba de reparación con rollback pasó, incluida conservación de Maagover y tres reintentos idempotentes. No quedaron cuentas de QA. Detalle en `VALIDACION_v0.10.1.md`; la **verificación portátil se registra en INFORME_ENTREGA** y no se anticipa aquí.

Históricamente 0.10.0 tuvo 1.050 comprobaciones, 214 partidas simuladas y 20.000 sobres de prueba con rollback. Sus 31 normales sorteadas incluían promociones y ese resultado no acredita la regla corregida. Los documentos, registros y capturas de esa entrega se conservan como historia.

La misión recibe el resultado comunicado por el cliente de una partida contra IA local: el servidor no valida su historial de jugadas. Los avisos de final que fallan sólo viven en memoria; mantener el juego abierto y reintentar en Misiones. Cerrar/cambiar sesión antes de enviarlos pierde el resultado pendiente. La apertura ya registrada en servidor sí persiste.

Correo, códigos, sesión y tokens sólo viven en memoria. Reingresar con el mismo correo recupera los datos del UUID. No pedir códigos reales para pruebas automatizadas. Las pruebas con cuentas ficticias y transacciones revertidas no acreditan correo/reingreso real ni una carrera simultánea entre dos clientes. La concurrencia real continúa pendiente.

## Continuación

Consultar el cierre portátil en INFORME_ENTREGA y seguir la próxima indicación del autor. Mantener la exclusión de promociones como regla vigente. Multijugador privado por sala, privacidad de manos/orden del Mazo y validación de jugadas en servicio siguen pendientes. Acordar alojamiento/costos antes de contratar; constructor, intercambios y diez efectos siguen pendientes. No volver a tratar como abiertas las probabilidades ni el reinicio diario ya confirmados.
