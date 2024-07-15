extends Control

const PLAYER_LIST_ITEM = preload("res://game_board/player_list_item.tscn")
const turn_state_strings = ["Waiting", "Moving", "Making Noise", "Attacking", "Ending Turn", "Dead (lol)", "Escaped"]

@onready var player_list_left = $Align/PlayerListLeft
@onready var player_list_right = $Align/PlayerListRight

@onready var turn_number = $Align/HexButton/VAlign/TurnNumber
@onready var turn_state = $Align/HexButton/VAlign/TurnState

var players: Array = []

signal open_movement_record

func _ready() -> void:
	$Align/HexButton.pressed.connect(_on_turn_pressed)


func init_players(player_id_list, is_self_alien: bool) -> void:
	var index = 0
	for player_id in player_id_list:
		var item = PLAYER_LIST_ITEM.instantiate()
		item.set_id(player_id)
		item.set_player_name(Global.get_username(player_id))
		if player_id == multiplayer.get_unique_id():
			item.set_team(item.Team.ALIEN if is_self_alien else item.Team.HUMAN)
			item.set_team_lock()
			
		
		players.append(item)
		
		(player_list_left if index % 2 == 0 else player_list_right).add_child(item)
		index += 1

func set_current_turn(player_id: int) -> void:
	for player in players:
		player.set_current_player(player_id == player.id)

func set_turn_state(state: Global.TurnState) -> void:
	turn_state.text = turn_state_strings[state]

func set_turn_number(number: int) -> void:
	turn_number.text = str(number)

func _on_turn_pressed() -> void:
	print("open the turn list real quick I guess")
	open_movement_record.emit()
