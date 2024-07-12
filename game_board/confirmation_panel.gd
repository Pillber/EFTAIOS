extends Control

@onready var confirm_button = $TransparentBackround/OpaqueBackground/ContentSpacer/VAlign/ConfirmDecline/Confirm
@onready var decline_button = $TransparentBackround/OpaqueBackground/ContentSpacer/VAlign/ConfirmDecline/Decline
@onready var single_confirm_button = $TransparentBackround/OpaqueBackground/ContentSpacer/VAlign/SingleConfirm/ConfirmButton

@onready var text_box = $TransparentBackround/OpaqueBackground/ContentSpacer/VAlign/Text
@onready var colored_elements = [$TransparentBackround/TopBar, $TransparentBackround/BottomBar, $TransparentBackround/HexBackground]
@onready var icon = $TransparentBackround/HexBackground/Icon

signal finished(confirmed)


const ICONS = {
	Global.TurnState.MOVING: preload("res://game_board/icons/move.png"),
	Global.TurnState.MAKING_NOISE: preload("res://game_board/icons/noise.png"),
	Global.TurnState.ATTACKING: preload("res://game_board/icons/attack.png"),
	Global.TurnState.ENDING_TURN: preload("res://game_board/icons/end.png"),
	-1: preload("res://icon.svg")
}

func _ready() -> void:
	confirm_button.pressed.connect(_on_confirm)
	single_confirm_button.pressed.connect(_on_confirm)
	decline_button.pressed.connect(_on_decline)
	
	hide()

func _on_confirm() -> void:
	finished.emit(true)
	hide()

func _on_decline() -> void:
	finished.emit(false)
	hide()

func confirm_decline() -> void:
	$TransparentBackround/OpaqueBackground/ContentSpacer/VAlign/ConfirmDecline.show()
	$TransparentBackround/OpaqueBackground/ContentSpacer/VAlign/SingleConfirm.hide()

func confirm() -> void:
	$TransparentBackround/OpaqueBackground/ContentSpacer/VAlign/ConfirmDecline.hide()
	$TransparentBackround/OpaqueBackground/ContentSpacer/VAlign/SingleConfirm.show()

func set_color(color: Color) -> void:
	for element in colored_elements:
		element.self_modulate = color

func set_icon(game_state: Global.TurnState) -> void:
	icon.texture = ICONS[game_state]

func pop_up(confirmation_text: String, color: Color, game_state: Global.TurnState, show_decline: bool = true) -> void:
	set_color(color)
	set_icon(game_state)
	confirm_decline() if show_decline else confirm()
	text_box.clear()
	text_box.append_text(Global.parse_text_to_bbcode(confirmation_text))
	# wait a frame to make sure the player doesn't select something and immediatly hit either confirm or decline
	await get_tree().process_frame
	show()
