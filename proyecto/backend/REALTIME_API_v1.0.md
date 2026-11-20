# Contrato v1.0

Se mantiene HTTPS para comandos/commits y resultados persistidos. Protocol3 añade room_version y players[].avatar_code. Los RPC existentes siguen disponibles. mp_response sigue privado, sin EXECUTE para clientes. Inbox privado realtime:aamix:user:<UUID>: join phx_join con JWT y private=true; heartbeat25s y access_token al renovar. Sólo el servidor emite broadcast event=room, payload=mp_response para el destinatario. RLS SELECT exige topic='aamix:user:'||auth.uid(); no política INSERT cliente. No hay claves administrativas en cliente.

room_version aumenta con estado, confirmaciones, invitado o revisión. Las respuestas HTTP de una versión anterior se ignoran. Comandos pendientes de la misma revisión se conservan ante replies anteriores. La cola visual consume snapshots contiguos a velocidad normal sin detener transporte. El anfitrión ejecuta comandos contra room.state confirmado y restaura el estado visual mientras espera el commit. No hay confirmación optimista de una jugada sin guardar.

Polling8s mantiene presencia/recuperación al estar suscrito; pendiente sin confirmación2s. Al perder WebSocket vuelve el polling adaptativo. Sesiones y salas se limpian al salir/cambiar de cuenta. El motor del anfitrión sigue siendo de confianza, sin arbitraje SQL de reglas.

Recuperación oficial administrada: admin_progress_tools_v100.sql y aamix_release_recovery_verify_v100.sql, sólo postgres, esquema privado cerrado. Respaldos y checksums fuera de la distribución. Las funciones de restauración preservan antes cualquier progreso posterior. No ejecutar de nuevo el reset de lanzamiento.

Documentación oficial consultada: https://supabase.com/docs/guides/realtime/broadcast y https://supabase.com/docs/guides/realtime/authorization . Los avisos INFO de RLS sin políticas en tablas internas y de respaldo reflejan cierre deliberado al cliente: https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy . El aviso histórico de protección de contraseñas filtradas permanece; el juego usa OTP: https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection .
