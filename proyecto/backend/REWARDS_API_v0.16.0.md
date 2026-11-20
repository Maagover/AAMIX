# Contrato vigente · AAMIX 0.16.0

Migración **20261019051553_aamix_economy_and_normal_packs_v0160** aplicada y verificada. Detalle de monedas, compras, misiones y sobres en ECONOMY_v0.16.0.md; evidencia en DEPLOYMENT_v0.16.0.json. No repetir migraciones.

25 comprobaciones SQL con cinco cuentas sintéticas y rollback integral: 10 muestras normales directas, una apertura normal y una TC; sin sorteos masivos ni premios/correos reales. Los campos anteriores de once tablas coinciden por hash. Se excluyen de esa comparación únicamente las tres columnas nuevas detalladas en el informe.

Los contratos de bienvenida, regalo inicial y desafíos de 0.15/0.14 permanecen vigentes salvo la nueva definición de misiones. Las dos diarias reinician a medianoche de Chile y usan un registro nuevo sin borrar pagos históricos. Las dos únicas conservan reclamos anteriores. Recurso y promociones se excluyen de la tienda; sólo 25 normales entran en el sobre café.

Asesor sin nuevos hallazgos RLS públicos. Se mantienen cinco INFO por tablas privadas cerradas ([referencia](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy)) y el aviso anterior de protección de contraseñas filtradas ([referencia](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection)); el juego usa OTP por correo y no se modificó Auth/SMTP.

Documentación técnica consultada: [funciones](https://supabase.com/docs/guides/database/functions), [protección de API](https://supabase.com/docs/guides/api/securing-your-api), [changelog](https://supabase.com/changelog). El aviso de TLS CBC de noviembre no cambia esta migración SQL.
