# AAMIX — Reglas vigentes y primer desarrollo

Versión: 1.5  
Fecha: 17 de octubre de 2026  
Estado vigente: prototipo **0.10.0**, con perfiles, presentación renovada, código de regalo, misión diaria y sobres persistentes. La sección 17 recoge las decisiones vigentes y prevalece sobre los estados históricos anteriores, incluida la sección 16. Backend aplicado; totales y paquete pendientes de cierre QA de esta entrega. Acceso por correo confirmado previamente por el autor.

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

## 10. Orden vigente de desarrollo

Orden aceptado por el autor el 17 de octubre de 2026. Sustituye el orden preliminar de las etapas futuras.

1. **Colección, regalo inicial y mazos guardados.** Vincular todo al UUID de Auth. Implementar el acceso inicial y el modo invitado, la elección única entre los tres mazos base y los apartados Mi Colección y Mis Mazos.
2. **Multijugador con salas privadas por código.** Crear y unirse a una sala, elegir un mazo obtenido y jugar desde computadores distintos. Validar acciones y mantener privadas las manos y el orden del Mazo. Definir el alojamiento y su costo antes de contratarlo.
3. **Sobres y recompensas.** Aperturas de cinco cartas, entrega a la colección, obtención diaria, misiones y códigos. Las probabilidades exactas y otras decisiones indicadas más abajo siguen pendientes.
4. **Constructor de mazos propios.** Usar las cartas obtenidas y validar las restricciones del juego. No forma parte de la primera entrega de colección.
5. **Intercambios.** Ofertas entre cuentas, confirmación de ambas partes y transferencia completa de cantidades, manteniendo coherentes la colección y los mazos.

Las cantidades, regalos, aperturas y transferencias se resolverán en el servicio, asociadas al usuario autenticado. Se registrarán las entregas para que volver a ingresar o repetir una solicitud no duplique recompensas.

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

### Activación de cuentas · prototipo 0.8.1

El autor pudo abrir el panel de Supabase en su navegador habitual. La pantalla mostró que, para este proyecto gratuito, configurar SMTP era un requisito previo para editar las plantillas. Se corrigió el orden de la configuración. El acceso a Google para generar una contraseña de aplicación siguió bloqueado; los códigos disponibles en Authenticator correspondían a otros servicios.

El autor creó una cuenta en Brevo, configuró su remitente y las credenciales SMTP en Supabase, y confirmó haber guardado Confirm sign up y Magic Link con `{{ .Token }}` y los asuntos en español. La captura confirmó que el editor quedó habilitado tras guardar SMTP. La clave SMTP y la contraseña de Brevo no se solicitaron, no se leyeron y no se incorporaron al juego.

La versión 0.8.1 activa `email_templates_ready: true` y `email_delivery: custom_smtp`. Mi cuenta permite Crear cuenta e Ingresar y deja de anunciar que los destinatarios deben ser administradores. Las pantallas piden nombre visible y correo para crear cuenta, y correo para ingresar. El código se introduce únicamente dentro del juego. El ID sólo aparece después de que Supabase verifica el código y entrega una sesión válida; no se inventa una identidad local.

La sesión sigue en memoria, con renovación y cierre. Al volver a abrir el juego se ingresa con el mismo correo y un código nuevo para recuperar el mismo UUID. El registro no crea una colección ni conecta las partidas entre jugadores. Se mantienen los tres mazos y toda la jugabilidad y presentación aprobadas. El motor de reglas, la IA, datos de cartas y mazos, arrastres, animaciones, audio y cliente de autenticación conservan sus bytes de 0.8; los cambios funcionales se limitan a habilitar la configuración del cliente y actualizar el número de versión visible.

Las pruebas automatizadas de cuentas usan un servidor HTTP local sin enviar correos. La comprobación real consulta Auth por HTTPS, sin crear usuarios ni acceder al buzón del autor. **La entrega real del correo y la primera cuenta verificada todavía requieren la prueba del autor desde esta versión.** No se presentan como ya verificadas. La validación de esta activación se documenta por separado de las 810 comprobaciones y 193 partidas históricas de 0.8.

