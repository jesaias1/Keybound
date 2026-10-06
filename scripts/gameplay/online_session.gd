class_name OnlineSession
extends Node
## Transport for host-authoritative online play. Two back ends, one interface:
##
##  - Browser: the page's WebRTC bridge (Convex rooms, see deployment/online.js).
##  - Desktop: Godot's built-in ENet. One player hosts; friends join by code.
##    On a LAN, hosts are discovered automatically. Over the internet the host
##    asks the router to open the port with UPnP; if the router refuses, UDP
##    port NET_PORT has to be forwarded by hand. No plugins, no servers.
##
## Either way the host simulates the match, guests send input and receive
## snapshots. Browser and desktop players cannot join each other: the two
## transports are different protocols.

signal event_received(data: Dictionary)
signal network_tick
signal lobby_changed

const CODE_CHARS := "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
const CODE_LENGTH := 7
const BEACON_TAG := "HOPKEY1"
const CONNECT_TIMEOUT := 8.0

var role := ""
var slot := 0
var peers: Array[int] = []
var epoch := 0
var input_active := false
var locked := false                 ## A match is running: refuse new joiners.
var status := ""                    ## Human-readable lobby line.
var lan_code := ""
var internet_code := ""
var internet_state := ""            ## "", "checking", "open", "closed"
var lan_hosts: Dictionary = {}      ## ip -> seconds since last beacon
var lan_watch_failed := false       ## Discovery port busy (another copy running here).
var debug_frame: InputFrame         ## Tests: replaces the polled keyboard.
var port := GameConfig.NET_PORT
var beacon_port := GameConfig.NET_BEACON_PORT
var _bridge: JavaScriptObject
var _source := InputSource.create(InputSource.KEYBOARD)
var _frame := InputFrame.new()
var _elapsed := 0.0
var _enet: ENetMultiplayerPeer
var _slot_by_id: Dictionary = {}
var _id_by_slot: Dictionary = {}
var _connecting := -1.0
var _join_address := ""
var _join_hint := ""
var _beacon: PacketPeerUDP
var _beacon_elapsed := 0.0
var _beacon_targets := PackedStringArray()
var _listener: PacketPeerUDP
var _upnp: UPNP
var _upnp_thread: Thread

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.has_feature("web"):
		_bridge = JavaScriptBridge.get_interface("HOPKEY_NET")

func is_web() -> bool:
	return _bridge != null

func available() -> bool:
	return is_web() or not OS.has_feature("web")

func open_lobby() -> void:
	if is_web():
		_bridge.openLobby()

func hide_lobby() -> void:
	if is_web():
		_bridge.hideLobby()

func close_room() -> void:
	if is_web():
		_bridge.close()
	_close_native()
	role = ""
	peers.clear()
	input_active = false
	locked = false
	status = ""
	lobby_changed.emit()

func send(packet: Dictionary, peer := -1) -> void:
	if is_web():
		_bridge.send(JSON.stringify(packet), peer)
		return
	if _enet == null or _enet.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	var target := 0
	if role == "guest":
		target = MultiplayerPeer.TARGET_PEER_SERVER
	elif peer >= 0:
		if not _id_by_slot.has(peer):
			return
		target = int(_id_by_slot[peer])
	elif _id_by_slot.is_empty():
		return
	_enet.set_target_peer(target)
	_enet.put_packet(JSON.stringify(packet).to_utf8_buffer())

# --- Desktop: hosting and joining ----------------------------------------------------

## Opens a room on this machine. Returns false if the port is unavailable.
func host_game() -> bool:
	_close_native()
	_enet = ENetMultiplayerPeer.new()
	if _enet.create_server(port, GameConfig.MAX_PLAYERS - 1) != OK:
		_enet = null
		status = "Could not open port %d. Is another Hopkey already hosting?" % port
		lobby_changed.emit()
		return false
	_enet.transfer_mode = MultiplayerPeer.TRANSFER_MODE_RELIABLE
	_enet.peer_connected.connect(_on_peer_connected)
	_enet.peer_disconnected.connect(_on_peer_disconnected)
	epoch = 0
	role = "host"
	slot = 0
	peers.clear()
	locked = false
	lan_code = code_for_ip(local_ip())
	internet_code = ""
	internet_state = "checking"
	status = "Room open. Share a code with your friends. If Windows asks, choose Allow."
	_beacon = PacketPeerUDP.new()
	_beacon.set_broadcast_enabled(true)
	_beacon_targets = broadcast_addresses()
	_upnp_thread = Thread.new()
	_upnp_thread.start(_open_router_port)
	event_received.emit({"kind": "hosted"})
	lobby_changed.emit()
	return true

