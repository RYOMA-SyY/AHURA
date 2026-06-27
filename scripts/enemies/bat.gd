class_name Bat
extends FlyingEnemy

enum AIState { IDLE, PATROL, CHASE, ATTACK }
var ai_state: AIState = AIState.IDLE

@export var scale_multiplier: float = 1.0:
	set(v):
		scale_multiplier = v
		scale = Vector2(v, v)

@export var patrol_speed: float = 60.0
@export var patrol_range: float = 80.0
@export var idle_time: float = 1.0
@export var detection_range: float = 180.0
@export var attack_range: float = 40.0
@export var chase_speed: float = 100.0

var start_position: Vector2
var idle_timer: float = 0.0
var patrol_dir: float = 1.0
var player: Node2D

func _ready() -> void:
	super()
	start_position = global_position
	anim.animation_finished.connect(_on_anim_finished)
	anim.play("idle")

func _find_player() -> void:
	if player and is_instance_valid(player):
		return
	var nodes = get_tree().get_nodes_in_group("player")
	if nodes.size() > 0:
		player = nodes[0]

func _physics_process(delta: float) -> void:
	if health <= 0:
		return

	_find_player()
	var dist_to_player := INF
	if player and is_instance_valid(player):
		dist_to_player = global_position.distance_to(player.global_position)

	if ai_state != AIState.ATTACK:
		if ai_state in [AIState.IDLE, AIState.PATROL] and dist_to_player < detection_range:
			ai_state = AIState.CHASE
		elif ai_state == AIState.CHASE:
			if dist_to_player > detection_range * 1.5:
				ai_state = AIState.PATROL

	match ai_state:
		AIState.IDLE:
			idle_timer -= delta
			velocity.x = move_toward(velocity.x, 0.0, 200.0 * delta)
			if idle_timer <= 0.0:
				ai_state = AIState.PATROL
				patrol_dir = -1.0 if randf() < 0.5 else 1.0

		AIState.PATROL:
			var offset = global_position.x - start_position.x
			if abs(offset) > patrol_range:
				patrol_dir *= -1
			velocity.x = patrol_speed * patrol_dir
			anim.flip_h = velocity.x < 0
			if global_position.distance_to(start_position) < 16.0:
				idle_timer = idle_time
				ai_state = AIState.IDLE

		AIState.CHASE:
			var dir = sign(player.global_position.x - global_position.x)
			velocity.x = chase_speed * dir
			anim.flip_h = dir < 0
			if dist_to_player < attack_range:
				ai_state = AIState.ATTACK
				_start_attack()

		AIState.ATTACK:
			velocity.x = move_toward(velocity.x, 0.0, 200.0 * delta)

	move_and_slide()

func _start_attack() -> void:
	anim.play("attack1" if randi() % 2 == 0 else "attack2")

func _on_anim_finished() -> void:
	if ai_state != AIState.ATTACK:
		return
	if player and is_instance_valid(player) and global_position.distance_to(player.global_position) < detection_range:
		ai_state = AIState.CHASE
	else:
		_restore_patrol()

func _restore_patrol() -> void:
	start_position = global_position
	ai_state = AIState.PATROL
