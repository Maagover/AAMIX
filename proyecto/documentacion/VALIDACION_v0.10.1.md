# Validación de AAMIX 0.10.1

17 de octubre de 2026, Chile. Corrección solicitada por el autor: **las promociones nunca aparecen en sobres**.

## Juego en Windows

**155 comprobaciones aprobadas, cero fallos y 21 partidas completas simuladas** en esta entrega, con el motor incluido para Windows:

| Suite repetida para 0.10.1 | Comprobaciones |
| --- | ---: |
| `test_profiles.gd`: perfiles y retratos | 40 |
| `test_maagover_v010.gd`: composición y partidas del Mazo Maagover | 64 |
| `test_rewards_v010.gd`: interfaz y flujo de recompensas con HTTP local | 51 |

Importación y arranque aprobados. Las pruebas de interfaz con HTTP local usan datos sintéticos y no acreditan correo real. Las 21 partidas corresponden al Mazo Maagover; no se presentan como una repetición de todas las partidas históricas.

## Backend real y sorteo

Migración **20261017221142_aamix_packs_exclude_promotional_v0101** aplicada mediante el panel SQL autenticado sobre el proyecto existente, con registro en el historial de migraciones. El conector de migraciones devolvía Invalid requestState; no se consideró ese intento fallido como aplicación. No se recrearon Auth, SMTP ni cuentas.

Se verificó la función desplegada y el catálogo: **41 cartas, seis promociones excluidas y 35 elegibles: 25 normales, nueve Especiales y un Recurso**. El filtro promocional cubre Recurso inicial, normales y rama Especial. Las cinco posiciones quedan protegidas, incluido el Recurso garantizado. Las probabilidades confirmadas se conservan: posición 5 normal 70%/Especial 30%; cuatro Especiales con 5% cada una y otras cinco con 16% cada una dentro de ese grupo.

`backend/test_rewards_rollback.sql` **PASS** con **10.000 sobres** en el servicio real, íntegramente revertidos. La muestra tuvo **3.025 Especiales** y **624 cartas del conjunto de las cuatro con peso 5%**. Son resultados de muestreo, no cambios en los pesos configurados. No se observaron promociones en ninguna posición.

Una prueba adicional real con **1.000 sobres** comprobó las ramas Recurso, normal y Especial con reclasificaciones sintéticas: **300 quintas Especiales y 700 normales**, sin promociones. La prueba y los cambios temporales de clasificación/restricciones se revirtieron; las restricciones quedaron restauradas.

## Reparación: prueba y operación real por separado

`backend/test_promo_repair_rollback.sql` **PASS**, usando sólo UUIDs aleatorios de cuentas sintéticas y rollback. El caso concede el Maagover histórico de 40 cartas con su promoción legítima, añade un sobre histórico de cinco y corrige únicamente su copia promocional. Conserva 45 cartas, la promoción legítima, mazo, canje, cartera y aliases. Verifica tres repeticiones idempotentes y la reversión integral si falta una copia después de haber iniciado otro reemplazo. También comprueba que el cliente no tiene ejecución de la función ni lectura de su auditoría privada.

**Operación real autorizada por el autor y ejecutada:** una copia de **Dragón Tee K.O (`01e`)**, que provenía de la **posición 2** del sobre anterior, se sustituyó por **El conflicto de Maagover (`0116`)**, una normal no promocional. Se conservó el total de **85 cartas** y la copia legítima `01c` del Mazo Maagover. Quedó **un registro de corrección** con el resultado anterior y el corregido; los identificadores privados de la cuenta y apertura no se incluyen en esta documentación.

Al finalizar no quedaron cuentas de QA. La corrección real autorizada se registra aparte de los ensayos sintéticos revertidos; no se presenta como si todas las operaciones hubieran sido rollback.

## Historia y límites

Las 1.050 comprobaciones, 214 partidas y 20.000 sobres de 0.10.0 se conservan en `VALIDACION_v0.10.0.md` como historia. Sus 31 normales incluían promociones; esos sorteos no acreditan esta corrección ni se suman a sus cifras actuales.

La misión conserva el resultado comunicado por el cliente de una partida local contra IA; el servidor no valida un historial de jugadas. La concurrencia simultánea entre dos clientes reales y una nueva entrega/reingreso por correo no se acreditan por estas pruebas. Reintentos secuenciales y rollback no equivalen a concurrencia real. La promoción legítima de un mazo sigue siendo válida y el catálogo/retratos conserva todas las cartas correspondientes.

## Paquete portátil

El ZIP de QA se extrajo en una carpeta nueva sin caché de Godot: CRC y todos los hashes del manifiesto aprobados; arranque, acceso y partida de invitado aprobados; 51 comprobaciones del flujo de recompensas aprobadas, cero fallos. Esta repetición portátil se registra aparte de las 155 comprobaciones del proyecto. El ZIP final se extrae y comprueba de nuevo antes de entregarlo. El informe contiguo `INFORME_ENTREGA_v0.10.1.json` registra su hash y comprobación final; dentro del paquete se conserva el informe de QA del mismo nombre.
