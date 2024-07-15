extends PanelContainer

func _ready() -> void:
	$HAlign/Sector.set("theme_override_colors/font_color", Global.get_color('moving'))

func set_turn_number(turn_number: int) -> void:
	$HAlign/TurnNumber.text = ' ' + str(turn_number) + ' '
	
func set_sector(sector: String) -> void:
	$HAlign/Sector.text = sector

func set_noise() -> void:
	$HAlign/TurnNoise/NoiseIcon.show()
	$HAlign/TurnNoise/NoiseLabel.show()

func set_attack() -> void:
	$HAlign/TurnActions.text += Global.parse_text_to_bbcode("c(Attacked, %s)" % Global.color_to_code('attack'))
