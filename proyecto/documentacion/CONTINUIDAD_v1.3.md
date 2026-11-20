# AAMIX Online v1.3 — estable (interna 1.11.0)

01/11/2026, America/Santiago. Publicación expresamente autorizada por el usuario. Editable independiente: work/AAMIX_v1.11.0/. Base: Prueba 02, work/AAMIX_v1.11_Prueba02/; última oficial anterior: Online v1.2.1 / 1.10.1. Release nueva v1.11.0, sin sobrescribir releases, carpetas ni ZIP anteriores. sources/ es sólo lectura. Paquete completo AAMIX.exe + motor/ + proyecto/. Ejecutables e instalador originales sin cambios. Mantener user://AAMIX, DPAPI CurrentUser, protocolo de instalador 1 y minimum_launcher 1.

## Cambios finales

Sam guía en el tablero real desde un panel verde suave, más angosto y centrado, con variante oscura legible. Presentación inicial conservada. Singular se explica mostrando SoyFlaan y se avanza con Continuar; eliminado el ejercicio y botón «Probar dos copias». Tutorial y partida aleatoria final no registran resultados ni entregan recompensas. Arrastre y pulsación carta/destino usan los controles y reglas reales.

Fuerza actual visible en la esquina inferior izquierda de cada Aliado mostrado, obtenida de game.force(uid) y actualizada por fotograma. Recuadro crema, alfa 0,88, número café al coincidir con la Fuerza impresa, verde si es mayor y rojo si es menor. El número vuelve al color normal cuando caduca el efecto. Incluye Objetos, Dominios, habilidades y bonus de combate. No modifica la Fuerza ni revela cartas ocultas. Los niveles bloqueados del Desafío tienen alfa 0,42 y conservan ocultos su nombre y portada.

mission_row.gd comparte el diseño de las misiones del Desafío, diarias, históricas y de evento: texto y premio a la izquierda, barra contrastante de 12 px sólo para objetivos mayores de 1, botón con icono(s) y cantidades de recompensa a la derecha. Verde y pulsable cuando puede reclamarse. Premio combinado se reclama con una sola acción, mostrando todos sus componentes. La fila sólo se atenúa si ya fue reclamada; un reinicio diario recupera su aspecto normal. Se conservan las funciones de cobro, idempotencia y autoridad del servidor. Primera victoria del Desafío sigue entregándose automáticamente y no se cobra dos veces.

## Integración desde la última versión pública

Incluye las mejoras de Prueba 01/02: tutorial práctico con Sam y práctica sin premios, IA que prefiere bloqueos con destrucción mutua antes de sacrificios inútiles, Enter sobre el botón enfocado con flechas, Escape, ventanas de lectura persistentes mientras el tablero sigue debajo, pago de coste automático opcional en Configuración > Juego, Registro en ventana viva, tablero y Desafío con madera negra, fondos generales según evento, disposición compacta del tablero y Dominio vertical/tenue. Conserva once niveles, sus portadas, primeras victorias y el bono de +5 Restos tras completar todo el Desafío.

Misiones por nivel: 1–11 ganar 5 = 2 TC; 4–11 ganar sin Singulares = 1 TC; 6–11 GANAR con más de 20 cartas en Mazo = 1 TC; SOLO 11 ganar sin perder ningún Aliado = 3 TC. Primera victoria basta para desbloquear el siguiente nivel. No hay que completar las misiones extra. Flechas persistentes y ficha vecina parcialmente visible. Los datos históricos sólo cuentan cuando hay evidencia; las métricas de cartas restantes/bajas nacen con esta versión.

## Servidor y datos

No se aplica ninguna migración nueva, reinicio ni modificación administrativa en esta revisión. Ya está aplicada 20261031201203 aamix_challenge_missions_v111; NO repetirla. RPC aamix_finish_challenge_v111 y aamix_claim_challenge_mission_v111, tablas privadas con RLS, lock_rewards y recibos propios; compatibles con clientes anteriores. Las condiciones de partidas individuales proceden del motor local, como los resultados anteriores: no hay arbitraje competitivo independiente. Multijugador conserva protocolo 3, ruleset 1.9 y anfitrión ejecutando reglas. No importar progreso de pruebas de Halloween ni ejecutar resets históricos.

## Verificación actual

148 comprobaciones dirigidas, sin fallos, en tests/test_v111_release.gd: recorrido real del tutorial, pago/combate/habilidad/Objetos/Dominio/características, Enter con foco secundario, carrusel/flechas/desbloqueo/filas, Fuerza aumentada/reducida/caducada sin reconstruir el tablero, panel de Sam, niveles atenuados y misiones de varios premios en Claro/Oscuro. 15 capturas nativas revisadas. Cero solicitudes de recompensa, cuentas nuevas o sorteos. No se suman pruebas históricas. Aviso conocido del entorno restringido al leer certificados de Windows; sin errores de scripts ni aserciones en la ejecución final. Sin pruebas nuevas de servidor, PCs remotos o latencia. Integridad de ZIP, extracción y binarios se registran en la verificación externa al empaquetar.

## Calendario siguiente

Cumpleaños Javieriv: 12–14/11/2026, ambas fechas incluidas, cumpleaños el 13. Juega 1: 25 Restos + Javieriv; gana 1 con al menos un Javieriv en el mazo: 1 sobre carta aleatoria + Javieriv; gana 3 con esa condición: 1 sobre TC + Javieriv. Misiones únicas durante el evento. Sin código adicional de regalo programado para este evento. Datos en data/eventos.json y calendario existente; no se cambian fechas ni premios.

## Publicación y límites

Release https://github.com/Maagover/AAMIX/releases/tag/v1.11.0 con ZIP completo, AAMIX_Instalador.exe, aamix-update.json y SHA256SUMS.txt. Cerrar el juego y Actualizar desde el instalador habitual. El instalador conserva versiones previas y datos en APPDATA, y verifica tamaño/SHA-256. Su propio ejecutable no se autoactualiza. H03 usa Fuerza 2 aunque el PNG recibido imprime 3. Ejecutables sin firma digital. Pendientes ajenos: reanudar individuales, ranking, emparejamiento público y servidor competitivo independiente. Continuidad histórica en CONTINUIDAD_PRUEBA02.md y anteriores; sus prohibiciones de publicar eran de esas pruebas y quedan supersedidas por la autorización actual.
