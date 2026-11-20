# Validación · AAMIX 0.8

17 de octubre de 2026. Godot 4.7.2 oficial, Linux, OpenGL Compatibility con renderizado por software.

## Resultado

810 comprobaciones automatizadas aprobadas y 193 partidas completas. No se registraron fallos de reglas ni de interfaz en las ejecuciones finales.

| Grupo | Comprobaciones | Partidas completas |
| --- | ---: | ---: |
| Motor original | 143 | 24 |
| Motor, pagos y bot anteriores | 125 | 88 |
| Arrastres nativos originales | 30 | — |
| Presentación y animaciones | 54 | — |
| Cartas y audio | 46 | — |
| Distribución, selección y Recursos | 43 | — |
| Defensa vacía y Configuración | 31 | — |
| Cuentas mediante contrato HTTP local | 31 | — |
| Mazos y habilidades de 0.8 | 242 | 81 |
| Interfaz nueva de 0.8 | 65 | — |
| **Total** | **810** | **193** |

Las 81 partidas nuevas cubren las nueve combinaciones entre Kajido, Papito y Flaan, incluidos los espejos: 54 con pago automático y 27 con pago manual de un jugador. Se comprueba la conservación de las 80 cartas después de cada acción y que cada partida llegue a un ganador, sin quedar esperando una decisión imposible.

## Casos nuevos verificados

- Tres listas exactas, 40 cartas, 18 Recursos, restricciones de copias y todas las cartas soportadas; seis cartas iniciales y Recurso tomado del mazo.
- Elección humana independiente del asiento y sorteo del rival entre los tres mazos. Portadas y botones visibles sin desbordamiento.
- Kajido: dos recuperaciones exactas, filtro de Coste y bono propio; SoyFlaan: Fuerza continua e Imbloqueable condicional.
- Oscarksss: búsqueda en Mazo y Cementerio; Papito: barajado, descarte del Objeto portado y mejora condicional que termina al salir.
- Feranando y Guitarramala: destinos y propietarios de Objetos y Dominio; Guitarramala desde Cementerio con pago manual de siete Recursos y anulación antes de entrar.
- Sam, Pastelito y Desaparición: filtros de búsqueda y revelado; Desaparición conserva el turno y Pastelito registra su uso.
- Transmisión caída: quema ambos campos y descarta Objetos. Quemadas no vuelve al Mazo.
- elDepul: elección después de ser derrotado bloqueando, antes del daño del siguiente atacante, con conservación de cartas.
- Serandimini: carta pública anunciada, coste ya pagado, anulación o dejar jugar, exclusión de Recursos y conservación de ventanas de Eventos. La anulación no resuelve habilidades ni devuelve Coste.
- Arrastres reales de Guitarramala y sus Recursos, acceso desde el detalle, Pastelito equipado y selección de Serandimini mediante controles nativos.
- Tablero capturado con cartas de los mazos nuevos, sin desbordamiento. Música y efectos conservan las pruebas anteriores de señal, volúmenes y guardado.

## Cuentas y servicio real

El contrato local verifica 14 solicitudes HTTP y no envía correos. Incluye alta, rechazo de códigos, renovación, cierre, dos clientes con el mismo ID, nombres repetidos, identidad distinta, límites y limpieza de campos. Las identidades ficticias sólo existen en ese servidor local de prueba.

Por separado, GET `/auth/v1/settings` desde Godot al proyecto AAMIX real devuelve HTTP 200 mediante HTTPS validado. Correo habilitado, registro permitido y confirmación de correo obligatoria. Esta prueba no envía correos y no equivale a un registro real.

El asesor de seguridad del proyecto no devolvió alertas. No se crearon tablas personalizadas ni se incluyeron claves secretas en el juego. La clave publicable está destinada a clientes.

Falta guardar las plantillas de código en el panel web: el inicio de sesión quedó bloqueado por una verificación de Google rechazada. Por ello, Crear cuenta e Ingresar todavía no pueden enviar un código en la entrega. El paquete lo indica y mantiene deshabilitado el envío. No se ha probado una cuenta real ni una sesión real de dos computadores.

## Límites de esta revisión

La ejecución nativa de la interfaz 0.8 en Windows no se ha realizado aquí. Se distribuye el mismo motor oficial para Windows de la entrega anterior; sus bytes se conservan. No se ha probado salida de audio física en el equipo del autor. Partidas online, colección y sobres todavía no están implementados.

El entorno gráfico de prueba avisa que su controlador no permite cambiar V-Sync; no modifica las reglas. La ejecución final de las pruebas nuevas cerró sin pérdidas de recursos de audio.

Los resultados estructurados están en `RESULTADOS_v0.8.json`. El paquete incluye los scripts de prueba y sus fixtures anteriores separados de las listas actuales.