## Joins by room code, IP address or host name.
func join_game(text: String) -> bool:
	var address := ip_for_code(text)
	if address.is_empty():
		status = "That code does not look right."
		lobby_changed.emit()
		return false
	_close_native()
	_enet = ENetMultiplayerPeer.new()
	if _enet.create_client(address, port) != OK:
		_enet = null
		status = "Could not start a connection to %s." % address
		lobby_changed.emit()
		return false
	_enet.transfer_mode = MultiplayerPeer.TRANSFER_MODE_RELIABLE
	role = "joining"
	_join_address = address
	_join_hint = ""
	if _is_private(address) and not same_subnet(address, local_ip()):
		_join_hint = " That is a home-network code, so you must both be on the same Wi-Fi. Over the internet, use the host's internet code."
	_connecting = CONNECT_TIMEOUT
	status = "Connecting to %s…" % address
	lobby_changed.emit()
	return true

## Starts listening for rooms on the local network (join screen).
func watch_lan(enabled: bool) -> void:
	if enabled and _listener == null:
		_listener = PacketPeerUDP.new()
		if _listener.bind(beacon_port) != OK:
			# Another copy of the game on this PC is already listening.
			_listener = null
			lan_watch_failed = true
	elif not enabled and _listener != null:
		_listener.close()
		_listener = null
		lan_hosts.clear()

## True when both addresses share their first three numbers (same home network).
static func same_subnet(a: String, b: String) -> bool:
	var left := a.split(".")
	var right := b.split(".")
	return left.size() == 4 and right.size() == 4 and left[0] == right[0] and left[1] == right[1] and left[2] == right[2]

static func _is_private(address: String) -> bool:
	if address.begins_with("192.168.") or address.begins_with("10."):
		return true
	if address.begins_with("172."):
		var second := int(address.get_slice(".", 1))
		return second >= 16 and second <= 31
	return false

## Where a host announces itself: the directed broadcast of each private
## subnet it is on, the global broadcast, and this machine.
static func broadcast_addresses() -> PackedStringArray:
	var result := PackedStringArray(["255.255.255.255", "127.0.0.1"])
	for address in IP.get_local_addresses():
		if _is_private(address):
			var directed := "%s.255" % address.rsplit(".", true, 1)[0]
			if directed not in result:
				result.push_back(directed)
	return result

static func local_ip() -> String:
	for address in IP.get_local_addresses():
		if _is_private(address):
			return address
	return "127.0.0.1"

## An IPv4 address as a short code that is easy to read out loud.
static func code_for_ip(address: String) -> String:
	var parts := address.split(".")
	if parts.size() != 4:
		return ""
	var value := 0
	for part in parts:
		if not part.is_valid_int() or int(part) < 0 or int(part) > 255:
			return ""
		value = value * 256 + int(part)
	var code := ""
	for index in range(CODE_LENGTH):
		code = CODE_CHARS[value % 36] + code
		value /= 36
	return code

## Accepts a room code, a dotted IPv4 address, or a host name.
static func ip_for_code(text: String) -> String:
	var value := text.strip_edges()
	if value.is_empty() or value.length() > 253:
		return ""
	if value.is_valid_ip_address():
		return value
	var upper := value.to_upper()
	if upper.length() == CODE_LENGTH:
		var number := 0
		var valid := true
		for index in range(CODE_LENGTH):
			var digit := CODE_CHARS.find(upper[index])
			if digit < 0:
				valid = false
				break
			number = number * 36 + digit
		if valid and number <= 0xFFFFFFFF:
			return "%d.%d.%d.%d" % [(number >> 24) & 255, (number >> 16) & 255, (number >> 8) & 255, number & 255]
	if value.contains(".") and not value.contains(" "):
		return value   # Host name.
	return ""

func _open_router_port() -> void:
	var upnp := UPNP.new()
	var external := ""
	if upnp.discover(2000, 2, "InternetGatewayDevice") == UPNP.UPNP_RESULT_SUCCESS:
		var gateway := upnp.get_gateway()
		if gateway != null and gateway.is_valid_gateway():
			if upnp.add_port_mapping(port, port, GameConfig.GAME_TITLE, "UDP", 0) == UPNP.UPNP_RESULT_SUCCESS:
				external = upnp.query_external_address()
	_router_port_result.call_deferred(upnp, external)

func _router_port_result(upnp: UPNP, external: String) -> void:
	if _upnp_thread != null:
		_upnp_thread.wait_to_finish()
		_upnp_thread = null
	if role != "host":
		if not external.is_empty():
			upnp.delete_port_mapping(port, "UDP")
		return
	_upnp = upnp if not external.is_empty() else null
	internet_code = code_for_ip(external)
	internet_state = "open" if not internet_code.is_empty() else "closed"
	lobby_changed.emit()

func _close_native() -> void:
	if _upnp_thread != null:
		_upnp_thread.wait_to_finish()
		_upnp_thread = null
	if _upnp != null:
		_upnp.delete_port_mapping(port, "UDP")
		_upnp = null
	if _beacon != null:
		_beacon.close()
		_beacon = null
	if _enet != null:
		_enet.close()
		_enet = null
	_slot_by_id.clear()
	_id_by_slot.clear()
	_connecting = -1.0
	lan_code = ""
	internet_code = ""
	internet_state = ""

