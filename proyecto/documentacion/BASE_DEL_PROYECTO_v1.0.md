# AAMIX — Reglas vigentes y primer desarrollo

Versión: 1.0  
Fecha: 17 de octubre de 2026  
Estado: prototipo 0.8 con Mazo Kajido, Mazo Papito y Mazo Flaan. Supabase real conectado; registro pendiente de terminar las plantillas de correo en el panel web.

## 1. Objetivo del proyecto

Adaptar el juego físico AAMIX a una aplicación personal para jugar online con amigos, con un costo bajo. El objetivo final incluye una versión descargable para computador, salas de partida, mazos, colección persistente y apertura de sobres virtuales.

El autor ya dispone de diseños de cartas y reglamento. El desarrollo y la conversión de documentos a datos pueden realizarse con asistencia; el autor valida las reglas y prueba el resultado.

## 2. Fuentes y prioridad

1. Aclaraciones posteriores del autor.
2. Reglas de torneo entregadas por el autor el 16 de octubre de 2026.
3. Manual original: REGLAS_Press.pdf, recibido en esta conversación.

Las reglas de torneo reemplazan las del PDF cuando hay diferencias. Las reglas del PDF siguen aplicándose donde no hay modificación. Las habilidades y efectos de las cartas tienen prioridad sobre las reglas generales, según el manual. Las referencias a Mitos y Leyendas sirven de contexto; no completan automáticamente reglas de AAMIX.

## 3. Preparación confirmada

- El mazo contiene 40 cartas.
- Hasta tres copias iguales de una carta que no sea Recurso.
- Los Recursos no tienen ese límite de copias.
- Las cartas Singulares permiten una sola copia en el mazo.
- El inicio se decide al azar y por acuerdo mutuo.
- Cada jugador comienza con un Recurso en su Zona de Recursos.
- El procedimiento conservado del PDF toma ese Recurso del propio mazo; por tanto, forma parte de las 40 cartas.
- Después se baraja el mazo y se roban seis cartas.
- Se permiten hasta dos cambios completos de mano. En cada cambio, se devuelve la mano al mazo y se baraja.
- Secuencia de tamaño de mano: 6 iniciales; 5 tras el primer cambio; 5 tras el segundo y último cambio.

## 4. Tipos de cartas

| Tipo | Función y permanencia |
| --- | --- |
| Aliado | Tiene Fuerza, Coste y un Tipo. Ataca y bloquea. Entra en la Línea de Defensa y permanece hasta salir por combate o un efecto. |
| Objeto | Se anexa a un Aliado y puede aportar fuerza o habilidades. Cada Aliado lleva como máximo uno. Si el portador sale del juego, el Objeto se descarta al Cementerio, cualquiera sea el destino del portador. |
| Dominio | Modifica el juego mientras permanece activo. Solo existe uno activo entre ambos jugadores. |
| Evento | Aplica su efecto y después se descarta al Cementerio. |
| Recurso | Paga costes. Al utilizarse pasa de Recursos a Pagados y vuelve al comienzo del siguiente turno propio. |

Al resolverse un Dominio nuevo, el anterior se descarta al Cementerio de su dueño. Para efectos que distingan acciones, se conserva la palabra “descarta” del torneo: no se equipara automáticamente este reemplazo a una destrucción.

## 5. Zonas

- Mazo.
- Mano.
- Línea de Defensa.
- Línea de Ataque.
- Zona de Recursos disponibles.
- Zona de Recursos Pagados.
- Zona de Dominio: un único Dominio activo entre ambos jugadores.
- Cementerio: cartas descartadas, destruidas, Eventos resueltos y cartas perdidas por daño. Las habilidades pueden recuperar cartas de esta zona.
- Quemadas: las cartas no pueden recuperarse ni volver al juego durante la partida.

## 6. Secuencia del turno

### A. Reagrupación

Es lo primero que se hace en cada turno:
- Mover todos los Recursos Pagados a la Zona de Recursos.
- Mover los Aliados propios de Ataque a Defensa.

### B. Oportunidad de bajar Recurso

Justo después de reagrupar, el jugador puede bajar un Recurso desde su mano.
- Es opcional.
- Solo uno por turno propio.
- Si omite esta oportunidad, no puede bajar uno posteriormente durante ese turno por la regla normal.
- Aclaración del 17-10-2026: si no tiene Recursos en Mano, el juego pasa automáticamente a Acciones después de reagrupar. Si tiene alguno, conserva la elección de bajar uno o continuar.

### C. Acciones

Puede jugar las cartas que pueda pagar y utilizar habilidades conforme a sus textos.

Procedimiento para jugar una carta:
1. Mostrar la carta.
2. Pagar su Coste moviendo los Recursos necesarios a Pagados.
3. Elegir objetivos si corresponde.
4. Dar al rival la oportunidad de anular prevista en el manual.
5. Si no se anula, resolverla y colocarla en la zona correspondiente.

Una carta anulada va al Cementerio sin resolver su efecto. El procedimiento descrito no contempla devolver su coste. Las habilidades se declaran, eligen objetivos cuando corresponde, pagan sus costes o cumplen condiciones y permiten respuestas según las reglas y el texto de las cartas.

### D. Ataque y defensa

El ataque es opcional.
- El atacante elige uno o más Aliados y los mueve de Defensa a Ataque.
- Un Aliado que entró ese turno no puede atacar, salvo que sea Ágil.
- El defensor puede asignar sus Aliados de Defensa para bloquear.
- Un defensor bloquea a un atacante; no se asignan varios defensores al mismo atacante.
- Declarar ataque cierra las jugadas normales del atacante. No puede jugar Aliados, Objetos ni Dominios después de declarar ataque.
- Solo puede jugar Eventos si al menos un ataque fue bloqueado o el defensor jugó un Evento en su Fase de Defensa. En esos casos, ambos pueden jugar solo Eventos, pagando sus costes, antes del daño.
- El defensor puede jugar Eventos en su Fase de Defensa antes del daño; es su momento normal para jugar cartas durante el turno rival. Las habilidades fuera del turno propio siguen sus textos.
- En la ventana de Eventos se conserva la alternancia comenzando por el defensor.
- Durante la defensa se puede responder y/o bloquear en los momentos permitidos.

| Comparación | Resultado |
| --- | --- |
| Defensor con mayor Fuerza | Atacante destruido; no hay daño al mazo. |
| Fuerzas iguales | Ambos destruidos; no hay daño al mazo. |
| Atacante con mayor Fuerza | Defensor destruido; la diferencia daña el mazo. |
| Atacante sin bloqueo | Su Fuerza completa daña el mazo. |

El daño al mazo se cuenta por cada Aliado atacante por separado. Por cada punto de daño, se envía una carta de la parte superior del mazo al Cementerio de su dueño. Los Aliados destruidos también van al Cementerio de sus dueños.

### E. Cierre del turno

El manual indica que terminan los efectos que duran el turno y se resuelven los efectos de final de turno. Se roba una carta para finalizar.

Aclaración confirmada por el autor:
- El robo final cierra las oportunidades normales de seguir jugando cartas en el turno propio.
- Después del robo ordinario, si el jugador que termina su turno tiene menos de tres cartas, roba las necesarias hasta quedar con tres.
- Si la mano supera ocho cartas, se eligen descartes hasta quedar con ocho antes de que empiece a jugar el rival.
- Esto no impide bloquear ni responder durante la defensa.
- Las habilidades que funcionan fuera del turno propio se rigen por el texto de cada carta.

## 7. Reglas adicionales

- Victoria: un jugador pierde cuando su mazo queda sin cartas.
- Búsquedas: mostrar la carta encontrada antes de incorporarla a la mano o ponerla en juego, verificando que cumple los criterios de la búsqueda.
- Imbloqueable: no puede ser bloqueado por Aliados defensores.
- Singular: una copia en el mazo.
- Ágil: puede atacar el turno en que entra.

## 8. Cartas y mazos recibidos

