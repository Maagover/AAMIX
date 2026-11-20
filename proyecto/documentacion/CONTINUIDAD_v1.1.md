# Continuidad · AAMIX 1.1.0

Base: ZIP oficial 1.0 sin reconstrucción. Desarrollo editable: work/AAMIX_v1.1. No modificar sources, work/AAMIX_v1.0 ni las entregas publicadas anteriores.

## Mazos

Constructor implementado en deck_builder.gd; validación compartida en deck_rules.gd. Interfaz Mis Mazos de main.gd: cuadrícula HFlow centrada, elementos reales de 300×300, Ver Mazo con cartas/cantidades, edición sólo personalizada y botón +. Portadas custom_transmision/custom_restos en assets/estetica_v110, composición con originales, resueltas por deck_art.gd.

Decisión confirmada por el autor: EXACTAMENTE40 para jugar, incluyendo Restos; al menos1Restos para el Recurso inicial. Borradores0–40, no jugables. Copias<=3, Singular<=1 incluso promocionales; Recursos sin ese límite, pero nunca más copias que las poseídas. Crear/editar no consume colección. No añadir requisitos ni cambiar listas base.

Persistencia sólo remota. aamix_inventory conserva decks para los clientes1.0 y añade custom_decks; collection.gd los combina en memoria y playable_decks excluye borradores/inválidos. RPC aamix_save_custom_deck usa UUID de solicitud y revisión optimista. Nueva ID vacía/revisión0; el servidor devuelve custom_UUID y revision1. Reintentos conservan payload/UUID; no deshacer el bloqueo de edición de un guardado ambiguo. Volver/reabrir recupera su formulario en memoria.

Individual: rewards.prepare_match confirma antes de iniciar, usa match_deck congelado y reutiliza el recibo preparado sin registrar dos comienzos. Salas MP ya congelaban las listas; se extiende el resolvedor a mazos personalizados, manteniendo vistas privadas, protocolo3, revisiones y abandono único. La integridad de recibos usa un registro privado de IDs, sin alterar listas base ni progreso previo.

## Backend y límites

Migración nueva aplicada: 20261020022913 aamix_custom_decks_v110. Leer backend/DEPLOYMENT_v1.1.json y backend/aamix_custom_decks_v110.sql. No repetir ésta ni las anteriores. Nunca ejecutar admin_reset_progress_v100.sql. No hubo otro reset. Se conservaron4cuentas existentes; las2sintéticas de HTTPS se eliminaron con sus sesiones y datos de prueba. Los3usuarios de la prueba SQL se revirtieron en transacción.

Las tablas privadas nuevas mantienen RLS sin políticas y privilegios de API revocados a propósito; public.aamix_custom_decks permite SELECT del propio auth.uid y no escritura directa. Los cambios requieren RPC autenticada. Los otros avisos previos del asesor de seguridad se describen en DEPLOYMENT_v1.1.json.

## Distribución

Versión del juego1.1.0, presentación1.1, Godot4.7.2 incluido. user:// conserva AAMIX. Nuevo iniciador A blanca recompilado con metadatos1.1.0.0; instalador A amarilla estable sin cambio, protocolo1 y minimum_launcher1. Empaquetar motor+proyecto+iniciador completos, nunca credenciales ni fixtures privados.

Publicar v1.1.0 con ZIP nuevo, AAMIX_Instalador.exe, aamix-update.json y SHA256SUMS.txt. Conservar v1.0.0. Tras verificar hashes/tamaños, activar Latest y verificar el manifiesto permanente y el instalador. Guía original: entregas/AAMIX_COMO_PUBLICAR_ACTUALIZACIONES.md.

Validación actual en documentacion/validacion_v1.1:24modelo,5integración local,48UI,8recuperación de guardado,31gruposSQL y22HTTPS reales. Los intentos de depuración no se suman. No se repitieron matrices históricas ni sorteos. No se probó WebSocket de nuevo ni dos PCs remotos; no inferir latencia. La validación de publicación se registra aparte al terminar.

Pendientes conservados: efectos de diez cartas catalogadas, intercambios, reanudar individuales, ranking, emparejamiento público y arbitraje competitivo independiente. El anfitrión sigue siendo autoridad de reglas.
