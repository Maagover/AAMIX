# Prompt vigente para continuar AAMIX desde 0.14.0

18 de octubre de 2026, Chile. Base vigente **BASE_DEL_PROYECTO_v1.10.md**, sección 22. Este prompt reemplaza al de 0.13.0, conservado como `PROMPT_CONTINUIDAD_historico_v0.13.0.md`. **331 comprobaciones locales únicas aprobadas, cero fallos y cinco partidas IA completas.** Consultar VALIDACION_v0.14.0.md; no sumar cifras históricas.

La migración **20261018203917_aamix_challenges_and_missions_v0140** está aplicada. La prueba SQL nueva y la regresión de códigos anterior pasaron en el servicio real con rollback, con **2.000 sobres sin promociones**. Ver `proyecto/backend/APPLIED_MIGRATIONS.json` y `proyecto/backend/DEPLOYMENT_v0.14.0.json`; no repetir migraciones aplicadas.

El informe externo `INFORME_ENTREGA_v0.14.0.json`, junto al ZIP, registra su hash final, integridad, extracción independiente y arranque sin caché.

Estamos continuando AAMIX, mi juego de cartas físico convertido en juego virtual para computador. Proyecto personal en español para jugar con amigos, sin comercializar y con costo gratuito o bajo. Continúa sobre la entrega real adjunta y conserva lo aprobado. Entrega versiones completas descargables para Windows y documentación suficiente para cambiar de chat.

## 1. Prioridad y estado

Entrega: `AAMIX_Prototipo_Local_Windows_v0.14.0.zip`, carpeta `AAMIX_Prototipo_Local_v0.14.0/`. Leer README, VERSION.json, CONTINUIDAD y base 1.10, sección 22. Las aclaraciones posteriores del autor prevalecen; siguen reglas de torneo del 16 de octubre, manual original y textos de cartas con sus aclaraciones. Distingue confirmado, implementado y propuesto; pruebas locales y remotas. No reconstruyas el proyecto ni pidas imágenes ya incluidas.

Godot 4.7.2, 2D, Windows de 64 bits, motor y lanzador incluidos. Partidas locales contra IA, sin ver la Mano humana ni el orden del Mazo rival. Catálogo de 41 cartas, 31 efectos soportados y diez pendientes. Acceso por correo/código, colección por UUID, regalo inicial único, perfiles y recompensas existen; no recrear Auth, SMTP ni cuentas. Multijugador sólo presenta «En desarrollo». El plan de 0.15 es una propuesta, sin red jugable todavía.

## 2. Mesa y reglas conservadas

Interfaces claras y madera del autor en la partida; logos, dorso e imágenes originales conservados. Dominio neutral compartido al centro. Columna propia Pagadas–Mazo–Recursos; Cementerio sobre Quemadas en casillas independientes. Panel Acciones junto al registro compacto; Mano capaz de mostrar ocho cartas. Cartas con redondeado leve, sin textos duplicados bajo la imagen; doble clic amplía, sin panel lateral permanente. Arrastrar para recursos, pagos, cartas, Eventos, ataques, bloqueos, descarte y habilidades prácticas. Eventos sobre mesa/objetivo, sin zona propia. Conservar selección, objetivos, numeración y animaciones sin filtrar cartas ocultas.

Reglas:

