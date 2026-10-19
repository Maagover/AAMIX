# Publicar actualizaciones de AAMIX

El jugador descarga **AAMIX_Instalador.exe** una vez. Lo abre para instalar, actualizar y jugar. El instalador consulta la última versión publicada; no hace falta enviar un instalador distinto con cada cambio del juego.

## El enlace para compartir

```text
https://github.com/Maagover/AAMIX/releases/latest/download/AAMIX_Instalador.exe
```

`Maagover/AAMIX` es el repositorio de distribución de AAMIX. Este enlace se mantiene mientras se conserve el repositorio y cada nueva versión incluya el archivo con ese nombre. [GitHub documenta estos enlaces permanentes a archivos de la última release.](https://docs.github.com/en/repositories/releasing-projects-on-github/linking-to-releases)

Los jugadores no necesitan una cuenta de GitHub. El repositorio de distribución debe ser público. Es posible conservar por separado el repositorio de desarrollo y usar éste sólo para las descargas y las instrucciones.

## Qué cambios necesitan una versión nueva

| Cambio | Acción |
|---|---|
| Código que regala Restos, cartas o sobres ya existentes | Añadirlo en Supabase. Queda disponible al canjearlo; no exige una descarga nueva. |
| Expansión, cartas o imágenes nuevas | Preparar el contenido del juego y los cambios del servidor; generar un nuevo ZIP y publicarlo. |
| Reglas, pantallas, sonidos, correcciones o conexión | Generar una versión nueva del juego y publicarla. |

Añadir una fila a `proyecto/data/codigos_regalo.json` sólo mantiene la referencia local: no activa un código. Los premios se entregan desde `aamix_private.gift_code_rewards` en Supabase. Los cambios de estructura o reglas del servidor deben ser compatibles con la versión anterior durante la transición, o acompañarse de una versión mínima obligatoria.

## Preparar una versión

1. Elige un número que no hayas usado: `1.0.1` para una corrección pequeña, `1.1.0` para una actualización de contenido, por ejemplo. El instalador usa tres números para compararlos; en pantalla puedes mostrar `1.1`.
2. Genera el juego completo en un ZIP, con una sola carpeta raíz. Por ejemplo, `AAMIX_Windows_v1.1.zip` debe contener `AAMIX_v1.1/AAMIX.exe` y el resto del juego. Prueba ese paquete antes de publicarlo.
3. Prepara `NOTAS_DE_VERSION.md` con los cambios que verá el jugador. Conserva una copia del instalador estable como `AAMIX_Instalador.exe`.
4. Abre PowerShell en la carpeta de las herramientas. Sólo la persona que publica necesita [GitHub CLI](https://cli.github.com/) y su sesión iniciada con `gh auth login`. No escribas contraseñas ni tokens en los archivos del juego.

Ejemplo para preparar los archivos sin subirlos:

```powershell
.\Publish-AAMIX.ps1 `
  -Repository 'Maagover/AAMIX' `
  -Version '1.1.0' `
  -DisplayVersion '1.1' `
  -GameZip 'C:\AAMIX\AAMIX_Windows_v1.1.zip' `
  -ArchiveRoot 'AAMIX_v1.1' `
  -Installer 'C:\AAMIX\AAMIX_Instalador.exe' `
  -NotesFile 'C:\AAMIX\NOTAS_DE_VERSION.md' `
  -PrepareOnly
```

El script valida los nombres y rutas del ZIP, comprueba que exista `AAMIX.exe`, calcula SHA-256 y genera `aamix-update.json` y `SHA256SUMS.txt` en `prepared/v1.1.0/`. El ZIP original se conserva. Antes de publicar, comprueba que el paquete contiene solamente material distribuible: nunca respaldos de cuentas, credenciales, sesiones ni archivos privados.

## Subir y activar la actualización

Repite el mismo comando **quitando `-PrepareOnly`**. El script crea un borrador y sube:

- El ZIP completo del juego.
- `AAMIX_Instalador.exe`, para mantener el enlace de descarga.
- `aamix-update.json`, para que el instalador conozca la versión, el enlace y el hash del juego.
- `SHA256SUMS.txt`, como comprobación adicional.

Sólo después de verificar los cuatro archivos con los hashes informados por GitHub, publica el borrador como **Latest**. Hasta ese momento los jugadores siguen recibiendo la versión anterior. GitHub recomienda cargar los archivos en un borrador antes de publicarlo. [Documentación oficial de releases](https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository).

Si `gh.exe` no está en PATH, añade `-GhPath 'C:\ruta\a\gh.exe'` al comando. Si se corta Internet, el borrador queda guardado; revísalo en GitHub antes de continuar. El script se detiene si esa versión ya existe y no reemplaza sus archivos. Corrige el borrador antes de activarlo; para corregir una versión ya publicada, crea una versión posterior.

Después de publicar, abre el mismo instalador que descargaste inicialmente y pulsa **Actualizar**. Comprueba que muestra la nueva versión y que permite jugar. El proceso de actualización conserva la cuenta y las preferencias guardadas fuera de la carpeta del programa.

## La versión inicial

Se utiliza sin modificar `AAMIX_Windows_v1.0.zip` como versión `1.0.0`:

```text
Carpeta raíz: AAMIX_v1.0
Entrada: AAMIX.exe
Tamaño: 364937782 bytes
SHA256: 9e93dcc7aee64ed75cb04be06e994edea995f1b4a7d91054dd3f4b70e18da9e5
```

El manifiesto conserva `minimum_launcher: 1`. No cambies este valor ni el protocolo del manifiesto sin preparar antes un instalador compatible: una actualización normal del juego no necesita modificarlo.

## Alojamiento y derechos

GitHub Releases admite archivos menores de 2 GiB y no establece un límite total de almacenamiento ni de ancho de banda para una release. Este ZIP ocupa aproximadamente 365 MB. [Límites oficiales de GitHub Releases](https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases).

Publicar una descarga no cede los derechos sobre AAMIX, su nombre, logotipo, ilustraciones ni música. Conserva los avisos de autor y las licencias de los componentes de terceros que ya incluye el juego. Esta herramienta no añade una licencia abierta al contenido de AAMIX.
