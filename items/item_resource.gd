extends Resource
class_name ItemResource

enum UseableStates {
	MOVING,
	NOISE,
	ATTACKING,
	AT_WILL
}

@export var name: String
@export var useable_turn_state: UseableStates

func is_useable(turn_state: Global.TurnState) -> bool:
	if useable_turn_state == UseableStates.AT_WILL and turn_state in [Global.TurnState.MOVING, Global.TurnState.MAKING_NOISE, Global.TurnState.ATTACKING, Global.TurnState.ENDING_TURN] \
	or useable_turn_state == UseableStates.MOVING and turn_state == Global.TurnState.MOVING \
	or useable_turn_state == UseableStates.NOISE and turn_state == Global.TurnState.MAKING_NOISE \
	or useable_turn_state == UseableStates.ATTACKING and turn_state == Global.TurnState.ATTACKING:
		return true
	return false
	#return turn_state in useable_turn_states
