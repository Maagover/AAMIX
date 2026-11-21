# Revisi�n m�vil: estado y continuidad

Base publicada: c036ad2c858f96fcda77f6535eee6a5fd135579a en Maagover/AAMIX. Trabajo local en mobile-reference-fixes.

## Cambios

- Tablero a escala sobre coordenadas de Tablero_Celular.png (916 � 1717), fondo oscuro, mano superpuesta, defensa/ataque rival invertidos, pilas propias con las im�genes originales de PC y Dominio central. Las cantidades y cartas de la captura son una partida local de prueba.
- Entrada web: �Pulsa para jugar�. En celular se oculta la barra externa de zoom/pantalla completa para conservar el encuadre.
- Canvas dimensionado por el motor, tolerancia de 24 unidades al desplazamiento t�ctil y sin transformaciones de entrada/hover sobre controles m�viles.
- Mano en un contenedor libre: PanelContainer ya no superpone las �reas activas de todas las cartas.
- La pesta�a Evento muestra su interfaz y explica cuando no hay evento activo.
- Acceso compartido por correo y contrase�a: ingreso, registro, validaci�n, recuperaci�n mediante correo, lectura del enlace de recuperaci�n y renovaci�n/cierre de sesi�n. Contrase�as ocultas, no almacenadas ni registradas.

## Verificaci�n

410 comprobaciones locales: 21 de Auth, 25 de controles compartidos, 151 de regresi�n PC, 60 de interacciones m�viles, 53 de pantallas y 50 de recursos por plataforma. Todas pasaron.

El pipeline ejecuta Auth con servidor HTTP local, interacciones GUI (incluye InputEventScreenTouch y peque�os desplazamientos), pruebas de pantallas, regresi�n PC y recursos dentro de ambas exportaciones. La captura es del renderizador nativo en vista m�vil: no sustituye una prueba de navegador Android/iPhone real.

Los 15 c�digos permanentes se probaron en una transacci�n del servidor y luego se hizo ROLLBACK, sin recompensas ni cuentas residuales. Lista en CODIGOS_REGALO.md.

## Configuraci�n para publicaci�n

Se instal� ChatGPT Codex Connector con acceso limitado a Maagover/AAMIX y se verific� escritura mediante la API de GitHub. El bloqueo 403 qued� resuelto el 21 de noviembre de 2026.

En Supabase se guard� Site URL https://aamix.cl/ y se a�adi� ese destino a Redirect URLs. El correo de confirmaci�n ahora incluye {{ .ConfirmationURL }} y conserva {{ .Token }} para compatibilidad con clientes PC anteriores. Recovery ya conten�a {{ .ConfirmationURL }}. Se verificaron el proveedor Email habilitado, los registros habilitados y la confirmaci�n de correo obligatoria. No se ha realizado una prueba de entrega y recuperaci�n con un buz�n real.

## Reinicio solicitado

Se complet� el reinicio solicitado despu�s de publicar y comprobar la carga del juego, el formulario por contrase�a y la navegaci�n hasta una partida. Se revocaron las sesiones anteriores antes de eliminar las cuentas. Los jugadores deben volver a registrarse. Las versiones PC y web comparten el mismo servicio de cuentas.

## Despliegue verificado

C�digo publicado: ab4b64ac30ffc3fe183e6d93b0216adc3daacd77. GitHub Actions 44862597273 termin� correctamente, con las 410 comprobaciones y ambas exportaciones. La web se verific� en https://aamix.cl/ con HTTPS, acceso por correo y contrase�a, navegaci�n como invitado y tablero nuevo. La prueba de entrega de correo y recuperaci�n con un buz�n real sigue pendiente.
