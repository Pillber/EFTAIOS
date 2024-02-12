extends Control

const VIRTUAL_PORT: int = 0

var lobby_id: int = 0
var lobby_members: Array = []

@onready var lobby_id_edit: LineEdit = $HostJoin/HostJoinContainer/LobbyID
@onready var message_line: LineEdit = $LobbyMainScreen/Players/MessagesAndPlayerList/MessagesContainer/MessageEdit/MessageLine
@onready var messages: TextEdit = $LobbyMainScreen/Players/MessagesAndPlayerList/MessagesContainer/Messages
@onready var player_list: VBoxContainer = $LobbyMainScreen/Players/MessagesAndPlayerList/PlayerScroll/PlayerList


func _ready() -> void:
	$HostJoin.show()
	$LobbyMainScreen.hide()
	
	Steam.lobby_created.connect(_on_lobby_created)
	Steam.lobby_joined.connect(_on_lobby_joined)
	Steam.lobby_chat_update.connect(_on_lobby_updated)
	Steam.persona_state_change.connect(_on_persona_changed)
	Steam.lobby_message.connect(_on_lobby_message)
	
	$HostJoin/HostJoinContainer/HostButton.pressed.connect(_on_host_game)
	$HostJoin/HostJoinContainer/JoinButton.pressed.connect(_on_join_game)
	$LobbyMainScreen/Players/ReadyButton.pressed.connect(_on_ready_pressed)
	$LobbyMainScreen/Players/StartButton.pressed.connect(_on_start_game)
	$LobbyMainScreen/Players/MessagesAndPlayerList/MessagesContainer/MessageEdit/SendMessage.pressed.connect(_on_send_message)
	message_line.text_submitted.connect(_on_send_message)
	
	multiplayer.peer_connected.connect(Global._on_player_connected)
	multiplayer.peer_disconnected.connect(Global._on_player_disconnected)
	multiplayer.connected_to_server.connect(Global._on_connected_to_server)
	multiplayer.server_disconnected.connect(Global._on_server_disconnected)
	multiplayer.connection_failed.connect(Global._on_connection_failed)


func update_player_list() -> void:
	for child in player_list.get_children():
		player_list.remove_child(child)
	
	var num_members = Steam.getNumLobbyMembers(lobby_id)
	
	for member in range(num_members):
		var member_id = Steam.getLobbyMemberByIndex(lobby_id, member)
		var member_name = Steam.getFriendPersonaName(member_id)
		var new_player := Label.new()
		new_player.text = member_name
		player_list.add_child(new_player)


func host_game() -> void:
	print("Hosting game!")
	var peer := SteamMultiplayerPeer.new()
	var host_created = peer.create_host(VIRTUAL_PORT, [])
	if host_created != Error.OK:
		print("Hosting failed")
	multiplayer.multiplayer_peer = peer


func join_game(owner_id: int) -> void:
	print("Joining game!")
	var peer := SteamMultiplayerPeer.new()
	var client_created = peer.create_client(owner_id, VIRTUAL_PORT, [])
	
	match client_created:
			Error.ERR_CANT_CREATE:
				print("Can't create client")
			Error.ERR_CANT_CONNECT:
				print("Can't connect")
	
	multiplayer.multiplayer_peer = peer

func _on_host_game() -> void:
	if lobby_id == 0:
		Steam.createLobby(Steam.LOBBY_TYPE_FRIENDS_ONLY, Global.MAX_PLAYERS_PER_GAME)


func _on_join_game() -> void:
	var id = int(lobby_id_edit.text)
	if lobby_id == 0 and not lobby_id_edit.text.is_empty():
		Steam.joinLobby(id)


func _on_ready_pressed():
	_on_send_message("readied up!")


func _on_start_game() -> void:
	Steam.setLobbyJoinable(lobby_id, false)
	print("Starting game!")
	Global.emit_signal("start_game")


