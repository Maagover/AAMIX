# Prompt vigente para continuar AAMIX desde 0.12.0

Actualizado el 18 de octubre de 2026, Chile. Base vigente: **BASE_DEL_PROYECTO_v1.8.md**, sección 20. Este prompt reemplaza al de 0.11.0, conservado como `PROMPT_CONTINUIDAD_historico_v0.11.0.md`. Backend 0.12.0 aplicado y su prueba real pasó con rollback. **582 comprobaciones y 48 partidas completas simuladas contra IA aprobadas en Windows, cero fallos.** Consultar VALIDACION_v0.12.0.md y VERSION.json; extracción, integridad y arranque del ZIP final se acreditan en INFORME_ENTREGA, sin sumar cifras históricas.

Estamos continuando AAMIX, mi juego de cartas físico convertido en un juego virtual para computador. Es un proyecto personal, en español, para jugar con amigos; no quiero comercializarlo y busco costo gratuito o muy bajo. Continúa sobre el proyecto real adjunto y conserva lo aprobado. Entrega versiones completas descargables y jugables para Windows y deja continuidad suficiente para cambiar de chat.

## 1. Contexto y prioridades

La entrega actual es **AAMIX_Prototipo_Local_Windows_v0.12.0.zip**, carpeta AAMIX_Prototipo_Local_v0.12.0/. Incluye motor, fuentes, assets, datos, pruebas, documentación y lanzador. Lee README, VERSION.json, CONTINUIDAD.md y BASE_DEL_PROYECTO_v1.8.md antes de modificar. La base conserva las secciones anteriores; la sección 20 reemplaza el logo inmóvil, la colección sin separación y la misión única. Se mantiene el bloqueo de retratos promocionales de la sección 19. La exclusión absoluta de promociones en sobres y sus probabilidades de la sección 18 siguen vigentes.

Prioridad: mis aclaraciones más recientes; base vigente y registro de decisiones; reglas de torneo/manual/textos con aclaraciones del autor; documentación histórica. Distingue implementado, confirmado pendiente e interpretación provisional. Un documento o plan no demuestra implementación. No reconstruyas el juego ni vuelvas a pedir imágenes incluidas en el ZIP. No supongas haber leído adjuntos inaccesibles.

## 2. Tecnología y estado real

- Godot 4.7.2, 2D, Windows x86_64. Jugar_AAMIX.bat ejecuta el motor incluido y OpenGL Compatibility; no requiere instalar Godot.
- Partidas individuales contra IA local. La IA usa su información privada y el estado público; no ve la Mano humana ni el orden de su Mazo.
- Catálogo de 41 cartas, incluidas seis promocionales. Hay 31 efectos soportados y diez pendientes. Obtener una carta no implica que su efecto esté programado.
- Acceso real por correo/código, regalo inicial único y colección por UUID desde 0.9.0. No recrear Auth, SMTP ni cuentas.
- Perfiles, regalos por código, misión diaria y sobres persistentes desde 0.10.0; exclusión absoluta de promociones en sobres desde 0.10.1; ajustes visuales, cinco códigos promocionales y bloqueo de retratos promocionales desde 0.11.0; colección 35+6, logo con flotación suave, tres misiones y códigos de sobre/Girabl desde 0.12.0.
- Multijugador, constructor, intercambios, guardado de partidas y desbloqueos promocionales todavía no están implementados. La segunda edición física no está incorporada.

Archivos: main.gd integra pantallas; game.gd reglas; ai.gd rival; account.gd Auth; collection.gd inventario/RPC; avatar_view.gd y profile_ui.gd retratos; home_cards.gd y gift_badge.gd presentación; rewards_ui.gd y pack_reveal.gd recompensas/apertura; sound.gd audio. Conserva drop_surface.gd, card_image.gd, motion.gd y los datos/recursos originales. Consulta backend/REWARDS_API.md y APPLIED_MIGRATIONS.json antes de tocar el servicio.

## 3. Mesa y reglas que se conservan

Estética de cuero marrón/cobre con logos y dorso originales. Dominio neutral compartido al centro. Columna propia Pagadas–Mazo–Recursos; Cementerio sobre Quemadas en casillas independientes. Panel Acciones junto al registro compacto; Mano capaz de mostrar ocho cartas. Cartas con redondeado leve, sin textos duplicados bajo la imagen; doble clic amplía, sin panel lateral permanente. Arrastrar para recursos, pagos, cartas, Eventos, ataques, bloqueos, descarte y habilidades prácticas. Eventos sobre mesa/objetivo, sin zona propia. Conservar selección, objetivos, numeración y animaciones sin filtrar cartas ocultas.

