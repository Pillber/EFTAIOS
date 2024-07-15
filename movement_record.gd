extends Control

const TURN_ITEM = preload("res://game_board/turn_item.tscn")

@onready var turns = $BackgroundPanel/VAlign/Scroll/Turns

signal close_movement_record

func _ready() -> void:
	hide()
	$BackgroundPanel/VAlign/TopBar/CloseButton.pressed.connect(func(): close_movement_record.emit())

func add_turn(turn_number: int) -> void:
	var turn = TURN_ITEM.instantiate()
	turn.name = str(turn_number)
	turn.set_turn_number(turn_number)
	
	turns.add_child(turn)

func set_turn_sector(turn_number: int, sector: String) -> void:
	var turn = turns.get_node(str(turn_number))
	turn.set_sector(sector)

func set_turn_attack(turn_number: int) -> void:
	var turn = turns.get_node(str(turn_number))
	turn.set_attack()
