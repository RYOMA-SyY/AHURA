class_name State
extends Node

var host  # PlayerController — untyped to avoid circular dependency
var state_machine  # StateMachine — untyped to avoid circular dependency

func enter() -> void:
	pass

func exit() -> void:
	pass

func update(_delta: float) -> void:
	pass

func physics_update(_delta: float) -> void:
	pass
