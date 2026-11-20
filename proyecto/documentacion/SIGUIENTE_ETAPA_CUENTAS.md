# Cuentas · estado vigente de la versión 0.8.1

El registro y el ingreso por correo están habilitados en el cliente. El autor confirmó la configuración de Brevo SMTP y el guardado de ambas plantillas con `{{ .Token }}` en el proyecto AAMIX de Supabase.

La conexión HTTPS real se comprueba por separado de las pruebas locales. El envío a un buzón real y la verificación de la primera cuenta deben probarse desde Mi cuenta en esta entrega. La comprobación completa requiere crear cuenta, verificar el código, copiar el UUID, cerrar sesión e ingresar con el mismo correo y otro código; el UUID debe ser el mismo.

El estado y el diagnóstico están en [CUENTAS_ESTADO_v0.8.1.md](CUENTAS_ESTADO_v0.8.1.md). No se almacenan claves SMTP en el juego. La confirmación de correo sigue obligatoria. Colección, sobres y multijugador continúan pendientes.
