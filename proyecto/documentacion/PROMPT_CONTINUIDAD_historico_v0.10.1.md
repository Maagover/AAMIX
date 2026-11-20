# Prompt vigente para continuar AAMIX desde 0.10.1

Actualizado el 17 de octubre de 2026. La base vigente es **BASE_DEL_PROYECTO_v1.6.md**, sección 18. Este prompt reemplaza el anterior, conservado como `PROMPT_CONTINUIDAD_historico_v0.10.0.md`. Juego y backend verificados: **155 comprobaciones y 21 partidas simuladas aprobadas en Windows, cero fallos**. La verificación portátil se registra en **INFORME_ENTREGA**; revisar ese informe, VERSION.json y VALIDACION_v0.10.1.md antes de afirmar resultados del ZIP.

Estamos continuando AAMIX, mi juego de cartas físico convertido en un juego virtual para computador. Es un proyecto personal, en español, para jugar con amigos; no quiero comercializarlo y busco costo gratuito o muy bajo. Continúa sobre el proyecto real adjunto y conserva lo aprobado. Entrega versiones completas descargables y jugables para Windows y deja continuidad suficiente para cambiar de chat.

## 1. Contexto y prioridades

La entrega actual es AAMIX_Prototipo_Local_Windows_v0.10.1.zip, carpeta AAMIX_Prototipo_Local_v0.10.1/. Incluye motor, fuentes, assets, datos, pruebas, documentación y lanzador. Lee README, VERSION.json, CONTINUIDAD.md y BASE_DEL_PROYECTO_v1.6.md antes de modificar. La base incorpora el contenido completo de la 1.5; su sección 18 prevalece sobre la inclusión histórica de promociones en sobres. La sección 17 conserva los demás requisitos de 0.10.0; las secciones más antiguas describen etapas anteriores.

Prioridad: mis aclaraciones más recientes; base vigente y registro de decisiones; reglas de torneo/manual/textos con aclaraciones del autor; documentación histórica. Distingue implementado, confirmado pendiente e interpretación provisional. Un documento o plan no demuestra implementación. No reconstruyas el juego ni vuelvas a pedir imágenes incluidas en el ZIP. No supongas haber leído adjuntos inaccesibles.

## 2. Tecnología y estado real

- Godot 4.7.2, 2D, Windows x86_64. Jugar_AAMIX.bat ejecuta el motor incluido con el proyecto y OpenGL Compatibility; no requiere instalar Godot.
- Partidas individuales contra IA local. El rival usa su información privada y el estado público, sin ver la Mano humana ni el orden de su Mazo.
- 41 cartas catalogadas, incluidas 6 promocionales. Hay 31 cartas con efectos soportados y diez sin efecto programado. La colección conserva las 41; sólo 35 no promocionales participan en sobres. No presentar todos sus efectos como implementados.
- Cuentas reales por correo/código confirmadas por mí; colección, regalo inicial único y mazos obtenidos desde 0.9.0.
- Desde 0.10.0: perfiles de Aliados, presentación/sonido renovados, código Maagover, misión diaria y sobres persistentes. En 0.10.1 se corrige exclusivamente la exclusión absoluta de promociones en sobres.
- Multijugador entre computadores, constructor, intercambios y guardado/reanudación de partidas siguen pendientes. La segunda edición física todavía no se incorpora.

Archivos: main.gd integra pantallas; game.gd contiene reglas; ai.gd rival; account.gd Auth; collection.gd inventario/RPC. avatar_view.gd y profile_ui.gd muestran los retratos; home_cards.gd y gift_badge.gd animan inicio/regalo; rewards_ui.gd y pack_reveal.gd integran recompensas y apertura. sound.gd controla música/efectos. Se conservan drop_surface.gd, card_image.gd, motion.gd y datos originales de catálogo, listas, reglas y cuentas. Consulta backend/REWARDS_API.md y APPLIED_MIGRATIONS.json antes de tocar el servicio.

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

## 4. Cambios de presentación confirmados

- Salir sólo en la pantalla de inicio, de invitado o cuenta; pregunta «¿Seguro que quieres salir?» con Confirmar/Cancelar. También confirmar al cerrar la ventana.
- Mostrar brevemente Tu turno / Turno rival después del robo y cambio de turno. Cambiar Pasar prioridad por Pasar daño sin modificar su regla.
- Hablar de cartas obtenidas, no códigos obtenidos, en las interfaces. Los códigos de acceso/regalo e identificadores técnicos siguen existiendo.
- Mi cuenta permite elegir cualquiera de los 27 Aliados como retrato circular del personaje, recortado para excluir textos. Guardar por UUID; no requiere poseer la carta.
- Regalo inicial con icono y sonidos; Victoria/Derrota centrado, con Revancha/Inicio debajo y sin Ver mesa al terminar. Centrar también las elecciones de cartas.
- Inicio con cartas flotando y Transmisión Caída en giro lento completo, mostrando frente/dorso.
- Conservar música y ajustes; agregar efectos de regalo, recepción, resultado, turno, abrir sobre y deslizar cartas. La presentación no debe revelar cartas privadas.

