# Cartas completadas en AAMIX 1.3

Se conservan textos, ilustraciones, costes, Fuerza impresa, límites de copias, colección y listas de mazos originales. Las 41 cartas del catálogo están admitidas por el motor. Esta actualización completa exclusivamente las diez que carecían de efecto:

| Carta | Efecto implementado |
| --- | --- |
| Nonungus 0101 | Al entrar permite buscar un Sam en el Mazo propio, mostrarlo, ponerlo en Mano y barajar. Puede omitirse. También baraja si no encuentra Sam. |
| Caída de elDepul 0118 | Necesita un Aliado en el Cementerio rival. Quema el último Aliado que todavía está allí; ignora Eventos y Objetos posteriores y los Aliados que salieron de esa zona. |
| Templo de Ow 0121 | Mientras está activo impide jugar Objetos a ambos jugadores. No retira los ya equipados. |
| Chanchuus 0125 | Conserva Fuerza 3 y Coste 4 frente a efectos de otras cartas. Un Objeto puede equiparse y conservar sus otras habilidades; Muñeco no cambia su Fuerza. |
| Viborín 0126 | Una vez por turno propio elige un Aliado propio y lo envía al Cementerio. Si Viborín permanece en juego obtiene +3 de Fuerza hasta terminar el turno. Puede elegirse a sí mismo, pero entonces no queda en juego para recibir el bono. |
| HNyko 0128 | Imbloqueable. Al ser derrotado en combate envía dos cartas del Mazo rival al Cementerio. También se dispara si Granjita reemplazó su destino por Quemadas. Descartarlo, sacrificarlo o enviarlo por otro efecto no lo activa. |
| Almenta 0129 | Una vez por turno propio elige un Aliado propio y paga un Recurso para otorgarle Imbloqueable hasta terminar ese turno. Permite pago manual, reservas previas y cancelación. No deshace bloqueos que ya se asignaron. |
| Granjita de Chanchuus 01d | Los Aliados derrotados en combate se queman. No reemplaza descartes, sacrificios ni daño del Mazo. Los Objetos equipados siguen yendo al Cementerio. |
| Dragón Tee K.O 01e | Singular. Gana +2 de Fuerza mientras tiene un Objeto equipado, además de los bonos que otorgue ese Objeto. |
| Almas Perdidas 01f | Singular. Gana +1 por cada otro Almas Perdidas en juego entre ambos jugadores. No se cuenta a sí mismo ni cuenta cartas que salieron del campo. |

## Aclaraciones del autor del 20 de octubre de 2026

«Derrotado» se aplica únicamente al combate. «Destruido» incluye combate y efectos de otras cartas. Viborín y Almenta se activan sólo durante el turno de su dueño, una vez por turno propio. Caída de elDepul no puede jugarse sin un Aliado en el Cementerio rival.

Las habilidades nuevas aprovechan las oportunidades de acción que ya ofrece el motor: Acciones, prioridad propia durante el combate y después del combate antes de iniciar el cierre del turno. Se mantienen los usos anteriores de Bigotes, Oscarksss y Pastelito. Cancelar una elección o un pago de Almenta no consume el uso; el efecto se confirma sólo al completar el coste. Los bonos se eliminan al salir del campo y no se arrastran al regresar. Se conserva el cómputo de una activación por carta y turno.

Se conserva el orden de combate existente: atacantes en el orden declarado, daño excesivo antes de procesar la derrota del bloqueador, y fin inmediato al vaciar un Mazo. Esta versión no crea un nuevo sistema de arbitraje ni cambia las reglas históricas de fin de partida.

## Partidas y pruebas

Ambos participantes de una sala nueva deben utilizar reglas 1.3. El transporte sigue en protocolo 3 y el formato de snapshot en 1; la versión de reglas es un dato adicional y el servidor impide mezclar versiones. Las salas anteriores permanecen con sus reglas. Una sala antigua propia puede cerrarse mediante confirmación para crear otra, sin restaurar su motor en 1.3.

25 escenarios deterministas del motor con 160 aserciones aprobadas; 23 comprobaciones de IA, privacidad y compatibilidad;6 de interfaz con 2 capturas revisadas. Se repitieron dos suites pequeñas relacionadas:15 de IA previa y 17 de snapshots. No se suman pruebas de entregas anteriores.

24 grupos SQL se ensayaron con rollback y dos usuarios sintéticos.13 comprobaciones HTTPS posteriores usaron dos clientes en un proceso, dos cuentas sintéticas y un estado inicial controlado con40 cartas por jugador. Después se ejecutaron comandos reales, pagos, búsqueda, publicación de estados, reintentos y abandono. No equivale a una partida completa desde el reparto ni a una prueba de Realtime, latencia o dos PCs remotos. Las cuentas, salas, sesiones y datos sintéticos se eliminaron. Cero correos enviados y cero simulaciones aleatorias masivas.
