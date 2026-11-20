# Alertas de Windows y ejecutables de AAMIX

El aviso comunicado por el autor es SmartScreen: «Windows protegió su PC» o «editor desconocido». SmartScreen comprueba firma y reputación de los archivos descargados; ese aviso no equivale a una detección de malware de Microsoft Defender.

## Comprobaciones de esta entrega

Se analizaron por separado con Microsoft Defender los cuatro ejecutables distribuidos: instalador, iniciador, motor Godot y auxiliar de sesión DPAPI. La salida de cada análisis indicó que no encontró amenazas, con código 0. El análisis se hizo sin aplicar cuarentena ni cambiar las protecciones del equipo. Esto describe esa comprobación local, no una garantía para todos los antivirus o equipos.

El motor Godot incluido conserva su firma Authenticode válida. El instalador, el iniciador con la A blanca y el auxiliar DPAPI no tienen firma digital propia. No se encontró un certificado de firma de código disponible para el usuario actual.

Esta versión no cambia los bytes de esos ejecutables: sólo actualiza el proyecto, las imágenes y la documentación. Se conserva el instalador estable y el iniciador de 1.1. El número del juego es 1.2.0 y aparece en su interfaz y proyecto; la versión de archivo del iniciador estable sigue 1.1.0.0. También se mantiene intacta la firma del motor oficial.

## Límite real y siguiente paso

SmartScreen puede seguir mostrando el aviso de editor desconocido. No se ha comprado ni instalado un certificado, ni configurado un servicio de firma, ni publicado en Microsoft Store. Una firma reconocida permite identificar al editor y construir reputación, pero ni siquiera una firma OV/EV garantiza la ausencia inmediata de avisos en una descarga nueva. La distribución mediante Microsoft Store es la vía recomendada por Microsoft para evitar el aviso de descarga SmartScreen.

No se pide desactivar SmartScreen, Defender ni las otras protecciones. Si en el futuro aparece una detección con nombre de amenaza, debe investigarse ese archivo y esa detección concreta; una disputa por falso positivo se tramita ante el fabricante del antivirus.

Fuentes oficiales consultadas el 20 de octubre de 2026:

- [Reputación SmartScreen y opciones de firma](https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/smartscreen-reputation).
- [Preguntas de desarrolladores sobre detecciones de Defender](https://learn.microsoft.com/en-us/defender-xdr/developer-faq).
- [Análisis personalizados con Microsoft Defender](https://learn.microsoft.com/en-us/defender-endpoint/command-line-arguments-microsoft-defender-antivirus).
