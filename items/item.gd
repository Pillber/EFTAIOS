extends Control
class_name Item

# attack items
static var ATTACK_ITEM = preload("res://items/attack_item.tres")

# defense items
static var DEFENSE_ITEM = preload("res://items/defense_item.tres")
static var CLONE_ITEM = preload("res://items/clone_item.tres")

# noise items
static var CAT_ITEM = preload("res://items/cat_item.tres")

# moving items
static var ADRENALINE_ITEM = preload("res://items/adrenaline_item.tres")
static var SEDATIVES_ITEM = preload("res://items/sedatives_item.tres")

# anytime items
static var MUTATION_ITEM = preload("res://items/mutation_item.tres")
static var TELEPORT_ITEM = preload("res://items/teleport_item.tres")
static var SENSOR_ITEM = preload("res://items/sensor_item.tres")
static var SPOTLIGHT_ITEM = preload("res://items/spotlight_item.tres")

@onready var button = $Button

var resource: ItemResource

signal use_item(item: ItemResource)

func _ready() -> void:
	button.pressed.connect(_on_use_item)

func set_resource(p_resource: ItemResource) -> void:
	resource = p_resource
	button.text = p_resource.name

func update_useable(turn_state: Global.TurnState) -> void:
	button.disabled = not resource.is_useable(turn_state)

func _on_use_item() -> void:
	emit_signal("use_item", resource)
