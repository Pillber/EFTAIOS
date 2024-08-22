extends Node2D

const MESSAGE = preload("res://game_board/message.tscn")
const TURN_ITEM = preload("res://game_board/turn_item.tscn")
const ITEM = preload("res://items/item.tscn")

@onready var confirmation_popup = $CanvasLayer/UI/ConfirmationPanel
@onready var message_container = $CanvasLayer/UI/MessageContainer
@onready var turn_and_players = $CanvasLayer/UI/TurnAndPlayers
@onready var movement_record = $CanvasLayer/UI/MovementRecord
@onready var item_list = $CanvasLayer/UI/ItemList
@onready var status_bar = $CanvasLayer/UI/StatusBar
@onready var camera = $Camera

var zone: Zone = null
var current_turn_number: int = 1
var current_turn_state: Global.TurnState = Global.TurnState.WAITING

var interrupted: bool = false
signal tile_selected(tile, interrupt)
signal using_item(item)

func _ready() -> void:
	$Camera/Stars.show()
	turn_and_players.open_movement_record.connect(_on_open_movement_record)
	movement_record.close_movement_record.connect(_on_close_movement_record)
	tile_selected.connect(_on_tile_selected)
	item_list.use_item.connect(_on_use_item)

func _input(event):
	if event.is_action_pressed("left_click"):
		tile_selected.emit(zone.get_tile_at_mouse(), interrupted)

func _on_open_movement_record() -> void:
	camera.scroll_locked = true
	movement_record.show()

func _on_close_movement_record() -> void:
	camera.scroll_locked = false
	movement_record.hide()

func _on_tile_selected(tile, interrupt) -> void:
	status_bar.close()

func init_player_list(player_id_list) -> void:
	turn_and_players.init_players(player_id_list, zone.is_alien)

func set_player_turn(player_id: int) -> void:
	turn_and_players.set_current_turn(player_id)

func set_player_turn_state(turn_state: Global.TurnState) -> void:
	current_turn_state = turn_state
	turn_and_players.set_turn_state(turn_state)
	item_list.update_all_items_useable(turn_state, zone.is_alien)


func set_current_turn(turn_number: int) -> void:
	current_turn_number = turn_number
	turn_and_players.set_turn_number(turn_number)
	movement_record.add_turn(turn_number)


func show_message(message: String) -> void:	
	var message_item = MESSAGE.instantiate()
	message_item.set_message_text(message)
	message_container.add_child(message_item)

func add_item(item_resource: ItemResource) -> void:
	print('adding item')
	item_list.add_item(item_resource)

func remove_item(item_resource: ItemResource) -> void:
	item_list.remove_item(item_resource)

func _on_use_item(item: ItemResource):
	print(using_item)
	using_item.emit(item)


func prompt_item(item: ItemResource):
	var prompt_text = "Use c(%s, %s) item?" % [item.name, Global.color_to_code('use_item')]
	confirmation_popup.pop_up(prompt_text, Global.get_color('use_item'), -1)
	var use_item = await confirmation_popup.finished
	return use_item


func use_cat(force_current_position: bool) -> Array[Vector2i]:
	var first_sector
	var second_sector
	if force_current_position:
		confirmation_popup.pop_up("Position revealed. Pick only one sector.", Global.get_color('use_item'), -1, false)
		await confirmation_popup.finished
		first_sector = await make_noise_any_sector()
		second_sector = zone.player_position
	else:
		confirmation_popup.pop_up("Position not revealed. Pick two sectors.", Global.get_color('use_item'), -1, false)
		await confirmation_popup.finished
		first_sector = await make_noise_any_sector()
		second_sector = await make_noise_any_sector()
	
	var result: Array[Vector2i] = [first_sector, second_sector]
	result.shuffle()
	
	return result

func enable_teleport_item(enable: bool) -> void:
	for item in item_list.get_items(item_list.at_will):
		if item.resource.name == "Teleport":
			item.update_useable(enable)

func use_spotlight() -> Array[Vector2i]:
	interrupted = true
	confirmation_popup.hide()
	var selected_tile
	while true:
		status_bar.pop_up('Select a tile to light up with its 6 neighbors')
		var result = await tile_selected
		selected_tile = result[0]
		var confirmation_text = "Light up c(%s, %s)?" % [zone.tile_to_sector(selected_tile), Global.color_to_code('use_item')]
		confirmation_popup.pop_up(confirmation_text, Global.get_color('use_item'), current_turn_state)
		if await confirmation_popup.finished:
			break
	interrupted = false
	return zone.get_adjecent_tiles(selected_tile)

#region Player Actions
func get_move() -> Vector2i:
	while true:
		status_bar.pop_up('Select a tile to move to')
		var result = await tile_selected
		if result[1]:
			continue
		var selected_tile = result[0]
		if selected_tile in zone.possible_moves:
			var sector = zone.tile_to_sector(selected_tile)
			enable_teleport_item(false)
			var confirmation_text = "Move to c(%s, %s)?" % [sector, Global.color_to_code('moving')]
			confirmation_popup.pop_up(confirmation_text, Global.get_color('moving'), current_turn_state)
			var confirmed = await confirmation_popup.finished
			if interrupted:
				continue
			if confirmed:
				movement_record.set_turn_sector(current_turn_number, sector)
				enable_teleport_item(true)
				return selected_tile
	return Vector2i.ZERO

func make_noise_any_sector() -> Vector2i:
	#confirmation_popup.pop_up("Select any tile to make noise", Global.get_color('making_noise'), current_turn_state, false)
	#await confirmation_popup.finished
	var selected_tile
	while true:
		status_bar.pop_up('Select any tile to make noise there')
		var result = await tile_selected
		if result[1]:
			continue
		selected_tile = result[0]
		var confirmation_text = "Make noise at c(%s, %s)?" % [zone.tile_to_sector(selected_tile), Global.color_to_code('making_noise')]
		confirmation_popup.pop_up(confirmation_text, Global.get_color('making_noise'), current_turn_state)
		var confirmed = await confirmation_popup.finished
		if interrupted:
			continue
		if confirmed:
			break
	
	return selected_tile

func make_noise_this_sector() -> Vector2i:
	while true:
		var confirmation_text = "Making noise at c(%s, %s)" % [zone.tile_to_sector(zone.player_position), Global.color_to_code('making_noise')]
		confirmation_popup.pop_up(confirmation_text, Global.get_color('making_noise'), current_turn_state, false)
		await confirmation_popup.finished
		if !interrupted:
			break
	return zone.player_position

func attack() -> bool:
	var should_attack
	while true:
		var confirmation_text = "Attack at c(%s, %s)?" % [zone.tile_to_sector(zone.player_position), Global.color_to_code('attack')]
		confirmation_popup.pop_up(confirmation_text, Global.get_color('attack'), current_turn_state)
		should_attack = await confirmation_popup.finished
		if !interrupted:
			break
	if should_attack:
		movement_record.set_turn_attack(current_turn_number)
	return should_attack

func end_turn() -> void:
	while true:
		confirmation_popup.pop_up("Ending turn", Global.get_color('ending_turn'), current_turn_state, false)
		await confirmation_popup.finished
		if !interrupted:
			break
#endregion
