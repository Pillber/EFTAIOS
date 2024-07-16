extends Control

func _ready() -> void:
	hide()

func pop_up(text: String) -> void:
	$BackgroundPanel/Text.text = text
	show()

func close() -> void:
	hide()
