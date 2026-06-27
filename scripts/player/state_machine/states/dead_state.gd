class_name DeadState
extends State

var _respawn_timer: float = 2.0

func enter() -> void:
	_respawn_timer = 2.0
	host.anim.play("dead")
	host.collision_layer = 0
	host.collision_mask = 0

func physics_update(_delta: float) -> void:
	_respawn_timer -= _delta
	if _respawn_timer <= 0.0:
		get_tree().reload_current_scene()
