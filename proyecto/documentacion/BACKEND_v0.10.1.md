# Backend AAMIX 0.10.1 · exclusión de promociones

17 de octubre de 2026. Migración **20261017221142_aamix_packs_exclude_promotional_v0101** aplicada y verificada en el Supabase existente `drpsedaiqyowwikhjugs`. Se utilizó el panel SQL autenticado después de que el conector devolviera Invalid requestState; la migración quedó registrada en el historial. No repetirla. Se conservan Auth, Brevo SMTP, UUIDs, catálogo, colección y mazos legítimos.

**Ninguna promocional puede sortearse en ninguna posición.** `reward_catalog.is_promotional` filtra las tres ramas: Recurso inicial, normales y Especiales. Se mantiene un cierre defensivo para los seis identificadores y una restricción sobre nuevos resultados. El servidor decide las cartas; la corrección protege nuevas aperturas de clientes anteriores.

El catálogo tiene **41 cartas**, incluidas las seis promociones `01a`–`01f`. Participan en sobres **35 no promocionales: un Recurso, 25 normales y nueve Especiales**. Las normales son uniformes y repetibles; posición 5 normal 70%/Especial 30%, con cuatro Especiales de 5% cada una y otras cinco de 16% cada una dentro del grupo. La exclusión tiene prioridad en todas las ramas incluso ante reclasificaciones.

Las promociones siguen válidas en colección, retratos y mazos que las incluyen. El código M4Z0M44G0 conserva el Maagover histórico exacto, incluida su copia legítima `01c`; el regalo de mazo no es un sobre.

## Verificación real

- `test_rewards_rollback.sql`: **PASS**, 10.000 sobres con rollback; 3.025 Especiales y 624 del conjunto de cuatro con peso 5%; sin promociones.
- Prueba adicional: **PASS**, 1.000 sobres, 300 quintas Especiales y 700 normales, exclusión ante clasificaciones sintéticas de Recurso/normal/Especial. Cambios y restricciones temporales revertidos; restricciones restauradas.
- `test_promo_repair_rollback.sql`: **PASS**, conservación de Maagover y promoción legítima, total 40+5, tres repeticiones idempotentes, recuperación por aliases y fallo parcial revertido íntegramente.

Los ensayos usan cuentas sintéticas y rollback. No quedaron cuentas de QA. Los resultados históricos de `BACKEND_v0.10.0.md` no se suman a estas pruebas nuevas.

## Reparación real autorizada

El autor confirmó sustituir la copia promocional del único sobre anterior detectado por una normal no promocional. La operación se ejecutó: **Dragón Tee K.O (`01e`), posición 2 → El conflicto de Maagover (`0116`)**. El total quedó en **85 cartas**, la copia legítima `01c` de Maagover se conservó y existe **un registro de auditoría** con cartas anteriores, corregidas y reemplazo. No se publican los UUIDs de la cuenta ni de la apertura.

La función administrativa no concede ejecución al cliente y su auditoría es privada. Reintentar devuelve la corrección anterior sin volver a sustituir ni alterar cantidades. Una promoción en posición 1 exige revisión separada y se rechaza; la reparación de este sobre no cambia su Recurso inicial.

El código y pruebas están en `backend/aamix_no_promo_packs.sql`, `promo_repair_admin.sql`, `test_rewards_rollback.sql` y `test_promo_repair_rollback.sql`; el historial exacto en `APPLIED_MIGRATIONS.json`. `build_rewards.py` y `rewards_template.sql` permanecen históricos de 0.10.0: generan el esquema original y requieren la corrección aditiva posterior; no deben repetirse sobre una instalación existente.

La misión sigue registrando el resultado declarado por el cliente local; no valida sus jugadas en servidor. La concurrencia simultánea de dos clientes reales sigue sin acreditarse. Ver `VALIDACION_v0.10.1.md` para juego/pruebas y **INFORME_ENTREGA** para la verificación del paquete portátil.
