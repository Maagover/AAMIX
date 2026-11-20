# Validación de AAMIX 0.14.0

18 de octubre de 2026, Chile. **331 comprobaciones locales únicas aprobadas, cero fallos, y cinco partidas IA completas.** Las capturas se generaron con el motor nativo de Windows y fueron revisadas. El cierre SQL remoto se documenta por separado.

## Suites locales ejecutadas

| Suite final | Comprobaciones | Modo |
| --- | ---: | --- |
| `tests/test_ui_v014.gd` | 76 | GUI de Windows; cuenta ficticia sólo en memoria, sin RPC real. |
| `tests/test_challenge_games_v014.gd` | 19 | Sin interfaz; cinco partidas IA completas por el resolvedor real de desafíos. |
| `tests/test_rewards_v014.gd` | 138 | GUI y servidor HTTP ficticio local. |
| `tests/test_pack_v014.gd` | 98 | GUI y servidor HTTP ficticio local. |

Se cuenta una sola ejecución final de cada suite. Sus repeticiones sin interfaz o nuevas capturas no se suman. Los dos resultados forzados de UI y los recibos de partidas del fixture HTTP son datos sintéticos; no cuentan entre las cinco partidas IA completas. Los 376 checks de 0.13.0 y 582/48 partidas/2.000 sobres de 0.12.0 se conservan como historia.

## Navegación y arte

Inicio con valle original y zoom suave sin salto al cerrar el ciclo; nodo y reloj persistentes tras render de inventario, y animación desactivable. Cuatro opciones en orden, identidad superior izquierda que abre Mi cuenta y código/configuración superior derecha. Multijugador muestra «En desarrollo». Partida individual abre sus dos modos; invitado conserva tres mazos y recibe avisos para contenido de cuenta. Salir permanece en Inicio con confirmación.

Se verificaron cinco etapas en orden, premios 1/1/1/2/3, selección bloqueada según inventario, cinco mazos propios visibles sin corte, portadas aportadas, progreso completado y repetición. Victoria/Derrota usan PNG originales. Revancha conserva el mazo por ID aun cuando cambia el orden del inventario. Las entradas de pantalla y ventana se cancelan correctamente, incluyen diálogos anidados, respetan animaciones desactivadas y no repiten sonido al refrescar la mesa.

Las cartas de Inicio y premios usan el redondeado común. Portadas de mazo, cartas sueltas y sobres muestran el arte correspondiente; colección 35+6, cantidades, retratos y mesa conservan su presentación. Capturas principales: Inicio, Mi cuenta, submenu individual, desafío bloqueado/progreso, selector de cinco mazos, mesa, Victoria, Derrota, colección, mazos, regalo, configuración, sonido y salida. Recompensas/apertura tienen capturas adicionales del fixture.

## Cinco partidas IA completas actuales

| Etapa / rival | Asiento humano | Semilla | Acciones | Ganador |
| --- | ---: | ---: | ---: | ---: |
| 1 / Papito | 1 | 24031 | 156 | 0 |
| 2 / Flaan | 0 | 24062 | 70 | 1 |
| 3 / Kajido | 1 | 24093 | 94 | 1 |
| 4 / Maagover | 0 | 24124 | 107 | 0 |
| 5 / Girabl | 1 | 24155 | 110 | 1 |

Cada partida terminó con la IA actual, usando el mismo `main.challenge_opponent` que la pantalla. Se alternaron asientos, se ejercitó el pago manual del lado humano y se comprobaron las 80 cartas y las invariantes tras cada acción. Maagover/Girabl coinciden con el fixture histórico; el grupo aleatorio de Kajido/Papito/Flaan no se modifica. No se afirma una matriz completa de emparejamientos.

## Cliente de misiones, desafíos y sobres

