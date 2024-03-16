extends Node

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
	var items: Array = []
	
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
	
	func die(alien_spawn: Vector2i) -> void:
		if team == Team.HUMAN:
			team = Team.ALIEN
			num_moves = 2
			position = alien_spawn
			# update num_moves on related player's board state
		else: # you are an alien
			current_state = TurnState.DEAD
			num_moves = 0
	
	func can_attack() -> bool:
		if team == Team.ALIEN: return true
		#if items.contains(attack): return true
		return false
#endregion

#region Initialization

var board = null
var players: Array[Player] = []
var current_player_turn: int = 0

signal end_game()

func _ready() -> void:
	set_process(multiplayer.is_server())
	set_physics_process(multiplayer.is_server())
	
	if not multiplayer.is_server():
		return
	
	end_game.connect(_on_end_game)
	
	Global.player_disconnected.connect(_on_player_disconnected)
	
	for player in Global.players:
		players.append(Player.new(player))
	
	
	var num_aliens = ceil(players.size() / 2.0)
	
	var player_id_list = []
	
	var i = 0
	for player in players:
		var team = Team.ALIEN if i < num_aliens else Team.HUMAN
		var spawn = board.zone.alien_spawn if team == Team.ALIEN else board.zone.human_spawn
		player.set_team(team, spawn)
		setup_player.rpc_id(player.id, player.num_moves, spawn, player.team == Team.ALIEN)
		i += 1
	
	# randomize???
	players.shuffle()
	
	for player in players:
		player_id_list.append(player.id)
	
	init_player_list.rpc(player_id_list)

	server_call.rpc(ServerMessage.SERVER_BROADCAST_PLAYER_TURN, {"player":players[current_player_turn].id})
	change_state(players[current_player_turn], TurnState.MOVING)

@rpc("reliable", "call_local")
func setup_player(num_moves: int, spawn: Vector2i, is_alien: bool) -> void:
	board.zone.player_num_moves = num_moves
	board.zone.is_alien = is_alien
	board.zone.set_player_position(spawn)

@rpc("reliable", "call_local")
func init_player_list(list) -> void:
	board.init_player_list(list)

func _on_end_game() -> void:
	set_process(false)
	set_physics_process(false)
	print("ending game!")
	
	await get_tree().create_timer(3).timeout
	
	end_quit_game.rpc()

@rpc("reliable", "call_local")
func end_quit_game() -> void:
	get_tree().quit()


func _on_player_disconnected(player_id: int) -> void:
	for player in players:
		if player.id == player_id:
			player.current_state = TurnState.DISCONNECTED
	queried_movement = false
	queried_noise = false
	queried_attack = false
	queried_end_turn = false

#endregion

#region Game Logic

enum TurnState {
	WAITING = 0b0,
	MOVING = 0b1,
	MAKING_NOISE = 0b10,
	ATTACKING = 0b100,
	ENDING_TURN = 0b1000,
	DEAD = 0b10000,
	ESCAPED = 0b100000,
	DISCONNECTED = 0b1000000,
	USING_ITEM,
}

