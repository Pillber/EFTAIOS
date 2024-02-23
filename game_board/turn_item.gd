extends PanelContainer

func set_turn_number(turn_number: int) -> void:
	$VBoxContainer/TurnLabel.text = "Turn " + str(turn_number)
	
func set_move(sector: String) -> void:
	$VBoxContainer/Move.text = "[" + sector + "]"

func set_attacked() -> void:
	$VBoxContainer/Move.text += "*"