Brevo ofrece una configuración de remitente temporal para las pruebas sin dominio propio; su documentación recomienda un dominio autenticado para una entrega fiable a largo plazo. La habilitación y los límites de Brevo siguen aplicándose. Si el correo no llega, se revisan Spam, los registros transaccionales de Brevo y los errores de Auth de Supabase, sin compartir códigos ni credenciales.

### Decisiones confirmadas de acceso, colección y sobres · próxima etapa

Estas decisiones corresponden a la próxima implementación. La versión descargable 0.8.1 todavía no incluye modo invitado separado, regalo inicial, colección persistente, mazos personales ni sobres.

#### Estado de la autenticación

Después de la entrega 0.8.1, el autor encontró el mensaje genérico de solicitud fallida. Los registros de Auth mostraron un error SMTP 535 5.7.8 Authentication failed en /otp. Se indicó corregir el Login SMTP y la clave SMTP de Brevo guardados en Supabase. El autor confirmó después: “Funciona, perfecto”. Esta confirmación actualiza el estado de acceso del proyecto; no equivale a afirmar que se hizo una nueva prueba automatizada de correo ni que ya se haya comprobado el UUID desde otro computador.

#### Acceso al abrir el juego

- La primera pantalla será de inicio de sesión, con acceso a Crear cuenta y una opción **Jugar como invitado**.
- El invitado tendrá acceso a **Partida individual** y **Configuración**, además de la navegación necesaria para volver al acceso y salir del juego.
- En Partida individual como invitado se elige uno de los tres mazos base, como en las pruebas actuales.
- El invitado no tendrá colección personal, mazos obtenidos ni acceso al multijugador.
- Después de iniciar sesión se accede al inicio normal, con Mis Cartas y el acceso a Multijugador cuando esté implementado, además de las opciones vigentes de partida individual, cuenta y configuración.
- Cerrar sesión vuelve a la pantalla de acceso.
- Se conserva la política vigente de sesión en memoria: al abrir otra vez el juego hay que ingresar de nuevo. Guardar la colección no significa guardar códigos o credenciales en el computador.

#### Mazos base y regalo único

- **Mazo Kajido, Mazo Flaan y Mazo Papito** se consideran los tres **Mazos base**.
- Al registrarse y verificar el correo, el jugador que aún no tenga regalo podrá revisar y elegir uno.
- El regalo se entrega **una sola vez por ID**, no por instalación ni por inicio de sesión.
- Se incorporan a la colección las **40 cartas del mazo elegido**, conservando las cantidades de su lista, y se registra ese mazo como obtenido y utilizable en partidas.
- La colección sigue contabilizando esas cartas aunque estén incluidas en un mazo guardado: no son cartas consumidas al guardar un mazo.
- La cuenta actual del autor y otras cuentas anteriores que aún no hayan recibido regalo también podrán escogerlo al entrar a la nueva versión.
- Al comienzo, la cuenta posee únicamente el mazo que eligió como regalo. Los otros dos mazos base no se muestran como obtenidos.
- En el modo invitado, los tres mazos base permanecen disponibles para las partidas individuales sin incorporarse a una colección.
- La elección y la entrega deben completarse juntas para evitar recibir cartas sin mazo o volver a reclamar el mismo regalo después de un fallo.
- La creación de mazos propios queda para una etapa posterior.

#### Mis Cartas

Mis Cartas tendrá dos apartados:

| Apartado | Contenido confirmado |
| --- | --- |
| **Mi Colección** | Cartas ordenadas por su código, desde 0100 en adelante. Cada carta conserva su lugar: un espacio vacío si no se posee; imagen y cantidad en su espacio si se ha obtenido. Los duplicados aumentan la cantidad de la misma carta. |
| **Mis Mazos** | Mazos obtenidos por la cuenta, asociados a su ID. Al principio muestra únicamente el mazo de regalo elegido, con su lista y cantidades, disponible para partidas. |

La presentación debe conservar el estilo, las imágenes y el detalle ampliado del juego. El límite de copias corresponde a construir un mazo; la colección registra las cantidades poseídas. No se incorpora todavía un constructor.

Los códigos alfanuméricos de las promocionales deben conservar su identidad. Su ubicación exacta al final o en otro grupo visual se podrá resolver al implementar la vista, sin renumerar cartas ni alterar los códigos corregidos.