var total_turns: int = 1

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
				if board.zone.is_escape_pod(current_player.position):
					print("At escape pod!")
					var escape_pod = board.zone.get_escape_pod(current_player.position)
					server_call.rpc(ServerMessage.SERVER_BROADCAST_MESSAGE, {"message":"Player [" + Global.get_username(current_player.id) + "] is trying to escape at Escape Pod " + str(escape_pod)})
					var escape_succeed
					match Decks.escape_deck.draw_card().type:
						Decks.CardType.ESCAPE_FAIL:
							escape_succeed = false
							server_call.rpc(ServerMessage.SERVER_BROADCAST_MESSAGE, {"message":"Escape pod " + str(escape_pod) + " broke! Player [" + Global.get_username(current_player.id) + "] did not escape!"})
						Decks.CardType.ESCAPE_SUCCESS:
							escape_succeed = true
							server_call.rpc(ServerMessage.SERVER_BROADCAST_MESSAGE, {"message":"Player [" + Global.get_username(current_player.id) + "] escaped!"})
							change_state(current_player, TurnState.ESCAPED)
							if check_all_human_dead_or_escaped():
								server_call.rpc(ServerMessage.SERVER_BROADCAST_MESSAGE, {"message":"All humans escaped! Escaped Humans win!"})
								emit_signal("end_game")
							queried_noise = false
							change_turn()
							return
					print(escape_succeed)
					server_call.rpc(ServerMessage.PLAYER_USE_ESCAPE_POD, {"position":current_player.position,"succeed":escape_succeed})
					if board.zone.available_escape_pods.size() == 0:
						# ran out of escape pods, humans lose
						server_call.rpc(ServerMessage.SERVER_BROADCAST_MESSAGE, {"message":"No more Escape Pods! Aliens win!"})
						emit_signal("end_game")
					queried_noise = false
				elif board.zone.is_dangerous_tile(current_player.position):
					#query deck about noise type
					match Decks.noise_deck.draw_card().type:
						Decks.CardType.NOISE_ANY_SECTOR:
							server_call.rpc_id(current_player.id, ServerMessage.SERVER_BROADCAST_MESSAGE, {"message":"Make a noise at any sector."})
							server_call.rpc_id(current_player.id, ServerMessage.PLAYER_NOISE_ANY_SECTOR)
						Decks.CardType.NOISE_THIS_SECTOR:
							server_call.rpc_id(current_player.id, ServerMessage.PLAYER_NOISE_THIS_SECTOR)
						_:
							server_call.rpc(ServerMessage.SERVER_BROADCAST_MESSAGE, {"message":"Silence in all sectors."})
							queried_noise = false
							change_state(current_player, TurnState.ATTACKING)
				else:
					server_call.rpc(ServerMessage.SERVER_BROADCAST_MESSAGE, {"message" : "Silent sector."})
					queried_noise = false
					change_state(current_player, TurnState.ATTACKING)
		TurnState.USING_ITEM:
			push_warning("TurnState.USING_ITEM: Not implemented yet!")
			pass
		TurnState.ATTACKING:
			if not queried_attack:
				queried_attack = true
				if current_player.can_attack():
					server_call.rpc_id(current_player.id, ServerMessage.PLAYER_ATTACK)
				else:
					queried_attack = false
					change_state(current_player, TurnState.ENDING_TURN)
		TurnState.ENDING_TURN:
			if not queried_end_turn:
				queried_end_turn = true
				server_call.rpc_id(current_player.id, ServerMessage.PLAYER_END_TURN)
		TurnState.WAITING:
			return
		TurnState.DEAD:
			# skip turn if dead
			change_turn()
		TurnState.ESCAPED:
			# skip turn if escaped
			change_turn()
		TurnState.DISCONNECTED:
			# skip turn if disconnected
			change_turn()


func change_turn() -> void:
	# update current player, and start their turn
	var previous_player_turn = current_player_turn
	current_player_turn = (current_player_turn + 1) % players.size()
	if current_player_turn <= previous_player_turn:
		total_turns += 1
		server_call.rpc(ServerMessage.SERVER_BROADCAST_NEXT_TURN, {"turn_number":total_turns})
	
	if total_turns >= 40:
		server_call.rpc(ServerMessage.SERVER_BROADCAST_MESSAGE, {"message":"Turn limit reached: Aliens Win!"})
		emit_signal("end_game")
	
	if not players[current_player_turn].current_state in [TurnState.DEAD, TurnState.ESCAPED, TurnState.DISCONNECTED]:
		server_call.rpc(ServerMessage.SERVER_BROADCAST_PLAYER_TURN, {"player":players[current_player_turn].id})
		change_state(players[current_player_turn], TurnState.MOVING)


