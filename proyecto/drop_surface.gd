extends PanelContainer

var board
var zone = ""
var card_owner = -1
var uid = -1
var display_uid = -1
var clicked = Callable()
var tap_started = -1
var long_press_opened = false

func _ready():
	if board != null and (uid != -1 or display_uid != -1 or clicked.is_valid()): board.hover_feedback(self,1.045)

func descriptor():
	return {"zone": zone, "owner": card_owner, "target": uid, "card":get_meta("card_surface", false)}

func _get_drag_data(_at_position):
	tap_started = -1
	if board != null: board.clear_tap_selection()
	if board == null: return null
	var data = board.drag_payload(uid, zone, card_owner)
	if data == null: return null
	set_drag_preview(board.drag_preview(uid, zone))
	board.highlight_destinations(data)
	return data

func _can_drop_data(_at_position, data):
	return board != null and board.can_drop(data, board.effective_destination(self))

func _drop_data(_at_position, data):
	board.apply_drop(data, board.effective_destination(self))

func _gui_input(event):
	if board != null and board.mobile_layout and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			tap_started = Time.get_ticks_msec()
			long_press_opened = false
		else:
			var should_tap = tap_started >= 0 and not long_press_opened
			tap_started = -1
			if should_tap:
				if board.tap_surface(self): accept_event()
				elif clicked.is_valid(): clicked.call()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if (board.presenting or board.fx.busy) and not event.double_click and zone!="inspection": return
		if event.double_click:
			var card_uid = display_uid if display_uid != -1 else uid
			if card_uid != -1:
				board.open_card_detail(card_uid)
				accept_event()
				return
		if board.tutorial.active and board.screen=="table" and board.tutorial.click_surface(self):
			accept_event();return
		if zone=="defense" and uid!=-1 and board.cancel_block_on_click(uid):accept_event();return
		if clicked.is_valid(): clicked.call()

func _process(_delta):
	if tap_started < 0 or long_press_opened or Time.get_ticks_msec() - tap_started < 550: return
	if board == null or not board.mobile_layout or board.presenting or board.fx.busy: return
	var card_uid = display_uid if display_uid != -1 else uid
	if card_uid != -1:
		long_press_opened = true
		board.clear_tap_selection()
		board.open_card_detail(card_uid)

func _notification(what):
	if what == NOTIFICATION_DRAG_END and board != null:
		board.clear_highlights()