## 5. Acceso, colección y mazos

Al abrir: Iniciar sesión, Crear cuenta o Jugar como invitado. Invitado tiene Partida individual y Configuración, más volver al acceso y Salir sólo en el inicio. Practica con los tres mazos Kajido, Papito y Flaan; la IA recibe cualquiera de esos tres al azar, incluidos espejos.

Con cuenta, usar sólo mazos obtenidos. Cada UUID puede elegir una sola vez un regalo inicial Kajido/Flaan/Papito; entregar sus 40 cartas exactas y guardar el mazo en una transacción. Las cuentas anteriores son elegibles si no lo recibieron; **mi regalo real ya elegido se conserva**, no afirmar de nuevo que está sin reclamar. Guardar un mazo no consume cartas. Los tres mazos base tienen 18 Recursos cada uno; conservar las listas exactas.

Mi Colección conserva 41 espacios por identificador desde 0100, faltantes vacíos y cantidades acumuladas; promociones 01a–01f sin renumerar. Mis Mazos muestra obtenidos, sus cantidades y acceso a jugar. El límite de copias del mazo no limita la colección. Todavía no hay constructor.

**Código de regalo** es un acceso independiente a la derecha del inicio. **M4Z0M44G0** entrega una vez por UUID el **Mazo Maagover histórico exacto**, aclaración del nombre abreviado Maago: 40 cartas y 15 Restos de tests/fixtures/mazos_legacy.json, portada 0108, id interno maago. Se añade a colección y Mis Mazos, disponible para la partida de esa cuenta. No consume el regalo inicial ni añade una cuarta opción al invitado o a la IA.

## 6. Misiones y sobres: decisiones completas y corrección promocional

Misiones contiene **Juega 1 partida**. Terminar con victoria o derrota completa la misión; después **Reclamar sobre** da un sobre una vez por UUID y día. Reinicio **00:00 America/Santiago**, según el servidor y su horario de verano. No usar el reloj del cliente ni convertirlo en una misión única para siempre.

**Mi corrección más reciente: las cartas promocionales no deben aparecer en sobres, nunca.** Excluir 01a, 01b, 01c, 01d, 01e y 01f de todas las posiciones y de todas las ramas, incluso si cambia su rareza o tipo. El catálogo conserva las 41, con colección, retratos y mazos válidos. M4Z0M44G0 mantiene el Mazo Maagover exacto, incluida 01c: un regalo de mazo no es un sobre. La sustitución histórica que autoricé ya se realizó: Dragón Tee K.O (01e), posición 2 del sobre anterior, se reemplazó por la normal El conflicto de Maagover (0116). Se conservaron 85 cartas y la promoción legítima 01c de Maagover; quedó un registro de auditoría idempotente. No publicar UUIDs reales ni extender la autorización a otras cartas o cuentas.

Participan 35 cartas: 1 Recurso, 25 normales y 9 Especiales. Posiciones del sobre:

1. Exactamente un Recurso no promocional garantizado, actualmente Restos. Nunca Recursos en posiciones 2–5.
2. Una normal uniforme entre 25 normales no Recurso y no promocionales.
3. Una normal uniforme entre las mismas, con repetición permitida.
4. Una normal uniforme entre las mismas, con repetición permitida.
5. Normal uniforme 70% o Especial no promocional 30%; puede repetir una normal anterior.

Dentro de la rama Especial, **Kajido 0105, SoyFlaan 0103, Papito 0115 y Transmisión Caída 0119 tienen 5% CADA UNO** (1,5% total por sobre cada uno). Los otros cinco son **Guitarramala 0134, HNyko 0128, Chanchuus 0125, Escuela de Vuelo 0131 y Serandimini 0130**, con **16% CADA UNO** del grupo (4,8% total por sobre cada uno). Los cuatro primeros no tienen 5% total por sobre. El 80% restante del grupo Especial se reparte por igual entre los otros cinco. No deducir rarezas de color/clase/Singular. La condición promocional es una exclusión independiente y prevalece sobre cualquier rama del sorteo; ninguna de las seis promociones participa en sobres.

Mis sobres abre el envoltorio con el mouse y exige deslizar las cinco cartas lateralmente para revelarlas una a una. Sorteo, consumo, cantidades y orden se deciden en una transacción del servidor antes de la animación. Guardar apertura pendiente y retomarla tras reingresar. Confirmar después de revelar las cinco. Las peticiones repetidas y los UUID nuevos que retomen la misma apertura quedan ligados al mismo resultado, incluso después de confirmar, sin volver a gastar ni sortear.

## 7. Backend y límites reales

Reutilizar Supabase AAMIX **drpsedaiqyowwikhjugs**, región São Paulo. Plan gratuito elegido; comprobar condiciones actuales antes de asumir costos. Auth por correo/código y Brevo SMTP ya funcionan, confirmados por mí. No reiniciar SMTP, plantillas ni cuentas ni volver al bloqueo administrativo antiguo. El UUID de Auth es el dueño real; el nombre visible no lo identifica.

