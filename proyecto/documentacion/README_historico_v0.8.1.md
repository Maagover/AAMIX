# AAMIX · Mesa 0.8.1

Partida individual contra el computador, con los tres mazos del autor e interacción por arrastre. Conserva el tablero de cuero y cobre, el Dominio neutral al centro, Pagadas–Mazo–Recursos de arriba hacia abajo y Cementerio sobre Quemadas en casillas separadas.

## Abrir en Windows

1. Extrae todo el ZIP en una carpeta nueva.
2. Abre `Jugar_AAMIX.bat` dentro de esa carpeta.
3. Pulsa **Partida individual** y elige **Mazo Kajido**, **Mazo Papito** o **Mazo Flaan**.
4. Revisa tus seis cartas iniciales. **Cómo jugar** explica los movimientos.

El motor oficial Godot 4.7.2 para Windows de 64 bits está incluido. No necesitas instalar Godot ni crear una cuenta para jugar contra el computador. Las cuentas necesitan internet. No mezcles archivos de versiones anteriores.

## Novedades

- Selección **Elige tu mazo**, con las tres opciones solicitadas. Cada mazo tiene 40 cartas y 18 Recursos. El rival recibe al azar cualquiera de los tres, incluido el mismo que tú. Revancha conserva tu elección y vuelve a sortear al rival.
- Las 21 cartas distintas de esos mazos tienen sus habilidades programadas. Se añaden 12 habilidades al motor y se conservan las 19 anteriores para regresiones: 31 códigos soportados en total.
- Serandimini ofrece una ventana al jugar el rival una carta que no sea Recurso. La carta se muestra y paga antes de resolver; puedes barajar tu Serandimini para anularla. No se devuelve el coste de una carta anulada.
- Guitarramala se puede jugar desde Cementerio pagando Coste 7. Arrastra su carta superior a Defensa, o usa **Ver → doble clic en Guitarramala → Jugar desde Cementerio** si hay otras cartas encima.
- Oscarksss y Pastelito de manjar activan sus búsquedas al arrastrarlos al Mazo. También aparece **Usar habilidad** en su detalle cuando corresponde. Pastelito se arrastra desde su miniatura equipada.
- **Crear cuenta e Ingresar ya están habilitados** en Mi cuenta. Usan el proyecto real AAMIX de Supabase y los correos con código configurados por el autor mediante Brevo. El primer registro y la entrega del correo deben comprobarse desde el juego; las cuentas sólo se aceptan cuando el servicio valida el código.

## Reglas y presentación conservadas

- Mazo de 40; hasta tres copias no Recurso, salvo Singulares de una copia. Recurso inicial tomado de esas 40. Mano inicial 6; cambios 5 y 5.
- Reagrupación al comenzar. Sólo un Recurso al inicio; si no hay Recursos en Mano, pasa automáticamente a Acciones.
- Paga moviendo Recursos a Pagadas. Puedes elegir primero la carta o preparar el pago. El pago sobrante sin gastar puede devolverse; el coste gastado espera a la reagrupación.
- Aliados a Defensa; Objetos a sus portadores; Dominio al centro compartido; Eventos sobre mesa u objetivo, sin casilla propia.
- Atacantes de Defensa a Ataque y botón **Declarar ataque**. Defensores sobre atacantes. Sin defensores se omite confirmar bloqueos; el daño pasa automáticamente si no existe Evento jugable del defensor.
- Después de declarar ataque sólo se juegan Eventos en las oportunidades permitidas. El daño se calcula por atacante. elDepul puede detener la resolución entre dos atacantes mientras se elige su recuperación.
- Robo al terminar, mínimo tres y descarte obligatorio hasta ocho antes del rival. No se puede seguir jugando tras ese robo. Quemadas no se recupera.
- Bigotes: una vez por turno propio. Azul: +1 en Ataque, +2 al bloquear, sin bono en Defensa sin bloquear.
- Cartas con esquinas suaves, sin rótulos repetidos. Doble clic para leer. Registro compacto e indicadores de selección y destinos de arrastre.
- Música original en inicio y selección; sonidos para movimientos. **Configuración → Sonido** guarda los volúmenes; **Salir** cierra el juego.

## Interpretaciones de las nuevas cartas

Se aplica literalmente el texto y se documentan estos criterios para revisión del autor:

