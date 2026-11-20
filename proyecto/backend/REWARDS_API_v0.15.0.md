# AAMIX 0.15.0 · bienvenida y mazo del desafío

Migración aplicada y verificada: **20261018215041_aamix_welcome_challenge_v0150**. El registro actual está en APPLIED_MIGRATIONS.json; detalle y hashes en DEPLOYMENT_v0.15.0.json. No volver a aplicarla.

El inventario conserva todos los campos anteriores y añade `welcome_pack:{claimed,granted,legacy_starter,challenge_entered}`. `aamix_claim_welcome_pack()` entrega un solo sobre TC al UUID confirmado sin mazo inicial previo. El cliente lo llama después de leer inventario cuando falta la bienvenida; se recupera con recarga si una respuesta se pierde. `welcome_awarded` informa si esta llamada concedió el premio y `welcome_reward_packs` vale 1 o 0. Una fila única por UUID y el bloqueo común de la cartera impiden duplicados.

`aamix_enter_challenge()` asegura primero la bienvenida y marca la entrada al desafío, sin elegir mazo. Sólo entonces `aamix_claim_starter(p_deck_id)` admite elegir Kajido, Papito o Flaan, concediendo sus 40 cartas una sola vez. Antes de entrar rechaza con `AAMIX_START_CHALLENGE`. Reintentar una elección anterior devuelve el regalo existente; no cambia mazo ni cantidades.

Las cuentas con mazo inicial previo conservan todo y no reciben otro sobre por esta migración. Las cuentas sin regalo previo siguen el flujo nuevo. Una cuenta nueva puede abrir el sobre, consultar su colección o canjear códigos antes de elegir mazo; necesita un mazo propio para una partida autenticada.

La tabla `aamix_welcome_packs` tiene RLS, lectura sólo del dueño y sin escritura directa del cliente. Wrappers públicos invoker; mutadores privados con UUID/correo confirmado y bloqueo común de cartera. No se cambian Auth, SMTP, misiones, códigos, sorteos, promociones excluidas ni progreso del desafío. El contrato 0.14.0 sigue vigente para esas áreas.

La prueba real de 20 casos se ejecutó una vez con cinco usuarios sintéticos y rollback integral. Comprueba permisos, cuentas sin confirmar, bienvenida idempotente, bloqueo previo del mazo, entrada, entrega exacta, 10 reintentos, aislamiento por UUID, apertura/reintento y conservación de cuentas antiguas; provoca un desbordamiento para verificar atomicidad. Los hashes agregados de diez tablas reales coinciden antes/después. No se hicieron muestreos masivos ni correos o canjes reales. No se probó concurrencia entre conexiones independientes.

Asesor: ningún hallazgo RLS público nuevo. Cinco INFO sobre tablas privadas sin políticas corresponden a denegación intencional ([referencia](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy)). Se conserva el aviso anterior de protección de contraseñas filtradas desactivada ([referencia](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection)); el juego usa códigos por correo y no se cambia Auth.


## Contrato anterior conservado

El detalle de desafíos, cuatro misiones y ocho códigos está en REWARDS_API_v0.14.0.md y CHALLENGES_AND_MISSIONS_v0.14.0.md. Sus cifras de validación son históricas; no se ejecutaron de nuevo en 0.15.0.
