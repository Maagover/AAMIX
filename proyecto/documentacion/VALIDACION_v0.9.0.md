# Validación de AAMIX 0.9.0

Fecha: 17 de octubre de 2026, Chile. Ejecución nativa en Windows con el motor oficial incluido: Godot 4.7.2, `ed1daf0bf`, OpenGL Compatibility y NVIDIA RTX 2060.

## Ejecutado en esta entrega

- **848 comprobaciones de scripts aprobadas**, cero fallos funcionales. Incluyen 38 del flujo nuevo, 65 de interfaz/jugabilidad y 31 de autenticación con un servidor HTTP local. Los registros individuales y RESULTADOS_v0.9.0.json desglosan las suites; las repeticiones de una suite no se suman dos veces.
- **193 partidas completas simuladas**: 81 con los tres mazos actuales y 112 de regresión con mazos históricos. Estos números corresponden a ejecuciones nuevas en Windows; los documentos anteriores conservan sus resultados históricos por separado.
- Animación de reparto, privacidad de la mano rival, robo, pagos, ataques, bloqueos, daño, descarte, barajado, cancelación de animaciones, detalles, contornos y arrastres. Música/efectos: archivos y señal del mezclador; no se afirma una escucha humana de los parlantes.
- Capturas revisadas de acceso, práctica, regalo, colección con espacios vacíos, detalle, Mis Mazos, inicio invitado, Configuración, Sonido y mesa. Las capturas de regalo/colección usan **datos ficticios del servidor local de pruebas**, no la cuenta del autor.
- Acceso inicial, menú restringido de invitado, tres mazos de práctica, cuenta con sólo el mazo obtenido, revisión de listas, confirmación del regalo, rechazo del segundo clic mientras hay solicitud, respuesta incierta y reintento, reingreso de prueba y aislamiento de un segundo UUID.
- Base **real de Supabase**: transacción de prueba con tres identidades temporales y rollback completo. Verificados los tres mazos y todas sus cantidades exactas tanto en colección como en mazo, 18 Recursos por regalo, veinte reintentos, un regalo y mazo por UUID, aislamiento RLS, rechazo de escrituras directas, ausencia de UUID, correo sin confirmar y mazo inexistente. No quedaron cuentas de prueba ni regalos de prueba confirmados. Los dos usuarios existentes no se borraron ni recrearon.
- HTTPS real desde Godot/Windows: `/auth/v1/settings` respondió 200 con correo habilitado y confirmación obligatoria. Los dos RPC de colección sin sesión respondieron 401; la clave publicable sola no concede regalos ni datos.
- Comparación de bytes: motor, reglas, IA, cliente Auth, catálogo, listas de mazos, JSON de reglas y cuentas, cartas, dorsos, logos, música, sonidos, arrastre y animaciones conservados. `sound.gd` sólo amplía la música a las nuevas pantallas de menú.

## Límites explícitos

El acceso por correo ya estaba confirmado por el autor antes de esta entrega. No se enviaron correos reales ni se solicitó su código. La prueba de **elegir un regalo real, cerrar el juego e ingresar con otro código** queda para el autor; la verificación automatizada del reingreso usa HTTP local y la transacción real se revierte para no consumir el regalo.

La protección de concurrencia está implementada mediante la clave primaria del UUID y `INSERT ... ON CONFLICT`, dentro de la misma transacción que entrega cartas y mazo. **No se validó una carrera real entre dos clientes con commit**. Los intentos paralelos a través del conector fueron serializados; una comprobación temporal detectó que no se solaparon. No se cuentan como prueba aprobada de concurrencia. Se suministra la prueba de reintentos y se conserva esta comprobación pendiente para dos sesiones reales.

Asesor de seguridad: sin errores de tablas públicas sin RLS ni funciones públicas con privilegios elevados. Hay dos avisos informativos por las tablas privadas deliberadamente sin políticas de acceso y un aviso de protección contra contraseñas filtradas desactivada. El juego usa código por correo, sin contraseñas; no se alteró Auth ni SMTP. El asesor de rendimiento informa tres índices nuevos aún sin uso; cubren referencias y no se retiraron por falta de tráfico.

La comprobación de extracción, manifiesto y arranque desde el ZIP se registra además en el informe de entrega situado junto al ZIP.

## Reproducir

Con Python y el motor incluido, desde la carpeta principal:

```powershell
python proyecto/herramientas/validar_windows.py motor/AAMIX.exe
python proyecto/herramientas/probar_cuentas.py motor/AAMIX.exe --gui
python proyecto/herramientas/probar_coleccion.py motor/AAMIX.exe --gui
motor/AAMIX.exe --headless --path proyecto --script res://tests/test_v08.gd
motor/AAMIX.exe --path proyecto --rendering-method gl_compatibility --script res://tests/test_ui_v08.gd
```

Las pruebas locales no requieren correo real. `backend/test_collection_rollback.sql` requiere acceso administrativo y se revierte íntegramente. No ejecutar la migración otra vez en el proyecto ya configurado.


## Paquete portátil verificado

Se creó el ZIP completo, se comprobó su CRC y se extrajo en una carpeta nueva con espacios en el nombre, sin .godot, archivos importados ni cachés de desarrollo. El manifiesto SHA-256 de todos los archivos coincidió. Desde esa extracción, el motor incluido abrió el acceso y una partida de invitado con 80 cartas válidas, imágenes y audio cargados. También pasaron nuevamente las 38 comprobaciones de acceso y colección con el servidor HTTP local; esa repetición no aumenta el total de casos. Se incluyen los registros en validacion_v0.9.0/. La invocación usa el mismo motor, --path y compatibilidad gráfica del lanzador, añadiendo sólo el guion de prueba para cerrar automáticamente.
