# Audio vigente · AAMIX 0.15.0

Intro/menús: `audio/menu_arcade_coins.mp3`, copia idéntica de Renser - Arcade Coins enviada por el autor, en bucle con AudioStreamMP3. Mesa aleatoria: `audio/batalla.wav` de 0.14. Mesa del desafío: `audio/combate_desafio.wav`, composición original procedimental a 158 BPM y 48,6076 segundos, sin muestras externas ni melodías de Pokémon. Generador `tools/generate_challenge_audio_v015.py` y metadatos `audio/METADATOS_DESAFIO_v0.15.0.json`. Un render de la misma pantalla no reinicia pista.

Cambiar entre mesa/menús elige pista y aplica entrada suave. Se mantienen controles Música/Efectos/Silenciar, preferencias locales y las señales popup, apertura, Singular, victoria/derrota y cartas. La intro reproduce música al aparecer. Los recursos se cargan desde bytes/archivos sin depender de caché importada.

La carga, asignación, bucle y disparo se comprobaron con controlador Dummy. No se acredita escucha física en altavoces. La documentación y generadores anteriores se conservan como historia; no regenerar ni sobrescribir el MP3 del autor.