- Primera edición: 35 cartas de N°1.rar.
- Promocionales de la primera edición: 6 cartas de 01TCPromocionales.rar.
- Total catalogado: 41 cartas, con imágenes, datos, textos y referencias vinculadas.
- Mazos actuales del autor: Kajido, Papito y Flaan, transcritos de las tres imágenes más recientes. Cada uno tiene 40 cartas y 18 Recursos. Los mazos anteriores Maagover y Girabl se conservan únicamente como pruebas de regresión.
- Los tres mazos actuales respetan las restricciones de copias y Singulares. En la lista Kajido, “Fernando” corresponde a Feranando (0110) según la carta.
- Escuela de Vuelo usa 0131 en los datos; Guitarramala conserva 0134.
- Desaparición de Papito ya no termina el turno; se editó su imagen y su texto vigente.
- Muñeco de Miku da +4 en total a Maagover o Dicky (Fuerza final 5 sobre base 1), y +1 a otros portadores.
- Las bonificaciones por contar Aliados de un Tipo incluyen a la propia carta si cumple ese Tipo.
- Los límites al número de Aliados u Objetos se cumplen escogiendo cada dueño las cartas que permanecen; el excedente se descarta al Cementerio.

El catálogo se usará dentro de la aplicación para mostrar las cartas, validar mazos y cargar partidas. Los textos de habilidades necesitan programación expresa para convertirse en efectos automáticos. En el prototipo 0.8 están implementadas las 21 cartas distintas de los tres mazos actuales. El motor conserva además las habilidades anteriores: son 31 códigos soportados entre los 41 catalogados. Los otros diez permanecen sólo catalogados.

## 9. Propuesta técnica

Motor utilizado para el prototipo: Godot 4.7.2. Se preparó una distribución para Windows de 64 bits con el motor oficial y el proyecto fuente. Ampliar a otros sistemas según los computadores de los jugadores.

Motivos: software gratuito, exportación de juegos para Windows, herramientas 2D y soporte de red. La implementación local permite evaluar esta elección con una partida real antes de desarrollar la conexión por internet.

El costo del motor es distinto del servicio online. El alojamiento de partidas y el almacenamiento persistente deberán elegirse y presupuestarse antes de desplegar. El autor autorizó usar la organización AAMIX de Supabase y se creó un proyecto en el plan gratuito con una cotización de US$0 al mes. Esto cubre la identidad inicial; no implementa por sí solo un servidor de partidas ni un remitente de correos para todos los amigos.

Documentación oficial consultada:
- Licencia: https://godotengine.org/license/
- Exportación para Windows: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_windows.html
- Multijugador: https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html
- Servidores dedicados: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_dedicated_servers.html

## 10. Orden propuesto de desarrollo

### Etapa 1: partida local verificable

Dos mazos de prueba y un tablero con las zonas reales. En la versión 0.2 el autor juega contra el computador, con interacción por arrastre. Esta prueba todavía no es multijugador online.

Automatizar preparación, pagos, turnos, bloqueos, daño, descarte final y las habilidades seleccionadas. Mostrar acciones disponibles y un registro de lo sucedido. La interfaz debe permitir terminar una partida completa.

### Etapa 2: partida online entre dos computadores

Crear y unirse a una sala privada. Sincronizar turnos y decisiones. Mantener privadas las manos y el orden de los mazos. El servidor valida acciones y envía a cada jugador solo la información que puede ver. Probar desde conexiones distintas.

La creación de salas y la conexión por internet requieren desarrollo y alojamiento; no aparecen solo por usar Godot.

### Etapa 3: colección y mazos

Identidad de jugador, cartas poseídas y mazos guardados. La colección registra cantidades, no solo imágenes. Las cantidades de una colección no deben perderse al cerrar el juego.

### Etapa 4: sobres y administración

Definir composición, probabilidades y forma de obtener sobres con el autor. Implementar apertura y guardado de cartas. Añadir herramientas para incorporar cartas nuevas y ajustar textos o datos.

## 11. Comprobaciones relevantes para el primer prototipo

- Mazo de 40 y restricciones de copias.
- Cambios de mano 6 → 5 → 5, sin tercer cambio.
- Reagrupación antes de cualquier otra acción.
- Recurso únicamente en su oportunidad inicial y una vez por turno.
- Pago correcto y rechazo de cartas cuyo coste no se pueda cubrir.
- Daño con atacante superior, inferior, igual y sin bloqueo.
- Sustitución de un único Dominio.
- Prohibición de seguir jugando después del robo final.
- Descarte hasta ocho antes de ceder el turno.
- Defensa y respuestas permitidas durante el turno rival.
- Quemadas no recuperables y comprobación de cartas buscadas.
- Fin de partida cuando un mazo llega a cero.

## 12. Casos pendientes para revisar con las cartas

