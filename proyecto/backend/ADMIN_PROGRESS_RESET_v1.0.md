> Ya aplicado y verificado. Antes de usar las herramientas en un entorno nuevo, aplicar también aamix_release_recovery_verify_v100.sql después de admin_progress_tools_v100.sql. No repetir el reinicio oficial.

# Reinicio recuperable de progreso para AAMIX v1.0

Estos scripts requieren la sesión administrativa `postgres`. No son migraciones
automáticas del cliente y no deben ejecutarse al abrir el juego. El esquema de
copias queda fuera de la API, con RLS y sin permisos para `anon`, `authenticated`
ni `service_role`.

1. Instalar `admin_progress_tools_v100.sql` una vez. Sólo crea herramientas privadas.
2. Ejecutar `admin_capture_progress_v100.sql`. Captura los UUID registrados en ese
   momento, excluyendo las cuentas sintéticas marcadas `qa_run`. No lleva UUIDs
   personales escritos en el código. Incluye todas las tablas `public.aamix_*`,
   las salas/comandos/membresías asociados y el historial de correcciones de sobres.
3. Exportar el JSON recuperable completo a un archivo **fuera del ZIP del juego**
   y conservar su SHA-256. La exportación sólo contiene datos de progreso, sin
   archivos gráficos. El checksum de identidad no contiene credenciales ni correos legibles.
4. Revisar y ejecutar `admin_reset_progress_v100.sql`. Verifica los checksums y que
   el progreso no cambió tras la copia, bloquea escrituras durante la transacción
   y elimina hijos antes que padres según las claves foráneas reales. Un cambio o
   error cancela toda la operación. Si hubo progreso nuevo después de exportar,
   capturar con una nueva etiqueta y exportar esa copia antes de intentar el reinicio.
5. Ejecutar `test_release_bootstrap_v100_rollback.sql`. Contiene ocho comprobaciones
   dirigidas; sus regalos y elección de mazo se revierten con `ROLLBACK`.

Se conservan `auth.users`, identidades, correos, nombres, IDs, sesiones y contraseñas.
El inventario, mazos, avatar, Restos, sobres, misiones, desafío, compras y canjes se
reinician. El siguiente inicio de sesión recibe los 100 Restos y un sobre TC
mediante el flujo habitual. El mazo inicial sigue esperando la entrada al desafío.

Para deshacer el reinicio, ejecutar **sólo cuando se decida recuperar**
`admin_restore_progress_v100.sql`. Antes de reemplazar progreso posterior crea otra
copia privada; devuelve su UUID para poder deshacer también esa recuperación.
Restaura tipos completos con `jsonb_populate_recordset`, padres antes que hijos.
Si otra cuenta ocupa una membresía única o hubo cambios de estructura, aborta sin
pisar datos ajenos. Las copias no se eliminan al reiniciar o recuperar.

Estado de elaboración: fuentes preparadas y revisadas con el esquema remoto;
la aplicación efectiva y la exportación se registran por separado en el informe
de entrega. No confundir estos archivos fuente con una copia de los datos reales.
