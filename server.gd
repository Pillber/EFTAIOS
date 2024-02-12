extends Node

#region Deck
"""
	77 total: 17 items
	27 Noise in Any Sector
	27 Noise in This Sector
	
	6 Silence (no item)
	17 Silence (with item)
		2 Attack
		1 Teleport
		3 Adrenaline
		3 Sedatives
		1 Defense
		2 Spotlight
		1 Clone
		1 Sensor
		1 Mutation
		1 Cat
"""

enum CardTypes {
	NOISE_ANY_SECTOR,
	NOISE_THIS_SECTOR,
	SILENT_SECTOR,
}

var deck: Array[CardTypes] = []
var discard: Array[CardTypes] = []

func setup_deck() -> void:
	for _i in range(1):
		deck.append(CardTypes.NOISE_ANY_SECTOR)
		deck.append(CardTypes.NOISE_THIS_SECTOR)
	
	for _i in range(1):
		deck.append(CardTypes.SILENT_SECTOR)
		
	deck.shuffle()

func draw_card() -> CardTypes:
	if deck.size() == 0:
		# shuffle discard
		deck = discard.duplicate()
		discard.clear()
		deck.shuffle()
	var drawn_card = deck.pop_back()
	match drawn_card:
		CardTypes.NOISE_ANY_SECTOR:
			discard.append(drawn_card)
		CardTypes.NOISE_THIS_SECTOR:
			discard.append(drawn_card)
		_: # any silent sector card, item or not
			pass
	return drawn_card
#endregion

#region Players
enum Team {
	HUMAN,
	ALIEN,
}

class Player:

	var id: int = -1
	var position: Vector2i = Vector2i.ZERO
	var num_moves: int = 1
	var moves: Array[Vector2i] = []
	var team: Team = Team.HUMAN
	
	var current_state: TurnState = TurnState.WAITING
	
	func _init(player_id: int):
		self.id = player_id
	
	func set_team(new_team: Team, spawn_position: Vector2i) -> void:
		team = new_team
		num_moves = 1 if new_team == Team.HUMAN else 2
		position = spawn_position
	
	func move_to(new_position: Vector2i) -> void:
		moves.append(position)
		position = new_position
	
	func die() -> void:
		if team == Team.HUMAN:
			team = Team.ALIEN
			num_moves = 2
			# update num_moves on related player's board state
		else: # you are an alien
			current_state = TurnState.DEAD
			num_moves = 0
#endregion

#region Initialization

var board = null
var players: Array[Player] = []
var current_player_turn: int = 0

func _ready() -> void:
	set_process(multiplayer.is_server())
	set_physics_process(multiplayer.is_server())
	
	if not multiplayer.is_server():
		return
	
	for player in Global.players:
		players.append(Player.new(player))
	
	# randomize???
	players.shuffle()
	
	var num_aliens = ceil(players.size() / 2.0)
	
	var player_id_list = []
	
	var i = 0
	for player in players:
		var team = Team.ALIEN if i < num_aliens else Team.HUMAN
		var spawn = board.zone.alien_spawn if team == Team.ALIEN else board.zone.human_spawn
		player.set_team(team, spawn)
		setup_player.rpc_id(player.id, player.num_moves, spawn)
		i += 1
		
		player_id_list.append(player.id)
	
	init_player_list.rpc(player_id_list)

	server_call.rpc(ServerMessage.SERVER_BROADCAST_PLAYER_TURN, {"player":players[current_player_turn].id})
	players[current_player_turn].current_state = TurnState.MOVING
	
	setup_deck()


@rpc("reliable", "call_local")
func setup_player(num_moves: int, spawn: Vector2i) -> void:
	board.zone.player_num_moves = num_moves
	board.zone.set_player_position(spawn)

@rpc("reliable", "call_local")
func init_player_list(list) -> void:
	board.init_player_list(list)

#endregion

#region Game Logic

