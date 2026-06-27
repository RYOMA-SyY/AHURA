class_name JumpState
extends State

func enter() -> void:
	if host.velocity.y >= 0.0:
		host.anim.play("fall")
	else:
		host.anim.play("jump")

func physics_update(delta: float) -> void:
	var input_dir := Input.get_axis("move_left", "move_right")
	var target_velocity = input_dir * host.speed

	if input_dir != 0:
		host.anim.flip_h = input_dir < 0
		host.velocity.x = move_toward(host.velocity.x, target_velocity, host.acceleration * delta)
	else:
		host.velocity.x = move_toward(host.velocity.x, 0.0, host.friction * delta)

	var holding := Input.is_action_pressed("jump")
	var ascending: bool = host.velocity.y < 0.0

	var gravity_scale := 1.0
	if holding and ascending:
		gravity_scale = host.jump_hold_multiplier
		if host.anim.frame >= 3:
			host.anim.frame = 3
	host.velocity.y += host.gravity * gravity_scale * delta

	if not ascending:
		host.anim.play("fall")

	host.move_and_slide()

	if Input.is_action_just_pressed("dash") and host.can_dash:
		state_machine.change_state(state_machine.dash_state)
	elif Input.is_action_just_pressed("jump") and host.enable_double_jump and host.can_double_jump:
		host.can_double_jump = false
		host.velocity.y = -host.jump_velocity
		host.anim.play("jump")
		host.jump_buffer_timer = 0.0
	elif Input.is_action_just_pressed("attack"):
		state_machine.change_state(state_machine.attack_state)
	elif host.is_on_floor():
		if Input.get_axis("move_left", "move_right") != 0:
			state_machine.change_state(state_machine.run_state)
		else:
			state_machine.change_state(state_machine.idle_state)
