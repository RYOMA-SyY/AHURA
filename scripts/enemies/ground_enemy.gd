class_name GroundEnemy
extends Enemy

@export var gravity: float = 2200.0
@export var floor_friction: float = 200.0

func _physics_process(delta: float) -> void:
	if health <= 0:
		return
	_update_movement(delta)
	velocity.y += gravity * delta
	move_and_slide()

# Override this in child classes instead of _physics_process.
func _update_movement(delta: float) -> void:
	pass
