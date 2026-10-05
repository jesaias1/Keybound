class_name LocalPlayerManager
extends Node

signal player_joined(player_id: int, device_id: int)
signal player_left(player_id: int)
signal device_status_changed(player_id: int, connected: bool)

var joined_devices: Array[int] = []

func _ready() -> void:
	Input.joy_connection_changed.connect(_on_joy_connection_changed)

func try_join(device_id: int) -> int:
	if device_id in joined_devices:
		return joined_devices.find(device_id)
	if joined_devices.size() >= GameConfig.MAX_PLAYERS:
		return -1
	joined_devices.push_back(device_id)
	var id := joined_devices.size() - 1
	player_joined.emit(id, device_id)
	return id

func leave_player(player_id: int) -> bool:
	if player_id < 0 or player_id >= joined_devices.size():
		return false
	joined_devices.remove_at(player_id)
	player_left.emit(player_id)
	return true

func has_device(device_id: int) -> bool:
	return device_id in joined_devices

func player_specs() -> Array[Dictionary]:
	var specs: Array[Dictionary] = []
	for index in range(joined_devices.size()):
		specs.push_back({"player_id": index, "device_id": joined_devices[index]})
	return specs

func clear() -> void:
	joined_devices.clear()

func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if device in joined_devices:
		device_status_changed.emit(joined_devices.find(device), connected)

