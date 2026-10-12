extends Node
## Mouse interaction adapter. Queries run only from the host's physics tick.
## Changes native pose and a persistent uniform size multiplier, never 4D fields.
signal picked(body)
var spring_strength := 900.0
var grab_strength := 1.0
var max_force := 2000.0
var original_lock_rotation := false
var camera: Camera3D
var held = null
var perspective_resize := true
var automatic_distance := false
var pending_pick := false
var pending_release := false
var pending_cancel := false
var wheel_steps := 0.0
var distance := 1.0
var initial_distance := 1.0
var initial_size := 1.0
var grab_local := Vector3.ZERO
var original_pose := Transform3D.IDENTITY
var original_linear := Vector3.ZERO
var original_angular := Vector3.ZERO
var message := "Left-drag a shape · wheel: distance · release: drop · Esc: cancel"

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not event.pressed: return
	if event.button_index == MOUSE_BUTTON_LEFT:
		pending_pick = true
		get_viewport().set_input_as_handled()
	elif held != null and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		wheel_steps += 1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1
		get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	# Release even over UI; don't leave a frozen body attached to the cursor.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		pending_release = true
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
		pending_cancel = true

func ray() -> Dictionary:
	var pixel := get_viewport().get_mouse_position()
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED: pixel = get_viewport().get_visible_rect().size * 0.5
	return {"origin": camera.project_ray_origin(pixel), "direction": camera.project_ray_normal(pixel)}

func physics_tick(delta: float = 1.0 / 60.0) -> void:
	if pending_cancel:
		cancel()
		pending_cancel = false
	if pending_pick:
		pending_pick = false
		if held == null:
			var r := ray()
			var query := PhysicsRayQueryParameters3D.create(r.origin, r.origin + r.direction * 200)
			var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
			if not hit.is_empty() and hit.collider.has_method("set_size_multiplier"):
				begin(hit.collider, hit.position, r.origin)
	if is_instance_valid(held):
		var r := ray()
		if automatic_distance:
			var query := PhysicsRayQueryParameters3D.create(r.origin, r.origin + r.direction * 80, 1, [held.get_rid()])
			var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
			distance = r.origin.distance_to(hit.position) if not hit.is_empty() else 40.0
		else:
			distance = clampf(distance * pow(1.12, wheel_steps), 0.3, 80.0)
		wheel_steps = 0
		var factor := clampf(initial_size * distance / initial_distance, 0.05, 20.0) if perspective_resize else initial_size
		var growth_blocked := resize_toward(factor, delta)
		var target: Vector3 = r.origin + r.direction * distance - held.global_basis * (grab_local * held.size_multiplier)
		pull_toward(target, delta)
		message = "Holding · %.2f kg · size ×%.2f%s" % [held.mass, held.size_multiplier, " · growth blocked" if growth_blocked else " · release to drop"]
		if held.suspended: message = "Simulation paused · resume to drag physically"
	if pending_release:
		pending_release = false
		release()

func begin(body, hit: Vector3, origin: Vector3) -> void:
	if body.fixed or not body.valid_volume:
		message = "Fixed objects cannot be pulled. Disable Fixed to move this shape."
		return
	held = body
	original_pose = body.global_transform
	original_linear = body.linear_velocity
	original_angular = body.angular_velocity
	initial_size = body.size_multiplier
	grab_local = (body.global_transform.affine_inverse() * hit) / initial_size
	initial_distance = maxf(origin.distance_to(hit), 0.3)
	distance = initial_distance
	body.held = true
	body.refresh_freeze()
	original_lock_rotation = body.lock_rotation
	body.lock_rotation = true
	body.angular_velocity = Vector3.ZERO
	body.sleeping = false
	picked.emit(body)

func fits(pose: Transform3D, factor: float) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	var shape := ConvexPolygonShape3D.new()
	shape.points = held.scaled_points(factor)
	query.shape = shape
	query.transform = pose
	query.exclude = [held.get_rid()]
	query.margin = 0.0
	return camera.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

## Limit resizing separately. Collision response, not a placement query, owns motion.
func resize_toward(factor: float, delta: float) -> bool:
	if held.suspended: return false
	var old_size: float = held.size_multiplier
	# Rate-limit growth to avoid abrupt collider/inertia changes.
	factor = clampf(factor, old_size * exp(-3.0 * delta), old_size * exp(3.0 * delta))
	if factor <= old_size:
		held.set_size_multiplier(factor)
		return false
	var low := old_size
	var high := factor
	if fits(held.global_transform, factor):
		low = factor
	else:
		for refinement in range(8):
			var middle := (low + high) * 0.5
			if fits(held.global_transform, middle): low = middle
			else: high = middle
	held.set_size_multiplier(low)
	return low < factor - 0.00001

## Assisted grab, separate from collision mass. Sublinear force scaling makes
## large objects manipulable while response frequency still falls with mass.
## Critical damping and implicit stepping keep light bodies from oscillating.
func spring_force(offset: Vector3, velocity: Vector3, body_mass: float, delta: float) -> Vector3:
	var assistance := pow(maxf(body_mass, 1.0), 0.8)
	var stiffness := spring_strength * grab_strength * assistance
	var damping := 2.0 * sqrt(stiffness * body_mass)
	var force_limit := max_force * grab_strength * assistance
	var denominator := 1.0 + damping * delta / body_mass + stiffness * delta * delta / body_mass
	return ((stiffness * offset - damping * velocity) / denominator).limit_length(force_limit)

func pull_toward(target: Vector3, delta: float) -> void:
	if held.suspended: return
	held.sleeping = false
	held.apply_central_force(spring_force(target - held.global_position, held.linear_velocity, held.mass, delta))

func release() -> void:
	if not is_instance_valid(held):
		held = null
		return
	held.lock_rotation = original_lock_rotation
	held.held = false
	held.refresh_freeze()
	held.sleeping = false
	held = null
	message = "Left-drag a shape · wheel: distance · release: drop · Esc: cancel"

func cancel() -> void:
	pending_pick = false
	wheel_steps = 0
	if is_instance_valid(held):
		held.set_size_multiplier(initial_size)
		held.global_transform = original_pose
		held.linear_velocity = original_linear
		held.angular_velocity = original_angular
	release()
