# Validación acotada · AAMIX 0.15.0

62 casos distintos GUI/HTTP en motor Windows y fixture local; 20 SQL reales con cinco usuarios sintéticos y rollback integral. No se ejecutaron suites históricas, matrices IA ni muestreos masivos. No son partidas completas de IA los resultados forzados del fixture. Se revisaron las 17 capturas de intro, inicio, modos, resumen, bienvenida, sobre, elección de mazo, niveles, resultados y premio.

El primer guion de prueba usaba una fase inexistente `ended` (el motor usa `finished`) y comparaba coordenadas físicas de ventana con las lógicas de la UI. Se corrigió el guion y se retomaron los casos 51–62; la alineación 27 se verificó aparte. Los demás casos ya aprobados no se repitieron como comprobaciones. Los registros íntegros inicial y reparado quedan en validacion_v0.15.0; los fallos del primer guion no se ocultan. Código de reglas/IA sin cambios.

La revisión suma 82 casos fuente distintos. Se preparó una prueba final de 6 casos desde el ZIP extraído sin caché: intro, MP3 loop, Inicio invitado, confirmación antes de jugar, partida válida y carga de arte/música. El resultado de esa extracción y el total cerrado de 88 están en el informe externo junto al ZIP. Incluyendo comprobaciones repetidas y preflight, el presupuesto es 93 aserciones; no se suman recuentos de versiones anteriores.

Backend verificado aplicado. Diez tablas reales tienen conteos y hashes iguales antes/después. Ningún correo, canje o recompensa de cuenta real. No se probó concurrencia entre dos conexiones. Audio con Dummy, sin escucha física acreditada. Los avisos previos del asesor se documentan con enlaces en backend/WELCOME_AND_CHALLENGE_v0.15.0.md.
