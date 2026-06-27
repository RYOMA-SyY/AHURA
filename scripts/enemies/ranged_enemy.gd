class_name RangedEnemy
extends GroundEnemy

@export var projectile_scene: PackedScene
@export var projectile_speed: float = 300.0
@export var projectile_damage: int = 1

func _shoot(target_pos: Vector2) -> void:
	if not projectile_scene:
		return
	var proj = projectile_scene.instantiate()
	proj.global_position = global_position
	if proj.has_method("set_direction"):
		proj.set_direction((target_pos - global_position).normalized())
	if proj.has_method("set_speed"):
		proj.set_speed(projectile_speed)
	if proj.has_method("set_damage"):
		proj.set_damage(projectile_damage)
	get_parent().add_child(proj)
