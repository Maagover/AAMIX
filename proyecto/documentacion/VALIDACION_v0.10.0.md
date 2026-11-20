# Validación de AAMIX 0.10.0

17 de octubre de 2026, Chile. Ejecuciones nuevas con el motor incluido de Windows de 64 bits, Godot 4.7.2 `ed1daf0bf`, OpenGL Compatibility/NVIDIA RTX 2060.

## Resultados actuales

**1050 comprobaciones de scripts, cero fallos funcionales; 214 partidas completas simuladas.** Las repeticiones no se suman como casos nuevos. Desglose en RESULTADOS_v0.10.0.json y registros en validacion_v0.10.0/.

| Suite | Comprobaciones |
| --- | ---: |
| Reglas, IA, perfiles y presentación sin interfaz | 590 |
| Regresiones gráficas: mesa, arrastres, pagos, audio, elecciones | 276 |
| Autenticación con HTTP local | 31 |
| Acceso y colección con HTTP local | 38 |
| Flujo completo de recompensas con HTTP local | 51 |
| Mazo Maagover en motor actual | 64 |

Las partidas incluyen 193 regresiones anteriores ejecutadas de nuevo y 21 con el Mazo Maagover usando el motor y la IA actuales, en ambos asientos contra los tres mazos base y espejo. El mazo regalado usa la lista histórica exacta: 40 cartas y 15 Recursos; invitado e IA conservan los tres originales.

Pruebas nuevas: Salir sólo en Inicio y confirmación al salir/cerrar ventana; turnos una vez tras robo/descarte y animación; Pasar daño; Victoria/Derrota sin Ver mesa; cartas flotantes/giro frente-dorso; retratos de 27 Aliados sin textos; UID diferente aislado; código inválido y canje repetido; respuesta perdida tras canje; misión por victoria/derrota; ID de partida del servidor diferente del UUID de reintento; final registrado aunque se vuelva a Inicio antes de la animación; apertura con mouse y cinco deslizamientos en orden; normales repetidas; respuesta perdida al abrir y al confirmar; Actualizar conserva el sobre ya rasgado y reconcilia la confirmación; reingreso recupera foto, mazo y cartas.

Las capturas de cuentas/recompensas son del **servidor HTTP local con identidades ficticias**, no de la cuenta del autor. Se revisaron las pantallas, márgenes, avatares, regalo, confirmación, victoria/derrota, misión y apertura. Sonidos originales nuevos medidos mediante el mezclador; no se afirma escucha humana de parlantes.

## Servicio real

Migración 20261017194519 aplicada en el proyecto existente. Dos ejecuciones de test_rewards_rollback.sql pasaron, con 20.000 sobres en total y regresión del backend 0.9. Incluye aislamiento, permisos, canje/entrega atómicos, fallos forzados por desbordamiento que revierten toda la entrega, misión diaria con hora chilena, reintentos del recibo de ayer, aperturas/alias de otro cliente y confirmación repetida. Se mantuvieron 2 cuentas, 1 regalo inicial, 1 mazo y 40 cartas ya existentes; no quedaron usuarios de prueba ni recompensas reales de los ensayos.

Última muestra de 10.000: 3.029 Especiales (30,29%); las cuatro de peso5% sumaron 602 (6,02%) del total. Las otras cinco aparecieron 469/481/465/505/507 veces. Las 31 normales aparecieron. Esto es una muestra, no un cambio de los pesos confirmados:70/30 y 5%/16% dentro del grupo Especial.

HTTPS real desde Windows: Auth respondió 200 y los siete nuevos RPC sin sesión respondieron 401. No se enviaron correos reales ni se accedió al buzón. La cuenta y SMTP existentes no se reiniciaron. Los avisos del asesor se detallan en backend/APPLIED_MIGRATIONS.json: sin problemas de RLS pública, privados deny-all e índices nuevos sin uso informativos; la advertencia previa de protección de contraseñas permanece sin cambiar Auth.

## Límites

El motor de partidas sigue siendo local: el servicio registra el resultado que comunica el cliente para la misión. **No valida un historial completo de jugadas ni demuestra que un cliente modificado haya jugado.** Sólo concede la recompensa configurada, una vez por UUID/día chileno. Un resultado pendiente de comunicar se reintenta mientras el juego está abierto; si se cierra antes de confirmarlo no puede reconstruirse desde el servidor.

La exclusión de recompensas usa bloqueos y restricciones únicas. No se validó una carrera con dos conexiones reales simultáneas: el conector serializa las consultas. Los reintentos, aislamiento y alias de un segundo cliente se probaron secuencialmente. La entrega real por correo y reingreso del autor no equivale a los HTTP locales; el autor ya confirmó el acceso anteriormente, sin nueva prueba de correo del agente.

Los datos de cartas/reglas/mazos base, game.gd, ai.gd, account.gd, arrastres y animaciones de mesa conservan sus bytes de 0.9.0. Los efectos de diez cartas catalogadas siguen pendientes; pueden coleccionarse y verse.

## Paquete portátil

El ZIP completo pasó comprobación CRC y se extrajo en una carpeta nueva con espacios en la ruta, sin .godot ni archivos importados. Todos los hashes del manifiesto coincidieron. El motor incluido abrió el acceso y una partida de invitado válida. También pasaron desde esa extracción las 51 comprobaciones del flujo de recompensas; esa repetición no aumenta el total. Los registros están incluidos en validacion_v0.10.0/.

El manifiesto contiene cada archivo salvo el propio manifiesto; el SHA-256 del ZIP final se entrega al lado del archivo. Los originales y las versiones anteriores se conservan.
