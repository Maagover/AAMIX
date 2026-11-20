# AAMIX

**[Jugar en celular o navegador — versión de prueba](https://maagover.github.io/AAMIX/)**

Esta rama incorpora el proyecto fuente compartido y una interfaz web vertical para celulares. Estado, pruebas y pasos pendientes en [MOVIL_VERTICAL.md](MOVIL_VERTICAL.md). La publicación del cliente web y las releases estables del instalador se registran por separado.

Para construir PC y web desde el mismo código: `node scripts/setup-tools.mjs` y `node scripts/build.mjs` (Node 24). Para la vista previa: `node scripts/serve-web.mjs`.

Juego de cartas AAMIX para **Windows 10 y 11 de 64 bits**.

**[Descargar AAMIX · Instalar y actualizar](https://github.com/Maagover/AAMIX/releases/latest/download/AAMIX_Instalador.exe)**

1. Descarga y abre **AAMIX_Instalador.exe**.
2. Pulsa **Instalar** y espera a que termine la descarga.
3. Pulsa **Jugar**.

Se crean accesos en el escritorio y en el menú Inicio. Cuando haya una versión nueva, abre ese mismo acceso y pulsa **Actualizar**. Tu cuenta, tu colección y tus preferencias se conservan.

La instalación se realiza para tu usuario de Windows y no requiere permisos de administrador. Necesitas Internet para descargar el juego y para las funciones de cuenta y multijugador.

También encontrarás el ZIP portátil completo y las notas de cada versión en [Releases](https://github.com/Maagover/AAMIX/releases).

## Publicar una actualización

Consulta [Cómo publicar actualizaciones](COMO_PUBLICAR_ACTUALIZACIONES.md). Las herramientas mantienen una dirección de descarga estable y verifican la integridad de cada paquete antes de activar una versión nueva.

Los códigos de regalo con recompensas ya existentes se configuran en el servidor; no necesitan una nueva descarga del juego.

## Derechos

AAMIX y sus elementos gráficos y sonoros pertenecen a sus respectivos autores. Este repositorio de distribución no concede una licencia abierta sobre el juego ni sus recursos. Se conservan los avisos y licencias de terceros incluidos en el paquete.
