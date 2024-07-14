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
	
	var sedated: bool = false
	
	var current_state: Global.TurnState = Global.TurnState.WAITING
	
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
		else: # you are an alien
			current_state = Global.TurnState.DEAD
			num_moves = 0
			
	func check_items(alien_case: bool, item_to_check: ItemResource) -> bool:
		if team == Team.ALIEN: return alien_case
		for item in items:
			if item == item_to_check:
				return true
		return false
	
	func can_attack() -> bool:
		return check_items(true, Item.ATTACK_ITEM)
	
	func can_defend() -> bool:
		return check_items(false, Item.DEFENSE_ITEM)
	
	func can_clone() -> bool:
		return check_items(false, Item.CLONE_ITEM)
	
	func can_cat() -> bool:
		return check_items(false, Item.CAT_ITEM)
	
	func can_adrenaline() -> bool:
		return check_items(false, Item.ADRENALINE_ITEM)
	
	func can_sedatives() -> bool:
		return check_items(false, Item.SEDATIVES_ITEM)
	
	func can_mutate() -> bool:
		return check_items(false, Item.MUTATION_ITEM)
	
	func remove_item(item_to_remove: ItemResource):
		for item in items:
			if item == item_to_remove:
				items.erase(item)
				break
		
#endregion

#region Initialization

var board = null
var players: Array[Player] = []
var current_player_turn: int = 0

signal end_game()

func add_board(p_board) -> void:
	board = p_board
	board.using_item.connect(_on_player_use_item)

func _ready() -> void:
	set_process(multiplayer.is_server())
	set_physics_process(multiplayer.is_server())
	
	if not multiplayer.is_server():
		return
	
	end_game.connect(_on_end_game)
	
	Global.player_disconnected.connect(_on_player_disconnected)
	
	for player in Global.players:
		players.append(Player.new(player))
	
	
	#var num_aliens = ceil(players.size() / 2.0)
	var num_aliens = 0
	
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
	change_state(players[current_player_turn], Global.TurnState.MOVING)

@rpc("reliable", "call_local")
func setup_player(num_moves: int, spawn: Vector2i, is_alien: bool) -> void:
	board.zone.player_num_moves = num_moves
	board.zone.is_alien = is_alien
	board.zone.set_player_position(spawn)

@rpc("reliable", "call_local")
func init_player_list(player_id_list) -> void:
	board.init_player_list(player_id_list)

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
			player.current_state = Global.TurnState.DISCONNECTED
	queried_movement = false
	queried_noise = false
	queried_attack = false
	queried_end_turn = false

#endregion

#region Game Logic

var total_turns: int = 1

