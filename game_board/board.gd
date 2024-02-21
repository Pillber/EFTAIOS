extends Node2D

const MESSAGE = preload("res://game_board/message.tscn")
const PLAYER_ITEM = preload("res://game_board/player_item.tscn")

@onready var confirmation_popup = $CanvasLayer/UI/ConfirmationPanel
@onready var message_container = $CanvasLayer/UI/MessageContainer
@onready var player_list = $CanvasLayer/UI/PlayerList

var zone: Zone = null

signal tile_selected(tile)

func _ready() -> void:
	$Camera2D/Stars.show()

func _process(_delta):
	show_mouse_sector()


func show_mouse_sector() -> void:
	var mouse_pos = zone.get_tile_at_mouse()
	$CanvasLayer/UI/Panel/SelectedSectorLabel.text = zone.tile_to_sector(mouse_pos)


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


func show_message(message: String) -> void:	
	var message_panel = make_message(message)
	message_container.add_child(message_panel)
	
	await get_tree().create_timer(5).timeout
	
	message_panel.queue_free()

func make_message(message: String) -> Control:
	var panel = MESSAGE.instantiate()
	panel.get_node("Panel/Text").text = message
	return panel

#region Player Actions
func get_move() -> Vector2i:
	while true:
		var selected_tile = await tile_selected
		if selected_tile in zone.possible_moves:
			confirmation_popup.pop_up("Would you like to move to:", zone.tile_to_sector(selected_tile))
			if await confirmation_popup.finished:
				return selected_tile
	return Vector2i.ZERO

func end_turn() -> void:
	confirmation_popup.pop_up("End Turn", "", false)
	await confirmation_popup.finished

func attack() -> bool:
	confirmation_popup.pop_up("Would you like to Attack at:", zone.tile_to_sector(zone.player_position))
	return await confirmation_popup.finished

func make_noise_any_sector() -> Vector2i:
	confirmation_popup.pop_up("Make noise at any sector:", "Select any tile to make a noise there", false)
	await confirmation_popup.finished
	
	var selected_tile
	while true:
		selected_tile = await tile_selected
		confirmation_popup.pop_up("Confirm Noise at:", zone.tile_to_sector(selected_tile))
		if await confirmation_popup.finished:
			break
	
	return selected_tile

func make_noise_this_sector() -> Vector2i:
	confirmation_popup.pop_up("Making noise at: ", zone.tile_to_sector(zone.player_position), false)
	await confirmation_popup.finished
	return zone.player_position
#endregion
