extends Control

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

func _on_item_removed(item_node: Node, category: Node) -> void:
	if category.get_child_count() <= 2: # item has not been removed yet, so item + title
		category.hide()

func _on_item_added(item_node: Node, category: Node) -> void:
	if category.get_child_count() >= 2:
		category.show()

func add_item(item_resource: ItemResource):
	pass

func remove_item(item_resource: ItemResource):
	pass