var queried_movement: bool = false
var queried_noise: bool = false
var queried_attack: bool = false
var queried_end_turn: bool = false
func _process(_delta) -> void:
	var current_player = players[current_player_turn]
	
	match current_player.current_state:
		Global.TurnState.MOVING:
			if not queried_movement:
				queried_movement = true
				#check for moving items, prompt action first if held item
				if await player_check_item(current_player, current_player.can_adrenaline, Item.ADRENALINE_ITEM):
					# save player so no race conditions on ending move state
					var player = current_player
					server_call.rpc(ServerMessage.SERVER_BROADCAST_MESSAGE, {"message": "Player [" + Global.get_username(player.id) + "] uses Adrenaline!"})
					player.remove_item(Item.ADRENALINE_ITEM)
					server_call.rpc_id(player.id, ServerMessage.PLAYER_REMOVE_ITEM, {"item": inst_to_dict(Item.ADRENALINE_ITEM)})
					player.num_moves += 1
					update_num_moves.rpc_id(player.id, player.num_moves, player.position)
					server_call.rpc_id(player.id, ServerMessage.PLAYER_MOVEMENT)
					await end_state
					player.num_moves -= 1
					update_num_moves.rpc_id(player.id, player.num_moves, player.position)
					# exit early, so no extra move
					return
				if await player_check_item(current_player, current_player.can_sedatives, Item.SEDATIVES_ITEM):
					current_player.sedated = true
					server_call.rpc(ServerMessage.SERVER_BROADCAST_MESSAGE, {"message": "Player [" + Global.get_username(current_player.id) + "] uses Sedatives!"})
					current_player.remove_item(Item.SEDATIVES_ITEM)
					server_call.rpc_id(current_player.id, ServerMessage.PLAYER_REMOVE_ITEM, {"item": inst_to_dict(Item.SEDATIVES_ITEM)})
				server_call.rpc_id(current_player.id, ServerMessage.PLAYER_MOVEMENT)
		Global.TurnState.MAKING_NOISE:
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
							change_state(current_player, Global.TurnState.ESCAPED)
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
				elif current_player.sedated:
					current_player.sedated = false
					queried_noise = false
					change_state(current_player, Global.TurnState.ATTACKING)
				elif board.zone.is_dangerous_tile(current_player.position):
					#check for cat item, prompt use if held
					if await player_check_item(current_player, current_player.can_cat, Item.CAT_ITEM):
						server_call.rpc(ServerMessage.SERVER_BROADCAST_MESSAGE, {"message": "Player [" + Global.get_username(current_player.id) + "] uses Cat!"})
						var force_position_card = Decks.noise_deck.draw_card(true)
						var force_current_position = force_position_card.type == Decks.CardType.NOISE_THIS_SECTOR
						
						server_call.rpc_id(current_player.id, ServerMessage.PLAYER_USE_CAT, {"force_current_position": force_current_position})
						await finished_prompt_item
						
						current_player.remove_item(Item.CAT_ITEM)
						server_call.rpc_id(current_player.id, ServerMessage.PLAYER_REMOVE_ITEM, {"item": inst_to_dict(Item.CAT_ITEM)})
						
						queried_noise = false
						change_state(current_player, Global.TurnState.ATTACKING)
						#end noise state early
						return
						#fall through if not using cat
					#query deck about noise type
					var card = Decks.noise_deck.draw_card()
					match card.type:
						Decks.CardType.NOISE_ANY_SECTOR:
							server_call.rpc_id(current_player.id, ServerMessage.SERVER_BROADCAST_MESSAGE, {"message":"Make a noise at any sector."})
							server_call.rpc_id(current_player.id, ServerMessage.PLAYER_NOISE_ANY_SECTOR)
						Decks.CardType.NOISE_THIS_SECTOR:
							server_call.rpc_id(current_player.id, ServerMessage.PLAYER_NOISE_THIS_SECTOR)
						_:
							server_call.rpc(ServerMessage.SERVER_BROADCAST_MESSAGE, {"message":"Silence in all sectors."})
							if card.item:
								current_player.items.append(card.item)
								server_call.rpc_id(current_player.id, ServerMessage.PLAYER_ADD_ITEM, {"item":inst_to_dict(card.item)})
							queried_noise = false
							change_state(current_player, Global.TurnState.ATTACKING)
				else:
					server_call.rpc(ServerMessage.SERVER_BROADCAST_MESSAGE, {"message" : "Silent sector."})
					queried_noise = false
					change_state(current_player, Global.TurnState.ATTACKING)
		Global.TurnState.USING_ITEM:
			push_warning("TurnState.USING_ITEM: Not implemented yet!")
			pass
		Global.TurnState.ATTACKING:
			if not queried_attack:
				queried_attack = true
				if await player_check_item(current_player, current_player.can_mutate, Item.MUTATION_ITEM):
					mutate_player(current_player)
				if current_player.can_attack():
					server_call.rpc_id(current_player.id, ServerMessage.PLAYER_ATTACK)
				else:
					queried_attack = false
					change_state(current_player, Global.TurnState.ENDING_TURN)
		Global.TurnState.ENDING_TURN:
			if not queried_end_turn:
				queried_end_turn = true
				server_call.rpc_id(current_player.id, ServerMessage.PLAYER_END_TURN)
		Global.TurnState.WAITING:
			return
		Global.TurnState.DEAD:
			print("player dead")
			change_turn()
		Global.TurnState.ESCAPED:
			print("player escaped")
			change_turn()
		Global.TurnState.DISCONNECTED:
			print("player disconnected")
			change_turn()

func player_check_item(current_player: Player, check_function: Callable, item: ItemResource) -> bool:
	if check_function.call():
		server_call.rpc_id(current_player.id, ServerMessage.PLAYER_PROMPT_ITEM, {"item": inst_to_dict(item)})
		var using_item = await finished_prompt_item
		if using_item:
			print("using ", item.name)
		return using_item
	return false

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
	
	if not players[current_player_turn].current_state in [Global.TurnState.DEAD, Global.TurnState.ESCAPED, Global.TurnState.DISCONNECTED]:
		server_call.rpc(ServerMessage.SERVER_BROADCAST_PLAYER_TURN, {"player":players[current_player_turn].id})
		change_state(players[current_player_turn], Global.TurnState.MOVING)


func change_state(current_player: Player, new_state: Global.TurnState) -> void:
	current_player.current_state = new_state
	server_call.rpc_id(current_player.id, ServerMessage.PLAYER_SET_TURN_STATE, {"turn_state":new_state})


@rpc("reliable", "call_local")
func update_num_moves(new_num_moves: int, player_position: Vector2i) -> void:
	board.zone.player_num_moves = new_num_moves
	board.zone.update_possible_moves(player_position, new_num_moves)


