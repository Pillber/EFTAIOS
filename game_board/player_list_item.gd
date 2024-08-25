extends Control

enum Team {
	HUMAN,
	ALIEN,
	EMPTY
}

var steam_id: int = -1
var id: int = -1
var team: Team = Team.EMPTY
var team_lock: bool = false


func set_player_name(player_name: String) -> void:
	$Panel/Align/PlayerName.text = player_name


func set_current_player(value: bool) -> void:
	$Panel/CurrentTurn.visible = value

func set_team_lock() -> void:
	team_lock = true


func set_team(new_team: Team) -> void:
	if team_lock:
		return
	team = new_team
	const team_string = ['H', 'A', '']
	$Panel/Align/PlayerAvatar/HumanAlien.text = team_string[new_team]


func set_ids(player_id: int, steam_id: int) -> void:
	self.id = player_id
	self.steam_id = steam_id

func _on_avatar_loaded(steam_id: int, avatar_size, avatar_texture: ImageTexture) -> void:
	if steam_id == self.steam_id and avatar_size == Steam.AVATAR_MEDIUM:
		$Panel/Align/PlayerAvatar.texture = avatar_texture
