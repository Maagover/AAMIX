# Validación de AAMIX 0.12.0

18 de octubre de 2026, Chile. **582 comprobaciones únicas y 48 partidas completas simuladas contra IA aprobadas en Windows, cero fallos.** Se separan pruebas reales del servicio, pruebas locales de interfaz y verificación del ZIP. No se suman cifras históricas ni repeticiones de una misma suite.

## Backend aplicado y pruebas reales

**20261018035100_aamix_missions_and_gifts_v0120** aplicada en el servicio existente. **PASS: `backend/test_missions_and_gifts_v0120_rollback.sql`**, con cuentas sintéticas y rollback. Verificó:

- Conservación de Juega 1 partida y sus reclamos históricos.
- Gana 1 partida diaria y Juega 10 partidas acumulativa de por vida; recibos anteriores y reclamos independientes.
- Reinicio a medianoche de America/Santiago aun con sesión de prueba en Honolulu.
- 20 reintentos sin duplicar premios; ocho códigos, incluidos AAMIXTC=1 sobre y M4Z0G1R4=Girabl exacto 40/12.
- Autenticación, RLS y reversión atómica ante desbordamiento.
- 1.000 sobres sin promociones, con grupo y probabilidades anteriores conservados.

También pasó una prueba compatible de 0.11.0 **adaptada a las definiciones actuales de ocho códigos**, con otros 1.000 sobres. Son **2.000 sobres de prueba en total**, íntegramente revertidos. No se presenta esa adaptación como ejecución sin cambios del esquema antiguo.

Una comparación independiente confirmó que Girabl sembrado en el servidor coincide con la lista histórica: 40 cartas/12 Restos. Al finalizar quedaron cero cuentas de QA; el estado real existente conservó 85 cartas, dos mazos, un canje y un recibo. No se reiniciaron Auth, SMTP, usuarios ni recompensas reales. La revisión no encontró problemas de RLS en tablas públicas; las cinco tablas privadas sin políticas mantienen su cierre intencional al cliente.

No se enviaron correos ni se acreditó concurrencia real de dos clientes. Consultar `backend/APPLIED_MIGRATIONS.json` y `backend/DEPLOYMENT_v0.12.0.json` para el registro del despliegue.

## Windows: pruebas actuales

| Suite | Entorno | Comprobaciones | Partidas IA completas |
| --- | --- | ---: | ---: |
| `test_ui_v012.gd` | Interfaz real | 130 | — |
| `test_presentation_v010.gd` actualizado | Sin interfaz | 43 | — |
| `test_profiles.gd` | Sin interfaz | 48 | — |
| `test_girabl_v012.gd` | Sin interfaz, reglas e IA actuales | 76 | 27 |
| `test_maagover_v010.gd` | Sin interfaz | 64 | 21 |
| `test_rewards_v012.gd` | Interfaz real y servicio HTTP local | 98 | — |
| `test_rewards_v011.gd` | Sin interfaz y servicio HTTP local | 71 | — |
| `test_rewards_v010.gd` | Interfaz real y servicio HTTP local | 52 | — |
| **Total único** | **Cero fallos** | **582** | **48** |

Las 130 comprobaciones UI y las 98 de recompensas nuevas también se ejecutaron sin interfaz; se registran como repeticiones y no aumentan el total único. Los **11 recibos del fixture HTTP** comprueban contratos/progreso y **no son partidas completas contra IA** ni se añaden a las 48 simulaciones.

## Revisión visual e interacción

Capturas nativas de inicio, colección, fila promocional, Mis Mazos, selección de varios/un mazo, Mi cuenta, partida y recompensas. Se verificó:

- Dos cartas más grandes y cercanas; logo con flotación menor, sin giro ni cambio frente/dorso; pie/título de versión actual y sin subtítulo anterior.
- 35 regulares centradas y seis promocionales separadas al final en una sola fila centrada, todas visibles al ancho normal.
- Cantidades y faltantes conservados; la acción de doble clic de cartas regular y promocional abre el detalle.
- Mis Mazos conserva Ver lista y usa «Obtenido · 40 cartas» sin texto adicional de guardado.
- Tres misiones con alcance/recompensa propios; canje de sobre y mazo con respuestas diferenciadas y compatibilidad con premios anteriores.

`test_ui_v011.gd` delega a `test_ui_v012.gd` como entrada de compatibilidad: no contarlas como suites distintas. Las pruebas locales usan identidades ficticias; no acreditan correo real ni concesiones a cuentas de jugadores.

## Historia y paquete

0.11.0 tuvo 336 comprobaciones y 21 partidas. Sus documentos/capturas permanecen como historia; no acreditan las funciones nuevas ni se suman a 0.12.0.

La extracción completa, CRC, hashes/manifiesto y arranque del **ZIP final sin caché** se registran en **INFORME_ENTREGA** al cerrar la entrega. Las 582 comprobaciones del proyecto no se presentan como acreditación de esa extracción. Consultar el informe para el archivo efectivamente entregado y su comprobación portátil.

Persisten los límites: resultado de IA declarado por cliente, cola no enviada sólo en memoria, multijugador, constructor, intercambios, diez efectos, guardado de partidas, desbloqueos promocionales y concurrencia real pendientes.


Verificación portátil de QA ejecutada: ZIP completo extraído sin caché, CRC y todos los hashes aprobados; arranque, acceso y partida de invitado aprobados; 98 comprobaciones de misiones, canjes y apertura aprobadas, cero fallos. Esta repetición portátil no se suma a las 582 comprobaciones únicas. El paquete final se comprueba nuevamente al cerrar la entrega; su hash y resultado se registran en el informe contiguo al ZIP.