No bloquean la organización inicial, pero deben resolverse antes de implementar las interacciones afectadas:
- Si existe alguna excepción de robo o reagrupación para el primer turno. No se ha indicado una excepción en las reglas recibidas.
- Orden de efectos simultáneos y cadenas de respuestas.
- Criterio cuando ambos mazos se vacían simultáneamente.
- Resultado de una búsqueda sin coincidencias y barajado posterior en cada tipo de búsqueda.
- Alcance y reinicio de otras habilidades de una vez por turno; significado de derrotado; orden de daño de distintos atacantes cuando importe. Bigotes y Azul ya están aclarados.
- Tratamiento de una desconexión durante una partida.
- Compatibilidad necesaria con macOS o Linux.

## 13. Evolución del prototipo y estado actual

El autor confirmó que la versión 0.1 abre y es jugable en Windows. Para la versión 0.2 pidió un tablero basado en Frame 54.png, interacción por arrastre y un rival controlado por el juego, como etapa previa al multijugador online.

Se separan Ataque y Defensa. Los Recursos, Pagadas, Mazo, Cementerio y Quemadas quedan a los costados, con el rival reflejado en la parte superior. El Dominio es único y compartido. La mano humana permanece visible para su dueño; la mano rival se muestra boca abajo.

El humano arrastra Recursos de Mano a Recursos y de Recursos a Pagadas; Aliados de Mano a Defensa; Objetos sobre sus portadores; Dominios a su zona; Eventos a la mesa o al objetivo; atacantes de Defensa a Ataque; defensores sobre atacantes; y descartes al Cementerio cuando lo exige el cierre o Escuela de Vuelo. Mazo a Mano termina el turno. Los pagos pueden prepararse antes o después de elegir la carta y cancelarse mientras no se hayan completado.

Declarar el grupo atacante y confirmar los bloqueos conservan botones. Reagrupación, daño y mínimo de mano son automáticos. Búsquedas, objetivos no arrastrados y reordenamiento se completan en ventanas de elección.

Bigotes: una vez en cada turno del dueño; nunca durante el turno rival. La activación sigue disponible en el turno propio antes del robo final, como habilidad separada de jugar cartas. Arrastrarlo al Mazo activa la búsqueda sin mover al Aliado fuera de su zona.

Azul: +1 mientras está en Ataque; +2 mientras bloquea. En Defensa sin bloquear pierde el bono. El +1 no desaparece al resolver el combate si Azul continúa en Ataque.

Se puede elegir Maagover o Girabl. El computador usa el otro mazo y las mismas reglas, con decisiones locales para pagos, cartas, búsquedas, ataques, bloqueos, Eventos y descartes. Sus decisiones consultan su propia información privada y el estado público de la partida. No hay rival automático en un servicio externo ni cobro por jugada.

La versión 0.3 conserva esa estructura y esas reglas. Añade fondo de cuero marrón inspirado en la referencia del autor, bordes cobrizos, logos a color y blanco, y el dorso original en los Mazos y la Mano rival. El detalle permanente se reemplaza por una ventana de lectura al hacer doble clic; el registro se reduce y puede ampliarse.

El reparto inicial, los robos, jugadas, pagos, reagrupación, ataques, bloqueos, descartes, daño al Mazo y barajado tienen animaciones. El motor comunica eventos visuales a una capa de presentación que no modifica las reglas. Los robos ordinarios del rival mantienen oculta la cara de la carta.

El inicio integra Partida individual, Multijugador, Mis cartas y Salir. Multijugador y Mis cartas son accesos con avisos de función pendiente. Volver al inicio conserva la partida durante la sesión; cerrar la aplicación no la guarda.

La versión 0.3 todavía no conecta computadores, guarda partidas ni mantiene colecciones. Un avance posterior será la partida online con servidor que valide acciones y entregue a cada jugador solo la información que puede conocer. El ID de usuario, la colección persistente y los sobres se desarrollarán después según lo solicitado por el autor.

La versión 0.4 aplica el nuevo criterio visual del autor: solo imágenes de cartas, con un redondeado muy leve; desaparecen las casillas individuales y los nombres, tipos y cifras repetidos debajo. El detalle ampliado conserva texto y fuerza actual. El diseño se aplica a Mano, Aliados en mesa, elecciones, inspección, dorsos y animaciones. Las zonas del tablero permanecen.

