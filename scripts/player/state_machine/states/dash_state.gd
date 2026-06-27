class_name DashState
extends State

var timer: float = 0.0
var direction: float = 1.0

func enter() -> void:
	timer = host.dash_duration
	host.anim.play("dash")
	host.can_dash = false
	host.dash_timer = host.dash_cooldown

	direction = -1.0 if host.anim.flip_h else 1.0
	host.velocity = Vector2(host.dash_speed * direction, 0.0)

func physics_update(delta: float) -> void:
	timer -= delta
	if timer <= 0.0:
		host.velocity.x *= 0.5
		if not host.is_on_floor():
			state_machine.change_state(state_machine.jump_state)
		elif Input.get_axis("move_left", "move_right") != 0:
			state_machine.change_state(state_machine.run_state)
		else:
			state_machine.change_state(state_machine.idle_state)

	host.move_and_slide()
