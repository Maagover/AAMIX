# Recursos gráficos · AAMIX 0.13.0

18 de octubre de 2026. Presentación vigente: fondo global blanco y tonos claros, paleta blanca/dorada/café del autor, madera en la partida y sobre real de Transmisión Caída. Esta integración sustituye el fondo global de cuero de la etapa 0.4. El documento anterior permanece en `RECURSOS_GRAFICOS_historico_v0.4.md`; su descripción del cuero no define la estética vigente.

## Originales del autor

Los nueve PNG se conservan byte por byte en `assets/estetica/`: `boton_blanco.png`, `boton_dorado.png`, `boton_cafe.png`, `panel_blanco.png`, `panel_dorado.png`, `panel_cafe.png`, `mesa_madera.png`, `sobre_cerrado.png` y `sobre_abierto.png`. `PROCEDENCIA.json` registra sus dimensiones, archivos de origen y SHA-256. No se generaron sustitutos ni se editaron los bitmaps.

Las texturas se escalan y presentan con controles de Godot. Se pueden definir regiones para omitir margen transparente y alinear las dos vistas del sobre; esas regiones no alteran el archivo. La madera se presenta opaca conservando el RGB porque el original contiene transparencia. Los ajustes viven en la presentación, no en una nueva copia retocada.

La paleta de integración toma blanco, oro `#fcdb7f` / `#cfb56b` y café `#956f4b` / `#7d5f42`. Los textos y contornos usan variantes con contraste suficiente para controles claros, estados seleccionados, campos y confirmaciones. Las ventanas y avisos también forman parte de la revisión visual.

Los logos originales `assets/logo_color.png` y `assets/logo_blanco.png`, el dorso `assets/dorso.jpg` y las ilustraciones de las 41 cartas se conservan. El logo a color se integra sobre los fondos claros; no se recolorea su bitmap. Las fotos siguen recortando al personaje mediante shader sin modificar la carta.

## Mesa e información privada

La madera del autor se usa en la superficie de la partida; el resto de la aplicación mantiene el fondo claro. Las zonas, cartas, pagos, arrastres y objetivos siguen dibujándose como controles interactivos. La textura no añade reglas ni rótulos de zonas.

`game.gd` registra acciones; `motion.gd` las presenta. La presentación no modifica cartas ni decisiones ni consume aleatoriedad del motor. Robos y manos ocultas del rival conservan el dorso; una carta sólo muestra el frente cuando las reglas ya lo permiten. Se mantienen las máscaras de esquinas de carta, que recortan alfa y no recolorean el arte.

## Sobre de Transmisión Caída

El sobre cerrado aparece flotando detrás del logo de Inicio junto a Transmisión Caída y Restos, y como portada de las filas de Misiones y Mis sobres. La flotación no gira ni alterna frente/dorso.

La apertura presenta cerrado → abierto con transición, destello y sonido; luego se deslizan las cinco cartas una a una. El resultado ordenado ya llegó del servidor y sus cantidades ya están guardadas. Ningún cambio de textura, transición, actualización o reanudación concede cartas ni vuelve a sortear. Peticiones y confirmaciones mantienen su idempotencia; esta estética no necesita backend nuevo.

## Validación

**AESTHETIC_QA_PENDING.** Ver `VALIDACION_v0.13.0.md` para las comprobaciones ejecutadas de originales, carga de arte, contraste, estados y apertura. La verificación del ZIP final se registra en INFORME_ENTREGA. Los resultados y capturas de etapas anteriores son históricos.