Añade música instrumental original en el inicio y la selección de mazo, y nueve sonidos originales para movimientos e interfaz. Los sonidos se sincronizan con las animaciones. El botón Sonido permite regular música y efectos por separado y silenciar todo, con ajustes persistentes. El código de reglas, los mazos y el catálogo no cambian.

Validación acumulada de la versión 0.4: 398 comprobaciones aprobadas y 112 partidas completas simuladas. La revisión gráfica incluye esquinas, cartas sin rótulos, arrastres y animaciones. Se comprobó la señal de música y efectos en el mezclador del motor y el guardado de ajustes. Se distribuye el motor oficial para Windows utilizado antes; no se ha ejecutado nativamente la interfaz 0.4 en Windows en este entorno.

El autor indicó que, terminados estos cambios, se continuará con cuentas e ID de jugador. Esa función no se presenta como implementada en 0.4. El alcance técnico inicial está descrito en SIGUIENTE_ETAPA_CUENTAS.md.

La distribución histórica de la versión 0.5 (sustituida por 0.6 según la corrección del autor) reordena la mesa: instrucciones y botones quedan en Acciones, a la izquierda del registro; la Mano dispone de espacio para ocho cartas. Las casillas auxiliares propias tienen igual tamaño y presentan cartas de 88 × 120, como la Mano y los Aliados propios. Cementerio y Quemadas comparten una casilla alternable; siguen siendo zonas lógicas separadas, con las restricciones originales de Quemadas. La vista cambia al Cementerio cuando es necesario descartar. Las casillas del rival conservan su formato compacto.

Se elimina la casilla de Eventos: se juegan sobre el tablero o un objetivo válido, pagando el coste y respetando las ventanas de respuesta. Los contornos de origen, destino válido y destino inválido se dibujan sobre las imágenes. Las búsquedas marcan la selección y el reordenamiento muestra números. Los botones principales tienen fondo claro y letras oscuras.

El único cambio de reglas es el avance automático desde la oportunidad de Recurso a Acciones si no existe un Recurso en Mano al comenzar el turno, después de reagrupar. Funciona para ambos jugadores. El límite de ocho sigue aplicándose al cierre; un robo o efecto puede superarlo temporalmente y el juego conserva el descarte obligatorio antes del rival.

Validación de 0.5: 439 comprobaciones aprobadas y 112 partidas completas simuladas, con revisión de interfaz y audio en Linux. Las 41 comprobaciones de esta entrega cubren distribución, tamaños, ocho cartas visibles, vista de descartes, selección, orden, contornos durante arrastres nativos, Eventos sobre tablero y objetivo, rechazo de objetivos inválidos, descarte final y avance sin Recursos. La ejecución nativa en Windows queda por comprobar.

### Corrección vigente del tablero y cuentas · prototipo 0.6

El Dominio se muestra en una única zona neutral, centrada entre los campos de ambos jugadores. La carta se presenta horizontal para aprovechar el espacio. La propiedad lógica de la carta se conserva para descartarla al Cementerio de su dueño cuando sea reemplazada.

El jugador humano vuelve a tener la columna Pagadas arriba, Mazo al centro y Recursos abajo. Pagadas y Recursos son compactos y el Mazo conserva un dorso de mayor tamaño. Cementerio y Quemadas vuelven a ser casillas independientes, con Cementerio sobre Quemadas; cada una conserva su botón Ver y su destino de animación. Se elimina el selector de la vista compartida de 0.5.

Se mantienen Acciones a la izquierda del registro, ocho cartas visibles en Mano, cartas sin rótulos repetidos, contornos y selección, botones claros, Eventos sobre el tablero u objetivo, arrastres, animaciones, música y salto automático sin Recursos. Las reglas, el catálogo y los mazos no cambian en esta entrega.

Mi cuenta añade las pantallas de creación e ingreso por correo y código, ID completo copiable y cierre de sesión. El cliente está preparado para Supabase Auth. Usa el UUID emitido por el servicio; no genera IDs locales ni identifica al usuario por su nombre visible. La sesión se renueva en memoria y se debe volver a ingresar al abrir otra vez el juego.

El servicio externo no está creado ni configurado y el envío real de correos no se ha probado. El paquete muestra claramente este estado y permite jugar sin sesión. Hay 31 comprobaciones de cuentas aprobadas mediante HTTP local con identidades ficticias, incluyendo el mismo ID desde dos clientes. Esta prueba no equivale a un registro online activado. La configuración pendiente y el alcance están en SIGUIENTE_ETAPA_CUENTAS.md.

