# Multijugador · propuesta para la próxima versión

La versión 0.14.0 incorpora el acceso «Multijugador» con el aviso «En desarrollo». La siguiente entrega puede comenzar con partidas privadas de dos jugadores: crear sala, compartir código, entrar con la cuenta habitual y elegir un mazo obtenido.

## Pasos de implementación

1. **Servidor de partida.** Ejecutar el motor de reglas `game.gd` en un proceso Godot sin interfaz. El servidor valida jugador, turno, fase, pagos, elecciones y cada acción; también baraja y decide el resultado. La interfaz local envía intenciones y presenta las respuestas.
2. **Salas y conexión.** Crear y unirse mediante código, reservar dos plazas, autenticar la cuenta y comprobar el mazo. Propuesta: conexión WebSocket segura (`wss`) a un servicio de partida; Supabase conserva cuentas, pertenencia a salas, historial y recompensas. Un juego de cartas por turnos admite el transporte ordenado de WebSocket; esta elección es una propuesta basada en el flujo actual y las API de Godot.
3. **Vista privada por jugador.** Enviar a cada participante su propia mano, los datos públicos de la mesa y los eventos que puede conocer. El servidor conserva el orden de los mazos y las cartas ocultas. El cliente rival recibe dorsos y cantidades mientras corresponda. Las animaciones usan los eventos filtrados.
4. **Continuidad y resultados.** Numerar acciones y estados, rechazar duplicados, guardar la partida y permitir reconexión. Definir un margen para volver, abandono y tiempo de turno. El servidor guarda una sola finalización y entrega los resultados a las misiones; las credenciales administrativas permanecen en el servicio.
5. **Prueba completa con dos cuentas.** Probar en dos computadores por internet: partidas terminadas, todos los pagos/elecciones, manos ocultas, acciones fuera de turno, duplicados, desconexión/reingreso y recompensas sin duplicación. Después preparar una beta privada y observar errores de conexión y recuperación.

## Primera entrega jugable propuesta

- Pantallas «Crear sala» y «Unirse con código», espera del rival y selección de mazos.
- Partida completa con las reglas implementadas, perfiles, manos privadas, turnos y resultados.
- Reconexión e historial de resultado que conserva la cuenta y las misiones.

Para comenzar ese trabajo falta elegir el alojamiento del servicio de partidas, su dominio y capacidad inicial. La propuesta permite separar el proceso de reglas de los datos de cuenta que ya existen. Esta versión no crea servicios de alojamiento ni hace cambios de infraestructura para multijugador.

## Referencias consultadas

Documentación oficial consultada el 18 de octubre de 2026: [red multijugador de Godot](https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html), [WebSockets en Godot](https://docs.godotengine.org/en/stable/tutorials/networking/websocket.html) y [RLS en Supabase](https://supabase.com/docs/guides/database/postgres/row-level-security). El orden de trabajo y el alcance anterior son recomendaciones para AAMIX, basadas también en su código actual.