- Mazo de 40 cartas; máximo 3 de cada no Recurso, Singular 1; Recursos sin ese límite. Recurso inicial tomado de esas 40; después barajar y robar 6.
- Hasta dos cambios completos de Mano: 6 → 5 → 5.
- Reagrupar Pagadas → Recursos y Ataque → Defensa. Después se puede bajar un Recurso; sin Recursos en Mano pasar automáticamente a Acciones.
- Pagar moviendo Recursos a Pagadas. Aliados entran en Defensa, Objetos se anexan con máximo uno por portador, Eventos resuelven al Cementerio. Dominio nuevo descarta el anterior al Cementerio de su dueño.
- Aliado recién jugado no ataca salvo Ágil. Declarar ataque cierra las jugadas normales y conserva las ventanas alternadas de Eventos del combate.
- Cada defensor bloquea a un atacante y cada atacante admite un bloqueador. Defensor más fuerte destruye al atacante sin dañar Mazo; empate destruye ambos; atacante más fuerte destruye defensor y diferencia daña Mazo; sin bloqueo toda la Fuerza daña Mazo. Resolver cada atacante por separado, punto a punto. Mazo vacío implica derrota.
- Sin Aliados defensores omitir Confirmar bloqueos; conservar respuesta legal de Evento, o aplicar daño automático si no la hay.
- Al terminar el turno, robar una carta y completar hasta tres si aún hay menos. Si supera ocho, elegir descartes antes del turno rival. Ese cierre no elimina posteriores respuestas/bloqueos defensivos.
- Las búsquedas muestran cartas válidas; Quemadas no se recuperan. Al salir un portador por cualquier destino, su Objeto va al Cementerio.
- Bigotes: una vez en cada turno del dueño. Azul: +1 en Ataque, +2 mientras bloquea, sin bono en Defensa sin bloquear. Muñeco de Miku da +4 a Maagover/Dicky sobre su base. Los bonos por Tipo incluyen a la propia carta cuando corresponda.
- Escuela de Vuelo es 0131, limita a cuatro Aliados y cada dueño elige cuáles conservar; Guitarramala es 0134. Desaparición de Papito no termina el turno.

No importar reglas de Mitos y Leyendas para llenar vacíos. Conservar como provisionales las interpretaciones anteriores de cartas y los casos pendientes de simultáneos, ambos mazos vacíos y búsquedas. No rediseñar la mesa ni cambiar reglas como efecto secundario de cuentas/recompensas.


## 3. Inicio, navegación y arte

Inicio usa el valle original con zoom suave continuo y reloj persistente entre renders. Menú ordenado: Partida individual, Multijugador, Misiones, Mi Colección. Foto y nombre arriba a la izquierda abren Mi cuenta; Código de regalo y Configuración arriba a la derecha. Sin botón antiguo Mi cuenta, acceso Sobres en Inicio ni «Juega contra el rival». El invitado mantiene práctica y avisos de cuenta para progreso/recompensas. Salir sólo en Inicio, con Confirmar/Cancelar, también al cerrar la ventana.

Partida individual abre Partida Aleatoria y Desafío AAMIX. La aleatoria conserva exactamente tres rivales base: Kajido, Papito y Flaan. Las cuentas usan sus mazos obtenidos. El desafío requiere cuenta y elección de un mazo propio antes del rival fijo:

| Etapa | Rival fijo | Premio por primera victoria |
| --- | --- | --- |
| 1 | Mazo Papito | 1 sobre. |
| 2 | Mazo Flaan | 1 sobre. |
| 3 | Mazo Kajido | 1 sobre. |
| 4 | Mazo Maagover | 2 sobres. |
| 5 | Mazo Girabl | 3 sobres. |

Cada etapa desbloquea la siguiente al ganar y concede su premio **una sola vez por cuenta y etapa**. Repetir no vuelve a premiar. Maagover y Girabl sólo se añaden como rivales de estas etapas, con listas históricas exactas 40/15 y 40/12 de `challenge_decks.json`, comparadas con `tests/fixtures/mazos_legacy.json`; preservar sus promociones legítimas. No modificar `game.decklists`.

Ocho PNG intactos en `assets/estetica_v014/`: valle, cinco portadas y dos resultados. PROCEDENCIA registra hashes. Usar portadas en elección, listas, regalo y premios; Victoria/Derrota usan PNG original y botones debajo. Cartas con máscara de esquinas, incluidas las de Inicio y premios; cajas, sobres y logos sin máscara de carta. Mantener los nueve originales de 0.13, interfaces claras, madera sólo durante la mesa y controles legibles. No regenerar bitmaps aportados.

Entradas de pantalla y ventana con fundido, pequeño rebote y sonido popup. Cancelar al navegar, respetar `animations_enabled` y no repetir cada actualización de mesa. Inicio mantiene dos cartas y sobre detrás del logo, flotación sin giro y logo más sutil. Música original de combate a 148 BPM, bucle de 51,8919 segundos, también en partidas; controles Música/Efectos/Silenciar. SONIDO.md y metadatos registran la fuente; pruebas Dummy no acreditan altavoces.