Reglas:

- Mazo de 40 cartas; máximo 3 de cada no Recurso, Singular 1; Recursos sin ese límite. Recurso inicial tomado de esas 40; después barajar y robar 6.
- Hasta dos cambios completos de Mano: 6 → 5 → 5.
- Reagrupar Pagadas → Recursos y Ataque → Defensa. Después se puede bajar un Recurso; sin Recursos en Mano pasar automáticamente a Acciones.
- Pagar moviendo Recursos a Pagadas. Aliados entran en Defensa, Objetos se anexan con máximo uno por portador, Eventos resuelven al Cementerio. Dominio nuevo descarta el anterior al Cementerio de su dueño.
- Aliado recién jugado no ataca salvo Ágil. Declarar ataque cierra las jugadas normales y conserva las ventanas alternadas de Eventos del combate.
- Cada defensor bloquea a un atacante y cada atacante admite un bloqueador. Defensor más fuerte destruye al atacante sin dañar Mazo; empate destruye ambos; atacante más fuerte destruye defensor y diferencia daña Mazo; sin bloqueo toda la Fuerza daña Mazo. Resolver cada atacante por separado, punto a punto. Mazo vacío implica derrota.
- Sin Aliados defensores omitir Confirmar bloqueos; conservar respuesta legal de Evento, o aplicar daño automático si no la hay.
- Al terminar el turno, robar una carta y completar hasta tres si aún hay menos. Si supera ocho, elegir descartes antes del turno rival. Ese cierre no elimina posteriores respuestas/bloqueos defensivos.
- Las búsquedas muestran cartas válidas; Quemadas no se recuperan. Al salir un portador por cualquier destino, su Objeto va al Cementerio.
- Bigotes: una vez en cada turno del dueño. Azul: +1 en Ataque, +2 mientras bloquea, sin bono en Defensa sin bloquear. Muñeco de Miku da +4 a Maagover/Dicky sobre su base. Los bonos por Tipo incluyen a la propia carta cuando corresponda.
- Escuela de Vuelo es 0131, limita a cuatro Aliados y cada dueño elige cuáles conservar; Guitarramala es 0134. Desaparición de Papito no termina el turno.

No importar reglas de Mitos y Leyendas para llenar vacíos. Conservar como provisionales las interpretaciones anteriores de cartas y los casos pendientes de simultáneos, ambos mazos vacíos y búsquedas. No rediseñar la mesa ni cambiar reglas como efecto secundario de cuentas/recompensas.

## 4. Presentación vigente

- Salir sólo en Inicio, de invitado o cuenta; pregunta «¿Seguro que quieres salir?» con Confirmar/Cancelar, también al cerrar la ventana.
- Tu turno / Turno rival brevemente después del robo y cambio de turno. Pasar daño conserva la regla del antiguo Pasar prioridad.
- Hablar de cartas obtenidas, no códigos obtenidos. Los códigos de acceso/regalo y los identificadores técnicos siguen existiendo.
- **Inicio 0.12.0:** Transmisión Caída y Restos más grandes y cercanos; logo también flota con desplazamiento menor. Conjunto a la derecha, sin giro ni alternancia de frente/dorso. Sin «JUEGO DE CARTAS · PRIMERA EDICIÓN»; pie/título «AAMIX · versión 0.12.0», sin Mesa.
- **Fotos 0.11.0:** 22 Aliados no promocionales sin requerir posesión; círculo del personaje sin textos de carta, imágenes sin nombres debajo y tooltips con nombre. Dicky, Maagover y Girabl tienen rostros reencuadrados desde el original. No mostrar la etiqueta «Tu foto de perfil» en Mi cuenta.
- Las promocionales están bloqueadas como foto incluso poseídas; futuros desbloqueos pendientes. Cliente y servidor las rechazan. Un dato histórico promocional se muestra como silueta; no resetear la base de datos ni borrar cartas.
- Misiones y Mis sobres son listas a la izquierda, con progreso/cantidades/acciones a la derecha. Apertura, cartas y selección de mazo centradas. **Colección 0.12.0:** 35 regulares en HFlow centrado y, con separación visible al final, seis promocionales en una sola fila centrada al ancho normal. Conservar cantidades, faltantes y doble clic. Mis Mazos sólo dice «Obtenido · 40 cartas» junto a Ver lista, sin «guardado en tu cuenta».
- Código de regalo usa un formulario mínimo de entrada y Canjear. No añadir una lista de códigos/recompensas a esa pantalla. La confirmación presenta el regalo real, no un mensaje fijo de Maagover.
- Regalo inicial con icono/sonido; Victoria/Derrota centrado con Revancha/Inicio debajo y sin Ver mesa. Centrar también las elecciones de cartas durante las partidas.
- Conservar música, ajustes, efectos de regalo/resultado/turno/abrir sobre/deslizar. La presentación no revela información privada.