#### Sobre de cinco cartas

La nueva aclaración reemplaza la composición anterior que sumaba seis cartas y la propuesta de una Especial garantizada.

| Posición | Contenido |
| --- | --- |
| **1** | **1 Carta Recurso**, siempre al principio. |
| **2, 3 y 4** | **3 cartas normales**. |
| **5** | **1 carta normal o 1 especial**. Las especiales tienen menor probabilidad de aparecer. |

Total: **5 cartas**. No se garantiza una Especial en cada sobre.

La rareza es independiente de la clase de carta y de características como Singular. Las únicas cartas especiales definidas por el autor son:

| Código | Carta especial |
| --- | --- |
| 0105 | Kajido |
| 0115 | Papito |
| 0103 | SoyFlaan |
| 0119 | Transmisión Caída |
| 0134 | Guitarramala |
| 0128 | HNyko |
| 0125 | Chanchuus |
| 0131 | Escuela de Vuelo |
| 0130 | Serandimini |

Se conservan los nombres del catálogo al identificar las cartas por código; “Transmisión Caída” corresponde a “Transmisión caída”. Escuela de Vuelo mantiene el código corregido 0131.

**Todas las demás cartas son normales**, conforme a la definición del autor. No se deducen rarezas nuevas de colores, tipo de carta, condición promocional ni de la palabra Singular.

#### Decisiones de sobres pendientes

- Porcentaje de Normal frente a Especial en la quinta posición.
- Probabilidades o pesos de aparición de cada carta elegible, incluyendo los específicos de las especiales.
- Si los Recursos, además de aparecer garantizados al principio, también pueden aparecer en las posiciones normales. Clasificar el Recurso como no Especial no resuelve por sí solo su elegibilidad en los otros espacios.
- Si se permiten varias copias de la misma carta dentro de un sobre.
- Cantidades, horarios y condiciones de la entrega diaria, misiones y códigos.

Estos pendientes no bloquean el desarrollo de acceso, invitado, colección y regalo inicial. No se asignaron porcentajes ni se implementó todavía la apertura de sobres.

## 14. Continuidad entre chats y entregas

El 17 de octubre de 2026, el autor pidió un prompt completo para retomar el proyecto en otro chat del mismo proyecto y seguir recibiendo versiones descargables, conservando las decisiones. El archivo **AAMIX_Prompt_de_continuidad.md** reúne el contexto y las instrucciones de trabajo. Esta actualización documental no crea una versión nueva del juego: la entrega jugable sigue siendo **0.8.1**.

### Archivos para retomar ahora

- **AAMIX_Prototipo_Local_Windows_v0.8.1.zip**: paquete jugable completo, con motor de Windows, código y recursos.
- **AAMIX_Base_del_proyecto_v1.3.md**: decisiones y estado consolidados posteriores al ZIP.
- **AAMIX_Prompt_de_continuidad.md**: instrucciones completas para el nuevo chat.

El ZIP de desarrollo reducido no sustituye al paquete completo: no incluye motor, imágenes ni audio. No es necesario volver a enviar las imágenes originales si se dispone del paquete completo.

Los textos históricos de esta base conservan el estado que tenía cada entrega. Para decidir qué está vigente, se aplican las aclaraciones más recientes y el estado confirmado de la última etapa. En particular, el acceso real ya funciona; colección, regalo inicial y modo invitado siguen pendientes. Las preguntas de sobres no se resolvieron durante este traspaso.

### Flujo de continuidad para las próximas entregas

