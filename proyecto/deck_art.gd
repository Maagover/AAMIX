extends RefCounted
## Unified v1.2 box designs generated from the original supplied illustrations.
## Original source images stay untouched; all ten boxes share one registered frame.
const FILES = {"kajido":"mazo_kajido.png","papito":"mazo_papito.png","flaan":"mazo_flaan.png","maago":"mazo_maago.png","girabl":"mazo_girabl.png"}
## Generated PNGs contain near-transparent specks outside the visible box. A common
## frame avoids independent alpha trimming changing each cover's apparent scale.
const FRAME = Rect2(236, 115, 800, 1060)
const CHALLENGE_FRAME = Rect2(210, 60, 880, 1160)
const REGISTRATION = "common_1254_frame236_115_800_1060"
## Saved deck UUIDs do not identify covers. Unlock eligibility belongs to the service.
const CUSTOM_FILES = {
	"custom_transmision": "estetica_v120/mazo_transmision.png",
	"custom_restos": "estetica_v120/mazo_restos.png",
	"custom_tsuki_akira": "estetica_v120/mazo_tsuki_akira.png",
	"custom_chanchuus": "estetica_v120/mazo_chanchuus.png",
	"custom_viborin": "estetica_v120/mazo_viborin.png",
	"custom_kajido": "estetica_v120/mazo_kajido.png",
	"custom_maagover": "estetica_v120/mazo_maago.png",
	"custom_girabl": "estetica_v120/mazo_girabl.png",
	"custom_dominios": "desafio_v110/dominios.png",
	"custom_miku": "desafio_v110/miku.png",
	"custom_tsuki_desafio": "desafio_v110/tsuki_akira.png",
	"custom_imbloqueable": "desafio_v110/imbloqueable.png",
	"custom_chanchuus_aliado": "desafio_v110/chanchuus.png",
	"custom_transmision_desafio": "desafio_v110/transmision.png"
}

static func normalized_id(deck):
	if deck is Dictionary and bool(deck.get("custom", false)):
		var cover = str(deck.get("portada", "custom_transmision"))
		return cover if CUSTOM_FILES.has(cover) else "custom_transmision"
	var value = str(deck.get("id", "")) if deck is Dictionary else str(deck)
	if value in ["maagover", "usuario_maagover"]: return "maago"
	if value == "usuario_girabl": return "girabl"
	return {"dominios": "custom_dominios", "miku": "custom_miku", "tsuki_akira": "custom_tsuki_desafio", "imbloqueable": "custom_imbloqueable", "chanchuus": "custom_chanchuus_aliado", "transmision": "custom_transmision_desafio"}.get(value,value)

static func texture(board, deck):
	var key = normalized_id(deck)
	var path = "halloween_2026/mazo_halloween.png" if key=="halloween" else (CUSTOM_FILES[key] if CUSTOM_FILES.has(key) else ("estetica_v120/" + FILES[key] if FILES.has(key) else ""))
	if path.is_empty(): return null
	var source = board.asset_texture(path)
	if source == null: return null
	var image = AtlasTexture.new()
	image.atlas = source
	var challenge_cover=key in ["custom_dominios", "custom_miku", "custom_tsuki_desafio", "custom_imbloqueable", "custom_chanchuus_aliado", "custom_transmision_desafio"]
	var frame=CHALLENGE_FRAME if challenge_cover else FRAME
	image.region = Rect2(frame.position * Vector2(source.get_width()/1254.0,source.get_height()/1254.0),frame.size * Vector2(source.get_width()/1254.0,source.get_height()/1254.0)) if key=="halloween" or challenge_cover else FRAME
	image.filter_clip = true
	image.set_meta("deck_cover_registration", REGISTRATION)
	return image

static func view(board, deck, width, height):
	var image = TextureRect.new()
	image.texture = texture(board, deck)
	image.custom_minimum_size = Vector2(width, height)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.set_meta("deck_cover", normalized_id(deck))
	return image
