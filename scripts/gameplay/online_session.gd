class_name OnlineSession
extends Node
## Browser-native WebRTC bridge. Native exports retain local co-op.
signal event_received(data: Dictionary)
signal network_tick
var role := ""
var slot := 0
var peers: Array[int] = []
var epoch := 0
var input_active := false
var _bridge: JavaScriptObject
var _source := InputSource.create(InputSource.KEYBOARD)
var _frame := InputFrame.new()
var _elapsed := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.has_feature("web"):
		_bridge = JavaScriptBridge.get_interface("KEYBOUND_NET")

func available() -> bool:
	return _bridge != null

func open_lobby() -> void:
	if available():
		_bridge.openLobby()

func hide_lobby() -> void:
	if available():
		_bridge.hideLobby()

func close_room() -> void:
	if available():
		_bridge.close()
	role = ""
	peers.clear()
	input_active = false

func send(packet: Dictionary, peer := -1) -> void:
	if available():
		_bridge.send(JSON.stringify(packet), peer)

func _physics_process(_delta: float) -> void:
	if role != "guest" or not input_active:
		return
	var frame := _source.poll()
	frame.jump_pressed = frame.jump_pressed or _frame.jump_pressed
	frame.pause_pressed = frame.pause_pressed or _frame.pause_pressed
	_frame = frame

func _process(delta: float) -> void:
	if not available():
		return
	var raw: Variant = JSON.parse_string(str(_bridge.drain()))
	if raw is Array:
		for event: Dictionary in raw:
			match str(event.get("kind", "")):
				"hosted":
					epoch = 0
					role = "host"
					slot = 0
					peers.clear()
				"joined":
					epoch = 0
					role = "guest"
					slot = int(event.slot)
				"peer_joined":
					if not peers.has(int(event.peer)):
						peers.push_back(int(event.peer))
				"peer_left": peers.erase(int(event.peer))
				"closed":
					role = ""
					peers.clear()
					input_active = false
			event_received.emit(event)
	_elapsed += delta
	if _elapsed < GameConfig.NETWORK_TICK:
		return
	_elapsed = fmod(_elapsed, GameConfig.NETWORK_TICK)
	if role == "guest" and input_active:
		send({"type": "input", "epoch": epoch, "frame": _frame.to_dict()}, 0)
		_frame.jump_pressed = false
		_frame.pause_pressed = false
	elif role == "host":
		network_tick.emit()
