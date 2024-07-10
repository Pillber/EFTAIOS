extends Control

@export var lifetime = 7.5

func _ready() -> void:
	await get_tree().create_timer(lifetime).timeout
	
	queue_free()


func set_message_text(text: String) -> void:
	$Text.text = text
