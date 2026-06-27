extends Node2D

@export var amount_particles: int = 7
@export var particle_lifetime: float = 0.45
@export var speed_min: float = 160.0
@export var speed_max: float = 260.0
@export var damping_min: float = 160.0
@export var damping_max: float = 220.0
@export var gravity_strength: float = 260.0
@export var circle_radius: int = 18
@export var min_frame_size: int = 8
@export var spritesheet_path: String = "res://assets/sprites/vfx/blood_damage_vfx/VFX_Blood_Batch_1_SpriteSheetRows.png"

var _particles: GPUParticles2D
var _splash: AnimatedSprite2D
var _anim_names: Array[String] = []

func _ready() -> void:
	_setup_particles()
	_setup_splash()

func _setup_particles() -> void:
	_particles = GPUParticles2D.new()
	_particles.texture = _make_circle_texture(circle_radius)

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0.0, -1.0, 0.0)
	mat.spread = 180.0
	mat.flatness = 1.0
	mat.initial_velocity_min = speed_min
	mat.initial_velocity_max = speed_max
	mat.damping_min = damping_min
	mat.damping_max = damping_max
	mat.gravity = Vector3(0.0, gravity_strength, 0.0)
	mat.angular_velocity_min = 0.0
	mat.angular_velocity_max = 0.0

	mat.scale_min = 0.5
	mat.scale_max = 1.3

	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 1.0))
	sc.add_point(Vector2(0.25, 0.9))
	sc.add_point(Vector2(0.6, 0.4))
	sc.add_point(Vector2(1.0, 0.0))
	var sctx := CurveTexture.new()
	sctx.curve = sc
	mat.scale_curve = sctx

	var grad := Gradient.new()
	grad.offsets = [0.0, 0.3, 0.65, 1.0]
	grad.colors = [
		Color(1.0, 0.08, 0.06, 1.0),
		Color(0.7, 0.03, 0.02, 1.0),
		Color(0.15, 0.01, 0.0, 0.55),
		Color(0.0, 0.0, 0.0, 0.0),
	]
	var gtx := GradientTexture1D.new()
	gtx.gradient = grad
	mat.color_ramp = gtx

	_particles.process_material = mat
	_particles.amount = amount_particles
	_particles.lifetime = particle_lifetime
	_particles.one_shot = true
	_particles.explosiveness = 1.0
	_particles.local_coords = false
	_particles.z_index = 100
	add_child(_particles)

func _setup_splash() -> void:
	var src := load(spritesheet_path) as Texture2D
	if not src:
		return
	var img := src.get_image()
	if not img:
		return
	var w := img.get_width()
	var h := img.get_height()

	var row_ranges := _find_row_strips(img, w, h)
	var sf := SpriteFrames.new()

	for ri in row_ranges.size():
		var ys: int = row_ranges[ri][0]
		var ye: int = row_ranges[ri][1]
		var fh: int = ye - ys
		var col_ranges := _find_col_strips(img, w, ys, ye)
		var anim_name := str(ri)
		sf.add_animation(anim_name)
		sf.set_animation_loop(anim_name, false)
		var frame_count := 0
		for c in col_ranges:
			var xs: int = c[0]
			var xe: int = c[1]
			var fw: int = xe - xs
			if fw < min_frame_size or fh < min_frame_size:
				continue
			if fw > fh * 3 or fh > fw * 3:
				continue
			var frame_img := Image.create(fw, fh, false, Image.FORMAT_RGBA8)
			frame_img.blit_rect(img, Rect2i(xs, ys, fw, fh), Vector2i.ZERO)
			sf.add_frame(anim_name, ImageTexture.create_from_image(frame_img))
			frame_count += 1
		if frame_count > 0:
			sf.set_animation_speed(anim_name, frame_count / particle_lifetime)
			_anim_names.append(anim_name)

	if _anim_names.is_empty():
		var anim_name := "0"
		sf.add_animation(anim_name)
		sf.set_animation_loop(anim_name, false)
		sf.set_animation_speed(anim_name, 15.0)
		var fallback := Image.create(32, 32, false, Image.FORMAT_RGBA8)
		fallback.fill(Color(1, 0.08, 0.08, 1))
		sf.add_frame(anim_name, ImageTexture.create_from_image(fallback))
		_anim_names.append(anim_name)

	_splash = AnimatedSprite2D.new()
	_splash.sprite_frames = sf
	_splash.z_index = 101
	_splash.visible = false
	_splash.animation_finished.connect(func(): _splash.visible = false)
	add_child(_splash)

func _find_row_strips(img: Image, w: int, h: int) -> Array:
	var result := []
	var in_content := false
	var start := -1
	for y in range(h):
		var empty := true
		for x in range(w):
			if img.get_pixel(x, y).a > 5.0 / 255.0:
				empty = false
				break
		if not empty and not in_content:
			start = y
			in_content = true
		elif empty and in_content:
			result.append([start, y])
			in_content = false
	if in_content:
		result.append([start, h])
	return result

func _find_col_strips(img: Image, w: int, ys: int, ye: int) -> Array:
	var result := []
	var in_content := false
	var start := -1
	for x in range(w):
		var empty := true
		for y in range(ys, ye):
			if img.get_pixel(x, y).a > 5.0 / 255.0:
				empty = false
				break
		if not empty and not in_content:
			start = x
			in_content = true
		elif empty and in_content:
			result.append([start, x])
			in_content = false
	if in_content:
		result.append([start, w])
	return result

func emit_burst(direction_bias: Vector2 = Vector2.ZERO) -> void:
	if direction_bias != Vector2.ZERO:
		var mat := _particles.process_material as ParticleProcessMaterial
		if mat:
			var tilt := -direction_bias.normalized()
			mat.direction = Vector3(tilt.x * 0.5, -0.8, 0.0)
			mat.spread = 140.0
	_particles.emitting = true

	if _anim_names.size() > 0:
		var pick := _anim_names[randi() % _anim_names.size()]
		_splash.visible = true
		_splash.play(pick)

	await get_tree().create_timer(particle_lifetime + 0.3).timeout
	if is_instance_valid(self):
		queue_free()

func _make_circle_texture(radius: int) -> ImageTexture:
	var size := radius * 2
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(radius, radius)
	for x in size:
		for y in size:
			var d := Vector2(x, y).distance_to(center)
			if d <= radius:
				var alpha := 1.0 - _smoothstep(float(radius) * 0.4, float(radius) * 1.0, d)
				img.set_pixel(x, y, Color(1, 1, 1, alpha))
	return ImageTexture.create_from_image(img)

static func _smoothstep(edge0: float, edge1: float, x: float) -> float:
	var t := clampf((x - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
