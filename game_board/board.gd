extends Node2D

const MESSAGE = preload("res://game_board/message.tscn")
const PLAYER_ITEM = preload("res://game_board/player_item.tscn")

@onready var noise_conf_popup = $CanvasLayer/UI/NoiseConfirmationPanel
@onready var attack_conf_popup = $CanvasLayer/UI/AttackConfirmationPanel
@onready var end_turn_popup = $CanvasLayer/UI/EndTurnPanel
@onready var message_container = $CanvasLayer/UI/MessageContainer
@onready var player_list = $CanvasLayer/UI/PlayerList

var zone: Zone = null

signal tile_selected(tile)
signal noise_selected(confirmed)
signal attack_selected(confirmed)
signal turn_ended()

func _ready() -> void:
	$Camera2D/Stars.show()
	
	noise_conf_popup.get_node("Center/VBoxContainer/Confirm").pressed.connect(_on_noise_confirmed)
	noise_conf_popup.get_node("Center/VBoxContainer/Decline").pressed.connect(_on_noise_declined)
	
	attack_conf_popup.get_node("Center/VBoxContainer/Confirm").pressed.connect(_on_attack_confirmed)
	attack_conf_popup.get_node("Center/VBoxContainer/Decline").pressed.connect(_on_attack_declined)

	end_turn_popup.get_node("Center/VBoxContainer/Confirm").pressed.connect(func(): emit_signal("turn_ended"))

func _process(_delta):
	show_mouse_sector()

func _input(event):
	if event.is_action_pressed("left_click"):
		tile_selected.emit(zone.get_tile_at_mouse())


func init_player_list(list) -> void:
	for player in list:
		var item = PLAYER_ITEM.instantiate()
		item.set_id(player)
		item.set_player_name(Global.get_username(player))
		
		player_list.add_child(item)

func set_player_turn(player_id: int) -> void:
	for player in player_list.get_children():
		if player.has_method("set_current_player"):
			player.set_current_player(player.id == player_id)


func set_current_turn(turn_number: int) -> void:
	$CanvasLayer/UI/PlayerList/TurnPanel/TurnLabel.text = "Current Turn: " + str(turn_number)

func show_mouse_sector() -> void:
	var mouse_pos = zone.get_tile_at_mouse()
	$CanvasLayer/UI/SelectedSectorLabel.text = zone.tile_to_sector(mouse_pos)


func show_message(message: String) -> void:
	
	var message_panel = make_message(message)
	message_container.add_child(message_panel)
	
	await get_tree().create_timer(5).timeout
	
	message_panel.queue_free()

func make_message(message: String) -> Control:
	var panel = MESSAGE.instantiate()
	panel.get_node("Panel/Text").text = message
	return panel

func get_move() -> Vector2i:
	while true:
		var selected_tile = await tile_selected
		if selected_tile in zone.possible_moves:
			return selected_tile
		else:
			print("Can't move there!")
	return Vector2i.ZERO

func end_turn() -> void:
	end_turn_popup.show()
	
	await turn_ended

	end_turn_popup.hide()

#region Attack

func attack() -> bool:
	attack_conf_popup.get_node("Center/VBoxContainer/Location").text = zone.tile_to_sector(zone.player_position)
	
	attack_conf_popup.show()
	
	return await attack_selected

func _on_attack_confirmed() -> void:
	attack_conf_popup.hide()
	emit_signal("attack_selected", true)


func _on_attack_declined() -> void:
	attack_conf_popup.hide()
	emit_signal("attack_selected", false)

#endregion

#region Noise

func make_noise_any_sector() -> Vector2i:
	noise_conf_popup.get_node("Center/VBoxContainer/Decline").show()
	
	var selected_tile
	while true:
		selected_tile = await tile_selected
		noise_conf_popup.get_node("Center/VBoxContainer/Location").text = zone.tile_to_sector(selected_tile)
		noise_conf_popup.show()
		
		if await noise_selected:
			break

	print("noise selected")
	return selected_tile

func make_noise_this_sector() -> Vector2i:
	noise_conf_popup.get_node("Center/VBoxContainer/Decline").hide()
	
	noise_conf_popup.get_node("Center/VBoxContainer/Location").text = zone.tile_to_sector(zone.player_position)
	noise_conf_popup.show()

	await noise_selected

	return zone.player_position

func _on_noise_confirmed() -> void:
	noise_conf_popup.hide()
	emit_signal("noise_selected", true)

func _on_noise_declined() -> void:
	noise_conf_popup.hide()
	emit_signal("noise_selected", false)

#endregion
