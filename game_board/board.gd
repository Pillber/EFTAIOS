extends Node2D

const MESSAGE = preload("res://game_board/message.tscn")
const PLAYER_ITEM = preload("res://game_board/player_item.tscn")
const TURN_ITEM = preload("res://game_board/turn_item.tscn")
const ITEM = preload("res://items/item.tscn")

@onready var confirmation_popup = $CanvasLayer/UI/ConfirmationPanel
@onready var message_container = $CanvasLayer/UI/MessageContainer
@onready var player_list = $CanvasLayer/UI/PlayerList
@onready var turn_grid = $CanvasLayer/UI/TurnContainer/VBoxContainer/TurnGridPanel/TurnGrid



var zone: Zone = null
var current_turn_number: int = 1
var current_turn_state: int = 0

signal tile_selected(tile)
signal using_item(item)

func _ready() -> void:
	$Camera2D/Stars.show()
	init_turn_grid()


func init_turn_grid() -> void:
	$CanvasLayer/UI/TurnContainer/VBoxContainer/TurnStateButton.pressed.connect(func(): turn_grid.visible = not turn_grid.visible)
	
	for i in range(1, 41):
		var turn = TURN_ITEM.instantiate()
		turn.name = str(i)
		turn.set_turn_number(i)
		turn_grid.add_child(turn)


func init_player_list(list) -> void:
	for player in list:
		var item = PLAYER_ITEM.instantiate()
		item.set_id(player)
		item.set_player_name(Global.get_username(player))
		
		player_list.add_child(item)


func _input(event):
	if event.is_action_pressed("left_click"):
		tile_selected.emit(zone.get_tile_at_mouse())


func set_player_turn(player_id: int) -> void:
	for player in player_list.get_children():
		if player.has_method("set_current_player"):
			player.set_current_player(player.id == player_id)


func turn_state_to_string(turn_state: int) -> String:
	const turn_state_strings = ["Waiting", "Moving", "Making Noise", "Attacking", "Ending Turn", "Dead (lol)", "Escaped"]
	return turn_state_strings[turn_state]


func set_player_turn_state(turn_state: int) -> void:
	current_turn_state = turn_state
	$CanvasLayer/UI/TurnContainer/VBoxContainer/TurnStateButton.text = "Current State: " + turn_state_to_string(turn_state)
	for item in $CanvasLayer/UI/ItemList/Items.get_children():
		item.update_useable(Global.TurnState.WAITING if zone.is_alien else turn_state)


func set_current_turn(turn_number: int) -> void:
	current_turn_number = turn_number
	$CanvasLayer/UI/PlayerList/TurnPanel/TurnLabel.text = "Current Turn: " + str(turn_number)


func show_message(message: String) -> void:	
	var message_item = MESSAGE.instantiate()
	message_item.set_message_text(message)
	message_container.add_child(message_item)


func add_item(item: ItemResource) -> void:
	var new_item = ITEM.instantiate()
	$CanvasLayer/UI/ItemList/Items.add_child(new_item)
	new_item.set_resource(item)
	new_item.use_item.connect(_on_use_item)


func remove_item(item: ItemResource) -> void:
	for child in $CanvasLayer/UI/ItemList/Items.get_children():
		if child.resource.name == item.name:
			$CanvasLayer/UI/ItemList/Items.remove_child(child)
			break


func _on_use_item(item: ItemResource):
	using_item.emit(item)


func prompt_item(item: ItemResource):
	var prompt_text = "Use c(%s, %s) item?" % [item.name, Global.color_to_code('use_item')]
	confirmation_popup.pop_up(prompt_text, Global.get_color('use_item'))
	var use_item = await confirmation_popup.finished
	return use_item


func use_cat(force_current_position: bool) -> Array[Vector2i]:
	var first_sector
	var second_sector
	if force_current_position:
		confirmation_popup.pop_up("Position revealed. Pick only one sector.", Global.get_color('use_item'), false)
		await confirmation_popup.finished
		first_sector = await make_noise_any_sector()
		second_sector = zone.player_position
	else:
		confirmation_popup.pop_up("Position not revealed. Pick two sectors.", Global.get_color('use_item'), false)
		await confirmation_popup.finished
		first_sector = await make_noise_any_sector()
		second_sector = await make_noise_any_sector()
	
	var result: Array[Vector2i] = [first_sector, second_sector]
	result.shuffle()
	
	return result

func enable_teleport_item(enable: bool) -> void:
	for item in $CanvasLayer/UI/ItemList/Items.get_children():
		if item.resource.name == "Teleport":
			item.update_useable(enable)

func use_spotlight() -> Array[Vector2i]:
	var selected_tile
	while true:
		confirmation_popup.pop_up("Select a sector to light up. This affects the 6 adjecent sectors.", "", false)
		await confirmation_popup.finished
		while true:
			selected_tile = await tile_selected
			confirmation_popup.pop_up("Would you like to light up: ", zone.tile_to_sector(selected_tile))
			if await confirmation_popup.finished:
				break
	return zone.get_adjecent_tiles(selected_tile)

#region Player Actions
func get_move() -> Vector2i:
	while true:
		var selected_tile = await tile_selected
		if selected_tile in zone.possible_moves:
			enable_teleport_item(false)
			var confirmation_text = "Move to c(%s, %s)?" % [zone.tile_to_sector(selected_tile), Global.color_to_code('moving')]
			confirmation_popup.pop_up(confirmation_text, Global.get_color('moving'))
			if await confirmation_popup.finished:
				turn_grid.get_node(str(current_turn_number)).set_move(zone.tile_to_sector(selected_tile))
				enable_teleport_item(true)
				return selected_tile
	return Vector2i.ZERO

func make_noise_any_sector() -> Vector2i:
	confirmation_popup.pop_up("Select any tile to make noise", Global.get_color('making_noise'), false)
	await confirmation_popup.finished
	
	var selected_tile
	while true:
		selected_tile = await tile_selected
		var confirmation_text = "Make noise at c(%s, %s)?" % [zone.tile_to_sector(selected_tile), Global.color_to_code('making_noise')]
		confirmation_popup.pop_up(confirmation_text, Global.get_color('making_noise'))
		if await confirmation_popup.finished:
			break
	
	return selected_tile

func make_noise_this_sector() -> Vector2i:
	var confirmation_text = "Making noise at c(%s, %s)" % [zone.tile_to_sector(zone.player_position), Global.color_to_code('making_noise')]
	confirmation_popup.pop_up(confirmation_text, Global.get_color('making_noise'), false)
	await confirmation_popup.finished
	return zone.player_position

func attack() -> bool:
	var confirmation_text = "Attack at c(%s, %s)?" % [zone.tile_to_sector(zone.player_position), Global.color_to_code('attack')]
	confirmation_popup.pop_up(confirmation_text, Global.get_color('attack'))
	var should_attack = await confirmation_popup.finished
	if should_attack:
		turn_grid.get_node(str(current_turn_number)).set_attacked()
	return should_attack

func end_turn() -> void:
	confirmation_popup.pop_up("Ending turn", Global.get_color('ending_turn'), false)
	await confirmation_popup.finished
#endregion
