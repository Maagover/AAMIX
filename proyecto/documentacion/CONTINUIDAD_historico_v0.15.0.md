# CONTINUIDAD · AAMIX 0.15.0

18 de octubre de 2026, Chile. Entrega completa: AAMIX_Prototipo_Local_Windows_v0.15.0.zip; carpeta AAMIX_Prototipo_Local_v0.15.0. Continuar sobre esta fuente sin reconstruir. El pedido explícito es **no avanzar multijugador**. El plan MULTIJUGADOR_PLAN_v0.15.md es anterior y no es autorización para implementarlo.

## Decisiones actuales del autor

La descripción de README 0.15.0 y la sección 23 de la base 1.11 sustituyen únicamente la presentación y flujo de bienvenida de 0.14.0. Conservan reglas, IA, catálogo, mazos, misiones, códigos, seguridad y exclusión de promociones. Historia completa intacta en BASE_DEL_PROYECTO_v1.10.md, CONTINUIDAD_historico_v0.14.0.md y PROMPT_CONTINUIDAD_historico_v0.14.0.md. No volver a los flujos anteriores de regalo al acceder, cinco rivales visibles, tarjetas ladeadas o Actualizar textual.

Intro inicial con fade de 2,5s, MP3 del autor y texto clicable desde cualquier parte; después Inicio invitado. Identidad sin fondo/nombre claro abre cuenta. Iniciar sesión recupera UUID y progreso; no se guardan tokens/correos en disco. Bienvenida única: 1 sobre TC. Mazo inicial a elección al entrar al desafío. Cuentas que ya obtuvieron mazo no reciben otro sobre ni pierden nada. Un mazo de código previo permite jugar sin consumir el regalo inicial.

Individual horizontal: aleatoria/dado a la izquierda, desafío/espadas a la derecha; Volver abajo. Toda selección de mazo pasa por `pending_match` con rival elegido una vez; sólo Comenzar llama al motor y crea recibo. Revancha mantiene rival. Desafío usa Nivel, premios TC y revela sólo el siguiente bloqueo con candado. Derrota: Revancha/Volver; victoria: Siguiente; ambos regresos vuelven a niveles aunque haya RPC en curso. La cola muestra premio sólo en niveles y después de confirmar servidor.

Mis sobres: casilla cuadrada centrada, accionable, portada/nombre/cantidad; cero no muestra casilla. Sólo la carta actual está visible, todas las demás comparten origen/rotación cero y permanecen ocultas hasta deslizar. Se conservan pausa extra de 1,12s, rareza de la quinta Singular y persistencia de apertura. Ninguna animación vuelve a sortear ni otorgar cantidades.

Recarga es un PNG con tooltip, sin texto de botón. Arte generado original en assets/estetica_v015, prompt completo y procedencia incluidos. Las cinco referencias están intactas. MP3 del autor intacto y loop; desafío usa combate_desafio.wav original a 158BPM/48,6076s; aleatoria usa batalla.wav anterior. No contiene melodías de Pokémon. Audio probado con Dummy; no afirmar escucha en altavoces.

## Servicio ya aplicado

Octava migración: 20261018215041_aamix_welcome_challenge_v0150. Tabla welcome con lectura del dueño, escritura revocada; RPC aamix_claim_welcome_pack y aamix_enter_challenge. aamix_inventory añade welcome_pack, y claim_starter exige entrada previa para el primer mazo. Reintentos bajo el bloqueo común de cartera, regalo único por UUID. No cambiar Auth/SMTP. APPLIED_MIGRATIONS.json, DEPLOYMENT_v0.15.0.json y WELCOME_AND_CHALLENGE_v0.15.0.md contienen el contrato. No repetir migraciones aplicadas.

Prueba real de 20 casos con cinco usuarios sintéticos y rollback; diez tablas reales idénticas por conteo/hash. Sin correo ni premios reales. Los hallazgos del asesor son los privados INFO y aviso de contraseñas previos; sin problemas RLS públicos nuevos. No se acredita concurrencia entre conexiones independientes.

## Validación acotada y entrega

62 casos UI/HTTP aislado, 20 SQL y 6 del paquete final: 88 casos distintos. Un primer guion usaba fase `ended` en lugar de `finished` y comparaba píxeles de ventana con coordenadas lógicas; se corrigió el guion y se retomó únicamente lo pendiente más la alineación. No se cambió game.gd por estos fallos. Los 331 casos/5 partidas de 0.14 y sus sorteos son historia, no pruebas nuevas. No ejecutar suites antiguas masivas por rutina: el autor pidió pocas pruebas y un máximo de 50–100 intentos cuando haga falta repetir.

Las capturas actuales están en capturas/v0.15.0. RESULTADOS y VALIDACION registran comprobaciones; el informe junto al ZIP registra CRC, SHA, extracción en carpeta con espacios y arranque sin caché. No sobreescribir entregas anteriores. Incluye motor oficial; basta extraer todo y ejecutar Jugar_AAMIX.bat.
