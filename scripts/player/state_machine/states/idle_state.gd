class_name IdleState
extends State

func enter() -> void:
	host.anim.play("idle")

func physics_update(delta: float) -> void:
	var input_dir := Input.get_axis("move_left", "move_right")

	host.velocity.x = move_toward(host.velocity.x, 0.0, host.friction * delta)

	if not host.is_on_floor():
		host.velocity.y += host.gravity * delta
		host.coyote_timer = 0.0
	else:
		host.can_double_jump = true

	host.move_and_slide()

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
	elif input_dir != 0:
		state_machine.change_state(state_machine.run_state)
