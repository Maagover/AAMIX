extends RefCounted
## Guided board. All user moves go through the ordinary board and game rules.
const Game=preload("res://game.gd")
var b
var active=false
var step="intro"
var refs={}
var internal_action=false
var selected={}
var messages={
	"resource":"Este es el tablero. Restos es tu Carta Recurso. Arrastra el Restos de tu MANO a RECURSOS. También puedes pulsar la carta y después la zona iluminada.",
	"pay_blue":"¡Bien! Tienes dos Recursos. Azul cuesta 2 Restos: mueve tus dos Recursos a PAGADAS, uno por uno. Así preparas su coste.",
	"play_blue":"El pago está preparado. Arrastra Azul desde tu MANO a tu LÍNEA DE DEFENSA. Ese es el lugar donde entran tus Aliados.",
	"new_turn":"Azul ya está en Defensa. No puede atacar el turno en que entra. Avancemos a tu siguiente turno: los Recursos pagados vuelven a estar disponibles.",
	"attack":"Ahora Azul puede atacar. Arrástralo de DEFENSA a ATAQUE. El recuadro de Fuerza muestra su Fuerza actual; cuando declare el ataque, Azul ganará +1.",
	"declare":"Azul está preparado. Pulsa Declarar ataque. Como Sam no tiene defensores ni Eventos para responder, el juego resolverá el daño automáticamente.",
	"attack_events":"Sam no bloqueará este ataque. En esta ventana podrían jugarse Eventos; por ahora pulsa Pasar daño y observa las cartas que pierde mi Mazo.",
	"blocking_intro":"Azul hizo 3 de daño: tres cartas de mi Mazo fueron al Cementerio. Ahora cambiemos de papel: te mostraré un ataque de Sam para que aprendas a bloquear.",
	"block":"Sam ataca con Javieriv (2) y Mog (3). Tú tienes a Sam (2) en Defensa. Arrastra tu Sam sobre Javieriv: el empate eliminará a ambos. La línea une cada atacante con su bloqueador.",
	"confirm_block":"Tu Sam bloquea a Javieriv. Mog queda sin bloquear. Pulsa Confirmar bloqueos para avanzar a los Eventos antes del daño.",
	"block_events":"Como defensor, respondes primero con Eventos. Ahora pulsa Pasar daño. Verás el bloqueo resolverse y el ataque de Mog llegar a tu Mazo.",
	"ability_intro":"Sam y Javieriv terminaron en sus Cementerios; Mog hizo 3 de daño a tu Mazo. Veamos una habilidad que puedes activar durante tu turno.",
	"ability":"Almenta puede hacer Imbloqueable a un Aliado pagando 1 Recurso. Haz doble clic en Almenta y pulsa Usar habilidad, como lo harías en una partida.",
	"ability_target":"Selecciona a Javieriv en la ventana de la habilidad y pulsa Confirmar. Después tendrás que pagar 1 Recurso.",
	"ability_pay":"Elegiste a Javieriv. Ahora mueve 1 Recurso a PAGADAS para completar la habilidad de Almenta.",
	"object_intro":"Javieriv es Imbloqueable hasta terminar este turno. Ahora probaremos un Objeto: se equipa sobre un Aliado propio, como máximo uno por Aliado.",
	"object_pay":"Dicky está en Defensa y tienes Muñeco de Miku en la Mano. Prepara su coste: mueve 2 Recursos a PAGADAS.",
	"object_play":"Arrastra Muñeco de Miku desde tu MANO directamente sobre Dicky. El Objeto queda enlazado a su portador.",
	"object_done":"Dicky pasó de Fuerza 1 a 5 gracias a Muñeco de Miku. Mira su contador de Fuerza y la pequeña carta equipada. Ahora veremos un Dominio en el centro del tablero.",
	"domain_pay":"En este nuevo turno se reagruparon tus Recursos. Talca cuesta 4: mueve cuatro Recursos a PAGADAS. Mog está en Defensa con Fuerza 3.",
	"domain_play":"Arrastra Talca desde tu MANO a la ZONA DE DOMINIO. La zona se ilumina al tomar una Carta Dominio.",
	"domain_done":"Talca permanece en el centro: permite bloquear a los Imbloqueables. Además, Mog gana +2 cuando hay un Dominio: ahora tiene Fuerza 5. Sólo hay un Dominio para ambos jugadores; uno nuevo reemplaza al anterior.",
	"agile_pay":"Probemos Ágil. Girabl acaba de llegar a tu Mano. Prepara su coste moviendo 3 Recursos a PAGADAS.",
	"agile_play":"Juega Girabl desde tu MANO a DEFENSA. Aunque acaba de entrar, su característica Ágil le permite atacar este mismo turno.",
	"agile_attack":"Arrastra Girabl a ATAQUE. A diferencia de Azul cuando entró, Girabl no necesita esperar otro turno.",
	"agile_declare":"Pulsa Declarar ataque para comprobarlo en el tablero.",
	"agile_events":"Pulsa Pasar daño. Girabl puede completar su ataque en el turno en que entró gracias a Ágil.",
	"unblock_intro":"¡Eso es Ágil! Ahora veremos Imbloqueable. Sam tendrá un defensor, pero elDepul podrá pasar sin que lo bloqueen.",
	"unblock_attack":"ElDepul tiene Imbloqueable. Arrástralo de DEFENSA a ATAQUE. Sam tiene a Azul defendiendo, pero esta vez no hay Talca en juego.",
	"unblock_declare":"Pulsa Declarar ataque: Sam no podrá asignar a Azul para bloquear a elDepul.",
	"unblock_events":"Azul no puede bloquear este ataque. Pulsa Pasar daño y observa cómo elDepul daña mi Mazo aunque tenga un defensor.",
	"singular_intro":"Imbloqueable evita los bloqueos, salvo excepciones como Talca. Nos queda Singular: una restricción al construir tu Mazo, no un coste adicional durante el combate.",
	"singular":"SoyFlaan es Singular. En un mazo sólo puedes incluir una copia de esa carta. Las variantes de una misma carta comparten ese límite. Pulsa Continuar para terminar.",
	"finish":"¡Ya practicaste las bases! Puedes empezar una partida aleatoria de práctica, sin premios ni cambios en tu progreso."}
