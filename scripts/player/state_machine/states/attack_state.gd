class_name AttackState
extends State

var timer: float = 0.0
var vfx_triggered: bool = false

func enter() -> void:
	timer = host.attack_duration
	vfx_triggered = false
	host.anim.play("attack")
	host.attack_area.scale.x = -1 if host.anim.flip_h else 1
	host.attack_area.monitoring = true
	host.slash_vfx.position.x = abs(host.slash_vfx.position.x) * (-1 if host.anim.flip_h else 1)
	host.slash_vfx.flip_h = host.anim.flip_h
	host.slash_vfx.show()
	host.slash_vfx.play("slash")

func exit() -> void:
	host.attack_area.monitoring = false
	host.slash_vfx.hide()

func physics_update(delta: float) -> void:
	if not vfx_triggered and host.anim.frame >= 2:
		vfx_triggered = true
		host.slash_vfx.show()
		host.slash_vfx.play("slash")

	if not host.is_on_floor():
		host.velocity.y += host.gravity * delta

	host.velocity.x = move_toward(host.velocity.x, 0.0, host.friction * delta)
	host.move_and_slide()

	timer -= delta
	if timer <= 0.0:
		if not host.is_on_floor():
			state_machine.change_state(state_machine.jump_state)
		elif Input.get_axis("move_left", "move_right") != 0:
			state_machine.change_state(state_machine.run_state)
		else:
			state_machine.change_state(state_machine.idle_state)
