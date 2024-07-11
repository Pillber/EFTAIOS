extends Node

class State:
	
	var enter_hooks: Array[Callable]
	var exit_hooks: Array[Callable]
	var state_action: Callable
	
	var next_state: State
	
	func _init(action: Callable):
		state_action = action
	
	func set_next_state(state: State) -> void:
		next_state = state
	
	func enter_state() -> void:
		for hook in enter_hooks:
			await hook.call()
		
		print("hooks done")
		
		await state_action.call()
		
		for hook in exit_hooks:
			await hook.call()
		
		await next_state.enter_state()
	

signal key_pressed()
signal key_pressed_2()

func _input(event):
	if event.is_action_pressed("ui_accept"):
		key_pressed.emit()
	elif event.is_action_pressed("ui_down"):
		print('down')
		key_pressed_2.emit()

var current_state: State = null

func _ready() -> void:
	var state_moving = State.new(moving_state_action)
	state_moving.set_next_state(state_moving)
	state_moving.enter_hooks.append(enter_state_debug_print)
	state_moving.enter_hooks.append(additional_enter_hook)
	state_moving.exit_hooks.append(exit_state_debug_print)
	
	print(state_moving.enter_hooks)

	current_state = state_moving

	await current_state.enter_state()

func moving_state_action():
	await key_pressed
	print("Moving!")

func enter_state_debug_print():
	print("entering state")
	await key_pressed
	print("entered state")

func additional_enter_hook():
	print("meow")

func exit_state_debug_print():
	print("exiting state")
	await key_pressed
	print("exited state")
