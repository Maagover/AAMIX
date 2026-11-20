# Estado de cuentas · AAMIX 0.8.1

Fecha: 17 de octubre de 2026.

## Configuración confirmada por el autor

- Brevo creado con correo y contraseña propios, sin depender del acceso bloqueado de Google.
- Remitente de correo configurado y credenciales SMTP guardadas únicamente en Supabase.
- Confirm sign up y Magic Link guardadas con `{{ .Token }}` y los asuntos en español. La captura del autor confirmó que el editor quedó habilitado tras configurar SMTP; el autor confirmó después haber guardado ambas plantillas.
- No se han leído ni solicitado al autor la contraseña de Brevo ni su clave SMTP. No están en el cliente.

## Cambios en esta entrega

- `data/cuentas.json`: `email_templates_ready: true` y `email_delivery: custom_smtp`.
- Crear cuenta e Ingresar permiten solicitar el código; se retira el aviso de destinatarios limitados al equipo.
- La URL real y la clave publicable del proyecto AAMIX se conservan. No hay claves secretas ni service-role en el cliente.
- La sesión se concede sólo cuando Supabase valida el código y devuelve un UUID y tokens válidos. No se generan IDs locales para aparentar una cuenta.
- Se conservan validación del correo y nombre, espera entre reenvíos, renovación, cierre de sesión y almacenamiento sólo en memoria.
- El juego conserva los tres mazos, tablero, reglas, animaciones, música y sonidos de 0.8.

## Validación y alcance

Consultar `VALIDACION_v0.8.1.md` para las comprobaciones ejecutadas en esta entrega. Las pruebas de registro e ingreso automatizadas usan HTTP local con datos ficticios y no envían correos. La comprobación real de HTTPS consulta la configuración pública de Auth, exige verificación de correo y no crea usuarios ni envía mensajes.

**Primera entrega real de correo y primera cuenta verificada: pendientes de la prueba del autor desde el juego.** No se ha accedido al buzón del autor ni se ha solicitado su código de acceso por chat.

## Primera prueba desde Windows

1. Extraer el ZIP completo en una carpeta nueva y abrir `Jugar_AAMIX.bat`.
2. Mi cuenta → Crear cuenta → nombre visible y correo → Enviar código.
3. Revisar la bandeja de entrada y Spam e introducir el código en el juego.
4. Verificar e ingresar. Copiar el ID.
5. Cerrar sesión → Ingresar → mismo correo → código nuevo. Comparar el ID.
6. Repetir en otro computador si se quiere comprobar la identidad entre equipos.

## Si no llega el correo

- Esperar al menos un minuto antes de reenviar. No repetir solicitudes continuamente.
- En Brevo → Transactional → Email logs, comprobar si el mensaje figura como enviado, entregado, rechazado o pendiente.
- Si Brevo indica que la plataforma transaccional no está activada, completar su proceso de habilitación.
- En Supabase → Authentication → Emails → SMTP Settings, verificar el remitente aprobado, host `smtp-relay.brevo.com`, puerto `587`, Login SMTP y clave SMTP de Brevo. El Login puede ser distinto al correo remitente. Una clave API o la contraseña de la cuenta no sustituyen a la clave SMTP.
- Revisar errores de Auth en Supabase si no existe intento de entrega en Brevo.
- Para pruebas sin dominio, Brevo puede reemplazar temporalmente el remitente por un dominio suyo; no se considera un remitente propio permanente. La documentación de Brevo recomienda un dominio autenticado para entrega fiable.
- Compartir sólo el mensaje de error y ocultar contraseñas, claves, códigos y tokens.

No se añadieron tablas, políticas o funciones nuevas. Colección, sobres, constructor de mazos y partidas online siguen pendientes. Autenticación de cuenta no equivale a multijugador.

## Fuentes oficiales

- https://supabase.com/docs/guides/auth/auth-email-passwordless
- https://supabase.com/docs/guides/auth/auth-email-templates
- https://supabase.com/docs/guides/auth/auth-smtp
- https://help.brevo.com/hc/en-us/articles/7959631848850-Create-and-manage-your-SMTP-keys
- https://help.brevo.com/hc/en-us/articles/7924908994450-Send-transactional-emails-using-Brevo-SMTP
- https://help.brevo.com/hc/en-us/articles/14925263522578-Comply-with-Gmail-Yahoo-and-Microsoft-s-requirements-for-email-senders