func mutate_player(current_player: Player) -> void:
	server_call.rpc(ServerMessage.SERVER_BROADCAST_MESSAGE, {"message": "Player [" + Global.get_username(current_player.id) + "] uses Mutation!"})
	current_player.team = Team.ALIEN
	current_player.num_moves = 2
	server_call.rpc_id(current_player.id, ServerMessage.PLAYER_UPDATE_TEAM, {"is_alien": true})
	update_num_moves.rpc_id(current_player.id, current_player.num_moves, current_player.position)
	if check_all_human_dead_or_escaped():
		server_call.rpc(ServerMessage.SERVER_BROADCAST_MESSAGE, {"message":"No more humans! Aliens win!"})
		emit_signal("end_game")
		return


func _on_player_use_item(item: ItemResource):
	client_call.rpc_id(SERVER, ClientMessage.PLAYER_USE_ITEM, {"item": inst_to_dict(item)})

enum ServerMessage {
	PLAYER_MOVEMENT,
	PLAYER_NOISE_THIS_SECTOR,
	PLAYER_NOISE_ANY_SECTOR,
	PLAYER_UPDATE_POSITION,
	PLAYER_UPDATE_TEAM,
	PLAYER_ATTACK,
	PLAYER_END_TURN,
	PLAYER_USE_ESCAPE_POD,
	PLAYER_SET_TURN_STATE,
	PLAYER_ADD_ITEM,
	PLAYER_REMOVE_ITEM,
	PLAYER_PROMPT_ITEM,
	PLAYER_USE_CAT,
	PLAYER_USE_SPOTLIGHT,
	SERVER_BROADCAST_MESSAGE,
	SERVER_BROADCAST_PLAYER_TURN,
	SERVER_BROADCAST_NEXT_TURN,
}

