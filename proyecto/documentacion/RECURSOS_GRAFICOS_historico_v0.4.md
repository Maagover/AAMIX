# Recursos gráficos · AAMIX 0.4

## Aportados por el autor

- `assets/logo_color.png`: copia exacta de `AAMIX_logo.png`.
- `assets/logo_blanco.png`: copia exacta de `AAMIX_logoW.png`.
- `assets/dorso.jpg`: copia exacta de `0000_Dorso.jpg`.
- `Tablero AAMIX vacío con zonas simétricas(1).png`: referencia de tonos marrones, cuero y cobre. Sus zonas y rótulos no se incorporaron como imagen del tablero.

Los logos se presentan mediante una región de textura que omite su margen transparente. Los archivos originales se conservan íntegros. El dorso se muestra en ambos Mazos y en la Mano oculta del rival, incluso durante sus robos.

La distribución de zonas sigue el esquema de la versión 0.2. La mesa, los bordes y los controles se dibujan en Godot para conservar la interacción y adaptarse al tamaño de la ventana.

## Textura de fondo generada

Archivo: `assets/mesa_cuero_v03.png`.

Herramienta: generación de imágenes integrada en ChatGPT, con la referencia estética del autor. Una imagen de cuero marrón, sin cartas, texto, logos ni zonas. Se usa como fondo de la aplicación, con una modulación de color para mantener legibles los controles. No sustituye ninguna ilustración de las cartas.

Prompt utilizado, íntegro:

> Use case: stylized-concept. Asset type: background texture for an existing desktop card-game interface, AAMIX. Use the supplied image only as a reference for its colors and material. Generate ONE new flat top-down background, landscape 16:10. Full-bleed warm brown leather tabletop with very fine worn grain, softly mottled copper and tobacco tones, slightly darker outer edges and a gently lighter center. Refined, understated, quiet enough for readable cards and UI on top. Natural subtle leather/paper feel, flat even lighting. ABSOLUTELY NO text, logos, letters, borders, rectangular slots, zones, playing cards, symbols, objects, or perspective. Do not reproduce the reference's layout; the application already draws every zone. Only the brown leather aesthetic is needed.

## Animación e información visible

`game.gd` registra movimientos de cartas y acciones; `motion.gd` los presenta sin modificar el estado de la partida ni consumir aleatoriedad. Los destinos se enmascaran durante el recorrido y sus contadores avanzan al llegar cada carta. Mientras una secuencia está en curso no se acepta otra acción.

Los robos ordinarios del rival muestran únicamente el dorso. Una carta jugada, descartada o mostrada por una búsqueda puede presentar su frente conforme a las reglas. Las cartas que vuelven al Mazo terminan boca abajo.

Ataque y bloqueo tienen movimientos breves y resaltados; el bloqueo vincula visualmente las dos cartas. El daño muestra cada carta del Mazo llegando al Cementerio. El barajado abanica y mueve varios dorsos sobre el Mazo.

## Presentación de cartas de la versión 0.4

Se eliminan las casillas individuales y todos los rótulos repetidos bajo las cartas. Las imágenes se presentan completas, conservando su proporción. Un shader compartido recorta únicamente las esquinas, con un radio equivalente al 3.5 % del ancho de la imagen. No cambia los colores ni los archivos originales. El mismo recurso se usa en cartas visibles, dorsos, elecciones, miniaturas y animaciones.

La selección y los destinos válidos pueden señalarse con un contorno fino temporal. Las reglas, el texto vigente y la fuerza actual siguen en el detalle mediante doble clic. El nombre y los datos auxiliares también están disponibles como ayuda al pasar el mouse; no aparecen como etiquetas permanentes bajo la imagen.
