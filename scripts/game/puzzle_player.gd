extends CharacterBody3D
## First-person movement and assisted physical grab; no teleporting held bodies.
var camera := Camera3D.new()
var artifact
var holding := false
var distance := 2.0
var starting_distance := 2.0
var starting_size := 1.0
var requested_angle := 0.0
var pitch := 0.0
var pick_requested := false
var reset_requested := false
var wheel_steps := 0
## Defaults preserve the free-play puzzle; the guided scene unlocks controls by lesson.
var environment_collision_mask := 1
var grab_enabled := true
var rotation_enabled := true
var resize_enabled := true

func _ready() -> void:
	collision_layer = 2
	collision_mask = environment_collision_mask # Artifact does not push the player.
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.25
	capsule.height = 1.7
	collision.shape = capsule
	collision.position.y = 0.85
	add_child(collision)
	camera.position.y = 1.55
	camera.fov = 75
	add_child(camera)
	camera.current = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * 0.0025)
		pitch = clampf(pitch - event.relative.y * 0.0025, -1.3, 1.3)
		camera.rotation.x = pitch
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			drop()
		elif event.keycode == KEY_E: pick_requested = true
		elif event.keycode == KEY_R: reset_requested = true
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			else: pick_requested = true
		elif holding and event.button_index == MOUSE_BUTTON_WHEEL_UP: wheel_steps += 1
		elif holding and event.button_index == MOUSE_BUTTON_WHEEL_DOWN: wheel_steps -= 1

func drop() -> void:
	holding = false
	wheel_steps = 0
	if is_instance_valid(artifact): artifact.held = false

func tick(delta: float) -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var movement := Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))).normalized()
		var direction := global_basis * Vector3(movement.x, 0, movement.y)
		velocity.x = direction.x * 3.5
		velocity.z = direction.z * 3.5
	else:
		velocity.x = 0
		velocity.z = 0
	velocity.y = 0.0 if is_on_floor() else velocity.y - 9.81 * delta
	move_and_slide()
	if pick_requested:
		pick_requested = false
		if holding: drop()
		elif grab_enabled:
			var origin := camera.global_position
			var query := PhysicsRayQueryParameters3D.create(origin, origin - camera.global_basis.z * 5.0, environment_collision_mask | 4, [get_rid()])
			var hit := get_world_3d().direct_space_state.intersect_ray(query)
			if not hit.is_empty() and hit.collider == artifact:
				holding = true
				artifact.held = true
				distance = origin.distance_to(artifact.global_position)
				starting_distance = distance
				starting_size = artifact.size_multiplier
				requested_angle = artifact.angle
	if not holding: return
	# Held arrows act like six wheel steps per second, independent of key repeat.
	var distance_direction := float(Input.is_physical_key_pressed(KEY_UP)) - float(Input.is_physical_key_pressed(KEY_DOWN))
	if resize_enabled: distance = clampf(distance * pow(1.1, wheel_steps + distance_direction * 6.0 * delta), 0.9, 8.0)
	wheel_steps = 0
	var turn := float(Input.is_physical_key_pressed(KEY_C)) - float(Input.is_physical_key_pressed(KEY_Z))
	if not rotation_enabled: turn = 0.0
	requested_angle = clampf(artifact.angle + turn * 65.0 * delta, 0.0, 90.0)
	var requested_size: float = starting_size * distance / starting_distance if resize_enabled else artifact.size_multiplier
	artifact.request_shape(requested_angle, requested_size, delta)
	var target := camera.global_position - camera.global_basis.z * distance
	var assistance := pow(maxf(artifact.mass, 1.0), 0.8)
	var stiffness := 220.0 * assistance
	var damping := 2.0 * sqrt(stiffness * artifact.mass)
	var denominator: float = 1.0 + damping * delta / artifact.mass + stiffness * delta * delta / artifact.mass
	var force: Vector3 = ((target - artifact.global_position) * stiffness - artifact.linear_velocity * damping) / denominator
	artifact.sleeping = false
	artifact.apply_central_force(force.limit_length(600.0 * assistance))

func reset_player() -> void:
	drop()
	global_position = Vector3(0, 0.05, 6)
	rotation = Vector3.ZERO
	pitch = 0.0
	camera.rotation = Vector3.ZERO
	velocity = Vector3.ZERO
	pick_requested = false
	reset_requested = false
