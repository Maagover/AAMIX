# Backend AAMIX 0.9.0

Proyecto existente: `drpsedaiqyowwikhjugs`, São Paulo. Sin cambios de plan ni contratación; sin cambios de SMTP, plantillas o cuentas existentes.

Inspección previa: esquema público sin tablas personalizadas ni migraciones. Aplicada la migración **20261017185851_aamix_collection_starter_v090** el 17-10-2026. El servicio ya está configurado para este cliente. No requiere pasos de instalación de base de datos por el jugador.

- `public.aamix_collection`: UUID, código original y cantidad positiva. Clave compuesta UUID/código; colección sin límite de tres copias.
- `public.aamix_owned_decks`: UUID, ID de mazo, nombre, portada, lista exacta y fecha. Guardar el mazo no resta colección.
- `public.aamix_starter_gifts`: una fila por UUID; clave primaria impide un segundo regalo.
- `aamix_private.catalog_codes` y `base_decks`: 41 códigos y tres listas inmutables desde el cliente, copiadas de los JSON del ZIP 0.8.1.
- `aamix_inventory()`: consulta de los datos del UUID autenticado, sin parámetro de dueño.
- `aamix_claim_starter(p_deck_id)`: acepta únicamente kajido, papito o flaan. La función pública invocadora llama a una función privada con privilegios para entregar cartas; ésta exige UUID y correo confirmado en Auth y rechaza usuarios anónimos de Auth. El invitado del juego no crea una cuenta de Auth.

Las tres tablas públicas tienen RLS y SELECT sólo del dueño. No hay permisos del cliente para insertar, modificar o eliminar cartas, mazos o entregas. Las cantidades nunca se aceptan desde el cliente. La función privilegiada privada tiene search_path vacío y referencias calificadas; EXECUTE revocado a PUBLIC/anon y concedido sólo a authenticated. También se revocó el acceso público a los dos RPC.

La inserción única de regalo es la puerta de exclusión. El ganador añade las cartas y guarda el mazo en la misma transacción; cualquier fallo revierte las tres operaciones. Repetir el mismo ID u otro devuelve el regalo original sin añadir cartas. La respuesta es una instantánea coherente. En READ COMMITTED una solicitud conflictiva espera al resultado de la primera inserción.

La migración SQL se incluye como registro reproducible y para revisión, **no para ejecutarla otra vez**. Antes de futuros cambios, inspeccionar tablas, funciones y migraciones; aplicar únicamente cambios aditivos. No reiniciar el proyecto ni borrar cuentas. No se guardan claves secretas o service_role en el cliente.

Pruebas y limitaciones: VALIDACION_v0.9.0.md. La prueba SQL usa identidades temporales dentro de una transacción revertida; no consume el regalo del autor. La carrera entre dos clientes reales con commit sigue sin validar. La persistencia real tras entrega y nuevo acceso por correo debe comprobarla el autor desde el juego, sin compartir códigos.

Referencias consultadas: [RLS](https://supabase.com/docs/guides/database/postgres/row-level-security), [seguridad del API](https://supabase.com/docs/guides/api/securing-your-api), [changelog](https://supabase.com/changelog?types=breaking-change), [HTTPRequest de Godot](https://docs.godotengine.org/en/stable/classes/class_httprequest.html).
