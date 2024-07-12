extends Control

var id: int = -1
var steam_id: int = -1

func _ready() -> void:
	Steam.getPlayerAvatar(Steam.AVATAR_MEDIUM, steam_id)
	Steam.avatar_loaded.connect(_on_loaded_avatar)


func set_id(player_id: int) -> void:
	id = player_id
	steam_id = Global.players[player_id]["steam_id"]


func set_player_name(player_name: String) -> void:
	$Panel/Align/PlayerName.text = player_name


func set_current_player(value: bool) -> void:
	$Panel/CurrentTurn.visible = value


func _on_loaded_avatar(user_steam_id: int, avatar_size: int, avatar_buffer: PackedByteArray) -> void:
	if steam_id == user_steam_id:
		var avatar_image = Image.create_from_data(avatar_size, avatar_size, false, Image.FORMAT_RGBA8, avatar_buffer)
		
		var avatar_texture = ImageTexture.create_from_image(avatar_image)
		
		$Panel/Align/PlayerAvatar.set_texture(avatar_texture)
