# Validación de AAMIX 0.13.0

18 de octubre de 2026, Chile. **376 comprobaciones aprobadas en Windows, cero fallos.** Se revisaron capturas del motor nativo de las interfaces, tablero y fases de apertura.

| Suite ejecutada | Comprobaciones | Modo |
| --- | ---: | --- |
| UI v0.13 | 143 | GUI |
| Auditoría de estética y persistencia | 71 | GUI, inventario sintético sin HTTP |
| Presentación v0.13 | 45 | GUI |
| Arte/apertura de sobre | 19 | GUI, fixture HTTP local |
| Contrato de recompensas v0.12 sobre el cliente actual | 98 | Sin interfaz, fixture HTTP local |

Se cuenta una sola ejecución final de cada suite. Los reintentos tras corregir problemas visuales y las ejecuciones iniciales no se suman. Los 11 recibos de partidas del fixture HTTP son datos sintéticos; no son partidas IA simuladas.

## Lo verificado

Fondo visible real RGB 255/250/240, controles y campos claros, contraste de texto/placeholder/confirmación y etiquetas legibles sobre madera. Las nueve imágenes originales pasan SHA-256 y carga en el motor. El rediseño muestra el sobre real en Inicio, Misiones, Mis sobres y premios de sobre. El logo conserva flotación más sutil que cartas/sobre, sin giro.

Las imágenes cerrada y abierta comparten encuadre; el envoltorio permanece en su posición durante el gesto y cambia mediante fundido/destello, con el sonido de rasgado nuevo. Después se deslizan las cinco cartas individualmente. Se verificaron gesto incompleto, transición, primera carta, salida/reentrada, refresco a mitad de la animación, orden recibido, inventario inmutable y reintentos con el mismo UUID. Carga y disparo de audio se probaron con Dummy; no se afirma escucha física por altavoces.

## Alcance conservado

No hubo cambios ni despliegue del backend, correo ni recompensas reales. Las reglas, IA, cuentas, inventario/RPC, catálogo, mazos, misiones, códigos, 14 SQL y recursos anteriores conservan sus bytes respecto de 0.12.0. Las tres misiones, ocho códigos y exclusión absoluta de promociones de sobres continúan vigentes.

No se repitieron partidas IA completas ni ensayos SQL remotos porque sus implementaciones se conservaron íntegras. Las 582 comprobaciones, 48 partidas y 2.000 sobres SQL de 0.12.0 son resultados históricos y no se suman a esta entrega. Resultados estructurados en `validacion_v0.13.0/resultados.json`; capturas en `../../capturas/v0.13.0/`.

La extracción final, CRC, manifiesto completo y arranque desde un ZIP sin caché se registran en **INFORME_ENTREGA_v0.13.0.json**, junto al ZIP. El informe externo contiene el hash final y el resultado de esa verificación independiente.

Los límites anteriores continúan: resultado de IA declarado por cliente, cola no enviada sólo en memoria, multijugador, constructor de mazos, intercambios, diez efectos, guardado de partidas y desbloqueos promocionales pendientes. No se acredita nueva prueba de concurrencia real ni entrega por correo.
