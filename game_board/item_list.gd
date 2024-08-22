extends Control

const ITEM = preload("res://items/item.tscn")

@onready var moving = $Panel/VAlign/MovingContainer
@onready var attacking = $Panel/VAlign/AttackingContainer
@onready var noise = $Panel/VAlign/NoiseContainer
@onready var at_will = $Panel/VAlign/AtWillContainer

signal use_item(item_resource)

func _ready() -> void:
	moving.child_entered_tree.connect(_on_item_added.bind(moving))
	attacking.child_entered_tree.connect(_on_item_added.bind(attacking))
	noise.child_entered_tree.connect(_on_item_added.bind(noise))
	at_will.child_entered_tree.connect(_on_item_added.bind(at_will))
	
	moving.child_exiting_tree.connect(_on_item_removed.bind(moving))
	attacking.child_exiting_tree.connect(_on_item_removed.bind(attacking))
	noise.child_exiting_tree.connect(_on_item_removed.bind(noise))
	at_will.child_exiting_tree.connect(_on_item_removed.bind(at_will))

func update_all_items_useable(turn_state: Global.TurnState, is_alien: bool):
	var all_groups = [moving, attacking, noise, at_will]
	for group in all_groups:
		for item in get_items(group):
			item.update_useable(Global.TurnState.WAITING if is_alien else turn_state)

func get_items(group: VBoxContainer):
	return group.get_children().filter(func(child): return child is Item)


func get_item_group(item_resource) -> VBoxContainer:
	match item_resource.useable_turn_state:
		item_resource.UseableStates.MOVING:
			return moving
		item_resource.UseableStates.ATTACKING:
			return attacking
		item_resource.UseableStates.NOISE:
			return noise
		item_resource.UseableStates.AT_WILL:
			return at_will
	push_error("No matching turn state")
	return null

func add_item(item_resource: ItemResource):
	var item_scene = ITEM.instantiate()
	var group = get_item_group(item_resource)
	group.add_child(item_scene)
	item_scene.set_resource(item_resource)
	item_scene.use_item.connect(_on_use_item)
	

func remove_item(item_resource: ItemResource):
	var group = get_item_group(item_resource)
	for item in get_items(group):
		if item.resource.name == item_resource.name:
			item.use_item.disconnect(_on_use_item)
			item.queue_free()
			break

func _on_use_item(resource):
	use_item.emit(resource)

func _on_item_removed(item_node: Node, category: Node) -> void:
	if category.get_child_count() <= 2: # item has not been removed yet, so item + title
		category.hide()

func _on_item_added(item_node: Node, category: Node) -> void:
	if category.get_child_count() >= 2:
		category.show()
