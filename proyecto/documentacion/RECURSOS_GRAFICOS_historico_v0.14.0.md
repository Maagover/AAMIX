# Recursos gráficos · AAMIX 0.14.0

18 de octubre de 2026. Inicio con valle del autor, interfaces claras, madera durante la partida, portadas de mazo y resultados originales. Los documentos `RECURSOS_GRAFICOS_historico_v0.13.0.md` y `RECURSOS_GRAFICOS_historico_v0.4.md` conservan las etapas anteriores; el cuero global histórico no define la presentación vigente.

## Ocho originales nuevos

`assets/estetica_v014/PROCEDENCIA.json` registra origen, dimensiones, bytes y SHA-256. Los ocho PNG del autor se conservan intactos:

| Archivo | Dimensiones originales | Integración |
| --- | --- | --- |
| `valle.png` | 1334×744 | Fondo de Inicio con zoom suave en bucle. |
| `mazo_kajido.png` | 1024×1024 | Portada de Mazo Kajido. |
| `mazo_papito.png` | 1024×1024 | Portada de Mazo Papito. |
| `mazo_flaan.png` | 1024×1024 | Portada de Mazo Flaan. |
| `mazo_maago.png` | 1024×1024 | Portada de Mazo Maagover. |
| `mazo_girabl.png` | 1024×1024 | Portada de Mazo Girabl. |
| `resultado_victoria.png` | 2000×2000 | Resultado de victoria. |
| `resultado_derrota.png` | 2000×2000 | Resultado de derrota. |

Se recorta margen transparente mediante regiones de textura, sin editar el PNG. `deck_art.gd` reutiliza las cinco portadas en elección, Mis Mazos, regalo inicial y premios de mazo. Los premios de cartas sueltas usan su carta real y los de sobre, el envoltorio de Transmisión Caída. Los resultados muestran el título original y las acciones debajo.

`home_backdrop.gd` conserva nodo y reloj entre renders; zoom sinusoidal con extremos suaves y sin salto. El movimiento se desactiva junto a las animaciones. Inicio conserva dos cartas y sobre detrás del logo: flotan sin girar y el logo tiene desplazamiento menor. Foto y nombre se presentan en un botón superior izquierdo que abre Mi cuenta.

## Recursos anteriores conservados

Los nueve originales de `assets/estetica/` conservan sus bytes: tres botones, tres paneles, madera, sobre cerrado y sobre abierto. Su PROCEDENCIA registra los hashes. Estética blanca/crema, oro y café, texto oscuro con contraste; madera presentada opaca conservando RGB sólo durante la mesa. Las zonas, pagos, arrastres y objetivos continúan como controles interactivos.

Los logos, dorso e imágenes de las 41 cartas se conservan. `card_image.gd` y su shader recortan ligeramente las esquinas de cartas, incluidas Inicio y premios; no recolorean la ilustración. Logos, cajas y envoltorios no reciben máscara de carta. Los perfiles mantienen recortes circulares del personaje desde su carta original, sin alterar los archivos.

## Movimiento y apertura

`interface_motion.gd` administra entradas con fundido y pequeño rebote por cambio de pantalla o ventana, respetando animaciones desactivadas. Se cancelan al navegar. Las actualizaciones de mesa y selección de una misma elección no reinician el efecto ni el sonido popup. La presentación no modifica la legalidad, la entrada ni el estado de la partida.

El sobre real cerrado pasa al abierto con transición, destello y rasgado, permanece brevemente abierto y después revela las cartas. Cada carta se desliza lateralmente sin inclinarse. La llegada a quinta posición de Kajido/SoyFlaan/Papito/Transmisión Caída activa brillo y partículas con sonido Singular; otras Especiales/posiciones no. Un refresco local no repite la llegada.

El efecto Singular es visual, no una rareza nueva: mantiene la exclusión promocional y todos los pesos de sobre. Sorteo, consumo, cantidades y orden ya están guardados antes de animar. Ninguna textura, transición, reentrada o confirmación puede consumir otro sobre ni conceder cartas otra vez. La Mano y orden ocultos del rival siguen usando dorso/cantidades mientras corresponda.

## Validación

331 comprobaciones locales únicas aprobadas y cinco partidas IA completas, cero fallos; capturas nativas revisadas. Las suites actuales verifican Inicio, etapas, portadas/resultados, premios y apertura/reanudación; ver `VALIDACION_v0.14.0.md`. Los ensayos SQL reales se documentan por separado. La verificación del ZIP final corresponde a INFORME_ENTREGA; no sumar cifras de versiones históricas.
