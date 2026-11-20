# CONTINUIDAD · AAMIX 0.14.0

18 de octubre de 2026, Chile. Carpeta de trabajo/entrega: **AAMIX_Prototipo_Local_v0.14.0/**; paquete previsto **AAMIX_Prototipo_Local_Windows_v0.14.0.zip**. Base vigente **BASE_DEL_PROYECTO_v1.10.md**, sección 22. Se conservan la base 1.9 y snapshots de README, LEEME, continuidad y prompt de 0.13.0.

**Validación local cerrada: 331 comprobaciones únicas, cero fallos, cinco partidas IA completas.** No sumar los 376 de 0.13.0 ni los 582/48/2.000 de 0.12.0. Ver VALIDACION_v0.14.0.md.

La migración **20261018203917_aamix_challenges_and_missions_v0140** está aplicada. La prueba SQL nueva y la regresión de códigos anterior pasaron en el servicio real con rollback, con **2.000 sobres sin promociones**. Ver `proyecto/backend/APPLIED_MIGRATIONS.json` y `proyecto/backend/DEPLOYMENT_v0.14.0.json`; no repetir migraciones aplicadas.

El informe externo `INFORME_ENTREGA_v0.14.0.json`, junto al ZIP, registra su hash final, integridad, extracción independiente y arranque sin caché.

## Decisiones vigentes del autor

Inicio usa `valle.png` con zoom suave en bucle, sin reiniciarlo al refrescar inventario. Menú principal en este orden: Partida individual, Multijugador, Misiones, Mi Colección. Foto/nombre arriba a la izquierda llevan a Mi cuenta; Código de regalo y Configuración arriba a la derecha. Se retiraron el botón antiguo Mi cuenta, el acceso Sobres del Inicio y «Juega contra el rival». Salir queda en Inicio, siempre con confirmación y también al cerrar la ventana. Multijugador presenta «En desarrollo»; el invitado conserva práctica, con avisos de cuenta para contenido persistente.

Partida individual abre Partida Aleatoria y Desafío AAMIX. La aleatoria y el invitado mantienen Kajido/Papito/Flaan. Las cuentas sólo eligen sus mazos obtenidos. Las cinco etapas del desafío son:

| Etapa | Rival fijo | Premio por primera victoria |
| --- | --- | --- |
| 1 | Mazo Papito | 1 sobre. |
| 2 | Mazo Flaan | 1 sobre. |
| 3 | Mazo Kajido | 1 sobre. |
| 4 | Mazo Maagover | 2 sobres. |
| 5 | Mazo Girabl | 3 sobres. |

**Recompensa única por etapa y cuenta, confirmada por el autor.** Ganar desbloquea la siguiente; perder no desbloquea ni premia. Una repetición de etapa completada no concede otro premio. Maagover y Girabl del desafío usan las listas históricas exactas (40/15 y 40/12), conservadas en `challenge_decks.json` a partir de `tests/fixtures/mazos_legacy.json`. No modificar `game.decklists` ni añadirlos al grupo aleatorio de tres rivales.

## Misiones y compatibilidad histórica

| Misión | Frecuencia | Recompensa vigente |
| --- | --- | --- |
| Juega 1 partida | Diaria; terminar con victoria o derrota. | 1 sobre. |
| Gana 1 partida | Acumulativa de por vida; una vez por cuenta. | 1 sobre. |
| Juega 10 partidas | Acumulativa de por vida; una vez por cuenta. | 3 sobres. |
| Gana 10 partidas | Acumulativa de por vida; una vez por cuenta. | 5 sobres. |

Se conservan los premios ya entregados. Un reclamo anterior de «Gana 1 partida», aunque fuera diario, impide cobrar otra vez la nueva misión de una victoria. Los reclamos históricos de «Juega 10 partidas» mantienen sus cinco sobres; no se retiran dos sobres ni se concede de nuevo el premio vigente de tres. Sólo «Juega 1 partida» se reinicia a las **00:00 America/Santiago**, según servidor; las otras tres no se reinician ni se repiten cada diez partidas. El progreso usa los recibos de partidas terminadas guardados, incluidos los anteriores.

Identificadores conservados: `play_one`, `win_one`, `play_ten`; nuevo `win_ten`. El inventario servidor define progreso y reclamos. No usar reloj del cliente ni crear progreso local. Los desafíos usan un recibo con etapa y rival fijo; las partidas terminadas también alimentan misiones según el contrato del servicio.

## Presentación y recursos

Ocho PNG originales intactos en `assets/estetica_v014/`: valle, cinco cajas de mazo y dos títulos de resultado. Se recorta sólo margen transparente al presentar. Portadas en selección, Mis Mazos, regalo inicial y premios de mazo; cartas sueltas usan su imagen real, sobres su envoltorio real. Victoria/Derrota muestran su PNG y acciones debajo. Las cartas de Inicio usan la máscara común de esquinas; pack y logo se mantienen sin esa máscara.

`interface_motion.gd` gestiona entradas con fundido y pequeño rebote; `main.gd` las dispara por cambio semántico de pantalla/ventana. Cancela tweens al navegar, respeta `animations_enabled` y evita reanimar cada actualización de mesa. `home_backdrop.gd` conserva el reloj del valle entre renders. No cambiar reglas, entrada o información oculta para conseguir efectos.

Audio nuevo original: `batalla.wav`, 148 BPM/32 compases/51,8919 s en bucle; `popup.wav` de 0,23 s; `singular.wav` de 1,05 s. Música durante todas las interfaces y la partida, con controles Música/Efectos/Silenciar. Ver SONIDO.md, `tools/generate_battle_audio.py` y `audio/METADATOS_COMBATE_v0.14.0.json`. Carga/disparo probados con Dummy; escucha física no acreditada.

Sobres: gesto del mouse, envoltorio cerrado→abierto y pausa breve antes de las cartas; deslizamiento lateral sin inclinar cartas. Sólo la quinta carta Kajido/SoyFlaan/Papito/Transmisión Caída activa brillo, partículas y sonido Singular. No repetir al refrescar la misma apertura local. Ningún efecto vuelve a sortear ni concede cantidades; el resultado persistido precede a la animación.

La estética clara y madera de 0.13 siguen vigentes fuera de la excepción del valle de Inicio. Los nueve originales anteriores, cartas, logo y dorso se conservan. Mi Colección mantiene 35 regulares centradas y seis promociones separadas al final en una sola fila; cantidades, faltantes y doble clic siguen disponibles. Mis Mazos mantiene «Obtenido · 40 cartas» y Ver lista.

## Perfiles, regalos y sobres conservados

22 Aliados no promocionales disponibles como retrato sin requerir posesión; sólo imágenes, tooltips con nombre. Dicky/Maagover/Girabl conservan encuadres revisados. No reponer «Tu foto de perfil» ni nombres bajo imágenes. Las promociones permanecen bloqueadas aun poseídas; un dato histórico promocional se presenta como silueta sin borrar el perfil ni cartas de base de datos.

Una vez por cuenta y código, no diarios; normalizar mayúsculas/espacios exteriores. No añadir esta tabla al formulario de canje:

| Código exacto | Recompensa |
| --- | --- |
| M4Z0M44G0 | Mazo Maagover histórico: 40 cartas, incluidos 15 Restos. |
| P3RI | 3 Peri. No lleva cero al final. |
| B1G0T3S | 3 Bigotes. |
| SI2TYA | 1 Tsuki y Akira. |
| CHANCHULINES | 1 Granjita de Chanchuus. |
| TORNEOAAMIX1 | 1 Dragón Tee K.O. |
| AAMIXTC | 1 sobre de Transmisión Caída en Mis sobres. |
| M4Z0G1R4 | Mazo Girabl histórico: 40 cartas, incluidos 12 Restos. |

No reiniciar canjes históricos ni regalo inicial real ya elegido. Las promociones legítimas de Maagover/Girabl no habilitan fotos ni sobres.

Las promociones nunca salen en sobres. La expansión N.º 1, **Transmisión Caída**, conserva **35 elegibles: 1 Recurso, 25 normales y 9 Especiales**. Recurso garantizado sólo en posición 1; normales uniformes y repetibles en 2–4; quinta normal 70% o Especial 30%. Dentro de Especiales, Kajido/SoyFlaan/Papito/Transmisión Caída tienen 5% cada uno; las otras cinco Especiales, 16% cada una. Son pesos dentro del grupo Especial, equivalentes a 1,5% y 4,8% del total de sobres por carta. Nunca hay otro Recurso en 2–5.

Sorteo, consumo, cantidades, orden y apertura pendiente se guardan en una transacción; confirmar tras revelar las cinco cartas es idempotente. Reintentos conservan UUID; no consumir otro sobre al entrar de nuevo.

## Backend, archivos y límites

Reutilizar el servicio Supabase existente y Auth/Brevo SMTP; no recrearlos. SQL nuevo aplicado en `backend/aamix_challenges_and_missions_v0140.sql`, con prueba `test_challenges_and_missions_v0140_rollback.sql` y comprobación `verify_challenges_v0140.sql`. El registro confirmado corresponde a APPLIED_MIGRATIONS.json, DEPLOYMENT_v0.14.0.json y VERIFICATION_v0.14.0.json; no inventar IDs ni repetir una migración aplicada. Los ensayos con fixture HTTP prueban cliente, no el despliegue real.

Contrato cliente: `collection.challenges` contiene las cinco etapas con desbloqueo/completado/premio. `begin_match(request_id,deck_id,challenge_stage=0)` usa el RPC de desafío si stage1–5; 0 mantiene el inicio aleatorio. `finish_match` conserva su llamada y devuelve la recompensa nueva de etapa cuando corresponde. `rewards_ui.gd` conserva etapa/UUID/dueño en la cola; la ventana de premio espera la salida de la mesa para no tapar el resultado. La respuesta de inventario no concede premios localmente.

main.gd integra pantallas; game.gd/ai.gd conservan reglas/rival; account.gd acceso; collection.gd inventario/RPC; deck_art.gd portadas; home_cards.gd cartas/logo; home_backdrop.gd valle; interface_motion.gd entradas; profile_ui/avatar_view retratos; rewards_ui/pack_reveal recompensas/apertura; sound.gd audio. 41 cartas, 31 efectos soportados y diez pendientes. Godot 4.7.2 Windows x86_64 incluido.

El resultado de las partidas contra IA local lo declara el cliente; el servidor no valida un historial de jugadas. La cola de resultados sin enviar vive sólo en memoria: conservar el juego abierto y reintentar en Misiones; cerrar o cambiar de cuenta pierde esa cola. Una apertura de sobre ya guardada sí persiste y se recupera al reingresar sin gastar otro sobre. No se acredita concurrencia real de dos clientes ni una nueva entrega por correo en las pruebas locales.

El UUID real y correo confirmado controlan pertenencia. No publicar credenciales, tokens, códigos reales, service_role ni SMTP secreto. URL y clave publicable son configuración pública. No borrar usuarios ni reparar recompensas reales por iniciativa propia; la reparación histórica de 0.10.1 ya terminó y no se repite.

## Validación y siguiente etapa

Suites actuales: test_ui_v014 76 GUI; test_challenge_games_v014 19 sin interfaz y cinco partidas completas; test_rewards_v014 138 GUI con servicio HTTP ficticio; test_pack_v014 98 GUI. Se cuenta una ejecución final de cada suite. Resultados forzados y recibos de fixture no son partidas completas. Capturas nativas revisadas en `capturas/v0.14.0/` cuando se cierre el paquete; logs/resultados acompañarán la validación.

El plan `MULTIJUGADOR_PLAN_v0.15.md` propone servidor de reglas, salas privadas, privacidad por jugador, reconexión y pruebas de dos cuentas. El botón actual es sólo un aviso; no hay red jugable ni alojamiento contratado. Faltan también constructor, intercambios, diez efectos, guardado de partidas y desbloqueos promocionales. Continuar desde la próxima solicitud, manteniendo decisiones confirmadas y separando implementación, prueba y propuesta.
