# Códigos de regalo · 0.17.0

Extensión aplicada y verificada de `aamix_redeem_code(p_code)`, con recompensas una sola vez por cuenta y código. Los ocho códigos anteriores y su historial se conservan.

| Código | Recompensa |
| --- | --- |
| AAMIX50 | 50 Restos |
| AAMIX100 | 100 Restos |
| AAMIX1000 | 1000 Restos |
| AAMIXNAVIDAD | 1 sobre Transmisión Caída + 50 Restos + 1 sobre Carta aleatoria |

Los sobres se guardan en Mis sobres. El sobre Carta aleatoria usa el sorteo existente de una carta normal elegible, sin recursos, Especiales, Singulares ni promocionales. Canjear el código entrega el sobre y no lo abre automáticamente. El popup muestra los tres componentes de Navidad con sus imágenes y cantidades.

La configuración privada añade `restos` y `normal_packs`, ambos con valor predeterminado cero. La restricción permite combinar sobres TC, Restos y sobres Carta aleatoria. Los premios históricos de mazo o cartas sueltas siguen siendo exclusivos y no se mezclan con esos componentes. No se conceden premios desde el catálogo informativo del cliente.

La función conserva la firma pública y el wrapper `SECURITY INVOKER` disponible sólo para `authenticated`. La función privada verifica la cuenta confirmada mediante `lock_rewards()` y serializa los escritores de su cartera. El regalo de registro de 100 Restos se garantiza con el registro existente `ensure_restos_welcome()`, una sola vez, antes de conceder un código válido. No se entrega ningún mazo inicial ni sobre de bienvenida desde el canje.

El registro `(user_id, gift_code)` conserva la idempotencia. Se normalizan mayúsculas y espacios externos. Un reintento devuelve el inventario actual y las cantidades del premio original con `already_redeemed=true`; no concede nada de nuevo. La concesión de todos los componentes y su registro se hace en la misma transacción. Un error en cualquier componente revierte el canje completo.

Además de las claves anteriores, la respuesta devuelve `reward_restos` y `reward_normal_packs`. `reward_packs` sigue significando sobres TC. Los tres campos incluyen cero cuando no corresponden. `reward_deck_id`, `reward_cards` y `reward_name` se mantienen para los premios anteriores.

Archivos: `aamix_wallet_gift_codes_v0170.sql` y `test_wallet_gift_codes_v0170_rollback.sql`. Las 12 comprobaciones del segundo pasaron en el servicio real con cinco cuentas sintéticas y ROLLBACK. Verifican permisos, configuración, autenticación, los cuatro premios, reintentos, normalización, aislamiento de cuentas, compatibilidad de códigos anteriores y rollback por desbordamiento. No sortean cartas ni simulan partidas. La comprobación de cliente `tests/test_wallet_gifts_v017.gd` pasó con los tres iconos, cantidades, texto e idempotencia visible. Consultar los metadatos de despliegue de esta entrega para la identidad exacta de la migración; no ejecutar de nuevo migraciones ya aplicadas.
