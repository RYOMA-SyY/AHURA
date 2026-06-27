class_name HurtState
extends State

func enter() -> void:
	host.anim.play("hurt")

func physics_update(delta: float) -> void:
	host.velocity.x = move_toward(host.velocity.x, 0.0, host.friction * delta)
	host.velocity.y += host.gravity * delta
	host.move_and_slide()

	if host.is_on_floor():
		state_machine.change_state(state_machine.idle_state)
