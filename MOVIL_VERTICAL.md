# AAMIX: interfaz móvil vertical

20 de noviembre de 2026. Base de reglas y backend: Online v1.3.1 / interna 1.11.1, protocolo 3, ruleset 1.9. Cliente web en etapa de prueba.

La interfaz utiliza los gráficos originales de PC. La diagramación toma como referencia las 33 pantallas de `AAMIX_Online_ReferenciasVerticales.zip`, incluido `Tablero_Celular.png`. Las referencias permanecen fuera del repositorio de distribución.

## Presentación y comportamiento

`proyecto/mobile_ui.gd` organiza inicio, acceso, cuenta, colección, mazos, tienda, misiones, sobres, desafío, salas, amigos, intercambios y tablero en vertical. Se conservan las acciones y servicios de los módulos existentes. El editor utiliza la misma validación, cantidades y guardado de mazos que PC. Las ventanas se ajustan al ancho disponible; las listas extensas tienen desplazamiento vertical.

El tablero coloca las zonas rivales arriba, el Dominio al centro y las zonas propias, Mano y acciones abajo. Tocar carta y destino y mantener pulsado para leer utilizan los controles compartidos. No hay un segundo motor de reglas.

La exportación web emplea una base de 480 × 854 con aspecto expandible. Las cartas y fondos seleccionados se reducen durante la exportación; los archivos originales permanecen intactos. Las cartas se sirven a la misma anchura de 650 px que ya usa el cliente PC al mostrarlas. Los diseños de mazo y atlas que dependen de coordenadas conservan sus dimensiones originales.

## Fuente compartida y publicación

El código, catálogo y recursos pertenecen a `Maagover/AAMIX`. Ambos presets se construyen desde un mismo árbol. El cliente web usa el mismo proyecto Supabase de PC; no se crea otra base de cuentas ni se ejecutan migraciones o reinicios.

El repositorio remoto comenzó como repositorio de distribución sin fuentes. La importación inicial descarga el ZIP oficial v1.11.1, comprueba su SHA-256 y recupera los fuentes completos; después aplica los archivos móviles versionados. Esa importación se ejecutó una sola vez en main y deja todos los fuentes en Git. Las actualizaciones posteriores editan esos fuentes directamente y no vuelven a importar el ZIP antiguo.

La automatización genera artefactos Web y Windows. La promoción del artefacto Windows al instalador estable sigue usando el publicador existente y requiere completar las pruebas de distribución y compatibilidad. Construir ambos artefactos no significa que el instalador estable ya haya publicado una actualización.

## Verificación

- 25 comprobaciones de selección por toques y controles compartidos.
- 151 comprobaciones de regresión del cliente PC.
- 53 comprobaciones de pantallas verticales, límites de ancho, ventanas, navegación, tamaño táctil y acciones reales del tablero.
- 50 comprobaciones de recursos en cada paquete exportado.

Estas pruebas funcionan sin escrituras remotas, nuevas recompensas ni operaciones sobre cuentas reales. El uso de datos locales de prueba para las pantallas autenticadas no equivale a una prueba de acceso por correo o de una transacción real.

Se verifica además la presentación en navegador con viewport de 390 × 844. Eso es una prueba de tamaño de pantalla, no una ejecución en Android o iPhone físico. La prueba PC–celular con dos cuentas reales sigue pendiente.

## Límites vigentes

El anfitrión sigue ejecutando las reglas del multijugador. Mantener la página abierta y en primer plano es necesario para ese rol. El progreso del servidor comparte la cuenta; las preferencias visuales y sonoras son locales a cada dispositivo. El guardado de sesión de Windows mediante DPAPI no se habilita en el navegador.

No se debe promover esta versión como cliente móvil estable hasta comprobar partidas cruzadas, reconexión y suspensión en dispositivos físicos.

## Publicación comprobada

Web pública: https://maagover.github.io/AAMIX/

La primera construcción y el despliegue en GitHub Pages finalizaron correctamente. Se verificó la página publicada a 390 × 844 y el recorrido de invitado hasta el tablero. Los cambios en main generan y publican la web automáticamente; los artefactos Windows de cada construcción quedan en Actions. El instalador estable conserva su proceso de publicación independiente.
