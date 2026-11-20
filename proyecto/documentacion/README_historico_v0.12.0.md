# AAMIX · versión 0.12.0

Versión portátil completa para Windows de 64 bits. Incluye Godot 4.7.2 oficial, fuentes, las 41 cartas del catálogo, imágenes, dorsos, logos, música, sonidos y documentación.

## Jugar

1. Extrae **todo el ZIP en una carpeta nueva**.
2. Abre **Jugar_AAMIX.bat**. No necesitas instalar Godot.
3. Ingresa con tu correo y código, crea tu cuenta o elige **Jugar como invitado**.

Internet es necesario para cuentas, colección, fotos de perfil y recompensas. El invitado puede practicar sin cuenta con Kajido, Papito o Flaan. Las cuentas juegan con sus mazos obtenidos. No mezcles archivos entre versiones.

## Cambios de 0.12.0

- **Mi Colección:** 35 cartas regulares en filas centradas y, al final, las seis promocionales separadas en una sola fila. Se conservan cantidades, faltantes y detalle por doble clic.
- **Inicio:** cartas más grandes y próximas; el logo también flota suavemente, con menor desplazamiento. No hay giro ni alternancia de frente/dorso. Se elimina el subtítulo y el pie usa **AAMIX · versión 0.12.0**.
- **Mis Mazos:** «Obtenido · 40 cartas», sin el texto adicional de guardado.
- **Misiones:** se añaden Gana 1 partida y Juega 10 partidas, con sus propias recompensas.
- **Regalos:** AAMIXTC entrega un sobre; M4Z0G1R4 entrega el Mazo Girabl histórico.

Se conservan las 22 fotos no promocionales, sus encuadres y el selector sin nombres debajo. Poseer una promoción no desbloquea su foto. La expansión N.º 1 sigue siendo **Transmisión Caída**, con el mismo grupo de 35 cartas y probabilidades de sobre.

## Códigos de regalo

Cada código se puede canjear **una vez por cuenta**, de forma independiente. No se reinician los canjes anteriores. Los códigos de cartas sueltas no conceden mazos, sobres ni fotos promocionales.

| Código exacto | Recompensa |
| --- | --- |
| M4Z0M44G0 | Mazo Maagover histórico: 40 cartas, incluidos 15 Restos. |
| P3RI | 3 Peri. No lleva cero al final. |
| B1G0T3S | 3 Bigotes. |
| SI2TYA | 1 Tsuki y Akira. |
| CHANCHULINES | 1 Granjita de Chanchuus. |
| TORNEOAAMIX1 | 1 Dragón Tee K.O. |
| AAMIXTC | 1 sobre de Transmisión Caída, guardado en Mis sobres. |
| M4Z0G1R4 | Mazo Girabl histórico: 40 cartas, incluidos 12 Restos. |

Actualizar el juego no reinicia los canjes anteriores ni el regalo inicial. M4Z0M44G0 conserva su mazo exacto, incluida su promoción legítima 01c. M4Z0G1R4 conserva exactamente la lista histórica de Girabl, incluidas 3 Peri, 2 Bigotes y 1 Tsuki y Akira. Esas promociones son válidas en el mazo; no entran en sobres ni desbloquean fotos. Ningún regalo de mazo añade opciones al invitado o a la IA. La pantalla de canje no muestra esta tabla.

## Misiones y sobres

| Misión | Frecuencia | Recompensa |
| --- | --- | --- |
| Juega 1 partida | Diaria; termina con victoria o derrota. | 1 sobre. |
| Gana 1 partida | Diaria; termina con victoria. | 1 sobre. |
| Juega 10 partidas | Acumulativa; diez partidas terminadas, una vez por cuenta. | 5 sobres. |

Las diarias se reinician a las **00:00 de Chile, America/Santiago**, según el servidor. La acumulativa conserva el progreso y no se reinicia a medianoche ni cada diez partidas. Una victoria puede completar ambas diarias, que se reclaman por separado. El progreso usa partidas finalizadas guardadas, incluidas anteriores a esta versión.

Abre el envoltorio con el mouse y desliza las cartas hacia un costado. El resultado se guarda antes de la animación. Si cierras durante una apertura, reingresa con el mismo correo para retomar las mismas cartas sin gastar otro sobre.

Las promociones **nunca salen en sobres**. Participan **35 cartas: 1 Recurso, 25 normales y 9 Especiales**. Primero hay un Recurso garantizado; las posiciones 2–4 son normales, uniformes y repetibles; la quinta es normal 70% o Especial 30%. Nunca aparecen Recursos después de la primera posición. Dentro del grupo Especial, Kajido, SoyFlaan, Papito y Transmisión Caída tienen 5% cada uno; las otras cinco Especiales, 16% cada una. Son probabilidades internas del grupo Especial: equivalen a 1,5% y 4,8% del total de sobres por carta, respectivamente.

## Cuenta y continuidad

Usa el mismo correo y un código nuevo al reabrir para recuperar tu UUID, cartas, mazos y recompensas. Correo, códigos de acceso y tokens sólo viven en memoria. El regalo inicial ya elegido se conserva. Salir sólo aparece en Inicio y siempre pide confirmación; siguen los avisos de turno, Pasar daño y Victoria/Derrota con Revancha e Inicio.

Si falla registrar el final de una partida, **mantén abierto el juego y reintenta en Misiones**. Ese resultado pendiente sólo vive en memoria y se pierde al cerrar o cambiar de cuenta. El juego comunica el resultado de la IA local; el servidor no valida su historial de jugadas. La apertura de sobre ya guardada sí persiste.

La migración **20261018035100_aamix_missions_and_gifts_v0120** está aplicada. Las pruebas nuevas y de compatibilidad pasaron con **2.000 sobres sin promociones**, cuentas sintéticas y rollback. Auth, usuarios y recompensas reales se conservaron. Consulta `proyecto/backend/APPLIED_MIGRATIONS.json` y `DEPLOYMENT_v0.12.0.json`; no repetir migraciones ya aplicadas.

**0.12.0: 582 comprobaciones y 48 partidas completas simuladas contra IA aprobadas en Windows, cero fallos.** Las repeticiones de suites y los recibos ficticios de HTTP no se suman como partidas nuevas. Consulta `proyecto/documentacion/VALIDACION_v0.12.0.md`; la extracción, integridad y arranque del ZIP final se registran en INFORME_ENTREGA. Las cifras de 0.11.0 y anteriores son historia.

Para continuar: `proyecto/documentacion/BASE_DEL_PROYECTO_v1.8.md`, sección 20, `CONTINUIDAD.md` y `PROMPT_CONTINUIDAD.md`. Siguen pendientes multijugador, constructor, intercambios, diez efectos, guardado de partidas y desbloqueos promocionales.

`SHA256SUMS.txt` contiene el manifiesto cuando se cierre el paquete. Las licencias del motor están en `motor/`.
