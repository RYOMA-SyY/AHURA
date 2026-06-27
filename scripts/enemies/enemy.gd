class_name Enemy
extends CharacterBody2D

signal health_changed(old_value: int, new_value: int)
signal hurt()
signal died()

@export var max_health: int = 3
@export var invincibility_duration: float = 0.5
var health: int
var invincible: bool = false

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D if has_node("AnimatedSprite2D") else null

var BloodScene = preload("res://scenes/vfx/blood.tscn")

func _ready() -> void:
	health = max_health
	if has_node("Hurtbox"):
		$Hurtbox.add_to_group("enemy_hurtbox")
	if has_node("Hitbox"):
		$Hitbox.body_entered.connect(_on_hitbox_body_entered)
	_setup()
	_on_ready()

# Child classes override these hooks instead of _ready()
# to ensure base setup always runs.
func _setup() -> void:
	pass

func _on_ready() -> void:
	pass


func _spawn_blood(pos: Vector2, dir: Vector2 = Vector2.ZERO) -> void:
	var blood = BloodScene.instantiate()
	get_parent().add_child(blood)
	blood.global_position = pos
	blood.emit_burst(dir)

func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO, source: Node = null) -> void:
	if health <= 0 or invincible:
		return
	_spawn_blood(global_position, knockback.normalized())
	var old = health
	health -= amount
	health_changed.emit(old, health)
	velocity = knockback
	invincible = true
	_start_invincibility_timer()
	_on_take_damage(amount, source)
	if health <= 0:
		_die()
	else:
		_hurt()

# Override this to react to damage (eg reset chase timer, enrage check).
func _on_take_damage(amount: int, source: Node) -> void:
	pass


func _hurt() -> void:
	_on_hurt_started()
	if anim and anim.sprite_frames.has_animation("hurt"):
		anim.play("hurt")
		await anim.animation_finished
	_on_hurt_finished()
	hurt.emit()

# Called before and after the hurt animation plays.
func _on_hurt_started() -> void:
	pass

func _on_hurt_finished() -> void:
	pass


func _die() -> void:
	set_physics_process(false)
	died.emit()
	_on_death_started()
	if anim and anim.sprite_frames.has_animation("dead"):
		anim.play("dead")
		await anim.animation_finished
	_on_death_finished()
	queue_free()

func _on_death_started() -> void:
	pass

func _on_death_finished() -> void:
	pass


func _start_invincibility_timer() -> void:
	await get_tree().create_timer(invincibility_duration).timeout
	if is_instance_valid(self):
		invincible = false

func _on_hitbox_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		var dir = (body.global_position - global_position).normalized()
		body.take_damage(1, dir * 300.0)
