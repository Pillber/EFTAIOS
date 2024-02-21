extends Control

signal finished(confirmed)

func _ready() -> void:
	$Panel/CenterContainer/VBoxContainer/ConfirmButton.pressed.connect(
		func(): 
			emit_signal("finished", true)
			hide())
	$Panel/CenterContainer/VBoxContainer/DeclineButton.pressed.connect(
		func(): 
			emit_signal("finished", false)
			hide())
	
	hide()


func pop_up(confirmation_text: String, sector: String = "", show_decline: bool = true) -> void:
	$Panel/CenterContainer/VBoxContainer/ConfirmationText.text = confirmation_text
	$Panel/CenterContainer/VBoxContainer/Sector.text = sector
	$Panel/CenterContainer/VBoxContainer/DeclineButton.visible = show_decline
	await get_tree().process_frame
	show()