## 5. Acceso, colección, mazos y códigos

Al abrir: Iniciar sesión, Crear cuenta o Jugar como invitado. Invitado practica con Kajido, Papito y Flaan. La IA recibe cualquiera de esos tres al azar, incluidos espejos. Las cuentas sólo usan sus mazos obtenidos.

Cada UUID puede elegir una sola vez un regalo inicial Kajido/Flaan/Papito, con sus 40 cartas exactas y mazo guardados en una transacción. No reiniciar regalos por actualizar. **Mi regalo real ya elegido se conserva**; no afirmar de nuevo que está sin reclamar. Guardar un mazo no consume cartas; los tres mazos base tienen 18 Recursos y sus listas se conservan exactas.

Mi Colección mantiene 41 espacios por identificador desde 0100, faltantes vacíos y cantidades acumuladas; promociones 01a–01f sin renumerar. Mis Mazos muestra obtenidos, cantidades y acceso a jugar. El límite de copias de mazo no limita la colección. Todavía no hay constructor.

Los siguientes códigos son decisiones confirmadas. **Una vez por cuenta/UUID y código**, no diarios. Se normalizan mayúsculas y espacios exteriores. No añadir la tabla a la interfaz mínima de canje.

| Código exacto | Recompensa |
| --- | --- |
| M4Z0M44G0 | Mazo Maagover histórico exacto, 40 cartas / 15 Restos, portada 0108, id interno maago; conserva su promoción legítima 01c. |
| P3RI | 3 Peri (01a); no lleva cero final. |
| B1G0T3S | 3 Bigotes (01b). |
| SI2TYA | 1 Tsuki y Akira (01c). |
| CHANCHULINES | 1 Granjita de Chanchuus (01d). |
| TORNEOAAMIX1 | 1 Dragón Tee K.O (01e). |
| AAMIXTC | 1 sobre Transmisión Caída en Mis sobres, sin abrirlo automáticamente. |
| M4Z0G1R4 | Mazo Girabl histórico exacto, 40 cartas / 12 Restos; portada 0127, id girabl. |

Maagover usa la lista exacta de tests/fixtures/mazos_legacy.json; no añadir una cuarta opción a invitado/IA. Los cinco códigos promocionales de 0.11.0 conceden sólo sus cartas. AAMIXTC entrega un sobre y M4Z0G1R4 concede mazo/cantidades exactas de `tests/fixtures/mazos_legacy.json:usuario_girabl`. Girabl tiene 40 cartas/12 Restos e incluye legítimamente 3 Peri, 2 Bigotes y 1 Tsuki y Akira; no adaptar la lista ni añadir Girabl al invitado o a la IA. Las promociones de un mazo no entran en sobres ni desbloquean sus fotos. Los ocho códigos son una vez por cuenta, independientes del regalo inicial; no reiniciar canjes históricos.

## 6. Expansión, misión y sobres

**La expansión N.º 1 se llama Transmisión Caída.** El nombre no añade cartas ni modifica pesos. Misiones contiene tres entradas independientes:

| Misión | Frecuencia y progreso | Recompensa |
| --- | --- | --- |
| Juega 1 partida | Diaria; terminar con victoria o derrota. | 1 sobre. |
| Gana 1 partida | Diaria; victoria. | 1 sobre. |
| Juega 10 partidas | Acumulativa de por vida; diez partidas terminadas, una vez por cuenta. | 5 sobres. |

