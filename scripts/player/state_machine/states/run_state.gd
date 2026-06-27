class_name RunState
extends State

func enter() -> void:
	_update_anim()

func physics_update(delta: float) -> void:
	var input_dir := Input.get_axis("move_left", "move_right")
	var running := Input.is_action_pressed("run")
	var target_speed = host.run_speed if running else host.speed
	var target_velocity = input_dir * target_speed

	if input_dir != 0:
		host.anim.flip_h = input_dir < 0
		host.velocity.x = move_toward(host.velocity.x, target_velocity, host.acceleration * delta)
	else:
		host.velocity.x = move_toward(host.velocity.x, 0.0, host.friction * delta)

	_update_anim()

	var was_on_floor = host.is_on_floor()

	if not host.is_on_floor():
		host.velocity.y += host.gravity * delta
	else:
		host.can_double_jump = true

	host.move_and_slide()

	if was_on_floor and not host.is_on_floor():
		host.coyote_timer = host.coyote_time

	if Input.is_action_just_pressed("dash") and host.can_dash:
		state_machine.change_state(state_machine.dash_state)
	elif ((Input.is_action_just_pressed("jump") or host.jump_buffer_timer > 0.0)
	and (host.is_on_floor() or host.coyote_timer > 0.0)):
		host.jump_buffer_timer = 0.0
		host.coyote_timer = 0.0
		host.velocity.y = -host.jump_velocity
		state_machine.change_state(state_machine.jump_state)
	elif Input.is_action_just_pressed("attack"):
		state_machine.change_state(state_machine.attack_state)
	elif input_dir == 0 and host.is_on_floor():
		state_machine.change_state(state_machine.idle_state)

func _update_anim() -> void:
	var running := Input.is_action_pressed("run")
	host.anim.play("run" if running else "move")
