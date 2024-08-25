@tool
extends TileMap
class_name Zone

#region Constants
const BOARD_LAYER: int = 0
const PLAYER_LAYER: int = 1

const BOARD_SOURCE_ID = 0
const SPECIALS_SOURCE_ID = 1
const PLAYER_SOURCE_ID = 2
#endregion

@export var human_spawn: Vector2i = Vector2i.ZERO
@export var alien_spawn: Vector2i = Vector2i.ZERO
@export var escape_pods: Array[Vector2i] = []

# all possible moves from current position
var possible_moves: Array[Vector2i] = []

# special tiles for validity checks
var used_board_tiles: Array[Vector2i]
var available_escape_pods: Array[Vector2i]
var player_position: Vector2i
var player_num_moves: int = 1
var is_alien: bool = false

func _ready() -> void:
	setup_board()

func setup_board() -> void:
	# get tiles
	used_board_tiles = get_used_cells(BOARD_LAYER)
	available_escape_pods = escape_pods.duplicate(true)
	
	# add label to normal tiles
	for tile in used_board_tiles:
		if get_cell_source_id(BOARD_LAYER, tile) == SPECIALS_SOURCE_ID:
			continue
		add_label_to_tile(tile, tile_to_sector(tile), Color.BLACK, 24)
	
	# label escape pods
	var index = 1
	for pod in escape_pods:
		add_label_to_tile(pod, str(index), Color.WHITE, 32)
		index += 1


func add_label_to_tile(tile: Vector2i, label_text: String, label_color: Color, font_size: int = -1) -> void:
	# make the label and add it to scene
	var tile_label = make_label(label_text, label_color, font_size)
	tile_label.name = label_text
	add_child(tile_label)
	# position label in center of tile
	tile_label.global_position = to_global(map_to_local(tile)) - Vector2(tile_label.size.x / 2, tile_label.size.y / 2)


func make_label(label_text: String, label_color: Color, font_size: int = -1) -> Label:
	var label := Label.new()
	label.text = label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.set("theme_override_colors/font_color", label_color)
	if font_size != -1: label.set("theme_override_font_sizes/font_size", font_size)
	return label


func get_tile_at_mouse() -> Vector2i:
	var mouse_pos = get_global_mouse_position()
	return local_to_map(mouse_pos)

# make static???
func tile_to_sector(tile: Vector2i) -> String:
	if tile.x < 0 || tile.y < 0 || tile.x > 25 || tile.y > 99:
		return ""
	return "%c%02d" % [65 + tile.x, tile.y]


func get_adjecent_tiles(tile: Vector2i) -> Array[Vector2i]:
	var top = Vector2i(tile.x, tile.y - 1)
	var bottom = Vector2i(tile.x, tile.y + 1)
	var left_top = Vector2i(tile.x - 1, tile.y)
	var left_bottom = Vector2i(tile.x - 1, tile.y + 1)
	var right_top = Vector2i(tile.x + 1, tile.y)
	var right_bottom = Vector2i(tile.x + 1, tile.y + 1)
	return [tile, top, bottom, left_top, left_bottom, right_top, right_bottom]


func is_dangerous_tile(tile: Vector2i) -> bool:
	return tile in get_used_cells_by_id(BOARD_LAYER, BOARD_SOURCE_ID, Vector2i(1, 0))


func is_escape_pod(tile: Vector2i) -> bool:
	return tile in available_escape_pods


func get_escape_pod(tile: Vector2i) -> int:
	var index = 1
	for pod in escape_pods:
		if tile == pod:
			return index
		index += 1
	return -1


func use_escape_pod(tile: Vector2i, succeed: bool) -> void:
	# deleting escape pod screws up finding
	set_cell(BOARD_LAYER, tile, SPECIALS_SOURCE_ID, Vector2i(0, 0), 2 if succeed else 1)
	available_escape_pods.erase(tile)


func set_player_position(new_position: Vector2i) -> void:
	player_position = new_position
	set_cell(PLAYER_LAYER, new_position, PLAYER_SOURCE_ID, Vector2i(0, 0), 1)
	update_possible_moves(new_position, player_num_moves)


func move_player(new_position: Vector2i) -> void:
	# erase old player
	erase_cell(PLAYER_LAYER, player_position)
	# set new player position
	set_player_position(new_position)


func update_possible_moves(center_position: Vector2i, num_moves: int = 1, first_iteration: bool = true) -> void:
	# reset array if necessary
	if first_iteration:
		possible_moves.clear()
		# if there should be no moves, stop right then and there
		if num_moves == 0:
			update_move_radius()
			return
	
	var possible_moves_from_here: Array[Vector2i] = []
	
	# get all possible moves from center position
	var surrounding_sectors = get_surrounding_cells(center_position)
	var valid_surrounding_sectors = get_valid_moves(surrounding_sectors)
	possible_moves_from_here.append_array(valid_surrounding_sectors)
	
	# add those moves to the total possible moves
	possible_moves.append_array(valid_surrounding_sectors)
	
	# if done recursing, stop (and update if haven't already)
	if num_moves <= 1:
		if first_iteration:
			update_move_radius()
		return
	
	# otherwise, we still have moves left, recurse
	for move in possible_moves_from_here:
		update_possible_moves(move, num_moves - 1, false)
	
	# update the radius when done
	update_move_radius()


func get_valid_moves(new_moves: Array[Vector2i]) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for move in new_moves:
		if move in possible_moves:
			#print("Already possible")
			continue
		elif not move in used_board_tiles:
			#print("Not on board")
			continue
		elif move == alien_spawn:
			#print("Alien spawn")
			continue
		elif move == human_spawn:
			#print("Human spawn")
			continue
		elif move == player_position:
			#print("Already there")
			continue
		elif is_alien and move in escape_pods:
			#print("escape pod, unusable by aliens")
			continue
		elif move in escape_pods and not move in available_escape_pods:
			#print("used escape pod, unuseable by all")
			continue
		result.append(move)
	return result


func clear_move_radius() -> void:
	var old_radius = get_used_cells_by_id(PLAYER_LAYER, PLAYER_SOURCE_ID, Vector2i(0, 0), 2)
	for old_sector in old_radius:
		erase_cell(PLAYER_LAYER, old_sector)


func update_move_radius() -> void:
	clear_move_radius()
	
	#print("updating radius: ", possible_moves)
	for possible_move in possible_moves:
		set_cell(PLAYER_LAYER, possible_move, PLAYER_SOURCE_ID, Vector2i(0, 0), 2)
