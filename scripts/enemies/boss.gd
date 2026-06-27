class_name Boss
extends GroundEnemy

signal phase_changed(phase: int)

@export var phase_health_thresholds: Array[float] = [0.66, 0.33]
var current_phase: int = 0

func _on_take_damage(amount: int, source: Node) -> void:
	var ratio = float(health) / max_health
	for i in phase_health_thresholds.size():
		var threshold = phase_health_thresholds[i]
		if ratio <= threshold and current_phase <= i:
			current_phase = i + 1
			phase_changed.emit(current_phase)
			_on_phase_changed(current_phase)

func _on_phase_changed(phase: int) -> void:
	pass