Migraciones YA aplicadas: **20261017185851_aamix_collection_starter_v090** y **20261017194519_aamix_profiles_rewards_v0100**. No reaplicarlas. La segunda añade perfil/cartera, canjes, recibos, misión diaria y aperturas/peticiones. La corrección 0.10.1 añade el indicador is_promotional, lo filtra en las tres ramas del sorteo y protege nuevos resultados mediante una restricción privada. La migración **20261017221142_aamix_packs_exclude_promotional_v0101** ya se aplicó y verificó por el panel SQL autenticado, con historial registrado, después del fallo Invalid requestState del conector. No repetirla. El sorteo corregido protege nuevas aperturas de clientes anteriores. Consultar backend/APPLIED_MIGRATIONS.json. Inspeccionar estado real antes de nuevas migraciones. RLS sólo lectura propia, cliente sin escrituras directas; funciones privilegiadas privadas con identidad/correo confirmado y RPC públicos invoker. No aceptar cantidades ni sorteos elegidos por el cliente.

No borrar cuentas, entregar datos ficticios como colección real, enviar secretos por chat ni incluir service_role/SMTP secreto en cliente o ZIP. URL y clave publicable son la configuración pública. Correo, códigos y tokens sólo viven en memoria; al cerrar sesión se borra lo privado local. Reingresar con el mismo correo y un código nuevo recupera UUID y datos del servidor.

**Las partidas contra IA son locales y el resultado de misión lo declara el cliente. Los recibos evitan duplicados y controlan UUID, pero el servidor no valida jugadas ni prueba que se jugó honestamente.** No presentar esta misión como juego autoritativo. Si falla registrar el final, la cola se conserva sólo en memoria y reintenta; cerrar/cambiar sesión antes de enviarla pierde ese resultado. Abrir un sobre es distinto: su resultado ya guardado sí se recupera después de cerrar.

## 8. Verificar y entregar

Mantener reglas, IA, datos y recursos originales. Separar pruebas HTTP locales, pruebas reales del servicio revertidas, correo real, comprobaciones del autor y partidas simuladas. No pedir ni usar códigos reales para automatizar la validación.

**Antecedentes históricos de 0.10.0, que no acreditan la exclusión promocional:** prueba de recompensas dos veces, 20.000 sorteos en total, regresión de colección 0.9.0 y rollback integral; las cuentas y recompensas reales quedaron intactas. No se enviaron correos reales ni se consumieron regalos. **La carrera real entre dos clientes con transacciones simultáneas no fue verificada**; bloqueos/reintentos/aliases no acreditan esa carrera. La prueba real de entrega y reingreso por correo del autor también es distinta de los datos sintéticos.

**Validación nueva de 0.10.1:** perfiles40 + Maagover64 + recompensasUI51 = **155 comprobaciones sin fallos y 21 partidas simuladas** en Windows; importación y arranque aprobados. En backend real: **10.000 sobres** de regresión (3.025 Especiales y 624 del conjunto con peso5%) y **1.000 adicionales** (300 quintas Especiales/700 normales), con exclusión ante reclasificaciones sintéticas Recurso/normal/Especial, rollback y restricciones restauradas. La reparación sintética pasó: Maagover40+5, promoción legítima conservada, tres repeticiones idempotentes y fallo parcial revertido. No quedaron cuentas de QA. Ver VALIDACION_v0.10.1.md y VERSION.json. La **verificación portátil se registra en INFORME_ENTREGA**. Históricamente 0.10.0 tuvo 1.050 comprobaciones, 214 partidas y 20.000 sorteos; 0.9.0 tuvo 848 y 193. No sumarlos a la ejecución nueva.

Entregar ZIP completo versionado para Windows con motor, fuentes, assets, lanzador e instrucciones. Probar extracción/integridad y arranque en carpeta nueva sin depender de .godot/cachés. Excluir temporales y credenciales. Actualizar coherentemente versión visible, VERSION.json, README y documentación, preservando el historial. Describir sólo funciones terminadas como disponibles.

## 9. Continuidad y próxima tarea

Cada entrega conserva base vigente con reglas/decisiones, CONTINUIDAD.md, este prompt, migraciones y resultados. Registrar fecha, origen confirmado/propuesto/provisional, qué reemplaza y estado implementado/pendiente. El último ZIP debe bastar para retomar sin memoria del chat ni rutas temporales.

Primero consultar el cierre portátil de 0.10.1 en INFORME_ENTREGA y el estado real. La migración y reparación correctivas ya están aplicadas; no repetirlas. Después seguir la nueva solicitud del autor. Multijugador privado por sala sigue pendiente; necesitará privacidad de manos/orden de Mazo y validación de jugadas en el servicio. Definir alojamiento/costos antes de contratar. Constructor e intercambios siguen después; no volver a preguntar probabilidades de sobres ya confirmadas ni cambiar reglas por iniciativa propia.