Las diarias se reinician **00:00 America/Santiago**, según servidor/horario de verano. La acumulativa no se reinicia ni se repite cada diez partidas. Una victoria puede completar ambas diarias, con reclamos separados. El progreso usa recibos finalizados guardados, incluidos los anteriores a 0.12.0; conservar el registro histórico de reclamos de Juega 1 partida. No usar el reloj del cliente ni fabricar progreso.

**Las promocionales nunca aparecen en sobres**, en ninguna posición ni rama, incluso si cambia su rareza/tipo. Se excluyen 01a, 01b, 01c, 01d, 01e y 01f. El catálogo y la colección conservan las 41 cartas; posesión o regalo legítimo de una promoción no modifica esta exclusión. La restricción de fotos es independiente.

Grupo elegible: **35 cartas: 1 Recurso, 25 normales y 9 Especiales**.

1. Un Recurso no promocional garantizado, actualmente Restos; siempre primero.
2. Normal uniforme entre las 25 normales no Recurso y no promocionales.
3. Normal uniforme del mismo grupo; puede repetirse.
4. Normal uniforme del mismo grupo; puede repetirse.
5. Normal uniforme 70% o Especial no promocional 30%; puede repetir una normal anterior.

Nunca hay Recursos en 2–5. Dentro del grupo Especial, Kajido 0105, SoyFlaan 0103, Papito 0115 y Transmisión Caída 0119 tienen **5% CADA UNO**: 1,5% total de sobres por carta. Guitarramala 0134, HNyko 0128, Chanchuus 0125, Escuela de Vuelo 0131 y Serandimini 0130 tienen **16% CADA UNO** del grupo: 4,8% total por carta. Los cuatro primeros no tienen 5% total por sobre. No deducir rarezas de puntos de color, clase o Singular.

Abrir envoltorio con el mouse y deslizar las cinco cartas lateralmente, una a una. Sorteo, consumo, cantidades y orden se guardan en una transacción antes de animar. Retomar la apertura pendiente tras reingresar y confirmar al revelar las cinco; peticiones repetidas devuelven el mismo resultado sin consumir otro sobre.

La reparación histórica autorizada ya se aplicó en 0.10.1: Dragón Tee K.O 01e en posición 2 de un sobre anterior se sustituyó por El conflicto de Maagover 0116; 85 cartas y promoción legítima 01c conservadas, con auditoría. No repetirla, publicar UUIDs privados ni extender esa autorización a otras cuentas/cartas.

## 7. Backend y límites reales

Reutilizar Supabase AAMIX **drpsedaiqyowwikhjugs**, región São Paulo, Auth por correo/código y Brevo SMTP ya existentes. No reiniciar SMTP, plantillas ni cuentas. El UUID de Auth es el dueño; el nombre visible no lo identifica. Plan gratuito elegido: comprobar condiciones actuales antes de asumir costos.

Migraciones históricas aplicadas: 20261017185851_aamix_collection_starter_v090, 20261017194519_aamix_profiles_rewards_v0100 y 20261017221142_aamix_packs_exclude_promotional_v0101. La nueva **20261018031742_aamix_gift_codes_and_avatar_lock_v0110** también está aplicada. El índice **20261018032104_aamix_gift_codes_index_v0110** también está aplicado y registrado por separado. Consulta **backend/APPLIED_MIGRATIONS.json** para el historial exacto y **backend/DEPLOYMENT_v0.11.0.json** para el despliegue completo. La nueva **20261018035100_aamix_missions_and_gifts_v0120** está aplicada y su prueba real pasó. Consulta también **backend/DEPLOYMENT_v0.12.0.json**. No volver a ejecutar las ya aplicadas ni utilizar los generadores históricos para reconstruir el servicio.

La migración 0.12.0 añade misiones independientes, `aamix_claim_mission(p_mission_id text)`, arreglo `missions` en el inventario y `reward_packs` en canjes. Conserva `mission` y `aamix_claim_daily_mission` para el reclamo diario anterior, sin duplicarlo; los códigos antiguos siguen funcionando. No cambia Auth/SMTP, usuarios ni el sorteo.

La migración 0.11.0 añade configuración privada de códigos, conserva `aamix_redeem_code(p_code)` y su clave única por UUID/código, y restringe `aamix_set_avatar` a Aliados no promocionales. Canje y cantidades son atómicos; la respuesta incluye regalo, cartas y estado de reintento. La restricción de avatares funciona aun poseyendo la carta. No cambia el sorteo corregido de sobres ni firmas públicas, Auth o SMTP.

