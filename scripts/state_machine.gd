extends Node
class_name CharacterStateMachine

signal state_changed(new_state: String)

enum State { IDLE, FOCUS, SLEEP }

const STATE_NAMES = {
	State.IDLE: "IDLE",
	State.FOCUS: "FOCUS",
	State.SLEEP: "SLEEP",
}

var current_state: State = State.IDLE


func _ready():
	pass


func change_state(new_state: State):
	if current_state == new_state:
		return
	var old_state = current_state
	current_state = new_state
	state_changed.emit(STATE_NAMES[new_state])


func get_state_name() -> String:
	return STATE_NAMES[current_state]


func go_idle():
	change_state(State.IDLE)


func go_focus():
	change_state(State.FOCUS)


func go_sleep():
	change_state(State.SLEEP)
