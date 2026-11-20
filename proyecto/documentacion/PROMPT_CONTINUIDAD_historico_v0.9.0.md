# Prompt vigente para continuar AAMIX desde 0.9.0

Actualizado el 17-10-2026. Esta cabecera y los documentos 0.9.0 prevalecen sobre referencias históricas del texto conservado abajo. La base actual está incluida en el ZIP y ya no se necesita una base externa posterior para comprender esta entrega.

Disponible: acceso inicial/invitado, colección real por UUID, regalo atómico y Mis Mazos. Migración aplicada, sin cambios a SMTP/Auth. Cerrar sesión borra datos privados en memoria y vuelve al acceso. Multijugador aún no está disponible. Pruebas nuevas ejecutadas nativamente en Windows; correos de prueba reales enviados por el agente: cero. Carrera entre dos clientes reales con commit y entrega persistente después de un nuevo código de correo: pendientes de validación. No afirmar lo contrario.

CONTINUIDAD.md, BACKEND_v0.9.0.md y VALIDACION_v0.9.0.md describen los archivos, las tablas y los resultados actuales. La prioridad inicial de leer los archivos, preservar reglas/estilo y distinguir implementado/pendiente/provisional sigue vigente. Las cifras históricas se conservan como historia; consultar RESULTADOS_v0.9.0.json para esta ejecución.

