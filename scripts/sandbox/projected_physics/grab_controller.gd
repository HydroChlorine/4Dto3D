extends Node
## Mouse interaction adapter. Queries run only from the host's physics tick.
## Changes native pose and a persistent uniform size multiplier, never 4D fields.
signal picked(body)
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

func physics_tick() -> void:
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
		var target: Vector3 = r.origin + r.direction * distance - held.global_basis * (grab_local * factor)
		move_safely(target, factor)
	if pending_release:
		pending_release = false
		release()

func begin(body, hit: Vector3, origin: Vector3) -> void:
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
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
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

## Sweep sampled poses/sizes and refine first blocked interval. This is a bounded
## placement heuristic, not exact continuous collision detection for deformation.
func move_safely(target: Vector3, factor: float) -> void:
	var start: Transform3D = held.global_transform
	var old_size: float = held.size_multiplier
	var accepted := 0.0
	var blocked := false
	for step in range(1, 13):
		var fraction := step / 12.0
		var candidate := Transform3D(start.basis, start.origin.lerp(target, fraction))
		if fits(candidate, lerpf(old_size, factor, fraction)):
			accepted = fraction
			continue
		var low := accepted
		var high := fraction
		for refinement in range(7):
			var middle := (low + high) * 0.5
			candidate.origin = start.origin.lerp(target, middle)
			if fits(candidate, lerpf(old_size, factor, middle)): low = middle
			else: high = middle
		accepted = low
		blocked = true
		break
	held.set_size_multiplier(lerpf(old_size, factor, accepted))
	held.global_transform = Transform3D(start.basis, start.origin.lerp(target, accepted))
	message = "Holding · size ×%.2f · %s" % [held.size_multiplier, "blocked by geometry" if blocked else "release to drop"]

func release() -> void:
	if not is_instance_valid(held):
		held = null
		return
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
