extends Control

const PLAYER_LIST_ITEM = preload("res://game_board/player_list_item.tscn")
const turn_state_strings = ["Waiting", "Moving", "Making Noise", "Attacking", "Ending Turn", "Dead (lol)", "Escaped"]

@onready var player_list_left = $Align/PlayerListLeft
@onready var player_list_right = $Align/PlayerListRight

@onready var turn_number = $Align/HexButton/VAlign/TurnNumber
@onready var turn_state = $Align/HexButton/VAlign/TurnState

var players: Dictionary = {}
var player_list: Array = []

signal open_movement_record
signal avatar_loaded(steam_id, avatar_size, avatar_texture)

func _ready() -> void:
	$Align/HexButton.pressed.connect(_on_turn_pressed)
	Steam.avatar_loaded.connect(_on_loaded_avatar)
	avatar_loaded.connect($PlayerPicker._on_avatar_loaded)


func _on_loaded_avatar(user_steam_id: int, avatar_size: int, avatar_buffer: PackedByteArray) -> void:
	var avatar_image = Image.create_from_data(avatar_size, avatar_size, false, Image.FORMAT_RGBA8, avatar_buffer)
	var avatar_texture = ImageTexture.create_from_image(avatar_image)
	avatar_size /= 32
	
	avatar_loaded.emit(user_steam_id, avatar_size, avatar_texture)

func init_players(player_id_list, is_self_alien: bool) -> void:
	var index = 0
	for player_id in player_id_list:
		
		var steam_id = Global.players[player_id]['steam_id']
		Steam.getPlayerAvatar(Steam.AVATAR_MEDIUM, steam_id)
		Steam.getPlayerAvatar(Steam.AVATAR_SMALL, steam_id)
		
		
		var item = PLAYER_LIST_ITEM.instantiate()
		item.set_ids(player_id, steam_id)
		item.set_player_name(Global.get_username(player_id))
		avatar_loaded.connect(item._on_avatar_loaded)
		if player_id == multiplayer.get_unique_id():
			item.set_team(item.Team.ALIEN if is_self_alien else item.Team.HUMAN)
			item.set_team_lock()
		
		(player_list_left if index % 2 == 0 else player_list_right).add_child(item)
		player_list.append(item)
		index += 1
	
	$PlayerPicker.init(player_id_list)

func set_current_turn(player_id: int) -> void:
	for player in player_list:
		player.set_current_player(player_id == player.id)

func set_turn_state(state: Global.TurnState) -> void:
	turn_state.text = turn_state_strings[state]

func set_turn_number(number: int) -> void:
	turn_number.text = str(number)

func select_player() -> int:
	return await $PlayerPicker.get_player()


func _on_turn_pressed() -> void:
	open_movement_record.emit()
