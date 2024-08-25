extends Control

var radius: float = 100.0
var num_players: int = -1

func init(players: Array) -> void:
	num_players = players.size()
	var index = 0
	for player_id in players:
		var item = TextureButton.new()
		#item.name = str(Global.players[player_id]['steam_id'])
		item.texture_normal = load("res://icon.svg")
		item.pressed.connect(_on_player_selected.bind(player_id))
		add_child(item)
		place_item(item, index)
		index += 1


func place_item(item: TextureButton, index: int) -> void:
	var segment = 2 * PI / num_players
	var current_segment = segment * index
	print(current_segment)
	var offset = Vector2(cos(current_segment), sin(current_segment)) * radius
	var center_offset = Vector2(-16, -16)
	print(offset)
	item.position += offset + center_offset
	pass


func _on_player_selected(player_id):
	hide()
	print(player_id)

func _on_avatar_loaded(steam_id: int, avatar_size: int, avatar_texture: ImageTexture) -> void:
	if avatar_size == Steam.AVATAR_SMALL:
		#get_node(str(steam_id)).texture_normal = avatar_texture
		pass
