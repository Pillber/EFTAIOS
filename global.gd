extends Node

const APP_ID: int = 480
const MAX_PLAYERS_PER_GAME: int = 8

var steam_id: int = 0
var steam_username: String = ""

var players: Dictionary = {}

signal player_disconnected
signal start_game

func _ready() -> void:
	var init_response = Steam.steamInitEx(true, 480, true)
	print("init? ", init_response)
	
	steam_id = Steam.getSteamID()
	steam_username = Steam.getPersonaName()
	
	print("ID: ", steam_id)
	print("Username: ", steam_username)


#region Networking


func add_self_to_players() -> void:
	players[multiplayer.get_unique_id()] = {
			"steam_id" : steam_id,
			"username" : steam_username,
	}


func _on_player_connected(multiplayer_id: int) -> void:
	# send my data to the player that just connected to me
	print("Player joined: ", multiplayer_id)
	send_data.rpc_id(multiplayer_id, steam_id, steam_username)


@rpc("any_peer")
func send_data(player_steam_id: int, player_username: String) -> void:
	var sender_id = multiplayer.get_remote_sender_id()
	players[sender_id] = {
		"steam_id" : player_steam_id,
		"username" : player_username,
	}

func _on_player_disconnected(multiplayer_id: int) -> void:
	# erase player's data from database as they are no longer there
	emit_signal("player_disconnected", multiplayer_id)
	print("Player left: ", multiplayer_id)
	players.erase(multiplayer_id)

func _on_server_disconnected() -> void:
	# this player left the server
	pass

func _on_connection_failed() -> void:
	# this player failed to connect to server
	multiplayer.multiplayer_peer = null
	print("Connection failed!")

func _on_connected_to_server() -> void:
	# this player connected to server
	print("Connected to server!")


func get_username(player_id: int) -> String:
	return players[player_id]["username"]
#endregion

enum TurnState {
	WAITING,
	MOVING,
	MAKING_NOISE,
	ATTACKING,
	ENDING_TURN,
	DEAD,
	ESCAPED,
	DISCONNECTED,
	USING_ITEM,
}


const colors: Dictionary = {
	'moving': Color.GOLDENROD,
	'attack': Color.INDIAN_RED,
	'making_noise': Color.SLATE_GRAY,
	'ending_turn': Color.WEB_GREEN,
	'use_item': Color.REBECCA_PURPLE,
}
var text_parse = RegEx.new()


func parse_text_to_bbcode(text: String) -> String:
	text_parse.compile("(?<tag>c)\\((?<text>\\w+), (?<option>#\\w+)\\)")
	var codes = []
	for code in text_parse.search_all(text):
		match code.get_string('tag'):
			'c':
				codes.append('[color='+code.get_string('option')+']'+code.get_string('text')+'[/color]')
	for code in codes:
		text = text_parse.sub(text, code)
	return '[center]'+text

func color_to_code(key: String) -> String:
	return "#" + colors[key].to_html()

func get_color(key: String) -> Color:
	return colors[key]
