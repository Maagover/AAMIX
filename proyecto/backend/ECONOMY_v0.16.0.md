# Restos, tienda y cartas aleatorias — 0.16.0

**Aplicado y verificado: 20261019051553_aamix_economy_and_normal_packs_v0160.**
25 casos SQL aprobados con rollback; evidencia en DEPLOYMENT_v0.16.0.json.

La economía pertenece al UUID confirmado de Supabase Auth. El cliente utiliza su
sesión y la clave publicable existente; nunca envía un propietario, precio, saldo
o cantidad de recompensa para decidir una concesión.

## Inventario

`aamix_inventory()` mantiene los campos anteriores y añade:

| Campo | Contenido |
| --- | --- |
| `restos` | Saldo entero de Restos; no puede ser negativo. |
| `restos_welcome_claimed` | Indica si este UUID ya recibió sus 100 Restos. |
| `normal_packs` | Sobres de una carta normal disponibles. |
| `shop` | 34 entradas `{code, price}`; 4 Singulares a 500 y las otras 30 a 150. |
| `pending_opening.kind` | `tc` o `normal_card`; los demás campos de apertura se conservan. |

`packs` continúa significando exclusivamente sobres TC de cinco cartas. El
catálogo de tienda excluye Recurso y todas las promocionales. Las Singulares son
`0103` SoyFlaan, `0105` Kajido, `0115` Papito y `0119` Transmisión caída. Las otras
cinco Especiales son elegibles a 150 Restos, igual que las cartas normales.

## Operaciones

| RPC | Parámetros | Resultado adicional |
| --- | --- | --- |
| `aamix_claim_restos_welcome` | Ninguno | `restos_awarded`, `restos_reward` (100 o 0). |
| `aamix_purchase_card` | `p_request_id: uuid`, `p_code: text` | `already_purchased`, `purchase_code`, `purchase_price`, `purchase`. |
| `aamix_open_normal_pack` | `p_request_id: uuid` | `opening` con `kind: normal_card` y una sola carta. |

Todas devuelven el inventario completo. `purchase` contiene `purchase_id`,
`request_id`, `code`, `price` y `purchased_at`. Una compra concede una copia.
Reintentar el mismo UUID y carta devuelve el recibo original sin gastar de nuevo;
el mismo UUID con otra carta produce `AAMIX_PURCHASE_REQUEST_MISMATCH`.
`AAMIX_INSUFFICIENT_RESTOS` y `AAMIX_CARD_NOT_FOR_SALE` rechazan la transacción
completa, sin descontar ni conceder una carta parcial.

Los 100 Restos se conceden una vez, al primer uso de la economía en esta versión,
tanto a cuentas nuevas como anteriores. La aplicación confirma los Restos después de leer el inventario y antes de entregar
el sobre inicial, para que la siguiente recarga no cierre el aviso de bienvenida. El registro independiente
`aamix_restos_welcome` impide volver a reclamarlos después de gastar el saldo.

Una única apertura pendiente cubre ambos tipos de sobre. Si se solicita otro
tipo mientras existe una apertura pendiente, se recupera esa apertura, sin
gastar el segundo sobre. El UUID nuevo queda vinculado a ese mismo resultado;
reutilizarlo después de reconocer la animación tampoco abre otro sobre.
`aamix_open_pack` y `aamix_acknowledge_opening` mantienen sus firmas anteriores.

El sobre café sortea uniformemente una de las 25 cartas con
`is_promotional=false`, `card_class<>'Recurso'` y `special_weight=0`. Recursos,
Especiales, Singulares y promocionales nunca entran en ese sorteo. El generador
TC existente conserva sus probabilidades y no se reemplaza.

## Misiones vigentes

| ID | Alcance | `reward_kind` | `reward_amount` |
| --- | --- | --- | --- |
| `play_one` | Diaria | `restos` | 50 |
| `win_one` | Diaria | `normal_pack` | 1 |
| `play_ten` | Única por cuenta | `tc_pack` | 3 |
| `win_ten` | Única por cuenta | `tc_pack` | 5 |

Las dos diarias usan la fecha del servidor en `America/Santiago`, con reinicio a
medianoche de Chile. Una derrota sirve para jugar; ganar exige una victoria
terminada ese día. Las nuevas recompensas diarias usan
`aamix_daily_claims_v016`, sin borrar o convertir los registros y recompensas
anteriores. Los pagos únicos de jugar/ganar diez conservan sus registros previos:
si una cuenta ya cobró la antigua recompensa de cinco sobres de jugar diez,
continúa cobrada y no se reduce ni se repite.

Cada misión y respuesta de reclamación incluye `reward_kind`, `reward_amount`
y el campo compatible `reward_packs` (0 para Restos/carta aleatoria). Los reintentos
conservan la recompensa indicada y devuelven `already_claimed=true`. El endpoint
antiguo `aamix_claim_daily_mission` reclama la misma misión `play_one`, impidiendo
que una versión anterior del cliente genere una recompensa TC adicional.

Los resultados contra IA siguen siendo declarados por el cliente local. Esta
versión no añade multijugador ni validación autoritativa de la partida.

## Preservación y seguridad

La migración añade `aamix_rewards_state.restos`,
`aamix_rewards_state.normal_packs` y `aamix_pack_openings.kind`. Los campos antiguos
de esas tablas no se cambian. Tampoco se modifican colecciones, mazos, regalos,
canjes, cantidades, aperturas históricas, recibos de partidas o reclamaciones
existentes. Al comparar los JSON de las filas anteriores, se excluyen únicamente
esas tres columnas nuevas.

Las nuevas tablas tienen RLS y lectura sólo para su propietario; los clientes no
poseen permisos de escritura. Los endpoints públicos son `SECURITY INVOKER`; los
escritores internos usan `SECURITY DEFINER`, `search_path=''` y la comprobación
existente de cuenta confirmada. Todas las escrituras de recompensas, compras y
aperturas se serializan con el bloqueo existente de la cartera por UUID. Los
generadores y la función interna que elige tipo de sobre no tienen permiso de
ejecución para clientes.

La prueba preparada `test_economy_v0160_rollback.sql` contiene 25 comprobaciones,
10 muestras acotadas del generador normal y dos aperturas sintéticas. Termina en
`ROLLBACK`; no reclama recompensas de cuentas reales. Su existencia no confirma
que haya sido ejecutada: la evidencia de despliegue/verificación debe registrarse
por separado después de aplicar y comprobar la migración revisada.
