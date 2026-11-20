# Continuidad oficial: AAMIX Online v1.0 / actualización 1.8.0

Base:ZIP oficial publicado 1.7.2. Editable separado work/AAMIX_v1.8/. Publicación GitHub con título exacto «AAMIX Online v1.0», tag v1.8.0, ZIP entregas/AAMIX_Online_v1.0_Windows.zip y raíz AAMIX_Online_v1.0/. No sobrescribir v1.0.0 ni ninguna entrega anterior. sources/ sólo lectura. Versión semántica 1.8.0 evita bajar de 1.7.2; VERSION.json/display_version y ventanas usan la marca final. Para lo no modificado rigen CONTINUIDAD_v1.7.2.md y toda la cadena previa.

## Cliente e interfaz

rewards.redeem y collection.redemption_message interceptan already_redeemed antes de presentar cartas, mazos, moneda o diseños. Mensaje exacto «ya has canjeado este regalo» en la zona de estado del formulario. Primeros canjes conservan su presentación y autoridad del servidor. Las variantes de Bigotes/Peri continúan compartiendo el mismo recibo.

Colección: número, nombre y Cantidad: x debajo de las 41 cartas, incluidas las no poseídas, con nombres amortiguados en las casillas vacías; texto «cartas coleccionadas». Tienda: número/nombre, altura mínima de nombre uniforme y propiedad sólo en confirmación como «(Tienes: x)», sin efectuar compra al abrir la ventana. Precios, exclusión de Recurso/promos y orden anteriores se conservan.

Eliminar Mazo sólo aparece cuando custom=true. Un regalo reparado tras intercambio conserva custom=false y editable=true; sigue protegido. Confirmación dentro del juego, servidor valida propiedad/revisión y que no esté en una sala vigente, sólo borra public.aamix_custom_decks. Conserva colección, deck_registry y recibos/snapshots de partidas/guardados. La tabla privada deleted_custom_decks_v180 recuerda el borrado por UUID/id para hacer idempotente un reintento; nueva solicitud de edición no resucita la fila y repetir una creación antigua sólo devuelve su recibo, sin reinsertarla. No se admite borrado directo por clientes ni anónimos.

Constructor elimina sólo el estilo/padding del botón interior de imagen, conservando la casilla exterior y lectura de carta. Texto: Máximo 3 copias por carta; se eliminan los dos textos indicados de guardar y el aviso de Ver Mazo. Límites: 40 cartas / 1 Recurso / 3 Normales / 1 Singular y propiedad permanecen.

Misiones diarias/históricas/eventos: panel alpha 0.72 cuando claimed o progreso>=objetivo; reclamar sigue activo si completada sin cobrar. Eventos separa título/frecuencia a la derecha, recompensa debajo, contador y botón con tamaño igual al estándar. MarginContainer con 24 px a la derecha separa contenido del scrollbar. Barra de progreso sólo para objetivo>1 se conserva.

Dominio rota a -PI/2 con posición (3,56) para conservar el rectángulo de montaje anterior (no basta invertir el signo sin mover el origen). La búsqueda ya enumeraba todas las instancias válidas según filtros; se verificaron tipos/Coste/Singular y se corrigió la presentación: orden visual por número/UID y restauración de scroll tras seleccionar, sin mutar options ni el orden real del Mazo. Scroll espera dos frames de layout. No se eliminan restricciones impresas. No cambia el protocolo/ruleset 1.3.

IA: safe_search no propone sacar del Mazo con menos de 15 cartas; sí admite Cementerio. choose_pending omite opciones del Mazo bajo ese umbral cuando opcional, pudiendo jugar un Aliado útil y omitir su búsqueda. Raid/Descubrimiento/Desaparición dejan de ser jugadas valoradas sin una búsqueda segura. Robo de cierre y mínimo de Mano siguen obligatorios. play_score de Maagover descarta otro si ya hay una instancia propia que entró ese turno; se vuelve a permitir al avanzar el turno. No consulta cartas ocultas del rival ni altera efectos para lograrlo. Son heurísticas dirigidas, no garantía de IA perfecta.

Cierre de sesión correcto deja account.status vacío; un fallo real de revocación por falta de conexión sigue informado. No se cambia DPAPI, refresh ni almacenamiento de contraseñas.

## Servidor

Supabase drpsedaiqyowwikhjugs:20261024033521 aamix_online_final_v180 aplicada una sola vez. SQL fuente backend/aamix_online_final_v180.sql. BEGIN/ROLLBACK se usó para 35 pruebas con 3 UUID sintéticos, sin usuarios persistentes o correos. La migración final mantiene 4 cuentas reales; ningún reset ni admin_reset_progress_v100.sql. No repetir migraciones antiguas.

Bienvenida conserva id bienvenida_2026 y end_day 26/10; start_day cambia al23/10. No se borra event_claims ni canjes ya efectuados, aunque el progreso nuevo se compute desde la nueva fecha. data/eventos.json y codigos_regalo.json son referencias sincronizadas de la nueva versión; la autoridad sigue siendo el servidor y America/Santiago.

finish_match conserva bloqueo de cartera por UUID, validación de recibo/rival del Desafío y premios únicos 8 TC. Antes de conceder una victoria nueva comprueba que existían las cinco completion filas. Sólo entonces añade 5 Restos y guarda challenge_repeat_restos=5 en el mismo recibo/transacción. Primera finalización del quinto nivel, derrotas, partidas ordinarias y recibos de otro UUID no dan bono. Los recibos previos a la migración quedan con 0 y no se pagan retroactivamente. Repetir el resultado devuelve el valor guardado sin volver a abonar. Cliente sólo encola aviso para un recibo que acaba de registrar y muestra +5 Restos en una tarjeta pequeña temporal después de la partida (sin anuncio previo ni nueva sección).

deleted_custom_decks_v180 tiene RLS y política denegatoria; RPC público aamix_delete_custom_deck security invoker, helper privado security definer con lock_rewards/auth.uid y validaciones. Registry se retiene porque match_receipts tiene FK, y los snapshots ya iniciados siguen siendo utilizables. Cliente no envía user_id ni controla cuantías de bonos. Asesor sin hallazgos nuevos: 12 INFO previos de tablas privadas y aviso previo de protección de contraseñas filtradas, sin tocar Auth/Windows.

## Verificación y continuidad

35SQL, 33 UI / 11 capturas, 19 IA + búsquedas, 36 bloqueos repetidas en esta entrega, 0 sorteos y 0 solicitudes de red en los fixtures cliente. Primeros diagnósticos del montaje SQL/fixture se corrigieron; no se suman aserciones de ejecuciones anteriores. No se probaron dos PCs remotos ni nueva latencia. El fixture restringido avisa de lectura de certificados del sistema, mientras UI nativa y actualizador HTTPS usan Windows/TLS normal. Evidencia dentro de documentacion/validacion_v1.8 y capturas/v1.8; pruebas finales de ZIP/actualización/publicación quedan fuera, en entregas/AAMIX_v1.8_publicacion.

Mantener toda la apertura/música de 1.7.1, líneas de bloqueo y limpieza 1.7.2, recompensas/perfiles 1.7 y trade rooms 1.6. Instalador y ejecutables estables conservados, user://AAMIX, DPAPI CurrentUser, protocolo 1 / minimum_launcher 1. Publicar cuatro assets:ZIP completo, AAMIX_Instalador.exe, aamix-update.json y SHA256SUMS.txt. Pendientes reales: reanudar individuales, ranking, emparejamiento público y arbitraje competitivo independiente. El anfitrión sigue ejecutando reglas.