RLS sólo lectura propia; funciones privilegiadas privadas verifican UUID/correo y RPC públicos son invoker. No aceptar del cliente cantidades, sorteos ni UUID de dueño. No borrar cuentas, inventar colecciones reales ni incluir service_role, SMTP secreto, tokens o códigos reales en cliente/ZIP. URL y clave publicable son configuración pública. Sesiones, correo y tokens sólo viven en memoria; reingresar con mismo correo y código nuevo recupera UUID/datos.

**El resultado de la misión lo declara el cliente de una partida local contra IA. El servidor controla identidad y duplicados; no valida un historial de jugadas ni prueba que se jugó honestamente.** Si falla enviarlo, mantener abierto el juego y reintentar en Misiones. Cerrar/cambiar sesión pierde esa cola en memoria. Una apertura de sobre ya guardada sí persiste después de cerrar.

## 8. Verificar y entregar

**Backend nuevo PASS:** `test_missions_and_gifts_v0120_rollback.sql` contra el servicio desplegado, íntegramente con cuentas sintéticas y rollback. Verifica Juega 1 partida histórico, Gana 1 diaria, Juega 10 de por vida, recibos anteriores, reclamos independientes, medianoche de Chile aunque la sesión use Honolulu, 20 reintentos, ocho códigos incluido AAMIXTC y Girabl 40/12, autorización/RLS, reversión atómica por desbordamiento y 1.000 sobres sin promociones. No es una prueba de correo real ni de dos clientes simultáneos; no se reinician Auth o recompensas reales.

**0.12.0: 582 comprobaciones únicas, cero fallos y 48 partidas completas contra IA.** UI GUI 130, presentación 43, perfiles 48, Girabl 76 con 27 partidas, Maagover 64 con 21 partidas, recompensas nuevas GUI 98 y flujos anteriores 71/52. Las repeticiones sin interfaz de UI 130 y recompensas 98 no se suman; los 11 recibos del fixture HTTP no son partidas IA. Backend: prueba nueva y prueba compatible adaptada a ocho códigos, 2.000 sobres sin promociones en total y rollback. Girabl del servicio coincide con la lista 40/12; cero cuentas QA y estado real conservado: 85 cartas/dos mazos/un canje/un recibo. Detalle en VALIDACION_v0.12.0.md; extracción/integridad/inicio del ZIP final se registra en INFORME_ENTREGA.

0.11.0 tuvo 336 comprobaciones y 21 partidas; se conserva como historia. Históricamente 0.10.1 tuvo 155 comprobaciones y 21 partidas; 0.10.0 tuvo 1.050 y 214; 0.9.0 tuvo 848 y 193. Conservar informes/capturas como historia. No pedir ni usar códigos reales para automatizar pruebas. Ensayos secuenciales/rollback no acreditan concurrencia real entre dos clientes ni una nueva entrega/reingreso por correo.

Entregar ZIP completo versionado Windows con motor, fuentes, assets, lanzador e instrucciones. Probar carpeta nueva sin .godot/cachés, excluir temporales/credenciales y actualizar versión visible, VERSION.json, README y documentación coherentemente. Describir sólo funciones terminadas como disponibles.

## 9. Continuidad y próxima tarea

Cada entrega conserva base, reglas/decisiones, CONTINUIDAD.md, prompt, migraciones y resultados. Registrar fecha, origen confirmado/propuesto/provisional, qué reemplaza y estado implementado/pendiente. El último ZIP debe bastar para retomar sin memoria del chat ni rutas temporales.

Primero consultar el cierre de 0.12.0 en VALIDACION e INFORME_ENTREGA y el estado real del servicio. Mantener promociones fuera de sobres, retratos promocionales bloqueados, probabilidades, códigos exactos, reinicio diario y progreso acumulativo confirmados. Luego seguir mi próxima solicitud. Multijugador privado por sala requerirá privacidad de manos/orden de Mazo y validación de jugadas en servicio; definir alojamiento/costos antes de contratar. Constructor, intercambios, diez efectos, guardado y desbloqueos promocionales siguen pendientes. No cambiar reglas ni reabrir decisiones ya confirmadas por iniciativa propia.
