extends Control

const PLAYER_LIST_ITEM = preload("res://game_board/player_list_item.tscn")
const turn_state_strings = ["Waiting", "Moving", "Making Noise", "Attacking", "Ending Turn", "Dead (lol)", "Escaped"]

@onready var player_list_left = $Align/PlayerListLeft
@onready var player_list_right = $Align/PlayerListRight

@onready var turn_number = $Align/HexBackground/VAlign/TurnNumber
@onready var turn_state = $Align/HexBackground/VAlign/TurnState

var players: Array = []


func init_players(player_list) -> void:
	var index = 0
	for player in player_list:
		var item = PLAYER_LIST_ITEM.instantiate()
		item.set_id(player)
		item.set_player_name(Global.get_username(player))
		
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
