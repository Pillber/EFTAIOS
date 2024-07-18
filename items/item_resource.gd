extends Resource
class_name ItemResource

enum UseableStates {
	MOVING,
	NOISE,
	ATTACKING,
	AT_WILL
}

@export var name: String
@export var useable_turn_states: Array[Global.TurnState]

func is_useable(turn_state: Global.TurnState) -> bool:
	return turn_state in useable_turn_states