Fixture HTTP: cuatro misiones con sus frecuencias/premios actuales, compatibilidad de reclamos antiguos, cola con etapa/mazo/UUID/dueño, reintentos y cambio de sesión; premio de desafío pendiente hasta salir de la mesa. Premios de carta, mazo y sobre muestran su imagen real. Las pruebas locales no hacen canjes ni reclamos sobre cuentas reales.

Apertura: gesto incompleto, envoltorio abierto con pausa, transición, cartas derechas al deslizar, quinta carta, reentrada y refresco sin otro sorteo. Brillo/partículas/audio sólo para 0105/0103/0115/0119 en quinta posición; las demás Especiales y otra posición no lo activan. Un refresco local no repite la llegada Singular. Se conserva orden recibido, inventario concedido antes de animar, UUID y confirmación idempotente. Los cambios de presentación no modifican el grupo ni los pesos.

Música de combate y señales popup/Singular se cargaron y dispararon con el controlador Dummy. Eso no acredita escucha física por altavoces. Las imágenes originales y metadatos conservan su procedencia; no se retocan bitmaps del autor.

## Backend real aplicado y probado

Migración **20261018203917_aamix_challenges_and_missions_v0140**, aplicada y registrada. El ensayo `test_challenges_and_missions_v0140_rollback.sql` pasó con usuarios sintéticos y rollback. Verificó cinco etapas/rivales de 40 cartas, premio único por UUID/etapa, bloqueo de saltos, derrota sin desbloqueo, recibos aleatorios sin atribución falsa de desafío, inmutabilidad de UUID/modo/etapa/mazo y resultado, repeticiones de intentos ya iniciados y 20 reintentos de inicio/finalización/reclamo.

Misiones: Juega1 diaria a medianoche de Chile y alias anterior; cualquier reclamo antiguo de Gana1 bloquea el nuevo premio de por vida; nuevos Juega10 por tres sobres sin alterar los cinco históricos; Gana10 de por vida por cinco y recibos anteriores incluidos. Se verificaron pertenencia/RLS, autenticación, ACL, wrappers invoker y rollback atómico por desbordamiento en desafíos y cuatro misiones.

El ensayo nuevo y la regresión `test_gift_codes_v0110_rollback.sql` sumaron **2.000 sorteos de sobre reales del servidor, cero promociones**, todos revertidos. Ocho definiciones de código conservadas y bloqueo de retratos promocionales vigente. Son pruebas remotas nuevas de 0.14 y se distinguen de los 2.000 sorteos históricos de 0.12; no se suman como comprobaciones locales ni partidas IA.

El primer intento de la suite nueva llegó al último bloque de sobres con un JWT vacío heredado de su prueba de autorización; el servidor lo rechazó correctamente. Se corrigió únicamente la preparación del fixture y la suite completa pasó. La fuente SQL de producción permaneció sin cambios, SHA-256 `56edb8ecb88865bdc2c5f13e17a732676aeb33dab8eef5d30aa99a378ec2aa31`.

Estado real antes/después: 142 cartas, tres mazos, cinco canjes, cinco recibos (tres finalizados), un reclamo de misión, dos diarios y cero sobres. Los hashes de campos anteriores en nueve tablas coinciden; cero cuentas QA y cero premios/reclamos/completados de desafío reales nuevos. Auth y SMTP no se modificaron. Detalle en `../backend/VERIFICATION_v0.14.0.json`, `DEPLOYMENT_v0.14.0.json` y `APPLIED_MIGRATIONS.json`.

## Paquete y límites

El informe externo `INFORME_ENTREGA_v0.14.0.json`, junto al ZIP, registra el hash final, CRC, manifiesto completo y arranque desde una extracción independiente sin caché.

El cliente declara los resultados de IA; no hay historial de jugadas validado por servidor. La cola no enviada sigue sólo en memoria. No se acredita concurrencia real de conexiones independientes ni entrega nueva por correo. Multijugador sólo muestra un aviso; el plan de 0.15 es una propuesta. Constructor, intercambios, diez efectos, guardado de partidas y desbloqueos promocionales siguen pendientes.
