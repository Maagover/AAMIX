# CONTINUIDAD · AAMIX 0.16.0

19 de octubre de 2026, Chile. Continuar sobre AAMIX_Prototipo_Local_v0.16.0 completo. Leer README y sección 24 de BASE_DEL_PROYECTO_v1.12.md. Las instrucciones posteriores del autor prevalecen sobre la historia. **No avanzar multijugador:** se mantiene En desarrollo.

## Economía y recompensas

Restos concede 100 una sola vez por UUID confirmado, también a cuentas existentes al acceder con esta versión. El saldo aparece bajo el nombre en Inicio y en Tienda. Una compra entrega una copia: las cuatro Singulares 0103, 0105, 0115 y 0119 cuestan 500; las otras 30 cartas elegibles, 150. Nunca se venden Recurso ni promocionales. El servidor decide el precio y descuenta/concede atómicamente. ShopUI conserva UUID y carta ante una respuesta incierta; un error 4xx definitivo limpia el intento. Cambiar de dueño limpia los intentos locales. Escape cancela la confirmación sin comprar.

Misiones: Juega 1 diaria da 50 Restos; Gana 1 diaria da un sobre de carta normal; Juega 10 única da 3 TC; Gana 10 única da 5 TC. Las diarias usan fecha del servidor en America/Santiago. El registro nuevo conserva pagos diarios antiguos y no vuelve a pagar los logros únicos, incluido Juega 10 histórico de cinco sobres.

normal_packs es inventario independiente de packs (TC). La apertura añade kind tc/normal_card; un solo resultado pendiente y los alias de petición conservan la idempotencia entre ambos tipos, también después de reconocer la animación. El café contiene una carta uniforme entre 25 normales, sin Recurso, Especial, Singular o promocional. TC conserva cinco posiciones y pesos. La animación nunca sortea ni mueve saldo. Mis sobres muestra casillas cuadradas y el texto vacío solicitado.

## Presentación

Tema Claro/Oscuro en Configuración → Visuales, por defecto claro. visual_settings_path conserva user://visual.cfg; las pruebas pueden asignar una ruta temporal del workspace. Paleta dinámica y AAMIXTheme con superficies opacas, fondo más oscuro que paneles y letras claras en oscuro. No cambiar madera, ilustraciones o reglas para aplicar el tema. Monedas bajo el nombre; Tienda es el quinto acceso principal.

Capas flotantes: Transmisión Caída → sobre → Recurso → logo. Los cinco niveles están visibles, con candado y sin mazo en cada futuro nivel. Conservan su orden y premios únicos por cuenta. Los sobres café cerrado/abierto comparten cuerpo, logo y borde inferior para el fundido.

## Backend aplicado

Novena migración: **20261019051553_aamix_economy_and_normal_packs_v0160**. No repetirla. Añade restos y normal_packs a la cartera y kind a aperturas; tablas de bienvenida, compras y reclamos diarios con RLS del dueño y sin escrituras directas. Wrappers públicos invoker y mutadores privados con UUID/correo confirmado y bloqueo común de cartera. No se cambiaron Auth, SMTP ni clave publicable. Contrato en ECONOMY_v0.16.0.md y registro en APPLIED_MIGRATIONS.json / DEPLOYMENT_v0.16.0.json.

25 comprobaciones SQL aprobadas con cinco cuentas sintéticas y rollback. Sólo diez muestras normales directas, una apertura normal y una TC. Los campos anteriores de once tablas reales coinciden por hash, excluyendo las tres columnas nuevas. Ningún correo, compra o premio real. No se acredita concurrencia entre conexiones independientes ni validación autoritativa de resultados de IA local.

## Validación y entrega

35 casos UI/HTTP y 18 de temas completan 53 casos locales. Se corrigieron el nombre reservado owner en ShopUI, el cooldown OTP del guion y la ruta de preferencias de prueba fuera del workspace. Se retomaron sólo los casos afectados. La moneda se confirma antes de entregar el sobre inicial para que otra recarga no cierre su aviso. Registros íntegros conservados. Los tests restringidos muestran el aviso nativo de certificados de Windows; no confundirlo con errores GDScript ni afirmar acceso real a cuentas desde ese entorno.

La prueba final del ZIP añade seis casos y, con SQL, cierra 84 distintos. El informe externo registra CRC, hashes y arranque sin caché. No se repitieron las matrices ni sorteos masivos de versiones anteriores. Audio con Dummy, sin escucha física acreditada.

Arte y prompts en assets/estetica_v016. Música, reglas, IA, catálogo, mazos y originales conservados. El ZIP 0.15.0 permanece intacto. Base 1.11 y continuidad 0.15 se conservan como historia. Entregar nuevas versiones completas con motor, recursos, fuente y documentación, sin sobrescribir archivos sincronizados de sources/.
