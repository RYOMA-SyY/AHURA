class_name HUD
extends CanvasLayer

@export var heart_full_color: Color = Color.RED
@export var heart_empty_color: Color = Color(0.3, 0.3, 0.3)
@export var heart_size: int = 20

var _hearts: Array[ColorRect] = []

func setup(player: PlayerController) -> void:
	var container = $MarginContainer/HBoxContainer
	for i in range(player.max_health):
		var heart = ColorRect.new()
		heart.custom_minimum_size = Vector2(heart_size, heart_size)
		heart.color = heart_empty_color
		container.add_child(heart)
		_hearts.append(heart)

	player.health_changed.connect(_refresh)
	_refresh(player.health)

func _refresh(hp: int) -> void:
	for i in _hearts.size():
		_hearts[i].color = heart_full_color if i < hp else heart_empty_color
