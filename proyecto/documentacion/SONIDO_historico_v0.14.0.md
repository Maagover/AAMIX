# Audio de AAMIX · estado 0.14.0

18 de octubre de 2026. La música y señales nuevas se sintetizaron para AAMIX desde cero, sin canciones, grabaciones, melodías existentes ni muestras externas. El juego reproduce WAV incluidos y no necesita Python ni internet para el audio.

## Música y señales nuevas

| Archivo | Duración | Formato | Uso |
| --- | --- | --- | --- |
| `audio/batalla.wav` | 51,8919 segundos | PCM16, 22.050 Hz, estéreo | Composición original de 148 BPM y 32 compases, en bucle durante interfaces y partidas. |
| `audio/popup.wav` | 0,23 segundos | PCM16, 22.050 Hz, mono | Entrada semántica de pantalla o ventana. |
| `audio/singular.wav` | 1,05 segundos | PCM16, 22.050 Hz, mono | Llegada de la quinta carta Kajido, SoyFlaan, Papito o Transmisión Caída. |

Generador reproducible: `tools/generate_battle_audio.py`. Parámetros, duración, pico, RMS y SHA-256 en `audio/METADATOS_COMBATE_v0.14.0.json`. El bucle de batalla tiene pico 0,74 y salto medido de frontera 0,000409 según sus metadatos; no se acredita por ello escucha física en el computador del autor.

`sound.gd` utiliza batalla en todas las pantallas, incluida mesa, y evita reiniciarla en cada render. Las entradas de interfaz disparan popup; una actualización corriente de mesa no lo repite. La señal Singular acompaña sólo la quinta carta de las cuatro indicadas y no repite su llegada al refrescar la misma apertura local. Ese efecto no cambia la selección de cartas ni sus probabilidades.

## Apertura y efectos conservados

`sobre_rasgar.wav`, incorporado en 0.13, conserva el crujido/rasgado original de 0,82 segundos y se dispara con el nombre lógico `sobre_abrir`. Parámetros en `audio/METADATOS_APERTURA_v0.13.0.json` y generador `tools/generate_pack_tear_audio.py`. `sobre_carta.wav` acompaña cada carta deslizada. El arpegio anterior `sobre_abrir.wav` permanece como archivo histórico.

Se conservan robo, carta, pago, ataque, bloqueo, descarte, barajar, daño e interfaz, además de regalo, regalo recibido, victoria, derrota y turno. Los generadores/metadatos históricos y `SONIDO_historico_v0.13.0.md` describen su procedencia. `inicio.wav`, composición original anterior de 90 BPM/42,667 segundos, se conserva como recurso histórico; su antiguo desvanecimiento al entrar a mesa no describe la música vigente de 0.14.

Música y efectos usan buses separados y voces limitadas. `motion.gd` acompaña los eventos al comenzar su recorrido. El sonido no consulta identidades ocultas, no cambia reglas ni consume aleatoriedad del motor.

## Controles y validación

Configuración → Sonido conserva Música, Efectos de las cartas, Silenciar todo y Probar sonido. Las preferencias se guardan como ajustes locales de audio y se recuperan al abrir; no contienen cuenta, correo, códigos ni token de acceso.

Las suites locales actuales validan carga/disparo con el controlador Dummy, música activa en mesa, efectos de ventana/Singular y ausencia de repeticiones al renderizar/reanudar. Las capturas revisan la interfaz, no el sonido físico. No se acredita escucha por altavoces ni dispositivos externos; los resultados ejecutados figuran en `VALIDACION_v0.14.0.md`. Los ensayos anteriores permanecen como historia.
