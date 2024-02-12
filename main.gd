extends Node

const GAME_BOARD = preload("res://game_board/board.tscn")
const SERVER = preload("res://server.tscn")


var MAP = preload("res://zones/fermi.tscn")

func _ready() -> void:
	Global.start_game.connect(_on_start_game)


func _on_start_game() -> void:
	load_board.rpc()


@rpc("reliable", "call_local")
func load_board() -> void:
	remove_child($Lobby)
	
	var board = GAME_BOARD.instantiate()
	add_child(board)
	
	var map = MAP.instantiate()
	board.add_child(map)
	board.zone = map
	
	var server = SERVER.instantiate()
	server.board = board
	add_child(server)
