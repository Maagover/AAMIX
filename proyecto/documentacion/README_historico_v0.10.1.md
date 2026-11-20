# AAMIX · Mesa 0.10.1

Versión portátil completa para Windows de 64 bits. Incluye el motor oficial Godot 4.7.2, código fuente, 41 cartas, mazos, imágenes, dorsos, logos, música, sonidos, pruebas y documentación.

## Jugar

1. Extrae **todo el ZIP en una carpeta nueva**.
2. Abre **Jugar_AAMIX.bat**. No necesitas instalar Godot.
3. Ingresa con tu correo y código, crea tu cuenta o pulsa **Jugar como invitado**.

Internet es necesario para cuentas, colección, perfiles y recompensas. El invitado puede practicar sin cuenta con Kajido, Papito o Flaan. Las cuentas juegan con sus mazos obtenidos. No mezcles archivos entre versiones.

## Corrección 0.10.1

**Las cartas promocionales nunca salen en sobres.** Se excluyen `01a`, `01b`, `01c`, `01d`, `01e` y `01f` de las cinco posiciones. La corrección está aplicada en el servidor y también protege las nuevas aperturas de clientes anteriores.

Las promociones siguen en catálogo, colección, retratos de Aliados y mazos válidos. El código **M4Z0M44G0** conserva el **Mazo Maagover histórico exacto**, incluidas sus copias de `01c`. Esta exclusión no cambia los regalos de mazos.

La reparación histórica autorizada ya se realizó: **Dragón Tee K.O (01e), posición 2 → El conflicto de Maagover (0116)**. El total se conservó en **85 cartas**, junto con la promoción legítima 01c de Maagover. La operación dejó una auditoría y no se repite al reintentar.

Cada sobre trae un Recurso primero, tres normales y una quinta carta normal 70% o Especial 30%. Participan **35 cartas no promocionales: 1 Recurso, 25 normales y 9 Especiales**. Nunca hay más Recursos fuera de la primera posición y las normales son uniformes y pueden repetirse. Dentro del grupo Especial, Kajido, SoyFlaan, Papito y Transmisión Caída tienen 5% cada uno (1,5% total por sobre cada uno); las otras cinco Especiales, 16% cada una (4,8% total).

La exclusión de promociones tiene prioridad antes de cualquier sorteo y en todas las posiciones, incluso si cambia una rareza. El detalle completo está en la **base 1.6, sección 18**.

## Funciones conservadas

- **Salir** sólo en el inicio; pide confirmación antes de cerrar. Avisos de cambio de turno y acción **Pasar daño**.
- **Mi cuenta**: elige uno de 27 retratos de Aliados, asociado a tu ID.
- Inicio con cartas flotando y Transmisión Caída giratoria. Regalo y final de partida con animación/sonidos; Victoria o Derrota con Revancha e Inicio debajo.
- **Código de regalo**: **M4Z0M44G0** entrega una vez por UUID el **Mazo Maagover**, sus 40 cartas exactas y 15 Restos. Se añade a Mis Mazos y no consume el regalo inicial.
- **Misiones**: termina una partida, ganes o pierdas, y reclama un sobre por día. Reinicio a las **00:00 de Chile, America/Santiago**, según el servidor.
- **Mis sobres**: abre el envoltorio con el mouse y desliza las cartas hacia el lado para verlas una a una. Si cierras durante la apertura, reingresa para retomar las mismas cartas sin gastar otro sobre.

## Cuenta y conexión

Usa el mismo correo y un código nuevo al reabrir para recuperar tu UUID, perfil, cartas y recompensas. Los códigos se introducen en el juego. La sesión y los tokens sólo viven en memoria; no se guardan en disco. El regalo inicial ya obtenido se conserva y las recompensas del servidor no se duplican por reintentar.

Si falla la conexión al registrar el final de una partida, **mantén abierto el juego y reintenta en Misiones**. Ese aviso pendiente sólo vive en memoria y se pierde si cierras o cambias de sesión. La partida no se guarda. El resultado de la IA local lo notifica el juego; el servidor controla identidad y duplicados, pero no valida las jugadas de esa partida.

## Verificación y continuidad

Backend aplicado y verificado: migración **20261017221142_aamix_packs_exclude_promotional_v0101** en el servicio existente. Consulta `proyecto/backend/APPLIED_MIGRATIONS.json`; no vuelvas a aplicarla. No se rediseña la interfaz ni se modifican las reglas. La concurrencia real entre dos clientes simultáneos continúa pendiente de verificar.

**Verificación 0.10.1: 155 comprobaciones y 21 partidas simuladas aprobadas en Windows, cero fallos.** En el servicio real pasaron 10.000 sobres de regresión y 1.000 adicionales con reclasificaciones sintéticas, todo con rollback, además de la prueba reversible de reparación. Consulta `proyecto/documentacion/VALIDACION_v0.10.1.md`. La **verificación portátil se registra en INFORME_ENTREGA**. Las cifras de 0.10.0 se conservan como historia y no se suman a esta entrega.

Lee `proyecto/documentacion/CONTINUIDAD.md`, `BASE_DEL_PROYECTO_v1.6.md` y `PROMPT_CONTINUIDAD.md`. No repitas las migraciones ya aplicadas. Las reglas, IA, Auth, listas de mazos y recursos originales se conservan. Siguen pendientes multijugador, constructor, intercambios, diez efectos y guardado de partidas. El catálogo conserva 41 cartas, pero sólo 35 participan en sobres; coleccionar una carta no significa que su efecto esté programado.

`SHA256SUMS.txt` contiene el manifiesto de integridad del paquete cuando se cierre la entrega. Las licencias del motor están en `motor/`.
