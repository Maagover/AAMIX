extends RefCounted
## A passive reader survives board renders; it never advances or pauses the rules.
var board
var shade
var grid
var scroll
var player=-1
var zone=""
var signature=""

func _init(value):board=value
func is_open():return is_instance_valid(shade) and not shade.is_queued_for_deletion()
func open(p,z):
	if p not in [0,1] or z not in ["graveyard","burned"] or not board.started:return
	close()
	player=p;zone=z;signature=""
	var center=board.overlay("inspection")
	shade=center.get_parent();shade.set_meta("passive_inspection",true)
	var body=board.box(board.panel(center),true,12)
	body.custom_minimum_size=Vector2(1070,600)
	body.add_child(board.label("%s · %s" % [board.game.players[p].name,board.game.zone_name(z)],24,board.GOLD))
	scroll=ScrollContainer.new();scroll.custom_minimum_size=Vector2(1040,480);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	grid=GridContainer.new();grid.columns=7;scroll.add_child(grid)
	body.add_child(board.button("Volver a la mesa",close))
	refresh()
func refresh():
	if not is_open():return
	if board.screen!="table" or not board.started or board.game.players.size()!=2:
		close();return
	var cards=board.game.players[player][zone]
	var state=str(cards)
	if state==signature:return
	signature=state
	for child in grid.get_children():grid.remove_child(child);child.queue_free()
	board.targets=board.targets.filter(func(n):return is_instance_valid(n) and n.zone!="inspection")
	for uid in cards:board.card(grid,uid,"inspection",player,137,183)
	if cards.is_empty():grid.add_child(board.label("Sin cartas en esta zona.",18,board.MUTED))
func close():
	if is_open():board.close_overlay(shade)
	shade=null;signature=""
	if board!=null:board.targets=board.targets.filter(func(n):return is_instance_valid(n) and n.zone!="inspection")
