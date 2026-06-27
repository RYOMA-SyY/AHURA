class_name PlayerController
extends CharacterBody2D

signal health_changed(new_health: int)

@export var speed: float = 420.0
@export var acceleration: float = 2800.0
@export var friction: float = 3200.0

@export var gravity: float = 2200.0
@export var jump_velocity: float = 450.0
@export var jump_hold_multiplier: float = 0.2

@export var jump_buffer_time: float = 0.1
@export var coyote_time: float = 0.08
@export var enable_double_jump: bool = true

@export var run_speed: float = 650.0
@export var dash_speed: float = 750.0
@export var dash_duration: float = 0.15
@export var dash_cooldown: float = 0.5

@export var attack_duration: float = 0.2
@export var attack_cooldown: float = 0.3

@export var max_health: int = 5
@export var invincibility_duration: float = 0.8
@export var knockback_force: float = 300.0

@export var shake_intensity: float = 8.0
@export var shake_decay: float = 0.3
@export var hitstop_duration: float = 0.02
@export var hitstop_scale: float = 0.1

var health: int
var invincible: bool = false
var invincibility_timer: float = 0.0

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_area: Area2D = $AttackArea2D
@onready var slash_vfx: AnimatedSprite2D = $SlashVFX
@onready var camera: Camera2D = $Camera2D

@onready var run_tex := preload("res://assets/placeholders/player/run.png")
@onready var move_tex := preload("res://assets/placeholders/player/run.png")
@onready var jump_tex := preload("res://assets/placeholders/player/jump.png")
@onready var fall_tex := preload("res://assets/placeholders/player/fall.png")
@onready var attack_tex := preload("res://assets/placeholders/player/attack.png")
@onready var dash_tex := preload("res://assets/placeholders/player/dash.png")
@onready var dead_tex := preload("res://assets/placeholders/player/dead.png")
@onready var hurt_tex := preload("res://assets/placeholders/player/idle.png")

var jump_buffer_timer: float = 0.0
var coyote_timer: float = 0.0
var can_double_jump: bool = false

var can_dash: bool = true
var dash_timer: float = 0.0

var state_machine: StateMachine

var BloodScene = preload("res://scenes/vfx/blood.tscn")

func _ready() -> void:
	health = max_health
	add_to_group("player")
	health_changed.emit(health)
	_build_animations()
	_build_vfx_frames()
	attack_area.area_entered.connect(_on_attack_area_entered)
	$HUD.setup(self)

	var sm := StateMachine.new()
	sm.name = "StateMachine"
	sm.host = self
	add_child(sm)

	for state_name in ["IdleState", "RunState", "JumpState", "AttackState", "DashState", "HurtState", "DeadState"]:
		var state: Node
		match state_name:
			"IdleState": state = IdleState.new()
			"RunState": state = RunState.new()
			"JumpState": state = JumpState.new()
			"AttackState": state = AttackState.new()
			"DashState": state = DashState.new()
			"HurtState": state = HurtState.new()
			"DeadState": state = DeadState.new()
		state.name = state_name
		sm.add_child(state)

	state_machine = sm
	sm._initialize()

func _spawn_blood(pos: Vector2, dir: Vector2 = Vector2.ZERO) -> void:
	var blood = BloodScene.instantiate()
	get_parent().add_child(blood)
	blood.global_position = pos
	blood.emit_burst(dir)

func shake_camera(intensity: float, duration: float) -> void:
	var tween = create_tween()
	var start = intensity
	tween.tween_method(func(v): camera.offset = Vector2(randf_range(-v, v), randf_range(-v, v)), start, 0.0, duration)
	tween.tween_callback(func(): camera.offset = Vector2.ZERO)

func hit_stop(duration: float, time_scale: float) -> void:
	Engine.time_scale = time_scale
	await get_tree().create_timer(duration).timeout
	Engine.time_scale = 1.0

func _hurt_flash() -> void:
	var tween = create_tween()
	tween.tween_property(anim, "self_modulate", Color(1.0, 0.2, 0.2), 0.05)
	tween.tween_property(anim, "self_modulate", Color.WHITE, 0.15)

func take_damage(amount: int, knockback: Vector2) -> void:
	if invincible:
		return
	_spawn_blood(global_position, knockback.normalized())
	shake_camera(shake_intensity, shake_decay)
	_hurt_flash()
	health -= amount
	health_changed.emit(health)
	if health <= 1:
		hit_stop(0.15, 0.3)
	velocity = knockback
	invincible = true
	invincibility_timer = invincibility_duration
	if health <= 0:
		state_machine.change_state(state_machine.dead_state)
	else:
		state_machine.change_state(state_machine.hurt_state)

func _on_attack_area_entered(area: Area2D) -> void:
	if not area.is_in_group("enemy_hurtbox"):
		return
	shake_camera(shake_intensity * 0.5, shake_decay * 0.5)
	hit_stop(hitstop_duration, hitstop_scale)
	var enemy: Node = area.get_parent()
	if enemy.has_method("take_damage"):
		enemy.take_damage(1, Vector2(-1.0 if anim.flip_h else 1.0, -0.5) * knockback_force)

func _build_vfx_frames() -> void:
	var sf := SpriteFrames.new()
	sf.add_animation("slash")
	sf.set_animation_loop("slash", false)
	sf.set_animation_speed("slash", 30.0)
	for i in range(30):
		var path := "res://assets/sprites/vfx/slash_arc_loop_red_30fps/slash_arc_loop_red_%05d.png" % i
		var tex := load(path) as Texture2D
		if tex:
			sf.add_frame("slash", tex, 1.0)
	slash_vfx.sprite_frames = sf

func _build_animations() -> void:
	var sf := anim.sprite_frames
	if sf == null:
		sf = SpriteFrames.new()
		anim.sprite_frames = sf

	var placeholders := {"move": move_tex, "run": run_tex, "jump": jump_tex, "fall": fall_tex, "attack": attack_tex, "dash": dash_tex, "hurt": hurt_tex, "dead": dead_tex}
	for anim_name in placeholders:
		if not sf.has_animation(anim_name):
			sf.add_animation(anim_name)
			sf.set_animation_loop(anim_name, false)
			sf.set_animation_speed(anim_name, 1.0)
			sf.add_frame(anim_name, placeholders[anim_name], 0.1)

func _process(delta: float) -> void:
	jump_buffer_timer = max(0.0, jump_buffer_timer - delta)
	coyote_timer = max(0.0, coyote_timer - delta)
	dash_timer = max(0.0, dash_timer - delta)

	if invincible:
		invincibility_timer -= delta
		anim.modulate.a = 0.4 if int(invincibility_timer * 12) % 2 == 0 else 1.0
		if invincibility_timer <= 0.0:
			invincible = false
			anim.modulate.a = 1.0

	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_time

	if dash_timer <= 0.0:
		can_dash = true
