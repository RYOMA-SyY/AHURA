class_name StateMachine
extends Node

var host  # PlayerController — untyped to avoid circular dependency
var current_state: State

var idle_state: State
var run_state: State
var jump_state: State
var hurt_state: State
var dead_state: State
var attack_state: State
var dash_state: State

func _initialize() -> void:
	for child in get_children():
		if not child is State:
			continue
		child.host = host
		child.state_machine = self
		match child.name:
			"IdleState": idle_state = child
			"RunState": run_state = child
			"JumpState": jump_state = child
			"HurtState": hurt_state = child
			"DeadState": dead_state = child
			"AttackState": attack_state = child
			"DashState": dash_state = child
	change_state(idle_state)

func _process(delta: float) -> void:
	if current_state:
		current_state.update(delta)

func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)

func change_state(new_state: State) -> void:
	if not new_state or new_state == current_state:
		return
	if current_state:
		current_state.exit()
	current_state = new_state
	current_state.enter()
