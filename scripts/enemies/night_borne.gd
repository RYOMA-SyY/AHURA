class_name NightBorne
extends GroundEnemy

enum AIState { IDLE, PATROL, CHASE, ATTACK }
var ai_state: AIState = AIState.IDLE

@export var scale_multiplier: float = 1.0:
	set(v):
		scale_multiplier = v
		scale = Vector2(v, v)

@export var patrol_speed: float = 50.0
@export var patrol_range: float = 100.0
@export var idle_time: float = 1.5
@export var detection_range: float = 200.0
@export var attack_range: float = 60.0
@export var chase_speed: float = 90.0
@export var attack_cooldown: float = 0.8

@export var brain_tick_rate: float = 0.3
@export var memory_duration: float = 2.0
@export var reaction_delay: float = 0.2
@export var wall_collision_layer: int = 1

var start_position: Vector2
var idle_timer: float = 0.0
var patrol_dir: float = 1.0
var player: Node2D
var attack_cooldown_timer: float = 0.0
var stagger_timer: float = 0.0
var _hitbox_offset: float

var brain_tick_timer: float = 0.0
var memory_timer: float = 0.0
var reaction_timer: float = 0.0
var player_seen: bool = false
var last_known_pos: Vector2
var ray: RayCast2D


func _ready() -> void:
	super()
	start_position = global_position
	idle_timer = idle_time
	anim.animation_finished.connect(_on_anim_finished)
	anim.play("idle")
	if has_node("Hitbox"):
		_hitbox_offset = $Hitbox.position.x

	ray = RayCast2D.new()
	ray.enabled = true
	ray.collision_mask = wall_collision_layer
	add_child(ray)
	_find_player()
	if player:
		ray.add_exception(player)


func _on_hurt_started() -> void:
	stagger_timer = 0.3

func _on_hurt_finished() -> void:
	ai_state = AIState.IDLE
	idle_timer = 0.5

func _find_player() -> void:
	if player and is_instance_valid(player):
		return
	var nodes = get_tree().get_nodes_in_group("player")
	if nodes.size() > 0:
		player = nodes[0]
		if ray:
			ray.add_exception(player)


func _can_see_player(dist: float) -> bool:
	if not player or not is_instance_valid(player):
		return false
	if dist > detection_range:
		return false
	ray.target_position = player.global_position - global_position
	ray.force_raycast_update()
	if ray.is_colliding():
		var c = ray.get_collider()
		if c and c != player:
			return false
	return true


func _update_movement(delta: float) -> void:
	_find_player()

	if stagger_timer > 0.0:
		stagger_timer -= delta
		velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
		return

	attack_cooldown_timer = max(0.0, attack_cooldown_timer - delta)

	# Brain tick — AI only makes decisions every brain_tick_rate seconds
	brain_tick_timer -= delta
	var do_brain_tick = brain_tick_timer <= 0.0
	if do_brain_tick:
		brain_tick_timer = brain_tick_rate

	var dist_to_player := INF
	var can_see := false
	if player and is_instance_valid(player):
		dist_to_player = global_position.distance_to(player.global_position)
		if do_brain_tick:
			can_see = _can_see_player(dist_to_player)

	if do_brain_tick:
		if can_see:
			player_seen = true
			last_known_pos = player.global_position
			memory_timer = memory_duration
			reaction_timer = reaction_delay
		else:
			memory_timer -= brain_tick_rate
			if memory_timer <= 0.0:
				player_seen = false

	# State machine
	match ai_state:
		AIState.IDLE:
			idle_timer -= delta
			velocity.x = move_toward(velocity.x, 0.0, 200.0 * delta)
			if idle_timer <= 0.0:
				ai_state = AIState.PATROL
				patrol_dir = -1.0 if randf() < 0.5 else 1.0
				anim.play("run")

		AIState.PATROL:
			var offset = global_position.x - start_position.x
			if abs(offset) > patrol_range:
				patrol_dir *= -1
			velocity.x = patrol_speed * patrol_dir
			anim.flip_h = velocity.x < 0
			$Hitbox.position.x = -_hitbox_offset if anim.flip_h else _hitbox_offset
			if global_position.distance_to(start_position) < 16.0:
				idle_timer = idle_time
				ai_state = AIState.IDLE
				anim.play("idle")

		AIState.CHASE:
			# Small brain: hesitation — sometimes briefly pauses
			if do_brain_tick and randf() < 0.03:
				ai_state = AIState.IDLE
				idle_timer = randf_range(0.3, 0.8)
				anim.play("idle")
				return

			if player_seen:
				reaction_timer -= delta
				if reaction_timer > 0.0:
					velocity.x = move_toward(velocity.x, 0.0, 200.0 * delta)
					return

				var dir = sign(last_known_pos.x - global_position.x)
				velocity.x = chase_speed * dir
				anim.flip_h = dir < 0
				$Hitbox.position.x = -_hitbox_offset if anim.flip_h else _hitbox_offset

				if dist_to_player < attack_range and attack_cooldown_timer <= 0.0:
					_start_attack()
			else:
				# Lost player — wander toward last known position, then give up
				if memory_timer > 0.0:
					var dir = sign(last_known_pos.x - global_position.x)
					velocity.x = chase_speed * 0.5 * dir
					anim.flip_h = dir < 0
					$Hitbox.position.x = -_hitbox_offset if anim.flip_h else _hitbox_offset
				else:
					_restore_patrol()

		AIState.ATTACK:
			velocity.x = move_toward(velocity.x, 0.0, 200.0 * delta)

	# Detection transitions (only on brain tick)
	if do_brain_tick and ai_state != AIState.ATTACK:
		if ai_state in [AIState.IDLE, AIState.PATROL] and player_seen:
			ai_state = AIState.CHASE
			anim.play("run")


func _start_attack() -> void:
	ai_state = AIState.ATTACK
	attack_cooldown_timer = attack_cooldown
	anim.play("attack")
	$Hitbox/CollisionShape2D.disabled = false


func _on_anim_finished() -> void:
	if ai_state != AIState.ATTACK:
		return
	$Hitbox/CollisionShape2D.disabled = true
	if player and is_instance_valid(player) and \
			global_position.distance_to(player.global_position) < detection_range:
		ai_state = AIState.CHASE
		anim.play("run")
	else:
		_restore_patrol()


func _restore_patrol() -> void:
	start_position = global_position
	ai_state = AIState.PATROL
	anim.play("run")