- Leer el último ZIP y la base antes de modificar; continuar el proyecto existente.
- Conservar las reglas, distribución del tablero, assets e interacciones aprobadas salvo cambios expresos del autor.
- Mantener separados los hechos implementados, las decisiones confirmadas pendientes y las interpretaciones provisionales.
- Actualizar esta base y el prompt con cada nueva decisión, registrando fecha, estado y qué instrucción anterior reemplaza.
- Incluir la base vigente, el prompt actualizado y un **CONTINUIDAD.md** dentro de la documentación de cada futuro ZIP.
- El resumen de continuidad debe indicar versión, archivos principales, estado real del juego y backend, migraciones, comprobaciones, limitaciones y siguiente tarea, sin secretos.
- Entregar un paquete completo y versionado para Windows, con instrucciones y manifiesto de integridad; comprobar extracción e inicio sin dependencias temporales.
- Describir con precisión las pruebas realizadas en esa entrega, distinguiéndolas de resultados históricos y de pruebas pendientes del autor.
- Mantener el proyecto existente de Supabase; inspeccionar su estado antes de cambios aditivos y no recrear cuentas ni repetir la configuración SMTP ya resuelta.
- No depender de memoria del chat ni de rutas locales anteriores. El objetivo es que cada futuro ZIP completo contenga la documentación necesaria para continuar.

La siguiente implementación sigue siendo acceso inicial/invitado, colección por UUID, regalo único entre los tres Mazos base y Mis Mazos. No se implementó ninguna de esas funciones al preparar este traspaso.

## 15. Registro de cambios

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

- 1.1: documenta la activación de Crear cuenta e Ingresar en el prototipo 0.8.1, con Brevo SMTP y plantillas configuradas por el autor. Conserva la distinción entre pruebas locales, conexión HTTPS real y primera entrega de correo aún por comprobar. No modifica reglas ni mazos.
- 1.2: registra la confirmación del acceso por correo tras corregir SMTP y las decisiones de inicio de sesión, modo invitado, Mazos base, regalo único por ID, Mi Colección, Mis Mazos y sobres de cinco cartas con nueve Especiales identificadas. Mantiene pendientes las probabilidades y otros detalles de los sobres. No modifica el código del juego ni publica una versión nueva.
- 1.3: añade el prompt completo y el flujo de continuidad entre chats, requiere documentación actualizada dentro de futuras entregas y distingue el ZIP jugable 0.8.1 de las decisiones posteriores. No modifica código, cuentas ni reglas y no genera una nueva versión del juego.



## 16. Estado histórico · 0.9.0 · 17-10-2026 · superado por la sección 17

Esta sección sustituye los estados de implementación de 0.8.1. Conserva las reglas, prioridades, aclaraciones confirmadas y las interpretaciones provisionales anteriores.

### Implementado y verificado en código

Acceso inicial separado con Iniciar sesión, Crear cuenta e invitado. Invitado sólo accede a práctica individual, Configuración, volver al acceso y salir. Con cuenta: inicio normal, Mi cuenta y Mis Cartas. Multijugador permanece oculto hasta implementarse. Cerrar sesión vuelve al acceso; no se escriben credenciales al disco.

Colección persistente y entrega del mazo inicial en el Supabase existente. Cada UUID confirmado puede elegir una sola vez Kajido, Papito o Flaan; la transacción guarda las 40 cartas con sus cantidades reales, el mazo y el registro del regalo juntos. Reintentos devuelven la primera elección. Cuentas creadas antes de la migración acceden si nunca recibieron regalo. Guardar un mazo no consume cartas. Al ingresar se juegan los mazos obtenidos; como invitado siguen disponibles los tres de práctica.

Mi Colección mantiene un espacio por código, desde 0100; cartas ausentes vacías y obtenidas con imagen y cantidad. Promociones 01a–01f al final en orden lexicográfico, sin renumerar. Mis Mazos muestra únicamente los obtenidos y permite revisar listas y jugar. La elección del regalo tiene revisión de lista y confirmación. No hay constructor ni sobres.

Backend: migración 20261017185851_aamix_collection_starter_v090 aplicada. RLS por UUID y escritura mediante función privada, sin parámetros de propietario ni cantidades desde el cliente. Ninguna cuenta existente borrada/recreada; Auth/SMTP conservados. Código/guía en backend/ y BACKEND_v0.9.0.md.

### Verificación y límites

Ver VALIDACION_v0.9.0.md y RESULTADOS_v0.9.0.json para los resultados de Windows, SQL real con rollback, pruebas HTTP locales y HTTPS real. No se consumió ningún regalo real ni se enviaron correos en las pruebas. El autor debe comprobar la entrega real y el nuevo ingreso por correo. La carrera entre dos clientes con commit queda sin validar: el conector serializó las consultas; no se cuenta como prueba de concurrencia. La protección única del UUID y la transacción están implementadas.

