# Multijugador entre amigos — 0.17.0

Dos jugadores con cuentas confirmadas eligen un mazo propio; uno crea una sala y
comparte su código de ocho caracteres, y el otro se une con ese código. Se emplea
el proyecto Supabase existente a través de HTTPS. No hace falta abrir puertos,
contratar otro servidor ni mantener un proceso adicional. La cuota gratuita del
proyecto sigue siendo un límite de servicio: este modo puede quedar temporalmente
sin disponibilidad si se agota o si el proyecto está pausado.

El ordenador anfitrión ejecuta el motor de reglas de Godot. El servidor valida las
cuentas, pertenencia a la sala, propietario del mazo, turno, revisión, tamaño,
orden de acciones y entrega única de resultados. **Es una beta para jugar con
personas de confianza:** el anfitrión conserva el estado completo y puede
inspeccionarlo o alterarlo si modifica el programa. No hay una simulación
competitiva de reglas ejecutada en un servidor independiente.

## Datos y recuperación

Las tres tablas están en `aamix_private`, con RLS y sin permisos de lectura ni
escritura directa para clientes. Las funciones públicas son invocadoras y sólo
dan acceso a las operaciones privadas que comprueban el UUID confirmado. No se
incluyen claves administrativas en el juego.

El anfitrión recibe la instantánea completa y una única acción pendiente. El
invitado recibe su vista filtrada: sus cartas y elecciones legales, zonas
públicas, cantidades ocultas y datos visibles del rival. Se eliminan las cartas
reales de ambos mazos y de la mano rival, las colas internas, el registro y el
estado del generador aleatorio. La base de datos rechaza identificadores reales
ocultos presentes por error en esa vista. El mazo completo elegido por cada
jugador se entrega sólo al anfitrión.

Cada UUID puede pertenecer a una sola sala activa. Hay un máximo de ocho salas
simultáneas. Una sala caduca a las dos horas; una espera sin actividad caduca a los
30 minutos. La desconexión durante una partida permite volver durante 180
segundos. Después, el rival conectado puede recibir la victoria al consultar la
sala. Si ambos desaparecen y la limpieza encuentra sus latidos vencidos, la sala
se cancela sin fabricar una partida completada. Las salas terminadas se conservan
siete días para recuperar el resultado y luego se eliminan al crear o unir otra
sala; sus registros de misión permanecen.

Las instantáneas completas tienen un máximo de 128 KiB y las del invitado 64 KiB.
Una consulta con la revisión actual omite la instantánea. La cola contiene a lo
sumo una acción por revisión. Los resultados terminados generan exactamente un
registro de victoria o derrota por participante, sin recompensas automáticas ni
un segundo envío de resultado mediante la cola de partidas individuales.

## Contrato RPC

Todos los nombres empiezan por `aamix_mp_`; parámetros con el prefijo `p_`.

| RPC | Parámetros |
| --- | --- |
| `create_room` | `request_id uuid`, `deck_id text` |
| `join_room` | `code text`, `deck_id text`, `request_id uuid` |
| `active` | ninguno |
| `poll` | `room_id uuid`, `since_revision integer = -1` |
| `submit` | `room_id uuid`, `request_id uuid`, `expected_revision integer`, `method text`, `args jsonb` |
| `commit` | `room_id uuid`, `request_id uuid`, `expected_revision integer`, `host_state jsonb`, `guest_view jsonb`, `actor_slot integer`, `winner integer = -1`, `error text = ''` |
| `leave` | `room_id uuid` |

La respuesta incluye `room_id`, `code`, `slot` (anfitrión 0, invitado 1),
`status`, `revision`, `actor_slot`, `winner`, `players`, `expires_at`,
`opponent_online`, `last_error` y `finish_reason`. `state` aparece cuando cambia
la revisión, o siempre si se solicita `-1`. `active` sin sala devuelve
`{"room_id":null}`. Los estados son `waiting`, `ready`, `playing`, `finished` y
`cancelled`. Al unirse el invitado, la revisión sigue en cero. El primer commit
inicia la partida y pasa a uno.

Sólo el anfitrión recibe `host_deck`, `guest_deck`, `players[i].deck` y
`commands`. Una acción tiene `request_id`, `slot`, `revision`, `method` y `args`.
Los argumentos son una matriz JSON de números, booleanos u otras matrices de
números, de hasta 4 KiB. Los métodos permitidos son las acciones públicas del
motor: mulligan, conservar mano, jugar carta, recursos, habilidades, elecciones,
atacar, bloquear, pasar daño y terminar turno. No se admiten nombres arbitrarios
de métodos ni cambios directos de estado por el invitado.

El anfitrión también envía sus acciones por `submit`. Cada commit posterior al
inicio consume el UUID pendiente y aumenta la revisión una sola vez. Reintentar
un UUID con datos distintos falla. Una acción que el motor no permite se reconoce
con `AAMIX_INVALID_ACTION`, manteniendo ambas instantáneas y el actor intactos;
se aumenta la revisión para desbloquear la siguiente acción. El error es genérico
para no revelar información privada. Abandonar durante la partida concede la
victoria al otro jugador; abandonar antes de empezar sólo cancela la sala.

## Comprobación

`test_multiplayer_v0170_rollback.sql` contiene 25 casos SQL acotados con usuarios
sintéticos y rollback completo. Los scripts `qa_multiplayer_clients_create_v017.sql`
y `qa_multiplayer_clients_cleanup_v017.sql` son herramientas administrativas para
una prueba de dos procesos nativos: crean exactamente dos cuentas sintéticas sin
enviar correo y permiten borrarlas mediante una etiqueta aleatoria exacta.
Sus contraseñas temporales no forman parte de la entrega.