Estamos continuando AAMIX, mi juego de cartas físico convertido en un juego virtual para computador. Es un proyecto personal, en español, para jugar con amigos; no quiero comercializarlo. Busco un costo gratuito o muy bajo.
Continúa trabajando sobre el proyecto real adjunto y entrégame versiones completas descargables y jugables para Windows, como se ha hecho hasta ahora. Conserva lo aprobado y registra las decisiones para poder cambiar de chat sin perder contexto.
1. Archivos y prioridad del contexto
La última entrega jugable es AAMIX_Prototipo_Local_Windows_v0.9.0.zip. Incluye motor de Windows, código fuente, imágenes, dorsos, logos, música, sonidos, datos, pruebas y documentación. Su carpeta principal es AAMIX_Prototipo_Local_v0.9.0/.
La base vigente de este traspaso es BASE_DEL_PROYECTO_v1.4.md. Está incluida en la documentación del ZIP 0.9.0 y recoge el estado implementado y las decisiones vigentes. Lee también README, VERSION.json, datos y documentos de implementación antes de modificar.
Prioridad:
1. Mis aclaraciones más recientes y decisiones posteriores a este prompt.
2. La base documental vigente y su registro de decisiones.
3. Reglas de torneo, manual y textos de cartas, con las aclaraciones del autor.
4. Documentación histórica de versiones anteriores.
Distingue siempre implementado, confirmado pendiente de implementar e interpretación provisional. Un plan escrito no demuestra que el código ya lo implemente. Los documentos históricos contienen estados superados: por ejemplo, el acceso por correo ya funciona aunque documentos antiguos digan que falta activarlo.
No reconstruyas el juego desde cero. Si tienes el ZIP completo, no vuelvas a pedirme imágenes originales que contiene. Si falta un archivo indispensable, intenta localizarlo entre los archivos del proyecto y explica cuál falta. No supongas que leíste adjuntos inaccesibles.
2. Tecnología y estado real
- Motor Godot 4.7.2, juego 2D, distribución Windows de 64 bits.
- Actualmente se entrega una distribución portátil con motor oficial y proyecto fuente. Jugar_AAMIX.bat ejecuta motor/AAMIX.exe con --path proyecto --rendering-method gl_compatibility. No requiere instalar Godot.
- Hay partidas individuales contra una IA local; no se pasa el computador entre jugadores. La IA usa su información privada y el estado público.
- Catálogo: 41 cartas de la primera edición, incluidas 6 promocionales. Hay 31 códigos con efectos soportados; las 21 cartas distintas de los tres mazos base están implementadas. Las otras 10 están catalogadas, pero sus efectos no deben presentarse como terminados.
- Existe una segunda edición física, todavía no incorporada.
- El registro e ingreso reales por correo y código de Supabase funcionan, confirmado por mí.
- Implementado en 0.9.0: acceso inicial/invitado, colección persistente, regalo inicial y mazos obtenidos guardados. Pendiente: sobres, multijugador entre computadores, constructor e intercambios.
- En 0.9.0 se aplicó la migración 20261017185851_aamix_collection_starter_v090: colección, mazos obtenidos, regalos y plantillas privadas. Inspecciona el estado real del servicio antes de preparar nuevas migraciones. No vuelvas a aplicar la migración inicial.
Archivos importantes dentro de proyecto/:
- main.gd: interfaz, pantallas e interacción.
- game.gd: reglas y efectos.
- ai.gd: rival individual.
- account.gd: autenticación real.
- drop_surface.gd, card_image.gd, motion.gd, sound.gd: arrastre, cartas, animación y audio.
- data/catalogo_edicion_1.json, data/mazos_prueba.json, data/reglas_vigentes.json, data/cuentas.json.
- imagenes/, assets/, audio/, tests/, documentacion/.
3. Diseño e interacción aprobados
La estética usa cuero marrón, tonos cobrizos y la paleta AAMIX, con logos y dorso originales.
- Dominio neutral al centro de la mesa, entre jugadores. Puede ser horizontal; no pertenece visualmente al campo de ninguno.
- Columna propia: Pagadas arriba, Mazo al centro, Recursos abajo. Recursos y Pagadas compactos; Mazo más grande.
- Cementerio sobre Quemadas, en dos casillas separadas. No volver a unirlas mediante pestañas.
- Instrucciones y botones en el panel de acciones, a la izquierda del registro compacto. La Mano debe acomodar ocho cartas.
- Cartas con esquinas apenas redondeadas, sin casillas individuales ni nombres o tipos repetidos debajo. Mostrar la imagen de la carta.
- Doble clic abre el detalle ampliado. No reinstalar un panel lateral permanente de detalle.
- Priorizar arrastrar y soltar: bajar Recursos, pagar, jugar Aliados, anexar Objetos, jugar Dominios, lanzar Eventos, atacar, bloquear, descartar y activar habilidades cuando sea práctico.
- Los Eventos se juegan sobre la mesa o el objetivo válido: no tienen una zona propia.
- Conservar indicadores de selección y origen, objetivos válidos e inválidos y botones frecuentes claros con texto oscuro.
- Conservar animaciones de reparto de seis cartas, robo, jugadas, pago, reagrupación, ataque, bloqueo, daño, descarte y barajado. No revelar cartas ocultas del rival mediante animaciones.
- Conservar música de inicio y selección de mazo y sonidos de movimientos.
- Sonido está dentro de Configuración. Salir tiene acceso visible.
No rediseñes la mesa ni cambies reglas como efecto secundario de añadir cuentas o colección.
4. Reglas que deben conservarse
AAMIX está inspirado en Mitos y Leyendas Nueva Era, pero usa sus propias reglas. No completes vacíos importando automáticamente reglas de ese juego.
- Mazo de 40 cartas, máximo 3 copias de cada no Recurso; Singular permite 1. Los Recursos no tienen ese límite.
- El Recurso inicial se toma de esas 40 cartas y entra en Recursos. Después se baraja y se roban 6.
- Hasta dos cambios completos de mano: 6 → 5 → 5.
- Primero se reagrupa: Pagadas → Recursos y Aliados de Ataque → Defensa.
- Justo después se puede bajar un Recurso de la Mano. Si no hay ninguno, avanzar automáticamente a Acciones.
- Se paga moviendo Recursos a Pagadas. Aliados entran en Defensa; Objetos se anexan a un Aliado, máximo uno por portador; Eventos resuelven y van al Cementerio.
- Hay un único Dominio compartido. El nuevo descarta el anterior al Cementerio de su dueño.
- Un Aliado recién jugado no ataca salvo que sea Ágil.
- Declarar ataque impide seguir jugando cartas normales. El defensor puede jugar Eventos durante Defensa antes del daño; el atacante puede responder con Eventos si hubo bloqueo o el defensor jugó un Evento. Conservar las ventanas y alternancia implementadas.
- Cada defensor bloquea a un solo atacante; cada atacante recibe un solo bloqueador.
- Defensor más fuerte: destruye al atacante, sin daño al Mazo. Empate: ambos destruidos. Atacante más fuerte: destruye al defensor y la diferencia daña el Mazo. Sin bloqueo: toda la Fuerza daña el Mazo.
- Resolver daño por atacante por separado. Cada punto envía una carta superior del Mazo al Cementerio. Mazo vacío implica derrota.
- Sin Aliados para defender, no pedir Confirmar bloqueos. Aplicar daño automáticamente si tampoco existe respuesta legal de Evento; preservar la decisión si sí existe.
- Al terminar el turno se roba una carta; si aún hay menos de tres, completar hasta 3. Si hay más de 8, elegir descartes antes de que juegue el rival.
- Ese robo cierra las jugadas propias, permite el descarte obligatorio y no elimina las respuestas o bloqueos posteriores durante Defensa.
- Las cartas buscadas se muestran y deben cumplir el criterio de búsqueda.
- Las Quemadas no se recuperan durante la partida.
- Si un portador sale del juego por cualquier destino, su Objeto va al Cementerio.
Aclaraciones concretas:
- Bigotes: una vez en cada turno de su dueño.
- Azul: +1 en Ataque, +2 mientras bloquea, sin bono en Defensa sin bloquear.
- Muñeco de Miku: +4 total a Maagover o Dicky; sobre base 1 quedan en 5. Los bonos por Tipo incluyen a la propia carta cuando corresponda.
- Escuela de Vuelo conserva código 0131 y limita a cuatro Aliados; cada dueño elige cuáles conservar. Guitarramala es 0134.
- Desaparición de Papito no termina el turno; la frase ya fue eliminada de datos e imagen.
- Las interpretaciones provisionales de Kajido, SoyFlaan, elDepul, Oscarksss, Pastelito y otras están registradas en la base. Consérvalas como provisionales, sin convertirlas en decisiones nuevas confirmadas.
Los tres mazos actuales son Mazo Kajido, Mazo Papito y Mazo Flaan. Cada uno tiene 40 cartas, con 18 Recursos. Usa las listas exactas de los datos; no inventes sustituciones. La selección dice «Elige tu mazo». La IA recibe uno de los tres al azar, incluido el mismo del humano.
5. Cuentas y Supabase: ya funcionan
Reutiliza el proyecto existente:
- Organización y proyecto: AAMIX.
- Referencia: drpsedaiqyowwikhjugs.
- URL: https://drpsedaiqyowwikhjugs.supabase.co.
- Región: São Paulo. Se eligió el plan gratuito; verifica condiciones vigentes antes de cualquier decisión de costo.
Usamos Supabase Auth por correo y código, con confirmación de correo. El ID real es el UUID de Auth. El nombre visible no identifica al dueño de los datos. El cliente incluye URL y clave publicable en data/cuentas.json.
El correo se entrega mediante Brevo SMTP, configurado por mí en Supabase. Confirm sign up y Magic Link incluyen {{ .Token }}. Los códigos se introducen en el juego; la interfaz admite de 6 a 10 dígitos.
El error genérico anterior era SMTP 535, Authentication failed. Corregí las credenciales SMTP y confirmé «Funciona, perfecto». No reinicies esa configuración ni me hagas volver al bloqueo de Google y al dispositivo antiguo. El acceso administrativo al panel y el ingreso de jugadores son procesos distintos.
Las sesiones se mantienen en memoria, con renovación y cierre. Al reabrir se ingresa con el mismo correo y un código nuevo para recuperar el mismo UUID. No guardes contraseñas, códigos ni tokens en disco sin acordar un cambio.
No me pidas enviar secretos por chat. No incluyas claves SMTP, secretas ni service_role en el cliente o ZIP. Para colección, regalos y mazos, valida identidad y permisos en el servicio. Inspecciona el esquema, aplica cambios aditivos y políticas por UUID; no borres cuentas ni recrees el proyecto. Las pruebas HTTP locales no equivalen a probar correos reales.
6. Alcance confirmado, implementado en 0.9.0; conservar
Acceso e invitado
1. Al abrir, mostrar primero Iniciar sesión, con Crear cuenta y Jugar como invitado.
2. El invitado accede únicamente a Partida individual y Configuración, más volver al acceso y salir.
3. Como invitado puede elegir cualquiera de los tres mazos base para practicar.
4. Al ingresar se entra al inicio normal, con Mis Cartas y Multijugador cuando esté disponible, además de las opciones vigentes.
5. Cerrar sesión vuelve al acceso. Conservar la sesión en memoria.
Regalo inicial y mazos
- Kajido, Flaan y Papito son los tres Mazos base.
- Cada jugador elige uno de regalo, una única vez por UUID.
- Añadir las 40 cartas con sus cantidades reales a su colección y guardar ese mazo como obtenido y utilizable.
- Las cuentas ya creadas, incluida la mía, deben poder elegir si nunca recibieron regalo.
- Al comienzo solo se posee el mazo elegido. Los otros dos siguen disponibles para práctica como invitado; no aparecen como obtenidos.
- Guardar un mazo no consume sus cartas de la colección.
- Entrega de cartas, cantidades, mazo y registro del regalo deben confirmarse juntos en el servidor, sin duplicación por reintentos, doble clic, reinstalación o nuevo inicio de sesión.
- No incluir todavía constructor de mazos propios.
Mis Cartas
Crear dos apartados:
- Mi Colección: espacios fijos ordenados por código desde 0100. Los faltantes dejan su espacio vacío; las obtenidas muestran imagen y cantidad en su lugar. Las copias suman cantidad, sin duplicar casillas. Conservar códigos alfanuméricos de las promocionales; no renumerarlas.
- Mis Mazos: mazos obtenidos y guardados del UUID. Inicialmente solo aparece el regalo elegido, con lista y cantidades, disponible para partidas.
El límite de copias se aplica al mazo, no al total de cartas poseídas. La colección puede mostrar todo el catálogo, aunque algunos efectos aún no estén programados.
7. Sobres: confirmado y pendiente
Se implementarán después. Cada sobre contiene 5 cartas, en este orden:
Posición	Contenido
1	Un Recurso garantizado
2, 3 y 4	Tres cartas normales
5	Una normal o una especial


