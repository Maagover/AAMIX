# Validación de AAMIX 0.11.0

18 de octubre de 2026, Chile. **336 comprobaciones y 21 partidas simuladas aprobadas en Windows, cero fallos.** Este documento separa las pruebas del proyecto de la verificación del ZIP final. Los resultados de versiones anteriores no se suman a 0.11.0.

## Backend aplicado y prueba real

Migración **20261018031742_aamix_gift_codes_and_avatar_lock_v0110**, aplicada en el Supabase existente. No se reiniciaron Auth, SMTP, usuarios, regalo inicial ni canjes históricos. También se aplicó **20261018032104_aamix_gift_codes_index_v0110**. El historial exacto se consulta en `backend/APPLIED_MIGRATIONS.json` y el cierre del despliegue en `backend/DEPLOYMENT_v0.11.0.json`. La verificación posterior encontró cero cuentas de QA, 85 cartas reales existentes conservadas, sin cambios en Auth/SMTP ni problemas de RLS en tablas públicas; las cinco tablas privadas sin políticas mantienen su cierre intencional al cliente.

**PASS: `backend/test_gift_codes_v0110_rollback.sql`**, ejecutada sobre el esquema desplegado con cuentas sintéticas y rollback. Verificó:

- P3RI: 3 Peri; B1G0T3S: 3 Bigotes; SI2TYA: 1 Tsuki y Akira; CHANCHULINES: 1 Granjita de Chanchuus; TORNEOAAMIX1: 1 Dragón Tee K.O.
- 20 reintentos por código sin repetir cantidades.
- M4Z0M44G0: Maagover histórico de 40 cartas/15 Restos, incluido canje ya registrado, independiente del regalo inicial.
- Separación por UUID, correo confirmado y rechazo de solicitudes no autorizadas.
- Reversión integral de canje/cantidades si la concesión falla por desbordamiento.
- Rechazo de retratos promocionales aun cuando la cuenta posea las cartas.
- 1.000 sobres sin promociones, conservando el grupo vigente de 35 elegibles.

El ensayo se revirtió. No equivale a una prueba de entrega real a un jugador, reingreso por correo o carrera simultánea de dos clientes. No se publican UUIDs reales ni credenciales.

## Juego e interfaz en Windows

| Suite nueva o repetida para 0.11.0 | Entorno | Comprobaciones |
| --- | --- | ---: |
| `test_ui_v011.gd` | Interfaz real | 61 |
| `test_profiles.gd` | Interfaz real | 48 |
| `test_presentation_v010.gd` | Sin interfaz | 40 |
| `test_maagover_v010.gd` | Sin interfaz | 64 |
| `test_rewards_v011.gd` | Interfaz real y servicio HTTP local | 71 |
| `test_rewards_v010.gd` | Interfaz real y servicio HTTP local | 52 |
| **Total único de esta ejecución** | **Cero fallos** | **336** |

La suite de Maagover completó **21 partidas simuladas**. La importación del proyecto pasó. Las 71 comprobaciones de recompensas también se repitieron sin interfaz; esa repetición se registra aparte y no incrementa el total único de 336.

Se verificaron inicio con dos cartas flotantes y logo fijo a la derecha; listas de misión/sobres a la izquierda; nombre Transmisión Caída; formulario mínimo y confirmaciones por recompensa; colección/selección de mazo centradas; selector de 22 retratos sin nombres visibles, con tooltips y promocionales bloqueadas. Dicky, Maagover y Girabl se revisaron contra las imágenes originales y en sus recortes mostrados por el motor.

Los servicios HTTP locales y perfiles usan identidades ficticias, sin correos reales ni canjes en cuentas de jugadores. Las 155 comprobaciones/21 partidas de 0.10.1 y 1.050/214 de 0.10.0 son antecedentes históricos y no se incluyen aquí.

## Paquete portátil

La extracción completa, CRC, comparación de hashes y arranque desde carpeta nueva sin caché de Godot se registran en **INFORME_ENTREGA** al cerrar el ZIP final. Las 336 comprobaciones del proyecto no se presentan como acreditación de esa extracción. Consultar ese informe para el archivo efectivamente entregado y su comprobación portátil.

## Límites que permanecen

El resultado contra IA lo declara el cliente; el servidor no verifica jugadas. Resultados de misión no enviados viven sólo en memoria; aperturas confirmadas persisten. No hay nueva prueba de correo real ni de dos clientes simultáneos. Multijugador, constructor, intercambios, diez efectos, guardado de partidas y futuros desbloqueos promocionales siguen pendientes.


Verificación portátil de QA ejecutada: ZIP completo extraído sin caché, CRC y todos los hashes aprobados; arranque, acceso y partida de invitado aprobados; 71 comprobaciones de nuevos canjes y pantallas aprobadas, cero fallos. Esta repetición portátil no se suma a las 336 comprobaciones únicas. El paquete final se comprueba nuevamente al cerrar la entrega; su hash y resultado se registran en el informe contiguo al ZIP.