enum TurnState {
	WAITING,
	MOVING,
	MAKING_NOISE,
	ATTACKING,
	ENDING_TURN,
	USING_ITEM,
	DEAD,
	ESCAPED,
}

var queried_movement: bool = false
var queried_noise: bool = false
var queried_attack: bool = false
var queried_end_turn: bool = false
func _process(_delta) -> void:
	var current_player = players[current_player_turn]
	
	match current_player.current_state:
		TurnState.MOVING:
			if not queried_movement:
				queried_movement = true
				server_call.rpc_id(current_player.id, ServerMessage.PLAYER_MOVEMENT)
		TurnState.MAKING_NOISE:
			if not queried_noise:
				queried_noise = true
				# get tile at player position
				if board.zone.is_dangerous_tile(current_player.position):
					#query deck about noise type
					var card = draw_card()
					match card:
						CardTypes.NOISE_ANY_SECTOR:
							server_call.rpc_id(current_player.id, ServerMessage.SERVER_BROADCAST_MESSAGE, {"message":"Make a noise at any sector."})
							server_call.rpc_id(current_player.id, ServerMessage.PLAYER_NOISE_ANY_SECTOR)
						CardTypes.NOISE_THIS_SECTOR:
							server_call.rpc_id(current_player.id, ServerMessage.PLAYER_NOISE_THIS_SECTOR)
						_:
							server_call.rpc(ServerMessage.SERVER_BROADCAST_MESSAGE, {"message":"Silence in all sectors."})
							queried_noise = false
							current_player.current_state = TurnState.ATTACKING
				else:
					server_call.rpc(ServerMessage.SERVER_BROADCAST_MESSAGE, {"message" : "Silent sector."})
					queried_noise = false
					current_player.current_state = TurnState.ATTACKING
		TurnState.USING_ITEM:
			push_warning("TurnState.USING_ITEM: Not implemented yet!")
			pass
		TurnState.ATTACKING:
			if not queried_attack:
				queried_attack = true
				if current_player.team == Team.ALIEN:
					server_call.rpc_id(current_player.id, ServerMessage.PLAYER_ATTACK)
				else:
					queried_attack = false
					current_player.current_state = TurnState.ENDING_TURN
		TurnState.ENDING_TURN:
			if not queried_end_turn:
				queried_end_turn = true
				server_call.rpc_id(current_player.id, ServerMessage.PLAYER_END_TURN)
		TurnState.WAITING:
			return
		TurnState.DEAD:
			# skip turn if dead
			change_turn()


func change_turn() -> void:
	# update current player, and start their turn
	current_player_turn = (current_player_turn + 1) % players.size()
	if players[current_player_turn].current_state != TurnState.DEAD:
		server_call.rpc(ServerMessage.SERVER_BROADCAST_PLAYER_TURN, {"player":players[current_player_turn].id})
		players[current_player_turn].current_state = TurnState.MOVING

@rpc("reliable", "call_local")
func update_num_moves(new_num_moves: int, player_position: Vector2i) -> void:
	board.zone.player_num_moves = new_num_moves
	board.zone.update_possible_moves(player_position, new_num_moves)

enum ServerMessage {
	PLAYER_MOVEMENT,
	PLAYER_NOISE_THIS_SECTOR,
	PLAYER_NOISE_ANY_SECTOR,
	PLAYER_UPDATE_POSITION,
	PLAYER_ATTACK,
	PLAYER_END_TURN,
	SERVER_BROADCAST_MESSAGE,
	SERVER_BROADCAST_PLAYER_TURN,
}

enum ClientMessage {
	PLAYER_RETURN_MOVEMENT,
	PLAYER_RETURN_NOISE,
	PLAYER_RETURN_ATTACK,
	PLAYER_END_TURN,
}

const SERVER: int = 1

