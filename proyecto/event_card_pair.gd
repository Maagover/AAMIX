extends Control
## One floating stack keeps both event headliners visible, without altering art.
var board
var cards=[]
var clock=0.0
func configure(value,codes):
	board=value;custom_minimum_size=Vector2(232,205)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	for code in codes:
		var image=board.catalog_image(str(code),132,180)
		image.set_meta("event_headliner",str(code));add_child(image);cards.append(image)
	return self
func _process(delta):
	if board.animations_enabled:clock+=delta
	for i in range(cards.size()):
		cards[i].size=Vector2(132,180)
		var x=(size.x-132)*.5 if cards.size()==1 else 5+i*90
		cards[i].position=Vector2(x,6+i*13+(sin(clock*1.35)*4 if board.animations_enabled else 0))
