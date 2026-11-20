# AAMIX · versión 0.14.0

Versión portátil completa para Windows de 64 bits. Incluye Godot 4.7.2 oficial, fuentes, catálogo de 41 cartas, imágenes, dorsos, logos, música, sonidos y documentación.

## Jugar

1. Extrae **todo el ZIP en una carpeta nueva**.
2. Abre **Jugar_AAMIX.bat**. No necesitas instalar Godot.
3. Ingresa con correo y código, crea tu cuenta o elige **Jugar como invitado**.

Internet es necesario para cuentas, colección, perfil y recompensas. El invitado practica con Kajido, Papito o Flaan; las cuentas juegan con mazos obtenidos. No mezcles archivos entre versiones.

## Cambios de 0.14.0

- **Inicio:** valle del autor con zoom suave continuo, cuatro opciones en orden: Partida individual, Multijugador, Misiones y Mi Colección. Foto y nombre arriba a la izquierda abren Mi cuenta; Código de regalo y Configuración quedan arriba a la derecha. Salir conserva confirmación. Multijugador muestra «En desarrollo».
- **Partida individual:** submenu con Partida Aleatoria y Desafío AAMIX. La aleatoria mantiene los tres rivales base; el desafío usa cinco etapas fijas con progreso por cuenta.
- **Arte y movimiento:** cinco portadas de mazo para selección, listas, regalo y premios; imágenes originales de Victoria/Derrota; entradas suaves de interfaces y ventanas con pequeño rebote y señal sonora. Las actualizaciones de mesa no repiten esa entrada. Las cartas de Inicio y premios conservan bordes redondeados.
- **Audio:** composición original de combate a 148 BPM, en bucle de 51,89 segundos, que acompaña también las partidas; señales nuevas de ventana y carta Singular.
- **Sobres:** pausa breve con el envoltorio abierto, cartas siempre derechas durante el deslizamiento y brillo/partículas/sonido al llegar a la quinta carta si es Kajido, SoyFlaan, Papito o Transmisión Caída. El efecto no cambia premios ni probabilidades.

Los ocho PNG nuevos permanecen intactos en `proyecto/assets/estetica_v014/`; `PROCEDENCIA.json` registra sus hashes. Se mantienen interfaces claras, madera durante la partida, colección 35+6 y 22 retratos no promocionales.

## Desafío AAMIX

| Etapa | Rival fijo | Premio por primera victoria |
| --- | --- | --- |
| 1 | Mazo Papito | 1 sobre. |
| 2 | Mazo Flaan | 1 sobre. |
| 3 | Mazo Kajido | 1 sobre. |
| 4 | Mazo Maagover | 2 sobres. |
| 5 | Mazo Girabl | 3 sobres. |

Se desbloquean en orden al ganar. Cada premio se entrega **una sola vez por cuenta y etapa**; volver a jugar una etapa completada no lo repite. Se elige un mazo obtenido propio antes de enfrentar al rival fijo. Las listas de Maagover (40/15) y Girabl (40/12) conservan las cantidades históricas, incluidas sus promociones legítimas. Esto no los añade a la Partida Aleatoria ni a la práctica del invitado.

La migración **20261018203917_aamix_challenges_and_missions_v0140** está aplicada. La prueba SQL nueva y la regresión de códigos anterior pasaron en el servicio real con rollback, con **2.000 sobres sin promociones**. Ver `proyecto/backend/APPLIED_MIGRATIONS.json` y `proyecto/backend/DEPLOYMENT_v0.14.0.json`; no repetir migraciones aplicadas.

## Misiones

| Misión | Frecuencia | Recompensa vigente |
| --- | --- | --- |
| Juega 1 partida | Diaria; terminar con victoria o derrota. | 1 sobre. |
| Gana 1 partida | Acumulativa de por vida; una vez por cuenta. | 1 sobre. |
| Juega 10 partidas | Acumulativa de por vida; una vez por cuenta. | 3 sobres. |
| Gana 10 partidas | Acumulativa de por vida; una vez por cuenta. | 5 sobres. |

