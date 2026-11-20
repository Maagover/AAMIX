extends Node
## Server-only broadcasts. Clients can receive only their own authenticated inbox.
signal message(data)
var account
var socket: WebSocketPeer
var joined=false
var inbox_owner=""
var token=""
var reference=0
var join_ref=""
var heartbeat_at=0
var heartbeat_pending=""
var retry_at=0
var connect_at=0
var join_sent=false
var received=0

func stop():
	if socket!=null: socket.close()
	socket=null
	joined=false
	join_sent=false
	heartbeat_pending=""
	inbox_owner=""
	token=""

func _process(_delta):
	if account==null or not account.signed_in():
		if socket!=null: stop()
		return
	if inbox_owner!=account.player_id(): stop()
	var now=Time.get_ticks_msec()
	if socket==null:
		if now<retry_at: return
		inbox_owner=account.player_id()
		token=account.access_token
		socket=WebSocketPeer.new()
		socket.inbound_buffer_size=1048576
		socket.outbound_buffer_size=65536
		var url=account.service_url.replace("https://","wss://")+"/realtime/v1/websocket?apikey="+account.publishable_key.uri_encode()+"&vsn=1.0.0"
		if socket.connect_to_url(url)!=OK: reconnect();return
		connect_at=now
	socket.poll()
	var state=socket.get_ready_state()
	if state==WebSocketPeer.STATE_CLOSED: reconnect();return
	if state!=WebSocketPeer.STATE_OPEN:
		if now-connect_at>12000: reconnect()
		return
	if not join_sent:
		join_ref=send("realtime:aamix:user:"+inbox_owner,"phx_join",{"config":{"private":true,"broadcast":{"ack":false,"self":false},"presence":{"enabled":false},"postgres_changes":[]},"access_token":token})
		join_sent=true
		heartbeat_at=now
	if token!=account.access_token:
		token=account.access_token
		send("realtime:aamix:user:"+inbox_owner,"access_token",{"access_token":token})
	while socket.get_available_packet_count()>0:
		var data=JSON.parse_string(socket.get_packet().get_string_from_utf8())
		if not data is Dictionary: continue
		var event=str(data.get("event",""))
		var payload=data.get("payload",{})
		if not payload is Dictionary: continue
		if event=="phx_reply":
			if str(data.get("ref",""))==join_ref:
				joined=payload.get("status","")=="ok"
				if not joined: reconnect();return
			if str(data.get("ref",""))==heartbeat_pending: heartbeat_pending=""
		elif event in ["phx_error","phx_close"]: reconnect();return
		elif event=="broadcast" and joined and payload.get("event","")=="room" and payload.get("payload") is Dictionary:
			received+=1
			message.emit(payload.payload)
	if now-heartbeat_at>25000:
		if not heartbeat_pending.is_empty(): reconnect();return
		heartbeat_pending=send("phoenix","heartbeat",{})
		heartbeat_at=now
	if not joined and now-connect_at>15000: reconnect()

func send(topic,event,payload):
	reference+=1
	var ref=str(reference)
	socket.send_text(JSON.stringify({"topic":topic,"event":event,"payload":payload,"ref":ref}))
	return ref

func reconnect():
	stop()
	retry_at=Time.get_ticks_msec()+2500