func change_state(current_player: Player, new_state: TurnState) -> void:
	current_player.current_state = new_state
	server_call.rpc_id(current_player.id, ServerMessage.PLAYER_SET_TURN_STATE, {"turn_state":new_state})


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
	PLAYER_USE_ESCAPE_POD,
	PLAYER_SET_TURN_STATE,
	SERVER_BROADCAST_MESSAGE,
	SERVER_BROADCAST_PLAYER_TURN,
	SERVER_BROADCAST_NEXT_TURN,
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
		ServerMessage.PLAYER_USE_ESCAPE_POD:
			board.zone.use_escape_pod(payload["position"], payload["succeed"])
		ServerMessage.PLAYER_SET_TURN_STATE:
			board.set_player_turn_state(payload["turn_state"])
		ServerMessage.SERVER_BROADCAST_MESSAGE:
			board.show_message(payload["message"])
		ServerMessage.SERVER_BROADCAST_PLAYER_TURN:
			board.set_player_turn(payload["player"])
		ServerMessage.SERVER_BROADCAST_NEXT_TURN:
			board.set_current_turn(payload["turn_number"])

# called from client onto server. server logic to use client responses
@rpc("any_peer", "reliable", "call_local")
func client_call(message: ClientMessage, payload: Dictionary = {}) -> void:
	var current_player = players[current_player_turn]
	match message:
		ClientMessage.PLAYER_RETURN_MOVEMENT:
			current_player.move_to(payload["new_position"])
			server_call.rpc_id(current_player.id, ServerMessage.PLAYER_UPDATE_POSITION, payload)
			queried_movement = false
			change_state(current_player, TurnState.MAKING_NOISE)
		ClientMessage.PLAYER_RETURN_NOISE:
			server_call.rpc(ServerMessage.SERVER_BROADCAST_MESSAGE, {"message":"Noise at " + board.zone.tile_to_sector(payload["noise_position"]) + "."})
			queried_noise = false
			change_state(current_player, TurnState.ATTACKING)
		ClientMessage.PLAYER_RETURN_ATTACK:
			if payload["should_attack"]:
				#attack
				server_call.rpc(ServerMessage.SERVER_BROADCAST_MESSAGE, {"message": "Player [" + Global.get_username(current_player.id) + "] attacking at " + board.zone.tile_to_sector(current_player.position) + "."})
				for player in players:
					if player == current_player:
						continue
					if player.position == current_player.position:
						# update attacker's moves if they kill a human
						if current_player.team == Team.ALIEN and player.team == Team.HUMAN:
							var new_num_moves = min(current_player.num_moves + 1, 3)
							current_player.num_moves = new_num_moves
							update_num_moves.rpc_id(current_player.id, current_player.num_moves, current_player.position)
						# have the attacked player die
						player.die(board.zone.alien_spawn)
						server_call.rpc_id(player.id, ServerMessage.PLAYER_SET_TURN_STATE, {"turn_state":TurnState.DEAD})
						# check for all humans dead, game over if so
						if check_all_human_dead_or_escaped():
							server_call.rpc(ServerMessage.SERVER_BROADCAST_MESSAGE, {"message":"All humans dead! Aliens win!"})
							emit_signal("end_game")
						# update the state of the attacked player
						update_num_moves.rpc_id(player.id, player.num_moves, player.position)
						server_call.rpc_id(player.id, ServerMessage.PLAYER_UPDATE_POSITION, {"new_position":player.position})
						server_call.rpc(ServerMessage.SERVER_BROADCAST_MESSAGE, {"message":"Player [" + Global.get_username(player.id) + "] has been killed!"})
			queried_attack = false
			change_state(current_player, TurnState.ENDING_TURN)
		ClientMessage.PLAYER_END_TURN:
			server_call.rpc(ServerMessage.SERVER_BROADCAST_MESSAGE, {"message": "Player [" + Global.get_username(current_player.id) + "] ends their turn."})
			queried_end_turn = false
			change_state(current_player, TurnState.WAITING)
			
			change_turn()

func check_all_human_dead_or_escaped() -> bool:
	for player in players:
		if player.team == Team.HUMAN:
			if player.current_state in [TurnState.DEAD, TurnState.ESCAPED, TurnState.DISCONNECTED]:
				continue
			else:
				return false
	return true

#endregion