func _init(board):b=board
func start():
	if b.started and b.game.winner==-1:
		b.show_notice("Tutorial","Termina o abandona tu partida actual antes de comenzar el tutorial.");return
	active=true;step="intro";selected={};b.screen="tutorial";b.render()
func render_screen():
	var center=CenterContainer.new();center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);b.add_child(center)
	var v=b.box(b.panel(center),true,22);v.custom_minimum_size=Vector2(880,530);v.alignment=BoxContainer.ALIGNMENT_CENTER
	var art=CenterContainer.new();v.add_child(art);var sam=b.asset_image("actualizacion_v111/sam.png",230,230);sam.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;art.add_child(sam)
	v.add_child(b.centered_label("Hola, soy Sam, y vengo a explicarte cómo jugar AAMIX Online",24,b.TEXT))
	v.add_child(b.button("Comenzar",begin,false,true));v.add_child(b.button("Saltar tutorial",leave))
func begin():
	b.practice_match=true;b.human=0;b.computer=1;b.active_challenge_stage=0;b.active_event_battle=false;b.active_deck_id="tutorial";b.automatic_uid=-1
	b.started=true;b.automation_pause=true;b.winner_announced=false;b.screen="table";setup(0);set_step("resource")
func lesson_deck():
	var entries=[{"codigo":"0100","cantidad":26}]
	for code in ["0104","0109","0114","0111","0129","0107","0124","0122","0127","0102","0103","0112","0113","0105"]:entries.append({"codigo":code,"cantidad":1})
	return {"id":"tutorial","nombre":"Mazo de práctica","recurso_inicial":"0100","cartas":entries}
func setup(chapter):
	b.game.new_game(112+chapter,[lesson_deck(),lesson_deck()]);refs={};selected={};b.draft.clear()
	var g=b.game;g.pending.clear();g.queue.clear();g.phase="main";g.active=0;g.actor=0;g.turn=2+chapter*2;g.manual_payment=[true,false]
	for p in [0,1]:
		for zone in ["hand","resources","paid","defense","attack","graveyard","burned"]:
			g.players[p].deck.append_array(g.players[p][zone]);g.players[p][zone].clear()
	g.players[1].name="Sam";g.players[0].name="Tu mazo de práctica"
	var amounts=[1,0,3,4,3,0,0]
	for i in range(amounts[chapter]):take("0100",0,"resources")
	match chapter:
		0:refs.resource=take("0100",0,"hand");refs.blue=take("0111",0,"hand");g.phase="resource"
		1:refs.sam=take("0114",0,"defense");refs.javier=take("0104",1,"defense");refs.mog=take("0109",1,"defense");g.active=1;g.actor=1
		2:refs.almenta=take("0129",0,"defense");refs.javier=take("0104",0,"defense")
		3:refs.dicky=take("0107",0,"defense");refs.object=take("0124",0,"hand")
		4:refs.gira=take("0127",0,"hand")
		5:refs.depul=take("0102",0,"defense");refs.defender=take("0111",1,"defense")
		6:refs.singular=take("0103",0,"defense")
	b.game.take_visual_events();b.announced_turn=g.turn
func take(code,p,zone):
	for uid in b.game.players[p].deck.duplicate():
		if b.game.code(uid)==code:
			b.game.players[p].deck.erase(uid);b.game.players[p][zone].append(uid);return uid
	return -1
