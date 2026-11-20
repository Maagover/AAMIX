# AAMIX · Mesa 0.11.0

Versión portátil completa para Windows de 64 bits. Incluye Godot 4.7.2 oficial, fuentes, las 41 cartas del catálogo, imágenes, dorsos, logos, música, sonidos y documentación.

## Jugar

1. Extrae **todo el ZIP en una carpeta nueva**.
2. Abre **Jugar_AAMIX.bat**. No necesitas instalar Godot.
3. Ingresa con tu correo y código, crea tu cuenta o elige **Jugar como invitado**.

Internet es necesario para cuentas, colección, fotos de perfil y recompensas. El invitado puede practicar sin cuenta con Kajido, Papito o Flaan. Las cuentas juegan con sus mazos obtenidos. No mezcles archivos entre versiones.

## Cambios de 0.11.0

- Inicio con **dos cartas de frente flotando detrás del logo fijo**, al lado derecho.
- Misiones y Mis sobres en listas a la izquierda. Progreso, cantidades y acciones quedan a la derecha. La colección y la elección de mazo presentan sus cartas centradas.
- **22 fotos de Aliados no promocionales**, sin nombres debajo de las imágenes. Dicky, Maagover y Girabl tienen nuevos encuadres de rostro. Los nombres se conservan en tooltips.
- Las fotos promocionales quedan reservadas para futuros desbloqueos. Poseer la carta no desbloquea su foto.
- Formulario de regalo simple: escribe el código y pulsa **Canjear**. Los canjes muestran la recompensa que corresponde a cada código.

La expansión N.º 1 se llama **Transmisión Caída**. Su sobre conserva el mismo grupo de 35 cartas no promocionales y las mismas probabilidades.

## Códigos de regalo

Cada código se puede canjear **una vez por cuenta**, de forma independiente. Los cinco nuevos códigos entregan cartas a Mi Colección, sin añadir mazos, sobres ni fotos promocionales.

| Código exacto | Recompensa |
| --- | --- |
| M4Z0M44G0 | Mazo Maagover histórico: 40 cartas, incluidos 15 Restos. |
| P3RI | 3 Peri. No lleva cero al final. |
| B1G0T3S | 3 Bigotes. |
| SI2TYA | 1 Tsuki y Akira. |
| CHANCHULINES | 1 Granjita de Chanchuus. |
| TORNEOAAMIX1 | 1 Dragón Tee K.O. |

Actualizar el juego no reinicia los canjes anteriores ni el regalo inicial. M4Z0M44G0 conserva su mazo exacto, incluida su promoción legítima 01c. La pantalla de canje no muestra esta tabla.

## Misiones y sobres

Termina una partida, ganes o pierdas, y reclama **un sobre por cuenta y día** en Misiones. El día se reinicia a las **00:00 de Chile, America/Santiago**, según el servidor.

Abre el envoltorio con el mouse y desliza las cartas hacia un costado. El resultado se guarda antes de la animación. Si cierras durante una apertura, reingresa con el mismo correo para retomar las mismas cartas sin gastar otro sobre.

Las promociones **nunca salen en sobres**. Participan **35 cartas: 1 Recurso, 25 normales y 9 Especiales**. Primero hay un Recurso garantizado; las posiciones 2–4 son normales, uniformes y repetibles; la quinta es normal 70% o Especial 30%. Nunca aparecen Recursos después de la primera posición. Dentro del grupo Especial, Kajido, SoyFlaan, Papito y Transmisión Caída tienen 5% cada uno; las otras cinco Especiales, 16% cada una. Son probabilidades internas del grupo Especial: equivalen a 1,5% y 4,8% del total de sobres por carta, respectivamente.

## Cuenta y continuidad

Usa el mismo correo y un código nuevo al reabrir para recuperar tu UUID, cartas, mazos y recompensas. Correo, códigos de acceso y tokens sólo viven en memoria. El regalo inicial ya elegido se conserva. Salir sólo aparece en Inicio y siempre pide confirmación; siguen los avisos de turno, Pasar daño y Victoria/Derrota con Revancha e Inicio.

Si falla registrar el final de una partida, **mantén abierto el juego y reintenta en Misiones**. Ese resultado pendiente sólo vive en memoria y se pierde al cerrar o cambiar de cuenta. El juego comunica el resultado de la IA local; el servidor no valida su historial de jugadas. La apertura de sobre ya guardada sí persiste.

Las migraciones **20261018031742_aamix_gift_codes_and_avatar_lock_v0110** y **20261018032104_aamix_gift_codes_index_v0110** están aplicadas sobre el servicio existente. Pasó su prueba reversible de códigos, retratos y 1.000 sobres sin promociones. Los ensayos usaron cuentas sintéticas y rollback; no acreditan correo real ni concurrencia simultánea de dos clientes.

**Verificación nueva 0.11.0: 336 comprobaciones y 21 partidas simuladas aprobadas en Windows, cero fallos.** Importación y revisión de interfaz aprobadas. Consulta `proyecto/documentacion/VALIDACION_v0.11.0.md`; la extracción, integridad y arranque del ZIP final se registran en INFORME_ENTREGA. Las cifras de versiones anteriores son históricas y no se suman a esta entrega.

Para continuar: `proyecto/documentacion/BASE_DEL_PROYECTO_v1.7.md`, sección 19, `CONTINUIDAD.md` y `PROMPT_CONTINUIDAD.md`. Consulta `proyecto/backend/APPLIED_MIGRATIONS.json` antes de tocar el backend; no repitas migraciones aplicadas. Siguen pendientes multijugador, constructor, intercambios, diez efectos, guardado de partidas y desbloqueos de fotos promocionales.

`SHA256SUMS.txt` contiene el manifiesto cuando se cierre el paquete. Las licencias del motor están en `motor/`.