### Registro vigente de decisiones

| Fecha | Decisión y autoridad | Reemplaza | Estado |
| --- | --- | --- | --- |
| 17-10-2026 | Acceso/invitado, colección, regalo único y mazos guardados: alcance confirmado por el autor en base 1.3 y solicitud de continuación | Estado pendiente del ZIP 0.8.1 | Implementado en 0.9.0 |
| 17-10-2026 | Espacios por código y cantidades sumadas: confirmado por el autor | Aviso de Mis cartas pendiente | Implementado |
| 17-10-2026 | Orden 01a–01f después de los códigos numéricos: decisión de presentación durante implementación, no regla nueva del autor | Ubicación visual sin definir | Implementado; reversible |
| 17-10-2026 | Transacción de regalo y restricciones RLS: implementación técnica del requisito confirmado | Sin tablas personalizadas | Implementado; pruebas de reintentos/aislamiento pasadas; concurrencia real con commit pendiente de validar |
| 17-10-2026 | No se envían correos nuevos en las pruebas de esta entrega | Ninguna confirmación previa del autor | Confirmación anterior del acceso preservada; entrega real del regalo aún por verificar por el autor |
| 17-10-2026 | Música original en acceso, regalo y Mis Cartas: elección de integración visual/sonora, sin cambiar assets | Música sólo en inicio y selección | Implementado |

Siguen pendientes multijugador, sobres, constructor e intercambios. Las decisiones aún abiertas sobre sobres y las interpretaciones provisionales de cartas no cambian. Base 1.4 incorpora la base 1.3 íntegra y esta actualización, por lo que ya no necesita adjuntarse la base 1.3 por separado.

## 17. Estado vigente · 0.10.0 · 17-10-2026

Esta actualización conserva el contenido completo de la base 1.4, salvo su cabecera y la marca de histórico de la sección 16. Las afirmaciones antiguas de sobres pendientes, probabilidades sin decidir o Salir en la mesa están superadas por las decisiones de esta sección. No convierte en definitivas las interpretaciones provisionales de cartas registradas antes.

### Presentación e interacción confirmadas por el autor

- El botón **Salir** existe únicamente en el inicio, tanto para invitado como para cuenta. Cerrar la aplicación pide «¿Seguro que quieres salir?» con Confirmar y Cancelar. El cierre de ventana también utiliza la confirmación.
- Al pasar el turno aparece brevemente **Tu turno** o **Turno rival**, una vez terminado el robo y la transición del turno. No altera el orden de reglas ni revela información oculta.
- La etiqueta **Pasar prioridad** se reemplaza por **Pasar daño**. Cambia el texto de la acción; conserva su comportamiento de combate.
- En la interfaz se habla de **cartas**, por ejemplo «cartas obtenidas», en vez de «códigos obtenidos». Los identificadores de cartas y los códigos de acceso o regalo mantienen su función técnica.
- **Mi cuenta** permite elegir entre los **27 Aliados** del catálogo. Se muestra un retrato circular recortado del personaje sin el texto de la carta; la selección se guarda en el servidor asociada al UUID. No requiere poseer esa carta.
- El regalo inicial incorpora icono animado y efectos de sonido; la recepción tiene su señal sonora. El final muestra **Victoria** o **Derrota**, con botones de revancha e inicio debajo. Se elimina **Ver mesa** después de la partida.
- El regalo, el final y las elecciones de cartas en partida presentan sus elementos centrados. El resto conserva la distribución y alineación aprobadas.
- El inicio muestra cartas flotando continuamente y **Transmisión Caída** en un giro lento completo, alternando el frente y el dorso original.
- Se añaden señales de cambio de turno, victoria, derrota, apertura y revelación de sobre; se conserva la música de menú y los controles de volumen/silencio.

### Código de regalo y Mazo Maagover

El botón **Código de regalo** es independiente del menú principal y se coloca a la derecha. El código de prueba confirmado es **M4Z0M44G0**. Entrega el **Mazo Maagover histórico exacto**, aclaración posterior al nombre abreviado «Mazo Maago» de la solicitud inicial: 40 cartas, incluidos 15 Restos, con las cantidades de `tests/fixtures/mazos_legacy.json`, id interno `maago` y portada 0108.