Mi Colección: 35 regulares centradas y seis promocionales al final en una fila separada; conservar cantidades, faltantes y doble clic. Mis Mazos muestra «Obtenido · 40 cartas» y Ver lista, sin «guardado en tu cuenta». Misiones/Mis sobres usan filas a la izquierda; elecciones, apertura y selección de mazo centradas. Mantener Tu turno/Turno rival tras robo, Pasar daño, regalo inicial con sonido y resultados sin Ver mesa.

Perfiles: 22 Aliados no promocionales sin requerir posesión, círculo del personaje sin textos de carta; sólo imágenes y tooltips, sin nombres debajo. Mantener encuadres de Dicky, Maagover y Girabl y retirar «Tu foto de perfil». Promocionales bloqueadas aun poseídas; un dato histórico promocional usa silueta sin borrar la base de datos.

## 4. Cuenta, códigos y misiones

Mismo correo y código nuevo recuperan UUID/datos. Tokens, códigos y correos de sesión sólo viven en memoria. Cada cuenta elige regalo Kajido/Flaan/Papito una vez; **el regalo real ya elegido se conserva**. No reiniciar regalos ni afirmar que aún no está reclamado. Los mazos base tienen 40 cartas/18 Recursos exactos; guardar mazo no consume cartas. Todavía no hay constructor.

Códigos: una vez por UUID y código, independientes, no diarios. Normalizar mayúsculas y espacios exteriores. El formulario conserva entrada y Canjear; no añadir una tabla de premios a la interfaz. La confirmación presenta el regalo real con carta, mazo o sobre correspondiente.

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

Maagover conserva 01c; Girabl conserva 3 Peri, 2 Bigotes y 1 Tsuki y Akira. Las promociones legítimas no pasan a ser elegibles en sobres ni fotos. No añadir estos mazos al invitado o al grupo aleatorio.

Misiones vigentes:

| Misión | Frecuencia | Recompensa vigente |
| --- | --- | --- |
| Juega 1 partida | Diaria; terminar con victoria o derrota. | 1 sobre. |
| Gana 1 partida | Acumulativa de por vida; una vez por cuenta. | 1 sobre. |
| Juega 10 partidas | Acumulativa de por vida; una vez por cuenta. | 3 sobres. |
| Gana 10 partidas | Acumulativa de por vida; una vez por cuenta. | 5 sobres. |

Se conservan los premios ya entregados. Un reclamo anterior de «Gana 1 partida», aunque fuera diario, impide cobrar otra vez la nueva misión de una victoria. Los reclamos históricos de «Juega 10 partidas» mantienen sus cinco sobres; no se retiran dos sobres ni se concede de nuevo el premio vigente de tres. Sólo «Juega 1 partida» se reinicia a las **00:00 America/Santiago**, según servidor; las otras tres no se reinician ni se repiten cada diez partidas. El progreso usa los recibos de partidas terminadas guardados, incluidos los anteriores.

IDs: `play_one`, `win_one`, `play_ten`, `win_ten`. Inventario y recibos del servidor controlan progreso/reclamos. No usar el reloj del cliente ni fabricar victorias. La victoria de un desafío terminado alimenta las misiones; sus premios siguen registros independientes.

## 5. Sobres y presentación Singular

Las promociones nunca salen en sobres. La expansión N.º 1, **Transmisión Caída**, conserva **35 elegibles: 1 Recurso, 25 normales y 9 Especiales**. Recurso garantizado sólo en posición 1; normales uniformes y repetibles en 2–4; quinta normal 70% o Especial 30%. Dentro de Especiales, Kajido/SoyFlaan/Papito/Transmisión Caída tienen 5% cada uno; las otras cinco Especiales, 16% cada una. Son pesos dentro del grupo Especial, equivalentes a 1,5% y 4,8% del total de sobres por carta. Nunca hay otro Recurso en 2–5.

Dentro del grupo Especial, 0105/0103/0115/0119 tienen 5% cada una; 0134/0128/0125/0131/0130, 16% cada una. No inferir rareza de puntos de color o clase. Catálogo y colección conservan 41 cartas, incluidas promociones 01a–01f. La exclusión promocional prevalece incluso ante cambios de tipo/rareza.