enum ClientMessage {
	PLAYER_RETURN_MOVEMENT,
	PLAYER_RETURN_NOISE,
	PLAYER_RETURN_ATTACK,
	PLAYER_END_TURN,
	PLAYER_PROMPT_ITEM,
	PLAYER_USE_ITEM,
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
		ServerMessage.PLAYER_UPDATE_TEAM:
			board.zone.is_alien = payload["is_alien"]
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
		ServerMessage.PLAYER_ADD_ITEM:
			board.add_item(dict_to_inst(payload["item"]))
		ServerMessage.PLAYER_REMOVE_ITEM:
			board.remove_item(dict_to_inst(payload["item"]))
		ServerMessage.PLAYER_PROMPT_ITEM:
			var use_item = await board.prompt_item(dict_to_inst(payload["item"]))
			client_call.rpc_id(SERVER, ClientMessage.PLAYER_PROMPT_ITEM, {"to_use": use_item})
		ServerMessage.PLAYER_USE_CAT:
			var sectors = await board.use_cat(payload["force_current_position"])
			client_call.rpc_id(SERVER, ClientMessage.PLAYER_RETURN_NOISE, {"noise_position": sectors[0], "end_state": false})
			client_call.rpc_id(SERVER, ClientMessage.PLAYER_RETURN_NOISE, {"noise_position": sectors[1], "end_state": true})
			client_call.rpc_id(SERVER, ClientMessage.PLAYER_PROMPT_ITEM, {"to_use": null})
		ServerMessage.PLAYER_USE_SPOTLIGHT:
			var sectors = await board.use_spotlight()

signal finished_prompt_item(use_item)
signal end_state()

# called from client onto server. server logic to use client responses
@rpc("any_peer", "reliable", "call_local")
func client_call(message: ClientMessage, payload: Dictionary = {}) -> void:
	var current_player = players[current_player_turn]
	match message:
		ClientMessage.PLAYER_RETURN_MOVEMENT:
			current_player.move_to(payload["new_position"])
			server_call.rpc_id(current_player.id, ServerMessage.PLAYER_UPDATE_POSITION, payload)
			end_state.emit()
			queried_movement = false
			change_state(current_player, Global.TurnState.MAKING_NOISE)
		ClientMessage.PLAYER_RETURN_NOISE:
			server_call.rpc(ServerMessage.SERVER_BROADCAST_MESSAGE, {"message":"Noise at " + board.zone.tile_to_sector(payload["noise_position"]) + "."})
			if payload["end_state"]:
				queried_noise = false
				change_state(current_player, Global.TurnState.ATTACKING)
		ClientMessage.PLAYER_RETURN_ATTACK:
			if payload["should_attack"]:
				#attack
				server_call.rpc(ServerMessage.SERVER_BROADCAST_MESSAGE, {"message": "Player [" + Global.get_username(current_player.id) + "] attacks at " + board.zone.tile_to_sector(current_player.position) + "."})
				# a human with attack card
				if current_player.team == Team.HUMAN:
					current_player.remove_item(Item.ATTACK_ITEM)
					server_call.rpc_id(current_player.id, ServerMessage.PLAYER_REMOVE_ITEM, {"item":inst_to_dict(Item.ATTACK_ITEM)})
				for player in players:
					if player == current_player:
						continue
					if player.position == current_player.position:
						# defend card
						if player.can_defend():
							player.remove_item(Item.DEFENSE_ITEM)
							server_call.rpc_id(player.id, ServerMessage.PLAYER_REMOVE_ITEM, {"item":inst_to_dict(Item.DEFENSE_ITEM)})
							server_call.rpc(ServerMessage.SERVER_BROADCAST_MESSAGE, {"message":"Player [" + Global.get_username(player.id) + "] defends against the attack!"})
							continue
						# clone card
						if player.can_clone():
							player.remove_item(Item.CLONE_ITEM)
							server_call.rpc_id(player.id, ServerMessage.PLAYER_REMOVE_ITEM, {"item":inst_to_dict(Item.CLONE_ITEM)})
							server_call.rpc(ServerMessage.SERVER_BROADCAST_MESSAGE, {"message":"Player [" + Global.get_username(player.id) + "] clones themselves!"})
							player.position = board.zone.human_spawn
							server_call.rpc_id(player.id, ServerMessage.PLAYER_UPDATE_POSITION, {"new_position":player.position})
							continue
						# update attacker's moves if they kill a human
						if current_player.team == Team.ALIEN and player.team == Team.HUMAN:
							var new_num_moves = min(current_player.num_moves + 1, 3)
							current_player.num_moves = new_num_moves
							update_num_moves.rpc_id(current_player.id, current_player.num_moves, current_player.position)
						# have the attacked player die
						server_call.rpc(ServerMessage.SERVER_BROADCAST_MESSAGE, {"message":"Player [" + Global.get_username(player.id) + "] has been killed!"})
						player.die(board.zone.alien_spawn)
						server_call.rpc_id(player.id, ServerMessage.PLAYER_SET_TURN_STATE, {"turn_state":Global.TurnState.DEAD})
						# check for all humans dead, game over if so
						if check_all_human_dead_or_escaped():
							server_call.rpc(ServerMessage.SERVER_BROADCAST_MESSAGE, {"message":"All humans dead! Aliens win!"})
							emit_signal("end_game")
							return
						# update the state of the attacked player
						update_num_moves.rpc_id(player.id, player.num_moves, player.position)
						server_call.rpc_id(player.id, ServerMessage.PLAYER_UPDATE_POSITION, {"new_position":player.position})
						server_call.rpc_id(player.id, ServerMessage.PLAYER_UPDATE_TEAM, {"is_alien": player.team == Team.ALIEN})
			queried_attack = false
			change_state(current_player, Global.TurnState.ENDING_TURN)
		ClientMessage.PLAYER_END_TURN:
			server_call.rpc(ServerMessage.SERVER_BROADCAST_MESSAGE, {"message": "Player [" + Global.get_username(current_player.id) + "] ends their turn."})
			queried_end_turn = false
			change_state(current_player, Global.TurnState.WAITING)
			
			change_turn()
		ClientMessage.PLAYER_PROMPT_ITEM:
			finished_prompt_item.emit(payload["to_use"])
		ClientMessage.PLAYER_USE_ITEM:
			# the only items that should get to this point are: teleport, spotlight, sensor, and mutation.
			var item = dict_to_inst(payload["item"])
			print(item.name)
			current_player.remove_item(item)
			server_call.rpc_id(current_player.id, ServerMessage.PLAYER_REMOVE_ITEM, {"item": inst_to_dict(item)})
			if item.name == "Mutation":
				mutate_player(current_player)
			elif item.name == "Teleport":
				server_call.rpc(ServerMessage.SERVER_BROADCAST_MESSAGE, {"message": "Player [" + Global.get_username(current_player.id) + "] uses Teleportation!"})
				current_player.position = board.zone.human_spawn
				server_call.rpc_id(current_player.id, ServerMessage.PLAYER_UPDATE_POSITION, {"new_position": current_player.position})
			elif item.name == "Spotlight":
				pass
			elif item.name == "Sensor":
				pass
			else:
				push_error("You can't use this item, silly!")
			

func check_all_human_dead_or_escaped() -> bool:
	for player in players:
		if player.team == Team.HUMAN:
			if player.current_state in [Global.TurnState.DEAD, Global.TurnState.ESCAPED, Global.TurnState.DISCONNECTED]:
				continue
			else:
				return false
	return true

#endregion