La base propuesta tiene plan gratuito, sujeto a condiciones del proveedor. Se necesita configurar SMTP para enviar códigos a los amigos; el envío incorporado de Supabase no admite libremente esos destinatarios. No se ha contratado ningún plan. Colecciones, sobres y partidas online siguen pendientes.

Validación de 0.6: 472 comprobaciones y 112 partidas completas simuladas aprobadas. Interfaz, arrastres, presentación y audio revisados con Godot en Linux; ejecución nativa en Windows y autenticación real pendientes.

### Defensa sin Aliados y Configuración · prototipo 0.7

Si no hay Aliados en la Línea de Defensa, no se pide confirmar bloqueos. Se pasa a la oportunidad de Eventos del defensor; si no existe un Evento soportado, con Coste pagable y objetivo válido cuando corresponda, se resuelve automáticamente el daño. Si existe uno, se conserva la decisión del defensor. El daño sigue contándose por separado para cada atacante y puede terminar la partida al vaciar un Mazo. La automatización no habilita Eventos al atacante por sí sola y no roba ni termina el turno.

Sonido se encuentra dentro de Configuración. En el inicio, Salir ocupa el antiguo acceso de Sonido y Configuración queda en el menú principal. La mesa ofrece Configuración y Salir en la cabecera. Esc vuelve de Sonido a Configuración y luego al juego; no cambia las cartas ni el estado de la partida. Se conservan la distribución central del Dominio y las columnas laterales aprobadas en 0.6.

El autor solicita poder crear una cuenta real en la próxima entrega. La integración de Supabase está disponible pero todavía no instalada/conectada; es el acceso que debe proporcionar el autor para continuar. La primera cuenta puede probarse con el correo del propietario del proyecto y las cuotas del envío incorporado; para los amigos hará falta un remitente SMTP. La configuración y la prueba del servicio real siguen pendientes. No se entregan IDs locales como si fueran cuentas online.

Validación de 0.7: 503 comprobaciones aprobadas y 112 partidas simuladas. Hay 31 comprobaciones nuevas de defensa vacía, Eventos, daño, derrota, animaciones y Configuración. La revisión se ejecutó en Linux; ejecución nativa en Windows y registro real pendientes.

### Tres mazos y conexión de cuentas · prototipo 0.8

La selección dice “Elige tu mazo” y ofrece “Mazo Kajido”, “Mazo Papito” y “Mazo Flaan”, en ese orden. Todos contienen 40 cartas, 18 de ellas Recursos. El computador recibe al azar cualquiera de los tres, incluso el mismo del humano. Revancha conserva la elección humana y vuelve a sortear al rival. Las listas exactas están en `data/mazos_prueba.json`, junto con su referencia de origen; las tres imágenes originales quedan en la documentación.

Se añadieron las habilidades de elDepul, SoyFlaan, Kajido, Oscarksss, Feranando, Sam, Papito, Desaparición de Papito, Transmisión caída, Pastelito de manjar, Serandimini y Guitarramala. Las 21 cartas distintas de los mazos nuevos están cubiertas. Se conservan las 19 habilidades anteriores: 31 códigos soportados en total.

Serandimini permite anular una carta rival después de que se muestra y paga y antes de resolverla; se baraja una Serandimini propia y la carta anulada va al Cementerio sin devolver su Coste. Los Recursos no abren esa respuesta. La interfaz muestra la carta entrante y permite seleccionar la Serandimini o Dejar jugar. La carta anunciada permanece en una zona lógica transitoria para conservar las 80 cartas; no se añade una casilla de Eventos al tablero.

Guitarramala puede jugarse desde Cementerio con el mismo pago manual que desde Mano. Si está arriba, se arrastra a Defensa; si está debajo, Ver y doble clic ofrecen Jugar desde Cementerio. Oscarksss y el Objeto Pastelito se arrastran al Mazo para activar sus habilidades; también pueden activarse desde el detalle cuando están disponibles. La recuperación de elDepul se resuelve entre el daño de dos atacantes, con una elección del dueño.

