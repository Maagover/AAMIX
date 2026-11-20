# Validación de AAMIX 0.8.1

Fecha: 17 de octubre de 2026. Motor: Godot 4.7.2 stable oficial.

## Alcance de esta entrega

Se habilitó el registro e ingreso en la configuración distribuida después de que el autor confirmara Brevo SMTP y ambas plantillas con código. Se actualizaron el número de versión y las instrucciones. No se modificó el cliente de autenticación ni la lógica de cartas, reglas, IA, pagos, arrastres, animaciones o audio.

## Comprobaciones ejecutadas

- Importación del proyecto con Godot 4.7.2: salida 0, sin errores de scripts ni recursos.
- `tests/test_accounts.gd` mediante el servidor HTTP local de `herramientas/probar_cuentas.py`: **31 comprobaciones aprobadas y cero fallos** en X11/OpenGL, incluyendo pulsaciones reales en la interfaz y Copiar ID. Hubo 14 solicitudes HTTP al servidor local y cero correos reales.
- El mismo flujo se comprobó previamente en modo headless: 30 comprobaciones aprobadas. La diferencia es Copiar ID, que requiere portapapeles gráfico. Estas ejecuciones prueban los mismos casos y no se suman como 61 casos distintos.
- Se revisó la configuración real distribuida en las pantallas Crear cuenta e Ingresar: botones Enviar código habilitados, sin aviso de destinatarios limitados al equipo, sin una sesión ni ID antes de verificar, y controles dentro de la ventana. Se capturaron esas pantallas sin datos personales ni códigos.
- HTTPS real desde `tests/test_live_auth.gd`: **HTTP 200**, correo habilitado, registro permitido y confirmación de correo obligatoria. Se validó TLS normalmente. El proxy del entorno sólo se usó en esta prueba y no se distribuye en el juego. La consulta fue de sólo lectura y no envió correos ni creó usuarios.
- Asesor de seguridad del proyecto Supabase: cero alertas. No se crearon tablas, políticas o funciones nuevas.
- Comparación SHA-256 entre 0.8 y 0.8.1: reglas, IA, cliente de cuentas, arrastres, animaciones, audio, representación de cartas, escena principal, catálogo, reglas JSON, los tres mazos y el ejecutable oficial de Windows conservan los mismos bytes.

Los 31 casos cubren validación del correo y nombre, estado pendiente sin ID local, HTTPS y rechazo de claves secretas, solicitud y reenvío, código inválido, sesión válida, limpieza de campos, ID completo copiable, mismo ID desde dos clientes, nombres repetidos con IDs distintos, renovación, expiración, cierre local incluso si falla el servicio, límite de solicitudes y conservación de la partida individual al abrir Mi cuenta.

## Qué todavía requiere una prueba real

**No se ha enviado un correo real ni se ha completado la primera cuenta verificada durante estas comprobaciones.** SMTP y plantillas se habilitan con la confirmación del autor. La entrega al buzón y la verificación se prueban desde Mi cuenta en esta versión, sin compartir el código por chat. Después se comprobará el mismo ID al cerrar sesión e ingresar otra vez.

La ejecución nativa de 0.8.1 en Windows está pendiente. Se conserva el mismo motor oficial para Windows que el autor ya utiliza. Las pruebas de esta entrega corren en Linux.

## Regresiones históricas

La versión 0.8 registró 810 comprobaciones aprobadas y 193 partidas completas simuladas. Esta entrega conserva esa lógica sin cambios y repite las pruebas de cuentas pertinentes. No se afirma que se hayan ejecutado nuevamente las 810 comprobaciones ni las 193 partidas para activar una configuración.

## Reproducir

Con Godot 4.7.2 disponible:

```bash
python proyecto/herramientas/probar_cuentas.py /ruta/a/godot --gui
```

El servidor de pruebas escucha sólo en 127.0.0.1 y usa datos ficticios. `tests/test_live_auth.gd` consulta exclusivamente la configuración pública del proyecto real. Los resultados de esta entrega están en `RESULTADOS_v0.8.1.json`.
