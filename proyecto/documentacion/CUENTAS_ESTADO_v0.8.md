# Estado de cuentas · AAMIX 0.8

Fecha: 17 de octubre de 2026.

## Completado

- Organización AAMIX elegida por el autor; plan gratuito, coste cotizado US$0 al mes.
- Proyecto AAMIX creado en `sa-east-1`, identificador `drpsedaiqyowwikhjugs`, activo.
- URL real y clave **publicable** incorporadas al cliente. No se incluye ninguna clave secreta o service-role.
- Auth por correo habilitado, registro permitido y confirmación de correo obligatoria, comprobado en el endpoint de configuración pública.
- Comprobación HTTPS desde Godot, con certificado validado y resultado HTTP 200. En este entorno se usa su proxy de red únicamente en la prueba; no se distribuye un proxy en el juego.
- Asesor de seguridad de Supabase sin alertas. No se crearon tablas personalizadas ni políticas abiertas.
- Cliente con código de correo, UUID, renovación de sesión en memoria y cierre de sesión. Pruebas HTTP locales separadas del servicio real.
- Plantillas en español preparadas: `correos/confirmacion.html` y `correos/ingreso.html`.

## Bloqueo pendiente

La herramienta de Supabase disponible no permite editar la configuración de correos. Se usó el panel web para ese ajuste; el inicio de sesión quedó en verificación de Google y el código fue rechazado. No se modificaron aún las plantillas del servidor y no se afirma que el registro esté activado.

El paquete conserva `email_templates_ready: false`; Enviar código permanece deshabilitado. La conexión al servicio es real y distinta del estado de habilitación del flujo de correos.

## Ajuste final concreto

En Authentication → Emails → Templates del proyecto AAMIX:

1. **Confirm signup**: asunto “Confirma tu cuenta de AAMIX”; contenido de `correos/confirmacion.html`.
2. **Magic Link**: asunto “Tu código de acceso a AAMIX”; contenido de `correos/ingreso.html`.
3. Guardar ambas y comprobar que contienen `{{ .Token }}`. Mantener la confirmación de correo habilitada.
4. Activar `email_templates_ready: true` en `data/cuentas.json` y volver a empaquetar.
5. El autor prueba Crear cuenta con su correo autorizado y verifica el código dentro del juego. Comprobar el mismo ID al cerrar sesión e ingresar otra vez. No registrar ni guardar los códigos o las credenciales durante la prueba.

El envío incorporado de Supabase sólo permite destinatarios autorizados del equipo y tiene límites reducidos. Para amigos externos hace falta SMTP con un remitente autorizado; no se les debe conceder acceso de administrador para recibir correos.

Fuentes oficiales consultadas: documentación de Supabase sobre acceso sin contraseña por correo, plantillas y SMTP; y la documentación de HTTPRequest de Godot. No se han enviado correos reales ni creado usuarios de prueba en producción durante esta entrega.