# called from the server onto clients. client logic to respond to what server wants
@rpc("authority", "reliable", "call_local")
func server_call(message: ServerMessage, payload: Dictionary = {}) -> void:
	match message:
		ServerMessage.PLAYER_MOVEMENT:
			var selected_tile = await board.get_move()
			client_call.rpc_id(SERVER, ClientMessage.PLAYER_RETURN_MOVEMENT, {"new_position":selected_tile})
		ServerMessage.PLAYER_NOISE_THIS_SECTOR:
			var selected_tile = await board.make_noise_this_sector()
			client_call.rpc_id(SERVER, ClientMessage.PLAYER_RETURN_NOISE, {"noise_position":selected_tile})
		ServerMessage.PLAYER_NOISE_ANY_SECTOR:
			var selected_tile = await board.make_noise_any_sector()
			client_call.rpc_id(SERVER, ClientMessage.PLAYER_RETURN_NOISE, {"noise_position":selected_tile})
		ServerMessage.PLAYER_ATTACK:
			var attack = await board.attack()
			client_call.rpc_id(SERVER, ClientMessage.PLAYER_RETURN_ATTACK, {"should_attack": attack})
		ServerMessage.PLAYER_END_TURN:
			await board.end_turn()
			client_call.rpc_id(SERVER, ClientMessage.PLAYER_END_TURN)
		ServerMessage.PLAYER_UPDATE_POSITION:
			board.zone.move_player(payload["new_position"])
		ServerMessage.SERVER_BROADCAST_MESSAGE:
			board.show_message(payload["message"])
		ServerMessage.SERVER_BROADCAST_PLAYER_TURN:
			board.set_player_turn(payload["player"])

# called from client onto server. server logic to use client responses
@rpc("any_peer", "reliable", "call_local")
func client_call(message: ClientMessage, payload: Dictionary = {}) -> void:
	var current_player = players[current_player_turn]
	match message:
		ClientMessage.PLAYER_RETURN_MOVEMENT:
			current_player.move_to(payload["new_position"])
			server_call.rpc_id(current_player.id, ServerMessage.PLAYER_UPDATE_POSITION, payload)
			queried_movement = false
			current_player.current_state = TurnState.MAKING_NOISE
		ClientMessage.PLAYER_RETURN_NOISE:
			server_call.rpc(ServerMessage.SERVER_BROADCAST_MESSAGE, {"message":"Noise at " + board.zone.tile_to_sector(payload["noise_position"]) + "."})
			queried_noise = false
			current_player.current_state = TurnState.ATTACKING
		ClientMessage.PLAYER_RETURN_ATTACK:
			if payload["should_attack"]:
				#attack
				for player in players:
					if player == current_player:
						continue
					if player.position == current_player.position:
						server_call.rpc(ServerMessage.SERVER_BROADCAST_MESSAGE, {"message":"Player [" + Global.get_username(player.id) + "] has been killed!"})
						var old_team = player.team
						player.die()
						if not player.current_state == TurnState.DEAD:
							player.position = board.zone.alien_spawn
						update_num_moves.rpc_id(player.id, player.num_moves, player.position)
						server_call.rpc_id(player.id, ServerMessage.PLAYER_UPDATE_POSITION, {"new_position":player.position})
						if current_player.team == Team.ALIEN and old_team == Team.HUMAN:
							var new_num_moves =  min(current_player.num_moves + 1, 3)
							current_player.num_moves = new_num_moves
							update_num_moves.rpc_id(current_player.id, current_player.num_moves, current_player.position)
				server_call.rpc(ServerMessage.SERVER_BROADCAST_MESSAGE, {"message": "Player [" + Global.get_username(current_player.id) + "] attacking at " + board.zone.tile_to_sector(current_player.position) + "."})
			queried_attack = false
			current_player.current_state = TurnState.ENDING_TURN
		ClientMessage.PLAYER_END_TURN:
			server_call.rpc(ServerMessage.SERVER_BROADCAST_MESSAGE, {"message": "Player [" + Global.get_username(current_player.id) + "] ends their turn."})
			queried_end_turn = false
			current_player.current_state = TurnState.WAITING
			
			change_turn()
#endregion