Gesto con mouse, envoltorio real cerrado→abierto, pausa breve y cinco cartas deslizables lateralmente sin inclinarse. La llegada a la quinta 0105/0103/0115/0119 activa brillo, partículas y sonido Singular una vez por apertura local; las otras Especiales/posiciones no activan ese efecto. No repetir por refresco. Efectos no piden otro sorteo ni consumen/conceden: resultado ordenado, consumo y cantidades ya se guardaron antes. Reingresar retoma la apertura pendiente con confirmación idempotente y mismo UUID.

La reparación histórica de 0.10.1 ya terminó; no repetirla ni modificar colecciones reales sin otra instrucción.

## 6. Backend y límites reales

Reutilizar Supabase existente, Auth/Brevo SMTP y migraciones aplicadas. No recrear el servicio. El cierre 0.14 usa `aamix_challenges_and_missions_v0140.sql`, `test_challenges_and_missions_v0140_rollback.sql`, `verify_challenges_v0140.sql` y DEPLOYMENT_v0.14.0.json. Consultar APPLIED_MIGRATIONS antes de desplegar; no inventar identificadores ni repetir SQL aplicado.

`collection.begin_match(request_id,deck_id,challenge_stage=0)` usa el RPC de desafíos para 1–5; 0 mantiene la aleatoria. Inventario.challenges expone orden, rival, desbloqueo, completado y premio. La cola de recompensas conserva UUID, dueño, mazo y etapa; finish_match distingue premio nuevo de repetición. La ventana de premio espera la salida de la mesa. No aceptar del cliente cantidades, sorteos ni UUID de dueño.

El resultado de las partidas contra IA local lo declara el cliente; el servidor no valida un historial de jugadas. La cola de resultados sin enviar vive sólo en memoria: conservar el juego abierto y reintentar en Misiones; cerrar o cambiar de cuenta pierde esa cola. Una apertura de sobre ya guardada sí persiste y se recupera al reingresar sin gastar otro sobre. No se acredita concurrencia real de dos clientes ni una nueva entrega por correo en las pruebas locales.

RLS y funciones controlan UUID real y correo confirmado; el nombre visible es editable y no determina identidad. No publicar service_role, secretos SMTP, tokens ni códigos reales, ni incluirlos en ZIP. URL y clave publicable son configuración pública. Los fixtures HTTP no acreditan SQL remoto ni correo real.

## 7. Verificar, entregar y continuar

331 comprobaciones únicas actuales: 76 UI, 19 simulación, 138 recompensas y 98 sobres, cero fallos. Cinco partidas IA completas, con asientos alternados y 80 cartas conservadas en cada acción. Dos resultados forzados de UI y recibos HTTP no cuentan como partidas. Repeticiones GUI/headless no se suman. Capturas nativas revisadas; ver VALIDACION_v0.14.0.md.

SQL real nuevo y regresión anterior pasaron con rollback: 2.000 sobres sin promociones, pruebas de etapas/misiones/compatibilidad/idempotencia/autorización y datos reales conservados. No convertir esos sorteos en partidas IA ni sumarlos a las 331 comprobaciones locales. Historia: 0.13 tuvo 376; 0.12, 582/48 partidas/2.000 sobres. No afirmar que esas cifras son nuevas ejecuciones.

Entregar ZIP completo con motor, fuentes, assets, datos, lanzador y documentación. Probar extracción, manifiesto e inicio sin caché y registrar cierre en INFORME_ENTREGA. Excluir temporales/credenciales. Base 1.10 conserva 1–21 como historia y añade 22; snapshots 0.13 conservados.

Seguir la próxima solicitud del autor. Plan 0.15 propone red privada con servidor de reglas, salas, privacidad, reconexión y pruebas de dos cuentas; falta elegir alojamiento/costos antes de contratar. Siguen pendientes constructor, intercambios, diez efectos, guardado de partidas y avatares promocionales. No cambiar reglas ni reabrir decisiones confirmadas por iniciativa propia.