Se conservan los premios ya entregados. Un reclamo anterior de «Gana 1 partida», aunque fuera diario, impide cobrar otra vez la nueva misión de una victoria. Los reclamos históricos de «Juega 10 partidas» mantienen sus cinco sobres; no se retiran dos sobres ni se concede de nuevo el premio vigente de tres. Sólo «Juega 1 partida» se reinicia a las **00:00 America/Santiago**, según servidor; las otras tres no se reinician ni se repiten cada diez partidas. El progreso usa los recibos de partidas terminadas guardados, incluidos los anteriores.

## Códigos y sobres

Una vez por cuenta/UUID y código, de manera independiente del regalo inicial y de otros canjes. No se reinician canjes al actualizar. La pantalla de Código de regalo conserva sólo el formulario; la tabla siguiente es documentación.

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

Girabl conserva 3 Peri, 2 Bigotes y 1 Tsuki y Akira; Maagover conserva su promoción legítima 01c. Poseer promociones no permite elegirlas como foto ni las introduce en sobres. Los códigos de cartas sueltas conceden sólo esas cartas.

Las promociones nunca salen en sobres. La expansión N.º 1, **Transmisión Caída**, conserva **35 elegibles: 1 Recurso, 25 normales y 9 Especiales**. Recurso garantizado sólo en posición 1; normales uniformes y repetibles en 2–4; quinta normal 70% o Especial 30%. Dentro de Especiales, Kajido/SoyFlaan/Papito/Transmisión Caída tienen 5% cada uno; las otras cinco Especiales, 16% cada una. Son pesos dentro del grupo Especial, equivalentes a 1,5% y 4,8% del total de sobres por carta. Nunca hay otro Recurso en 2–5.

Abre el envoltorio con el mouse y desliza las cinco cartas lateralmente. El resultado ordenado y sus cantidades se guardan antes de animar; reingresar permite recuperar una apertura pendiente sin otro sorteo. Mantén el mismo correo para recuperar UUID, colección y mazos; correo, códigos de acceso y tokens de sesión sólo viven en memoria.

El resultado de las partidas contra IA local lo declara el cliente; el servidor no valida un historial de jugadas. La cola de resultados sin enviar vive sólo en memoria: conservar el juego abierto y reintentar en Misiones; cerrar o cambiar de cuenta pierde esa cola. Una apertura de sobre ya guardada sí persiste y se recupera al reingresar sin gastar otro sobre. No se acredita concurrencia real de dos clientes ni una nueva entrega por correo en las pruebas locales.

## Validación y continuidad

**331 comprobaciones locales únicas aprobadas, cero fallos, y cinco partidas IA completas.** Hay 76 de interfaz, 19 de simulación de desafíos, 138 de recompensas y 98 de sobres. Repeticiones GUI/headless no se suman; los resultados forzados y recibos HTTP del fixture no cuentan como partidas IA. Capturas del motor nativo revisadas. Ver `proyecto/documentacion/VALIDACION_v0.14.0.md`.

El informe externo `INFORME_ENTREGA_v0.14.0.json`, junto al ZIP, registra su hash final, integridad, extracción independiente y arranque sin caché.

Base vigente: `BASE_DEL_PROYECTO_v1.10.md`, sección 22, junto a `CONTINUIDAD.md` y `PROMPT_CONTINUIDAD.md`. La base 1.9 y los documentos 0.13.0 permanecen como historia; sus 376 comprobaciones y los 582/48/2.000 de 0.12.0 no se suman a esta entrega. El plan `MULTIJUGADOR_PLAN_v0.15.md` propone la próxima etapa y no acredita red jugable. Siguen pendientes constructor, intercambios, diez efectos, guardado de partidas y desbloqueos promocionales.

`SHA256SUMS.txt` contiene el manifiesto del paquete cerrado. Licencias del motor en `motor/`. No repetir migraciones ya aplicadas; consultar el registro real en `proyecto/backend/APPLIED_MIGRATIONS.json`.
