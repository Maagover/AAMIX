# AAMIX · versión 0.17.0

Juego portátil para Windows de 64 bits. **Extrae todo el ZIP en una carpeta nueva y abre Jugar_AAMIX.bat.** Incluye Godot 4.7.2 oficial; no requiere instalación. Haz clic en la intro para entrar. La foto y el nombre abren Mi cuenta. Usa tu cuenta habitual para conservar colección y progreso; el modo invitado permite practicar sin recompensas persistentes.

## Inicio y Tienda

El menú principal queda en este orden: **Partida individual, Multijugador, Mi Colección y Misiones**. Tienda pasa a la esquina superior derecha, junto a Código de regalo y Configuración.

El icono de Restos es ahora la manzana comida `item_0234.png` entregada por el autor, conservada sin modificar sus bytes. El saldo sigue bajo el nombre en Inicio y arriba en Tienda. Cada cuenta recibe 100 Restos una sola vez al incorporarse a esta economía; no se cobran compras con dinero real.

La Tienda muestra primero las cartas de **150 Restos** y al final las cuatro Singulares de **500 Restos**. Dentro de cada precio se ordenan por número de carta ascendente. Siguen siendo 34 cartas disponibles: las cuatro Singulares y otras 30 cartas, incluidas las otras cinco Especiales a 150. No se venden Recursos ni promocionales. Cada compra entrega una copia y pide confirmación. El servidor valida precio, saldo y propiedad; un reintento con el mismo identificador recupera la compra sin repetirla.

## Códigos de regalo nuevos

| Código | Recompensa una vez por cuenta |
| --- | --- |
| AAMIX50 | 50 Restos |
| AAMIX100 | 100 Restos |
| AAMIX1000 | 1000 Restos |
| AAMIXNAVIDAD | 1 sobre TC + 50 Restos + 1 sobre Carta aleatoria |

Los ocho códigos anteriores siguen disponibles y conservan su historial. Los sobres del regalo se guardan en Mis sobres; el popup muestra cada componente con su imagen y cantidad. Se permiten espacios externos y minúsculas al ingresar el código. Cada código se obtiene una sola vez por cuenta, aunque se vuelva a intentar el canje.

## Multijugador entre amigos

1. Ambos jugadores deben usar esta versión, acceder a sus cuentas confirmadas y tener un mazo propio. Si aún no tienes uno, entra al Desafío AAMIX para elegir tu mazo inicial.
2. En Multijugador, uno elige **Crear sala**, selecciona su mazo y comparte el código de ocho caracteres.
3. El otro elige **Unirme con código**, selecciona su mazo e ingresa el código. La partida comienza cuando ambos están en la sala.
4. El creador debe mantener el juego abierto. **Retomar sala** permite recuperar la sala si la conexión se interrumpe.

Se utiliza el servicio HTTPS de Supabase ya existente, sin contratar otro servidor ni abrir puertos. Es una **beta de salas privadas para dos personas de confianza**. El ordenador anfitrión ejecuta las reglas y conserva el estado completo; puede inspeccionarlo o alterarlo si modifica el programa. El invitado recibe su vista filtrada. El servicio controla participantes, revisiones, orden de acciones y resultados únicos; no ejecuta un motor competitivo independiente.

Hay un máximo de ocho salas simultáneas y una sala por cuenta. Cada sala dura como máximo dos horas; la desconexión de una partida admite 180 segundos de recuperación. Tras ese plazo, el rival conectado puede recibir la victoria. Abandonar una partida iniciada cuenta como derrota; cancelar antes del inicio no cuenta como partida completada. Los resultados en línea se registran una vez por participante para las misiones. No hay emparejamiento público, ranking ni draft.

La alternativa aprovecha el proyecto disponible y su [plan gratuito de Supabase](https://supabase.com/pricing). Las cuotas, el ancho de banda y una posible pausa del proyecto limitan el servicio; no se promete capacidad ilimitada ni disponibilidad permanente. Los datos privados se exponen sólo mediante [operaciones autenticadas de la API](https://supabase.com/docs/guides/api/securing-your-api).

## Misiones, sobres y desafío

| Misión | Frecuencia | Recompensa |
| --- | --- | --- |
| Juega 1 partida | Diaria | 50 Restos |
| Gana 1 partida | Diaria | 1 carta aleatoria |
| Juega 10 partidas | Única por cuenta | 3 sobres TC |
| Gana 10 partidas | Única por cuenta | 5 sobres TC |

Las diarias se reinician a las 00:00 de America/Santiago según el servidor. Se conservan los pagos históricos y los logros únicos cobrados no vuelven a pagarse. Reclama los premios desde Misiones.

El sobre café de Carta aleatoria contiene una carta uniforme entre las 25 normales, sin Recursos, Especiales, Singulares ni promocionales. TC conserva cinco cartas: Recurso sólo al inicio, tres normales repetibles y una quinta normal con 70% o Especial con 30%. Dentro del grupo Especial, cada una de las cuatro Singulares tiene 5% y cada una de las otras cinco tiene 16%. Ningún sobre contiene promociones. Una apertura pendiente se recupera sin gastar otro sobre. Sin sobres aparece **No tienes sobres por abrir**.

Las cuentas nuevas reciben un sobre TC al acceder y eligen el mazo inicial al entrar al desafío. Los cinco niveles mantienen sus premios únicos y ocultan los mazos de niveles bloqueados. Se conservan los temas Claro/Oscuro, la música y las imágenes anteriores.

## Verificación y continuidad

Pasaron 12 comprobaciones SQL de códigos y 25 de multijugador con fixtures y rollback. También pasaron 21 casos de instantáneas multijugador, uno de regalos y ocho de interfaz. La prueba de red utilizó dos procesos nativos del juego contra HTTPS real, con dos cuentas sintéticas y sin enviar correos: 12 comandos del motor, avance hasta turno 5, pago del anfitrión sin revelar su carta, reconexión del invitado y abandono con dos recibos únicos. No fue una prueba entre dos computadores remotos ni una partida completa de IA.

La validación de fuente reúne 77 casos aprobados: 37 SQL, 21 de instantáneas multijugador, uno de regalos, ocho de interfaz y diez escenarios nativos HTTPS. El cierre portátil comprende otros seis casos, cuyo resultado consta en el informe final junto al ZIP. No se suman pruebas históricas ni reintentos como casos nuevos.

Las dos cuentas sintéticas se eliminaron con una operación de doble guarda por correo y etiqueta de prueba exactos, ejecutada en la interfaz oficial autenticada de Supabase tras fallar el conector. La lectura posterior confirmó idénticos los hashes de campos originales de 14 tablas antes y después; sólo se excluyó la nueva columna online_room_id de recibos. No se alteraron datos originales de jugadores.

Migraciones aplicadas: **20261019123235** para códigos con Restos y **20261019124033** para salas privadas. No volver a aplicarlas. El contrato de economía 0.16 permanece vigente; los códigos nuevos son una extensión. No se cambiaron Auth ni SMTP. La autoridad de resultados contra IA local sigue en el cliente; las salas en línea confían en su anfitrión.

Fuentes, motor, recursos y documentación incluidos. Base vigente **BASE_DEL_PROYECTO_v1.13.md**, sección 25, junto a CONTINUIDAD.md y PROMPT_CONTINUIDAD.md. El ZIP 0.16.0 se conserva intacto. Constructor, intercambios, diez efectos pendientes y guardado de partidas individuales siguen fuera de esta entrega.
