# Audio de AAMIX · estado 0.13.0 e historial

En 0.13.0 se conservan íntegros los archivos y controles de audio de 0.12.0 y se añade `sobre_rasgar.wav`: un crujido y rasgado de envoltorio original, sintetizado sin muestras externas, de 0,82 segundos. La transición entre las imágenes reales del sobre cerrado y abierto dispara este recurso con el nombre lógico `sobre_abrir`; cada carta deslizada sigue disparando `sobre_carta.wav`. El arpegio anterior `sobre_abrir.wav` se conserva como archivo histórico. Se mantienen volumen, silencio y música de las interfaces. Las pruebas verifican carga y disparo de los recursos con el controlador de audio Dummy; no acreditan escucha física por altavoces. Generador y parámetros: `tools/generate_pack_tear_audio.py` y `audio/METADATOS_APERTURA_v0.13.0.json`.

En 0.10.0 se conservaron los archivos y controles anteriores y se añadieron `regalo.wav`, `regalo_recibido.wav`, `victoria.wav`, `derrota.wav`, `turno.wav`, `sobre_abrir.wav` y `sobre_carta.wav`. Son señales de regalo, resultado, cambio de turno y apertura/revelación. La música acompaña también las pantallas de cuenta, colección y recompensas. La confirmación de cierre y los cambios visuales no alteran los controles de volumen ni silencio. La validación de aquella versión se conserva en VALIDACION_v0.10.0.md.

El resto de este documento conserva la descripción técnica y validación histórica de los recursos originales de 0.4; no acredita pruebas nuevas de salida física por altavoces.

La música y los nueve efectos se sintetizaron desde cero para este prototipo, sin usar canciones, grabaciones o bancos de muestras externos. El generador reproducible está en `herramientas/generar_audio.py`; usa Python 3 y NumPy únicamente para preparar los archivos. El juego utiliza los WAV incluidos y no necesita Python ni internet.

- `inicio.wav`: composición instrumental original, 90 BPM, 16 compases, 42.667 segundos. Plucks suaves, bajo y fondo sostenido; cola de reverberación circular para repetir el bucle. Suena en Inicio y selección de mazo, y se desvanece al entrar a jugar.
- `robo.wav`: roce breve de carta. También acompaña el reparto inicial.
- `carta.wav`: movimiento y colocación de carta, incluidos jugadas y reagrupación.
- `pago.wav`: confirmación breve del traslado de Recursos a Pagadas.
- `ataque.wav`: desplazamiento con impacto suave.
- `bloqueo.wav`: golpe corto de bloqueo.
- `descarte.wav`: carta enviada al Cementerio o a Quemadas.
- `barajar.wav`: sucesión de roces al barajar o reordenar el Mazo.
- `dano.wav`: impacto del daño al Mazo, seguido de los descartes individuales.
- `interfaz.wav`: pulsación discreta de los botones.

Formato: PCM de 16 bits, 22.050 Hz; música estéreo y efectos mono. Los archivos no contienen saturación digital. `audio/METADATOS.json` conserva duraciones, picos y nivel medio de los recursos.

`sound.gd` mantiene música y efectos en buses separados y un conjunto limitado de reproductores. `motion.gd` llama al sonido al comenzar el recorrido de cada carta o su acción. El audio no consulta identidades de cartas ocultas, no modifica el motor ni consume números aleatorios del juego.

El botón Sonido ofrece dos volúmenes, silencio general y una prueba de robo. Las preferencias se guardan en la carpeta de datos de la aplicación AAMIX y se recuperan al abrir. Ese archivo de preferencias no es un perfil ni una cuenta de jugador.

Validación: carga de todos los archivos, señal no nula desde los buses de música y efectos, independencia de volúmenes, silencio, guardado y recuperación de preferencias, transiciones de pantallas y cierre. La salida por altavoces de Windows debe comprobarse en el computador del autor.