Interpretaciones registradas para revisión del autor: Kajido elige exactamente dos o se omite; SoyFlaan cuenta Yuri y Celia de ambos campos para Fuerza pero exige pareja propia para Imbloqueable; elDepul se dispara por derrota al bloquear y puede elegirse a sí mismo ya en el Cementerio; Oscarksss se activa en turno propio y no tiene un límite inventado de una vez por turno; Pastelito sigue el criterio de Bigotes de una vez por turno propio; Serandimini usa una copia propia y no añade una cadena de respuestas a esa habilidad. Papito pierde sus mejoras al salir. Desaparición de Papito mantiene la corrección de no terminar el turno.

Cuentas: el autor eligió la organización AAMIX. Se creó el proyecto real AAMIX en São Paulo, plan gratuito, referencia `drpsedaiqyowwikhjugs`. El cliente incluye sólo la URL y la clave publicable. Se verificó el endpoint Auth por HTTPS desde Godot: correo habilitado, registro permitido y confirmación de correo obligatoria. El asesor de seguridad no devolvió alertas. No se crearon tablas personalizadas ni se añadieron políticas públicas.

El registro no está activado todavía. Falta guardar las plantillas Confirm signup y Magic Link con `{{ .Token }}`. Ese ajuste no está expuesto por la herramienta conectada y el acceso al panel web quedó en verificación de Google, con un código rechazado. Los dos correos en español están preparados en `documentacion/correos/`. El paquete conserva Enviar código deshabilitado e informa el motivo; no se simulan cuentas. No se han enviado correos reales ni creado o verificado una cuenta real durante estas pruebas.

La primera prueba podrá usar el correo autorizado del propietario después de configurar esas plantillas. Para admitir amigos con correos externos hace falta SMTP. El ID será el UUID de Auth, el mismo al volver a ingresar con el mismo correo; la sesión continúa en memoria. Colecciones, sobres, partidas entre computadores y guardado de partidas siguen pendientes.

Validación de 0.8: 810 comprobaciones automatizadas aprobadas y 193 partidas completas. Incluye 242 comprobaciones del motor nuevo y 65 de interfaz, además de las 503 anteriores. Se ejecutaron 81 partidas con los mazos nuevos: 54 con pagos automáticos y 27 con pago manual de un jugador; abarcan las nueve combinaciones y espejos. La conexión HTTPS real y la configuración de verificación se comprobaron por separado, sin envío de correo. Interfaz y audio se revisaron en Linux; la ejecución nativa en Windows sigue pendiente.

## 14. Registro de cambios

- 0.1: consolida manual, reglas de torneo y aclaración del cierre tras el robo; incorpora el plan inicial de desarrollo y una propuesta de motor. No incluye código del juego.


- 0.2: incorpora las seis promocionales, los mazos del autor, mínimo de tres cartas al cerrar el turno, restricciones de Eventos después de declarar ataque, daño por atacante, destino de Objetos, interpretación de bonos y corrección de Desaparición de Papito.

- 0.3: incorpora el estado real del prototipo local jugable, Godot 4.7.2, sus validaciones y las interpretaciones provisionales que debe revisar el autor.

- 0.4: fija Bigotes y Azul según el autor; incorpora mesa por zonas, arrastre, pago manual y rival automático del prototipo 0.2.

- 0.5: documenta la interfaz y las animaciones del prototipo 0.3, los recursos gráficos del autor y los botones de funciones futuras; no cambia las reglas.

- 0.6: documenta cartas sin casillas ni rótulos, esquinas suaves, música y efectos del prototipo 0.4; prioriza cuentas con ID permanente como siguiente etapa. No modifica reglas.

- 0.7: documenta el prototipo 0.5, sus zonas y controles reorganizados, indicadores, botones claros y el avance automático sin Recursos en Mano, confirmado por el autor.

- 0.8: documenta el prototipo 0.6: Dominio neutral al centro, columna vertical Pagadas–Mazo–Recursos, descartes separados y primera integración de cuentas por correo/código con UUID del servicio; activación externa pendiente. No modifica reglas.

- 0.9: documenta el prototipo 0.7: defensa sin Aliados sin confirmación, daño automático con respuesta de Eventos preservada, Configuración → Sonido y Salir; acceso a Supabase pendiente para activar cuentas reales.


- 1.0: documenta el prototipo 0.8: tres mazos nuevos, doce habilidades añadidas y conexión al proyecto real de Supabase; activación de correos pendiente de completar el acceso web.