func _on_peer_connected(id: int) -> void:
	if role != "host":
		return
	var free_slot := -1
	for candidate in range(1, GameConfig.MAX_PLAYERS):
		if not _id_by_slot.has(candidate):
			free_slot = candidate
			break
	if locked or free_slot < 0:
		_enet.disconnect_peer(id)
		return
	_slot_by_id[id] = free_slot
	_id_by_slot[free_slot] = id
	if not peers.has(free_slot):
		peers.push_back(free_slot)
	send({"type": "welcome", "slot": free_slot}, free_slot)
	status = "%d / %d players connected." % [peers.size() + 1, GameConfig.MAX_PLAYERS]
	event_received.emit({"kind": "peer_joined", "peer": free_slot})
	lobby_changed.emit()

func _on_peer_disconnected(id: int) -> void:
	if role != "host" or not _slot_by_id.has(id):
		return
	var left := int(_slot_by_id[id])
	_slot_by_id.erase(id)
	_id_by_slot.erase(left)
	peers.erase(left)
	status = "%d / %d players connected." % [peers.size() + 1, GameConfig.MAX_PLAYERS]
	event_received.emit({"kind": "peer_left", "peer": left})
	lobby_changed.emit()

func _poll_native(delta: float) -> void:
	if _listener != null:
		var changed := false
		for ip: String in lan_hosts.keys():
			lan_hosts[ip] = float(lan_hosts[ip]) + delta
			if float(lan_hosts[ip]) > 3.5:
				lan_hosts.erase(ip)
				changed = true
		while _listener.get_available_packet_count() > 0:
			var text := _listener.get_packet().get_string_from_utf8()
			var ip := _listener.get_packet_ip()
			if text.begins_with(BEACON_TAG) and not ip.is_empty():
				changed = changed or not lan_hosts.has(ip)
				lan_hosts[ip] = 0.0
		if changed:
			lobby_changed.emit()
	if _enet == null:
		return
	_enet.poll()
	if role == "host" and _beacon != null and not locked:
		_beacon_elapsed += delta
		if _beacon_elapsed >= 1.0:
			_beacon_elapsed = 0.0
			# Announce on every local subnet: a plain 255.255.255.255 broadcast
			# only leaves through one adapter, which is often the wrong one.
			for address in _beacon_targets:
				_beacon.set_dest_address(address, beacon_port)
				_beacon.put_packet(BEACON_TAG.to_utf8_buffer())
	if role == "joining":
		_connecting -= delta
		var state := _enet.get_connection_status()
		if state == MultiplayerPeer.CONNECTION_DISCONNECTED or _connecting <= 0.0:
			_close_native()
			role = ""
			status = "Could not connect to %s. Check the code, that the host's room is open, and that Windows Firewall allows Hopkey.%s" % [_join_address, _join_hint]
			lobby_changed.emit()
			return
	elif role == "guest" and _enet.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		_close_native()
		role = ""
		input_active = false
		status = "The host closed the room."
		event_received.emit({"kind": "closed"})
		lobby_changed.emit()
		return
	while _enet != null and _enet.get_available_packet_count() > 0:
		var from := _enet.get_packet_peer()
		var bytes := _enet.get_packet()
		if bytes.size() > GameConfig.NET_MAX_PACKET:
			continue
		var packet: Variant = JSON.parse_string(bytes.get_string_from_utf8())
		if not packet is Dictionary:
			continue   # Invalid packets never enter gameplay.
		if role == "host":
			if _slot_by_id.has(from):
				event_received.emit({"kind": "packet", "peer": int(_slot_by_id[from]), "packet": packet})
		elif from == MultiplayerPeer.TARGET_PEER_SERVER:
			if role == "joining" and str(packet.get("type", "")) == "welcome":
				role = "guest"
				slot = clampi(int(packet.get("slot", 1)), 1, GameConfig.MAX_PLAYERS - 1)
				epoch = 0
				status = "Connected as P%d. Waiting for the host to start…" % (slot + 1)
				event_received.emit({"kind": "joined", "slot": slot})
				lobby_changed.emit()
			elif role == "guest":
				event_received.emit({"kind": "packet", "peer": 0, "packet": packet})

# --- Shared loop -------------------------------------------------------------------------

func _physics_process(_delta: float) -> void:
	if role != "guest" or not input_active:
		return
	var frame := debug_frame if debug_frame != null else _source.poll()
	if debug_frame != null:
		frame = InputFrame.from_dict(debug_frame.to_dict())
		debug_frame.jump_pressed = false
	frame.jump_pressed = frame.jump_pressed or _frame.jump_pressed
	frame.pause_pressed = frame.pause_pressed or _frame.pause_pressed
	_frame = frame

func _process(delta: float) -> void:
	if is_web():
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
	else:
		_poll_native(delta)
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

func _exit_tree() -> void:
	_close_native()
	if _listener != null:
		_listener.close()