Cada UUID puede canjearlo una sola vez. El servidor registra conjuntamente el canje, las cantidades y el mazo obtenido. El mazo aparece en Mis Mazos y puede usarse en la selección de partidas de esa cuenta. No reemplaza ni consume el regalo inicial. No amplía los tres mazos de práctica para invitado ni los tres posibles mazos de la IA. No habilita un constructor de mazos.

### Misión diaria

**Misiones** contiene **Juega 1 partida**. Terminar con victoria o derrota completa la misión; después se pulsa **Reclamar sobre** para obtener un sobre. Sólo puede reclamarse una vez por UUID y día. El día se reinicia a las **00:00 de America/Santiago**, considerando automáticamente los cambios de horario de Chile. Se toma la fecha del servidor, nunca una fecha enviada por el cliente.

Al comenzar se solicita un recibo de partida y al terminar se registra su resultado. Los recibos y reclamos son idempotentes: reintentar una partida ya registrada no completa otra misión al día siguiente. **La partida contra IA se ejecuta localmente y su resultado es declarado por el cliente. El servidor no valida un historial de jugadas ni demuestra que se jugó honestamente.** Los recibos controlan identidad y duplicados, no son una implementación de multijugador autoritativo.

Si falla la conexión al registrar un resultado, se conserva una cola sólo en memoria y se puede reintentar mientras el juego continúe abierto. Cerrar el juego o cerrar/cambiar la sesión pierde lo que aún no llegó al servicio. Una partida local no se guarda ni se reanuda.

### Sobres: reglas completas y confirmadas

Cada sobre tiene exactamente cinco cartas en este orden:

| Posición | Contenido y probabilidad |
| --- | --- |
| 1 | Un Recurso garantizado. Actualmente corresponde a Restos 0100. |
| 2, 3 y 4 | Una carta normal uniforme en cada posición, entre las 31 normales no Recurso. Se permiten repeticiones. |
| 5 | 70% una normal uniforme, o 30% una Especial. Se permiten repeticiones con las posiciones anteriores. |

Nunca sale un Recurso en las posiciones 2–5. Todas las 41 cartas del catálogo pueden obtenerse, independientemente de que su efecto ya esté programado. La rareza no se deduce de colores, clase, promoción o Singular.

Dentro de la rama Especial de la posición 5:

| Carta | Probabilidad dentro de las Especiales | Probabilidad total por sobre |
| --- | --- | --- |
| Kajido 0105 | 5% | 1,5% |
| SoyFlaan 0103 | 5% | 1,5% |
| Papito 0115 | 5% | 1,5% |
| Transmisión Caída 0119 | 5% | 1,5% |
| Guitarramala 0134 | 16% | 4,8% |
| HNyko 0128 | 16% | 4,8% |
| Chanchuus 0125 | 16% | 4,8% |
| Escuela de Vuelo 0131 | 16% | 4,8% |
| Serandimini 0130 | 16% | 4,8% |

Los porcentajes de las cuatro primeras cartas son **cada uno dentro del grupo Especial**, según aclaración expresa del autor; no son 5% total por sobre. Los otros cinco tienen reparto uniforme del 80% restante del grupo. Las 31 normales también tienen reparto uniforme.

### Apertura y persistencia

En **Mis sobres**, se abre el envoltorio con el mouse y se deslizan las cartas hacia el costado para revelar las cinco, una tras otra. El servidor consume un sobre, sortea, suma las cantidades y guarda el orden exacto en una sola transacción. La animación no decide ni entrega recompensas.

La apertura pendiente persiste en el servidor y vuelve a aparecer después de cerrar/reabrir e ingresar con el mismo UUID. Al revelar las cinco se confirma esa apertura. Los UUID de peticiones, incluidos los de otro cliente que retome la misma apertura, quedan ligados al mismo resultado; reintentar no consume un segundo sobre ni cambia las cartas. Las operaciones por cuenta se serializan con bloqueo de cartera e índices únicos.

### Backend y continuidad técnica

