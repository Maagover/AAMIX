extends RefCounted
## Shared client validation. The service repeats these rules with the owner's inventory.
const MAX_CARDS = 40
const VARIANTS={"H01":"0104","H02":"0130","H03":"0127","H04":"0102","H05":"0103"}
static func canonical(code):return VARIANTS.get(str(code),str(code))
const FREE_COVERS = ["custom_transmision", "custom_restos"]
const CUSTOM_COVERS = ["custom_transmision", "custom_restos", "custom_tsuki_akira", "custom_chanchuus", "custom_viborin", "custom_kajido", "custom_maagover", "custom_girabl", "custom_dominios", "custom_miku", "custom_tsuki_desafio", "custom_imbloqueable", "custom_chanchuus_aliado", "custom_transmision_desafio"]

static func cover_name(key):
	return {"custom_transmision":"Transmisión Caída", "custom_restos":"Restos", "custom_tsuki_akira":"Tsuki y Akira", "custom_chanchuus":"Granjita de Chanchuus", "custom_viborin":"Viborín", "custom_kajido":"Kajido", "custom_maagover":"Maagover", "custom_girabl":"Girabl", "custom_dominios":"Dominios · Desafío", "custom_miku":"Miku · Desafío", "custom_tsuki_desafio":"Tsuki y Akira · Desafío", "custom_imbloqueable":"Imbloqueable · Desafío", "custom_chanchuus_aliado":"Chanchuus · Desafío", "custom_transmision_desafio":"Transmisión Caída · Desafío"}.get(str(key), "Diseño")

static func load_catalog():
	var result = {}
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalogo_edicion_1.json"))
	for card in data.cartas: result[str(card.codigo)] = card
	return result

static func copy_limit(definition):
	if str(definition.get("clase", "")) == "Recurso": return MAX_CARDS
	if "Singular" in definition.get("palabras_clave", []): return 1
	return 3

static func validate(deck, catalog, owned = {}, require_owned = false):
	if not deck is Dictionary or not deck.get("cartas") is Array:
		return invalid("AAMIX_INVALID_DECK_CARDS", "Elige las cartas del mazo.")
	var entries = []
	var seen = {}
	var families={}
	var total = 0
	for entry in deck.cartas:
		if not entry is Dictionary: return invalid("AAMIX_INVALID_DECK_CARDS", "La lista de cartas no es válida.")
		var code = str(entry.get("codigo", ""))
		var quantity = entry.get("cantidad", 0)
		if not (quantity is int or quantity is float) or float(quantity) != floor(float(quantity)) or int(quantity) <= 0:
			return invalid("AAMIX_INVALID_DECK_CARDS", "Cada cantidad debe ser un número entero positivo.")
		if not catalog.has(code): return invalid("AAMIX_INVALID_DECK_CARDS", "El mazo contiene una carta desconocida.")
		if seen.has(code): return invalid("AAMIX_INVALID_DECK_CARDS", "Cada carta debe aparecer una sola vez en la lista.")
		seen[code] = true
		var definition = catalog[code]
		var count = int(quantity)
		var family=canonical(code)
		families[family]=int(families.get(family,0))+count
		if families[family] > copy_limit(definition):
			return invalid("AAMIX_DECK_COPY_LIMIT", "%s permite hasta %d copia%s por mazo." % [str(definition.nombre), copy_limit(definition), "" if copy_limit(definition) == 1 else "s"])
		if require_owned and count > int(owned.get(code, 0)):
			return invalid("AAMIX_DECK_UNOWNED_CARD", "No tienes suficientes copias de %s." % str(definition.nombre))
		total += count
		entries.append({"codigo":code, "cantidad":count})
	if total > MAX_CARDS: return invalid("AAMIX_DECK_TOO_LARGE", "El mazo puede tener hasta 40 cartas, incluidos los Restos.")
	if not seen.has("0100"):
		return invalid("AAMIX_DECK_INITIAL_RESOURCE", "Incluye al menos un Restos como Recurso, también para guardar un borrador.")
	if deck.get("draft", false) != true:
		if total != MAX_CARDS:
			return invalid("AAMIX_DECK_SIZE", "Para jugar, el mazo debe tener 40 cartas, incluidos los Restos. Puedes guardarlo como borrador.")
		if not seen.has("0100"):
			return invalid("AAMIX_DECK_INITIAL_RESOURCE", "Incluye al menos un Restos para usarlo como Recurso Inicial.")
	entries.sort_custom(func(a, b): return str(a.codigo) < str(b.codigo))
	return {"ok":true, "message":"", "code":"", "total":total, "entries":entries}

static func invalid(code, message):
	return {"ok":false, "message":message, "code":code, "total":0, "entries":[]}

