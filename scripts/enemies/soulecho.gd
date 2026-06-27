class_name SoulEcho
extends GroundEnemy

enum AIState { IDLE, PATROL, CHASE, LISTEN, ATTACK, JUMP }
var ai_state: AIState = AIState.IDLE

@export var scale_multiplier: float = 1.0:
	set(v):
		scale_multiplier = v
		scale = Vector2(v, v)

@export var patrol_speed: float = 40.0
@export var patrol_range: float = 100.0
@export var idle_time_min: float = 1.0
@export var idle_time_max: float = 3.0

@export var detection_range: float = 250.0
@export var enrage_detection_range: float = 400.0
@export var chase_speed: float = 100.0
@export var chase_accel_time: float = 0.5
@export var player_lost_timeout: float = 3.0
@export var track_delay: float = 0.5

@export var slash_range: float = 80.0

@export var lunge_min_range: float = 80.0
@export var lunge_max_range: float = 200.0
@export var lunge_distance: float = 150.0
@export var lunge_speed: float = 400.0
@export var lunge_require_chase_time: float = 2.0

@export var attack_cooldown_min: float = 0.5
@export var attack_cooldown_max: float = 1.0
@export var slash_punish: float = 0.6
@export var lunge_punish: float = 0.8

@export var listen_time_min: float = 1.0
@export var listen_time_max: float = 2.0
@export var listen_cooldown_time: float = 5.0

@export var jump_velocity: float = -450.0
@export var player_height_threshold: float = 80.0
@export var jump_telegraph_time: float = 0.4
@export var jump_horiz_speed: float = 60.0

@export var enrage_health_ratio: float = 0.3
@export var enrage_speed_mult: float = 1.4

@export var wall_check_distance: float = 40.0
@export var wall_collision_layer: int = 1

var start_position: Vector2
var last_known_position: Vector2
var player: Node2D
var _hitbox_offset: float
var wall_checker: RayCast2D

var idle_timer: float = 0.0
var patrol_dir: float = 1.0

var chase_current_speed: float = 0.0
var player_lost_timer: float = 0.0
var chase_hit_timer: float = 0.0
var track_timer: float = 0.0
var detection_range_actual: float
var chase_speed_actual: float

var listen_timer: float = 0.0
var listen_cooldown_timer: float = 0.0

var attack_cooldown_timer: float = 0.0
var whiff_punish_timer: float = 0.0
var is_lunge_attack: bool = false
var lunge_start_x: float = 0.0
var lunge_dir: float = 1.0
var hit_landed: bool = false
var is_in_punish: bool = false

var jump_telegraph_timer: float = 0.0
var jump_dir: float = 0.0
var has_jumped: bool = false

var is_enraged: bool = false
var invincibility_timer: float = 0.0
var stagger_timer: float = 0.0

signal player_detected()


func _ready() -> void:
	super()
	start_position = global_position
	anim.animation_finished.connect(_on_anim_finished)
	idle_timer = randf_range(idle_time_min, idle_time_max)
	listen_cooldown_timer = listen_cooldown_time * 0.5
	anim.play("idle")
	detection_range_actual = detection_range
	chase_speed_actual = chase_speed

	wall_checker = RayCast2D.new()
	wall_checker.enabled = true
	wall_checker.collision_mask = wall_collision_layer
	add_child(wall_checker)

	if has_node("Hitbox"):
		_hitbox_offset = $Hitbox.position.x
		$Hitbox/CollisionShape2D.disabled = true


func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO, source: Node = null) -> void:
	if health <= 0 or invincibility_timer > 0.0:
		return
	_spawn_blood(global_position, knockback.normalized())
	health -= amount
	velocity = knockback

	if health <= 0:
		set_physics_process(false)
		$Hitbox/CollisionShape2D.disabled = true
		anim.play("dead")
		await anim.animation_finished
		queue_free()
		return

	invincibility_timer = 0.5
	stagger_timer = 0.3
	ai_state = AIState.IDLE
	is_in_punish = false
	is_lunge_attack = false
	anim.play("hurt")
	await anim.animation_finished