func set_step(value):step=value;selected={};b.render()
func render_guide(parent):
	var center=CenterContainer.new();parent.add_child(center)
	var guide=b.panel(center);guide.set_meta("sam_guide",step);guide.custom_minimum_size.x=minf(1120,b.get_viewport_rect().size.x-120)
	var skin=b.style(Color("e0eee6") if not b.dark_theme else Color("273f3b"),Color("639785"),10)
	skin.set_border_width_all(2);guide.add_theme_stylebox_override("panel",skin)
	var row=b.box(guide,false,12);var sam=b.asset_image("actualizacion_v111/sam.png",70,70);sam.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;row.add_child(sam)
	var text=b.label(messages.get(step,""),18,b.TEXT);text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;text.size_flags_horizontal=Control.SIZE_EXPAND_FILL;text.custom_minimum_size.x=600;row.add_child(text)
	var narratives=["new_turn","blocking_intro","ability_intro","object_intro","object_done","domain_done","unblock_intro","singular_intro","singular","finish"]
	if step in narratives:
		var controls=b.box(row,true,4);controls.custom_minimum_size.x=150
		controls.add_child(b.button("Partida de práctica" if step=="finish" else "Continuar",next,false,true))
func render_actions(parent):
	parent.add_child(b.label("PRÁCTICA CON SAM",15,b.GOLD))
	var hint=b.label("Sigue la indicación de Sam en el tablero iluminado.",15,b.TEXT);hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;hint.custom_minimum_size.x=385;parent.add_child(hint)
	if step in ["declare","agile_declare","unblock_declare"]:parent.add_child(b.button("Declarar ataque",b.declare_attack,b.draft.is_empty(),true))
	elif step=="confirm_block":parent.add_child(b.button("Confirmar bloqueos",b.finish_blocks,false,true))
	elif step in ["attack_events","block_events","agile_events","unblock_events"]:parent.add_child(b.button("Pasar daño",b.pass_priority,b.game.actor!=0,true))
	elif step=="ability":parent.add_child(b.button("Leer Almenta",b.open_card_detail.bind(refs.almenta),false,true))
	elif step=="ability_target" and b.choice_dismissed:parent.add_child(b.button("Resolver elección",b.resume_choice,false,true))
func next():
	match step:
		"new_turn":
			var before=b.capture_layout();b.game.start_turn();step="attack";b.schedule_presentation(before)
		"blocking_intro":
			setup(1);step="block";scripted(b.game.declare_attack.bind([refs.javier,refs.mog]))
		"ability_intro":setup(2);set_step("ability")
		"object_intro":setup(3);set_step("object_pay")
		"object_done":
			var before=b.capture_layout();b.game.start_turn();refs.domain=take("0122",0,"hand");refs.mog=take("0109",0,"defense");step="domain_pay";b.schedule_presentation(before)
		"domain_done":setup(4);set_step("agile_pay")
		"unblock_intro":setup(5);set_step("unblock_attack")
		"singular_intro":setup(6);set_step("singular")
		"singular":set_step("finish")
		"finish":practice()
func scripted(action):
	internal_action=true;b.perform(action);internal_action=false
func poll():
	if not active or b.screen!="table" or b.presenting or b.fx.busy:return
	var g=b.game
	if step in ["attack_events","block_events","agile_events","unblock_events"] and g.actor==1:
		if g.phase=="blocks":scripted(g.finish_blocks);return
		if g.phase=="events":scripted(g.pass_priority);return
	match step:
		"resource":if refs.resource in g.players[0].resources:set_step("pay_blue")
		"pay_blue":if g.reserved[0].size()==2:set_step("play_blue")
		"play_blue":if refs.blue in g.players[0].defense:set_step("new_turn")
		"attack":if refs.blue in b.draft:set_step("declare")
		"declare":
			if g.phase=="after_combat":set_step("blocking_intro")
			elif g.phase in ["blocks","events"]:set_step("attack_events")
		"attack_events":if g.phase=="after_combat":set_step("blocking_intro")
		"block":if g.blocks.get(refs.javier,-1)==refs.sam:set_step("confirm_block")
		"confirm_block":if g.phase=="events":set_step("block_events")
		"block_events":if g.phase=="after_combat":set_step("ability_intro")
		"ability":if g.pending.get("kind","")=="grant_unblockable":set_step("ability_target")
		"ability_target":if g.payment_request.get("kind","")=="ability":set_step("ability_pay")
		"ability_pay":if g.unblockable(refs.javier):set_step("object_intro")
		"object_pay":if g.reserved[0].size()==2:set_step("object_play")
		"object_play":if g.instances[refs.dicky].object==refs.object:set_step("object_done")
		"domain_pay":if g.reserved[0].size()==4:set_step("domain_play")
		"domain_play":if g.domain_uid==refs.domain:set_step("domain_done")
		"agile_pay":if g.reserved[0].size()==3:set_step("agile_play")
		"agile_play":if refs.gira in g.players[0].defense:set_step("agile_attack")
		"agile_attack":if refs.gira in b.draft:set_step("agile_declare")
		"agile_declare":
			if g.phase=="after_combat":set_step("unblock_intro")
			elif g.phase in ["blocks","events"]:set_step("agile_events")
		"agile_events":if g.phase=="after_combat":set_step("unblock_intro")
		"unblock_attack":if refs.depul in b.draft:set_step("unblock_declare")
		"unblock_declare":if g.phase=="blocks":set_step("unblock_events")
		"unblock_events":if g.phase=="after_combat":set_step("singular_intro")