- El “Fernando” de la lista Kajido corresponde a **Feranando (0110)**. Su imagen conserva ese nombre.
- Kajido recupera exactamente dos Aliados válidos o se omite la habilidad. Se cuenta a sí mismo en su bono de Tipo.
- SoyFlaan cuenta Yuri y Celia de ambos campos para su Fuerza (“en juego”); para Imbloqueable exige tener ambos del lado propio (“si tienes”).
- elDepul dispara al ser derrotado en combate mientras bloquea; no al ser descartado, barajado o quemado por un efecto. Ya está en el Cementerio y puede elegirse a sí mismo.
- Oscarksss se activa durante el turno propio con tres copias en juego. Busca Papito en Mazo o Cementerio y baraja el Mazo. Su texto no limita repeticiones, pero debe existir Papito en una de esas zonas.
- Pastelito de manjar usa una activación por turno del dueño, siguiendo el criterio de Bigotes. El uso se registra en el Objeto.
- Serandimini baraja una copia propia como coste. Es una habilidad, sin una cadena adicional de cartas para responder a esa habilidad en este prototipo.
- Papito sólo conserva +2, Ágil e Imbloqueable mientras permanezca en juego después de barajar al menos tres Oscarksss al entrar. Al salir pierde esas mejoras.
- Desaparición de Papito conserva la corrección del autor: busca un Aliado Singular y no termina el turno. No añade un barajado que su texto no indica.

## Crear tu cuenta real

1. Con internet, abre **Mi cuenta → Crear cuenta**.
2. Escribe tu nombre visible (entre 2 y 24 caracteres) y un correo al que tengas acceso.
3. Pulsa **Enviar código** y revisa la bandeja de entrada y Spam.
4. Introduce el código del correo de AAMIX en **Código recibido** y pulsa **Verificar e ingresar**.
5. Al verificarse, verás tu **ID de jugador** completo y podrás copiarlo.
6. Para comprobar que se conserva, pulsa **Cerrar sesión → Ingresar**, usa el mismo correo y verifica un código nuevo. El ID debe ser idéntico. Esto también debe funcionar en otro computador.

El código lo envía AAMIX por correo. No se usa Google Authenticator ni se pide iniciar sesión en Google dentro del juego. El nombre visible puede repetirse: la identidad corresponde al UUID emitido por Supabase.

La sesión vive en memoria. Al cerrar y volver a abrir el juego hay que ingresar otra vez; se recupera el mismo ID usando el mismo correo. El juego no guarda correos, códigos ni tokens en archivos locales. Las preferencias de sonido sí se guardan.

### Estado de la conexión

El autor confirmó que configuró Brevo como SMTP y guardó las plantillas Confirm sign up y Magic Link con `{{ .Token }}`. La configuración distribuida habilita el registro y ya no limita los destinatarios al equipo administrador. La clave SMTP queda en Supabase: no forma parte del juego.

La conexión real por HTTPS se verifica sin enviar correos. Las pruebas automatizadas de registro, renovación e ingreso usan exclusivamente un servidor local de pruebas. **El envío y la primera verificación de un correo real quedan pendientes de la prueba del autor desde esta versión**; no se presentan como completados.

Brevo dispone de su propia activación y límites de envío. Para las pruebas sin dominio propio puede sustituir el remitente por una dirección temporal suya, tal como se explicó durante la configuración. Que la configuración esté guardada no garantiza que todos los destinatarios reciban el correo.

Si no llega el código, revisa Spam, espera al menos un minuto y usa **Reenviar código**. Comprueba que el correo esté bien escrito. El detalle de diagnóstico para el administrador está en `proyecto/documentacion/CUENTAS_ESTADO_v0.8.1.md`. No compartas códigos, claves SMTP ni tokens en capturas.

Esta entrega aún no incluye partidas entre computadores, colección personal, sobres ni guardado de partidas.

## Código y validación

`proyecto/` contiene el código fuente, catálogo e imágenes. `motor/` contiene el ejecutable oficial para Windows y su licencia. Las reglas corren en `game.gd`; la presentación, arrastres, audio y cliente de cuentas están separados.

Las comprobaciones realizadas para esta activación y su alcance se guardan en `proyecto/documentacion/VALIDACION_v0.8.1.md`. Las pruebas de interfaz y audio se ejecutan en Linux; esta interfaz no se ha ejecutado nativamente en Windows en este entorno. El ejecutable de Windows es el mismo motor oficial de la entrega anterior.