Se conserva el proyecto Supabase **drpsedaiqyowwikhjugs**, Auth y Brevo SMTP existentes. La migración **20261017194519_aamix_profiles_rewards_v0100** ya se aplicó sobre **20261017185851_aamix_collection_starter_v090**. No reaplicar ninguna de ellas. El historial está en `backend/APPLIED_MIGRATIONS.json`.

Se añadieron perfil/cartera, canjes, recibos de partida, misiones diarias, aperturas y correspondencias de peticiones. Las tablas públicas permiten leer sólo las filas propias con RLS; las escrituras del cliente están revocadas. Los RPC públicos invocan funciones privadas que verifican UUID y correo confirmado. No se incluyen secretos ni service_role. El regalo inicial conserva su exclusión por UUID y sólo admite Kajido, Flaan y Papito; la nueva plantilla Maagover no se puede reclamar como regalo inicial.

Archivos principales añadidos: `avatar_view.gd`, `profile_ui.gd`, `home_cards.gd`, `gift_badge.gd`, `pack_reveal.gd` y `rewards_ui.gd`. Se modifican `main.gd`, `collection.gd` y `sound.gd` para integrar la presentación y recompensas. El motor de reglas, la IA, Auth, los datos de catálogo/listas/reglas/cuentas y los recursos originales se conservan; los efectos sonoros nuevos se agregan junto a los anteriores.

### Validación y límites de esta entrega

Backend confirmado: prueba de recompensas pasada dos veces con 20.000 sobres sorteados en total y transacciones revertidas; regresión de colección 0.9.0 aprobada. La última muestra de 10.000 tuvo 3.029 Especiales y 602 de las cuatro con peso 5%; aparecieron las 31 normales. Antes y después permanecieron 2 usuarios, 1 regalo inicial, 1 mazo y 40 cartas en 12 filas de colección. No se dejaron usuarios ni recompensas de prueba. El regalo real que el autor ya había elegido se conservó.

**Totales de pruebas del juego, revisión visual y verificación final del ZIP: 1050 comprobaciones y 214 partidas simuladas aprobadas nativamente en Windows; extracción, manifiesto y arranque del paquete portátil verificados.** Consultar VALIDACION_v0.10.0.md y los metadatos finales; no trasladar las 848 comprobaciones de 0.9.0 como si fueran el total de 0.10.0.

No se enviaron códigos de correo reales ni se consumieron regalos o recompensas reales durante estas pruebas. No se verificó la carrera de dos clientes reales con transacciones simultáneas: se revisaron los bloqueos y se probaron reintentos y recuperación de peticiones. No afirmar concurrencia real validada. La prueba de correo/reingreso del autor es distinta de las transacciones sintéticas revertidas.

### Pendientes y registro de decisiones

Continúan pendientes multijugador privado por sala, constructor, intercambios, efectos de las diez cartas aún sin implementar y guardado de partidas. Esta etapa incorpora sobres y recompensas antes del multijugador por petición expresa del autor; no implica que éste exista. Mantener como provisionales los casos de reglas previamente registrados y definir alojamiento/costos antes de contratar cualquier servicio.

| Fecha | Decisión y origen | Reemplaza | Estado |
| --- | --- | --- | --- |
| 17-10-2026 | Cambios visuales, avatares y etiquetas: solicitud del autor | Presentación 0.9.0, Salir en otras pantallas y Pasar prioridad | Integrados; cierre QA de entrega pendiente |
| 17-10-2026 | Código M4Z0M44G0 = histórico Mazo Maagover exacto, confirmado por el autor | Nombre abreviado inicial Mazo Maago | Backend aplicado; interfaz integrada |
| 17-10-2026 | Misión diaria con victoria o derrota, un sobre, reinicio Chile 00:00: aclaraciones del autor | Frecuencia y horario pendientes | Backend aplicado; interfaz integrada |
| 17-10-2026 | Recursos sólo posición 1; normales uniformes y repetibles; posición 5 70/30; pesos Especiales 4×5% y 5×16% dentro del grupo | Probabilidades y repetición antes sin decidir | Backend aplicado y muestreado; apertura integrada |
| 17-10-2026 | Apertura persistente y transaccional por UUID: solución técnica al requisito de sobres reales | Sobres no implementados | Backend aplicado y verificado con rollback |