func _on_hitbox_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		var dir = (body.global_position - global_position).normalized()
		body.take_damage(1, dir * 300.0)
		hit_landed = true
		chase_hit_timer = 0.0


func _can_see_player(dist: float) -> bool:
	if not player or not is_instance_valid(player):
		return false
	if dist > detection_range_actual:
		return false
	wall_checker.target_position = player.global_position - global_position
	wall_checker.force_raycast_update()
	if wall_checker.is_colliding():
		var c = wall_checker.get_collider()
		if c and c != player:
			return false
	return true


func _enter_chase() -> void:
	ai_state = AIState.CHASE
	chase_current_speed = 0.0
	player_lost_timer = 0.0
	chase_hit_timer = 0.0
	is_in_punish = false
	is_lunge_attack = false
	has_jumped = false
	anim.play("run")
	$Hitbox/CollisionShape2D.disabled = true


func _enter_patrol() -> void:
	start_position = global_position
	ai_state = AIState.PATROL
	patrol_dir = -1.0 if randf() < 0.5 else 1.0
	anim.play("move")
	$Hitbox/CollisionShape2D.disabled = true


func _physics_process(delta: float) -> void:
	if health <= 0:
		return

	_find_player()

	if invincibility_timer > 0.0:
		invincibility_timer -= delta

	if stagger_timer > 0.0:
		stagger_timer -= delta
		velocity.y += gravity * delta
		move_and_slide()
		return

	attack_cooldown_timer = max(0.0, attack_cooldown_timer - delta)
	listen_cooldown_timer = max(0.0, listen_cooldown_timer - delta)

	_update_enrage()

	var dist_to_player := INF
	var can_see := false
	if player and is_instance_valid(player):
		dist_to_player = global_position.distance_to(player.global_position)
		can_see = _can_see_player(dist_to_player)

	if ai_state != AIState.ATTACK:
		if ai_state in [AIState.IDLE, AIState.PATROL] and can_see:
			if not is_enraged:
				player_detected.emit()
			detection_range_actual = enrage_detection_range if is_enraged else detection_range
			_enter_chase()
		elif ai_state == AIState.CHASE:
			if not can_see:
				player_lost_timer += delta
				if player_lost_timer >= player_lost_timeout:
					_enter_patrol()
			else:
				player_lost_timer = 0.0

	match ai_state:
		AIState.IDLE:
			idle_timer -= delta
			velocity.x = move_toward(velocity.x, 0.0, 200.0 * delta)
			if idle_timer <= 0.0:
				_enter_patrol()

		AIState.PATROL:
			_physics_patrol(delta)

		AIState.CHASE:
			_physics_chase(delta, dist_to_player, can_see)

		AIState.LISTEN:
			_physics_listen(delta)

		AIState.ATTACK:
			_physics_attack(delta)

		AIState.JUMP:
			_physics_jump(delta)

	velocity.y += gravity * delta
	move_and_slide()


func _physics_patrol(_delta: float) -> void:
	var offset = global_position.x - start_position.x
	if abs(offset) > patrol_range:
		patrol_dir *= -1

	wall_checker.target_position = Vector2(wall_check_distance * patrol_dir, 0)
	wall_checker.force_raycast_update()
	if wall_checker.is_colliding():
		patrol_dir *= -1

	velocity.x = patrol_speed * patrol_dir
	anim.flip_h = velocity.x < 0
	$Hitbox.position.x = -_hitbox_offset if anim.flip_h else _hitbox_offset

	if global_position.distance_to(start_position) < 16.0:
		idle_timer = randf_range(idle_time_min, idle_time_max)
		ai_state = AIState.IDLE


