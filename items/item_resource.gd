extends Resource
class_name ItemResource

@export var name: String
@export var useable_turn_states: Array[Global.TurnState]

func is_useable(turn_state: Global.TurnState) -> bool:
	return turn_state in useable_turn_states
