class_name FlyingEnemy
extends Enemy

func _physics_process(delta: float) -> void:
	if health <= 0:
		return
	_update_movement(delta)
	move_and_slide()

# Override in child classes for flight movement AI.
func _update_movement(delta: float) -> void:
	pass