func _physics_chase(delta: float, dist_to_player: float, can_see: bool) -> void:
	if can_see:
		player_lost_timer = 0.0
		chase_hit_timer += delta

		track_timer -= delta
		if track_timer <= 0.0:
			last_known_position = player.global_position
			track_timer = track_delay

		var dir = sign(last_known_position.x - global_position.x)
		if dir == 0.0:
			dir = 1.0

		chase_current_speed = move_toward(chase_current_speed, chase_speed_actual,
			(chase_speed_actual / chase_accel_time) * delta)
		velocity.x = chase_current_speed * dir
		anim.flip_h = dir < 0
		$Hitbox.position.x = -_hitbox_offset if anim.flip_h else _hitbox_offset

		if listen_cooldown_timer <= 0.0 and randf() < delta * 0.05:
			velocity.x = 0.0
			listen_timer = randf_range(listen_time_min, listen_time_max)
			if is_enraged:
				listen_timer *= 0.6
			ai_state = AIState.LISTEN
			anim.play("idle")
			listen_cooldown_timer = listen_cooldown_time
			return

		if player.global_position.y < global_position.y - player_height_threshold \
				and is_on_floor():
			velocity.x = 0.0
			jump_telegraph_timer = jump_telegraph_time
			jump_dir = sign(player.global_position.x - global_position.x)
			if jump_dir == 0.0:
				jump_dir = 1.0
			has_jumped = false
			ai_state = AIState.JUMP
			anim.play("idle")
			return

		if attack_cooldown_timer <= 0.0:
			var do_lunge = false
			var in_slash_range = dist_to_player <= slash_range
			var in_lunge_range = dist_to_player >= lunge_min_range \
				and dist_to_player <= lunge_max_range
			if in_slash_range:
				do_lunge = false
			elif in_lunge_range and chase_hit_timer >= lunge_require_chase_time:
				do_lunge = true

			if in_slash_range or do_lunge:
				_start_attack(do_lunge)
		else:
			velocity.x = move_toward(velocity.x, 0.0, 200.0 * delta)


func _physics_listen(delta: float) -> void:
	listen_timer -= delta
	velocity.x = move_toward(velocity.x, 0.0, 200.0 * delta)
	if listen_timer <= 0.0:
		_enter_chase()


func _physics_attack(delta: float) -> void:
	if is_in_punish:
		whiff_punish_timer -= delta
		velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
		if whiff_punish_timer <= 0.0:
			_enter_chase()
		return

	if is_lunge_attack:
		if abs(global_position.x - lunge_start_x) < lunge_distance:
			velocity.x = lunge_dir * lunge_speed
		else:
			velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)


func _physics_jump(delta: float) -> void:
	if jump_telegraph_timer > 0.0:
		jump_telegraph_timer -= delta
		velocity.x = move_toward(velocity.x, 0.0, 200.0 * delta)
		anim.flip_h = jump_dir < 0
	elif not has_jumped:
		has_jumped = true
		velocity.y = jump_velocity
		velocity.x = jump_dir * jump_horiz_speed
		if anim.sprite_frames.has_animation("jump"):
			anim.play("jump")
		else:
			anim.play("move")
	elif is_on_floor():
		_enter_chase()


func _start_attack(is_lunge: bool) -> void:
	ai_state = AIState.ATTACK
	is_lunge_attack = is_lunge
	hit_landed = false
	is_in_punish = false
	attack_cooldown_timer = randf_range(attack_cooldown_min, attack_cooldown_max)

	if is_lunge:
		lunge_dir = sign(player.global_position.x - global_position.x) if player else 1.0
		if lunge_dir == 0.0:
			lunge_dir = 1.0
		lunge_start_x = global_position.x
		anim.play("heavy_attack")
	else:
		anim.play("light_attack")

	$Hitbox/CollisionShape2D.disabled = false


func _on_anim_finished() -> void:
	if ai_state != AIState.ATTACK:
		return

	$Hitbox/CollisionShape2D.disabled = true

	if hit_landed:
		_enter_chase()
	else:
		is_in_punish = true
		whiff_punish_timer = lunge_punish if is_lunge_attack else slash_punish


func _update_enrage() -> void:
	if is_enraged:
		return
	var health_ratio = float(health) / max_health
	if health_ratio <= enrage_health_ratio:
		is_enraged = true
		chase_speed_actual = chase_speed * enrage_speed_mult
		detection_range_actual = enrage_detection_range
		anim.speed_scale = 1.15


func _find_player() -> void:
	if player and is_instance_valid(player):
		return
	var nodes = get_tree().get_nodes_in_group("player")
	if nodes.size() > 0:
		player = nodes[0]
		wall_checker.add_exception(player)