func _on_lobby_created(connection_result: int, new_lobby_id: int) -> void:
	if connection_result == Steam.RESULT_OK:
		lobby_id = new_lobby_id
		
		print("Creating lobby: ", lobby_id)
		
		Steam.setLobbyJoinable(lobby_id, true)
		
		Steam.setLobbyData(lobby_id, "name", Global.steam_username + "'s Lobby")
		Steam.setLobbyData(lobby_id, "mode", "testing")
		
		var relay_enabled = Steam.allowP2PPacketRelay(true)
		print("P2P relay enabled?: ", relay_enabled)
		
		$LobbyMainScreen/Players/StartButton.show()
		
		host_game()


func _on_lobby_joined(new_lobby_id: int, _permissions: int, _locked: bool, connection_result: int) -> void:
	if connection_result == Steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		
		$HostJoin.hide()
		$LobbyMainScreen.show()
		
		lobby_id = new_lobby_id
		
		print("Joining lobby: ", lobby_id)
		
		update_player_list()
		
		var lobby_owner = Steam.getLobbyOwner(lobby_id)
		if Global.steam_id != lobby_owner:
			join_game(lobby_owner)
		
		Global.add_self_to_players()
		
	else:
		var fail_reason: String
		match connection_result:
			Steam.CHAT_ROOM_ENTER_RESPONSE_DOESNT_EXIST: fail_reason = "This lobby no longer exists."
			Steam.CHAT_ROOM_ENTER_RESPONSE_NOT_ALLOWED: fail_reason = "You don't have permission to join this lobby."
			Steam.CHAT_ROOM_ENTER_RESPONSE_FULL: fail_reason = "The lobby is now full."
			Steam.CHAT_ROOM_ENTER_RESPONSE_ERROR: fail_reason = "Uh... something unexpected happened!"
			Steam.CHAT_ROOM_ENTER_RESPONSE_BANNED: fail_reason = "You are banned from this lobby."
			Steam.CHAT_ROOM_ENTER_RESPONSE_LIMITED: fail_reason = "You cannot join due to having a limited account."
			Steam.CHAT_ROOM_ENTER_RESPONSE_CLAN_DISABLED: fail_reason = "This lobby is locked or disabled."
			Steam.CHAT_ROOM_ENTER_RESPONSE_COMMUNITY_BAN: fail_reason = "This lobby is community locked."
			Steam.CHAT_ROOM_ENTER_RESPONSE_MEMBER_BLOCKED_YOU: fail_reason = "A user in the lobby has blocked you from joining."
			Steam.CHAT_ROOM_ENTER_RESPONSE_YOU_BLOCKED_MEMBER: fail_reason = "A user you have blocked is in the lobby."
		print("Failed to join lobby: ", fail_reason)


func _on_lobby_updated(_changed_lobby_id: int, change_id: int, _making_change_id: int, change: int) -> void:
	var username: String = Steam.getFriendPersonaName(change_id)
	if change == Steam.CHAT_MEMBER_STATE_CHANGE_ENTERED:
		print(username, " has entered the lobby")
		update_player_list()
	elif change == Steam.CHAT_MEMBER_STATE_CHANGE_DISCONNECTED:
		print(username, " has left the lobby")
		update_player_list()


func _on_persona_changed(_changed_id: int, _flag: int) -> void:
	if not lobby_id == 0:
		update_player_list()


func _on_lobby_message(sent_lobby_id: int, sender_id: int, message: String, chat_type: int) -> void:
	if lobby_id == sent_lobby_id and chat_type == Steam.CHAT_ENTRY_TYPE_CHAT_MSG:
		var sender_username = Steam.getFriendPersonaName(sender_id)
		messages.text += "[" + str(sender_username) + "]: " + message + "\n"


func _on_send_message(message_text: String = "") -> void:
	message_text = message_line.text if message_text.is_empty() else message_text
	if not message_text.is_empty():
		var sent = Steam.sendLobbyChatMsg(lobby_id, message_text)
		if not sent:
			print("Message failed to send!")
		else:
			message_line.clear()