func expected_uid():
	return refs.get({"resource":"resource","play_blue":"blue","attack":"blue","object_play":"object","domain_play":"domain","agile_play":"gira","agile_attack":"gira","unblock_attack":"depul","block":"sam"}.get(step,""),-1)
func allows_drop(data,destination):
	var uid=int(data.get("uid",-1));var z=destination.get("zone","");var owner=int(destination.get("owner",-1))
	if not b.game.instances.has(uid):return false
	if step in ["pay_blue","ability_pay","object_pay","domain_pay","agile_pay"]:
		return b.game.location(uid).get("zone","")=="resources" and z=="paid" and owner==0
	if uid!=expected_uid():return false
	match step:
		"resource":return z=="resources" and owner==0
		"play_blue","agile_play":return z=="defense" and owner==0
		"attack","agile_attack","unblock_attack":return z=="attack" and owner==0
		"object_play":return destination.get("target",-1)==refs.dicky
		"domain_play":return z=="domain"
		"block":return destination.get("target",-1)==refs.javier and owner==1
	return false
func allows_action(method,args):
	if internal_action:return true
	match method:
		"request_play":return args[0]==expected_uid() and step in ["resource","play_blue","object_play","domain_play","agile_play"]
		"reserve_resource":return step in ["pay_blue","ability_pay","object_pay","domain_pay","agile_pay"]
		"declare_attack":return step in ["declare","agile_declare","unblock_declare"]
		"assign_block":return step=="block" and args[0]==refs.javier and args[1]==refs.sam
		"finish_blocks":return step=="confirm_block"
		"pass_priority":return step in ["attack_events","block_events","agile_events","unblock_events"]
		"activate":return step=="ability" and args[0]==refs.almenta
		"choose":return step in ["ability","ability_target"] and args[0]==[refs.javier]
	return false
func click_surface(surface):
	if surface.zone in ["choice","inspection"] or b.presenting or b.fx.busy:return false
	if not selected.is_empty() and b.can_drop(selected,surface.descriptor()):
		var payload=selected.duplicate();selected={};return b.apply_drop(payload,surface.descriptor())
	var data=b.drag_payload(surface.uid,surface.zone,surface.card_owner)
	if data!=null:selected=data;b.paint_indicator(surface,"selected");return true
	return false
func decorate_board():
	for surface in b.targets:
		if not is_instance_valid(surface):continue
		var zone=surface.zone;var own=surface.card_owner==0
		var target_zone={"resource":"resources","pay_blue":"paid","play_blue":"defense","attack":"attack","object_pay":"paid","domain_pay":"paid","domain_play":"domain","agile_pay":"paid","agile_play":"defense","agile_attack":"attack","unblock_attack":"attack","ability_pay":"paid"}.get(step,"")
		var selected_source=surface.uid==expected_uid() and surface.get_meta("card_surface",false)
		if selected_source or (zone==target_zone and (own or zone=="domain")) or (step=="block" and surface.uid==refs.javier):
			surface.set_meta("persistent_selected",true);b.paint_indicator(surface,"selected")
			if not selected_source:
				var indicator=surface.get_meta("indicator");var skin=indicator.get_theme_stylebox("panel").duplicate()
				skin.border_color=Color("79cba0");skin.shadow_color=Color(0.2,0.9,0.5,0.32);skin.set_border_width_all(3);indicator.add_theme_stylebox_override("panel",skin)
func practice():
	active=false;selected={};b.human=0;b.computer=1;b.practice_match=true;b.active_challenge_stage=0;b.active_event_battle=false;b.active_deck_id="practice"
	b.game.manual_payment=[true,false];var decks=b.game.decklists.duplicate();decks.shuffle();b.game.new_game(-1,[decks[0],decks[1]])
	b.started=true;b.automation_pause=false;b.winner_announced=false;b.announced_turn=0;b.screen="table";b.draft.clear();b.schedule_presentation({})
func leave():
	active=false;selected={};b.reset_match();b.open_single()