Las Especiales son menos probables. No hay una Especial garantizada.
Las únicas Especiales son:
Código	Carta
0105	Kajido
0115	Papito
0103	SoyFlaan
0119	Transmisión Caída
0134	Guitarramala
0128	HNyko
0125	Chanchuus
0131	Escuela de Vuelo
0130	Serandimini


Todas las demás son normales. No deduzcas rarezas por color, tipo, condición promocional o Singular.
Todavía no he decidido:
- Si los Recursos pueden salir también en posiciones 2–5.
- Si una carta puede repetirse dentro del sobre.
- Probabilidad Normal/Especial de la quinta carta y porcentajes o pesos de cada carta.
- Cantidades, horarios y condiciones de sobres diarios, misiones y códigos.
No inventes estas respuestas. No bloquean la versión de colección y regalo inicial.
8. Orden posterior
1. Acceso/invitado, colección, regalo inicial y mazos guardados.
2. Multijugador privado por código de sala.
3. Sobres y recompensas diarias, misiones y códigos.
4. Constructor de mazos propios.
5. Intercambios con confirmación de ambas partes y transferencia completa y coherente.
El multijugador debe validar jugadas en el servicio y preservar manos y orden del Mazo privados. Recompensas e intercambios deben evitar duplicaciones y transferencias parciales. Falta decidir alojamiento y costos; no contrates servicios de pago por iniciativa propia.
También quedan casos puntuales de reglas: efectos simultáneos, ambos mazos vacíos y algunas búsquedas sin resultados, además de desconexiones. Consulta la base antes de tocar las interacciones afectadas.
9. Cómo trabajar y entregar versiones
- Revisa el estado real y continúa sobre él. Avanza dentro del alcance solicitado; pregunta por decisiones que afecten el trabajo o por bloqueos concretos.
- Haz cambios reales en archivos y, cuando corresponda, en el backend autorizado. No presentes datos locales ficticios como colección remota ni cuentas reales.
- Conserva assets, mazos, reglas, arrastres, audio, animaciones y distribución aprobada salvo cambios que yo pida.
- Prueba lo relevante. Al tocar colección conserva las comprobaciones de regalo único, reintentos, cantidades exactas, aislamiento entre UUID, cuentas anteriores y restricciones de invitado. Queda por validar una carrera real de dos clientes con commit y la persistencia después de un nuevo acceso por correo del autor; no confundirlas con HTTP local o transacciones revertidas.
- Comprueba inicio del juego y regresiones de interfaz y jugabilidad. Distingue pruebas automatizadas, de interfaz, conexión real y comprobaciones hechas por mí.
- Como referencia histórica, 0.8 tuvo 810 comprobaciones y 193 partidas simuladas; 0.8.1 tuvo pruebas específicas de cuentas. No afirmes que se repitieron si no lo hiciste. Las revisiones hasta 0.8.1 fueron en Linux. En 0.9.0 se ejecutaron 848 comprobaciones de scripts y 193 partidas simuladas nativamente en Windows, con registros incluidos. No atribuyas esas pruebas al autor ni a versiones que no las ejecutaron.
- Entrega un ZIP completo y versionado para Windows, con código fuente, motor o ejecutable necesario, assets, lanzador, instrucciones y documentación. No entregues solo fragmentos, un parche o fuentes incompletas como si fueran el juego listo.
- Comprueba extracción e inicio sin depender de carpetas o cachés del entorno de trabajo. Incluye manifiesto de integridad y excluye temporales y credenciales.
- Actualiza coherentemente la versión visible y los metadatos. Conserva versiones anteriores.
- Indica brevemente cambios, pruebas y pendientes. Entrega enlaces a los archivos y describe solo funciones terminadas como disponibles.
10. Continuidad en cada entrega
Mantén una base documental viva y este prompt actualizado. Cada decisión debe registrar:
- Qué se decidió y cuándo.
- Si fue confirmada por mí, propuesta o interpretación provisional.
- Qué decisión o regla anterior reemplaza.
- Si está implementada, pendiente o descartada.
Incluye dentro de documentacion/ de cada nuevo ZIP:
1. La base vigente, con reglas, decisiones y pendientes.
2. CONTINUIDAD.md: versión actual, archivos principales, estado del juego y backend, validaciones, limitaciones y siguiente tarea.
3. El prompt actualizado para iniciar otro chat.
4. Cambios y migraciones o instrucciones de backend necesarias, sin secretos.
El objetivo es continuar con el último ZIP completo, sin depender de memoria de conversaciones ni rutas temporales. El ZIP 0.9.0 ya incluye la base vigente y no depende de adjuntar la base 1.3 por separado.
No marques algo como implementado sin comprobar código y verificaciones. Si una decisión nueva contradice este prompt, actualiza los documentos afectados y señala cuál está vigente.
11. Para comenzar ahora
Revisa el ZIP 0.9.0, CONTINUIDAD.md y la base 1.4 dentro de documentacion/. Confirma brevemente la versión recibida. El alcance de acceso/invitado, colección, regalo y Mis Mazos ya está implementado; conserva esa implementación. La siguiente etapa aprobada es multijugador privado por código de sala. Antes de implementarlo, definir alojamiento y costos sin contratar servicios de pago por iniciativa propia. Consultar las limitaciones de validación del regalo real y concurrencia en VALIDACION_v0.9.0.md.
Las preguntas pendientes de sobres pueden esperar. Si el entorno no permite acceder a un recurso indispensable, identifica el bloqueo y completa mientras tanto lo que puedas preparar y verificar.