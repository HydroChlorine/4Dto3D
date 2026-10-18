extends SceneTree
## Real Jolt contacts and obstacle queries, not just geometry formula checks.
const Room = preload("res://scenes/artifact_puzzle.tscn")
const Artifact = preload("res://scripts/game/projected_artifact.gd")
var room
var failures := 0

func _initialize() -> void:
	call_deferred("verify")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func frames(count: int) -> void:
	for i in range(count): await physics_frame

func place(degrees: float, factor: float, position: Vector3) -> void:
	room.player.drop()
	room.artifact.commit_shape(degrees, factor)
	room.artifact.position = position
	room.artifact.linear_velocity = Vector3.ZERO
	room.artifact.angular_velocity = Vector3.ZERO

func turn_key(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_C
	event.pressed = pressed
	Input.parse_input_event(event)

func verify() -> void:
	room = Room.instantiate()
	root.add_child(room)
	await frames(3)
	var body = room.artifact
	if "--preview-only" in OS.get_cmdline_user_args():
		await frames(30)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/artifact_puzzle_preview.png")
		room.queue_free()
		await process_frame
		quit()
		return
	check(body.collider.shape is ConvexPolygonShape3D, "Artifact needs a native projected convex collider")
	check(body.points.size() == 16, "Projection must retain all 16 source corners")
	for angle in [0.0, 9.4623, 45.0, 90.0]:
		var points := Artifact.projected_points(angle, 0.8)
		var bounds := AABB(points[0], Vector3.ZERO)
		for point in points: bounds = bounds.expand(point)
		check(bounds.size.is_equal_approx(Artifact.dimensions_at(angle, 0.8)), "Core projection must match analytic puzzle dimensions")
	check(Artifact.dimensions_at(0, Artifact.MIN_SIZE).x > 1.4, "Shrinking alone must fail")
	check(Artifact.dimensions_at(90, 1).y > 1.4, "Rotating alone must fail")
	check(4 * pow(1.4 / 1.6, 3) < 6, "Every passing size must be too light for the plate")
	# Real grab ray and distance-based resizing, with the player left in place.
	room.player.camera.look_at(body.global_position)
	room.player.pick_requested = true
	await frames(2)
	check(room.player.holding, "Player must be able to ray-pick the artifact")
	room.player.wheel_steps = -2
	await frames(35)
	check(body.size_multiplier < 0.95, "Bringing the grab nearer must shrink the artifact")
	room.player.drop()
	room.player.camera.rotation = Vector3.ZERO
	# Stop room input updates while exercising the same collision/plate components.
	room.set_physics_process(false)
	# Full delivery using the actual grab spring, rotation input, and perspective rule.
	# Only walking and aiming are scripted; the artifact is never placed through a wall.
	room.reset_room()
	await frames(3)
	room.player.camera.look_at(body.global_position)
	room.player.pick_requested = true
	room.player.tick(1.0 / 60.0)
	check(room.player.holding, "Full route must start with a real grab ray")
	room.player.wheel_steps = -2
	turn_key(true)
	for i in range(130):
		await physics_frame
		room.player.camera.look_at(room.player.camera.global_position + Vector3(0, -0.2, -room.player.distance))
		room.player.tick(1.0 / 60.0)
	turn_key(false)
	check(body.angle > 89 and body.size_multiplier < 0.875, "Actual rotation and perspective input must produce passing dimensions")
	for i in range(180):
		await physics_frame
		room.player.position.z = lerpf(6.0, 1.0, minf(float(i) / 140.0, 1.0))
		room.player.tick(1.0 / 60.0)
	check(body.position.z < -1.1, "Held artifact must pass aperture under the grab spring")
	var passing_distance: float = room.player.distance
	var heavy_distance: float = room.player.starting_distance * 1.2 / room.player.starting_size
	for i in range(180):
		await physics_frame
		room.player.distance = lerpf(passing_distance, heavy_distance, minf(float(i) / 140.0, 1.0))
		room.player.position.z = room.player.distance - 2.6
		room.player.camera.rotation = Vector3.ZERO
		room.player.tick(1.0 / 60.0)
	check(body.mass >= 6, "Perspective enlargement beyond wall must achieve plate mass")
	room.player.drop()
	for i in range(180):
		await physics_frame
		room.plate.tick(body, 1.0 / 60.0)
	check(room.plate.active, "Complete grab/rotate/pass/enlarge/drop sequence must activate plate")
	room.reset_room()
	await frames(3)
	body.gravity_scale = 0
	place(90, 0.8, Vector3(0, 1.35, 0))
	await frames(3)
	check(body.change_fits(90, 0.81), "Known passing shape must have clearance inside aperture")
	check(not body.change_fits(0, 0.8), "Rotation envelope must detect the wall")
	check(not body.change_fits(90, 1.2), "Growth through sill/lintel must be blocked")
	body.request_shape(0, 1.2, 1.0)
	check(body.blocked, "Unsafe shape changes need blocked feedback")
	check(body.size_multiplier < 0.9, "Blocked shape changes must retain a passing height")
	# The valid solid actually travels through the wall under native 3D physics.
	place(90, 0.8, Vector3(0, 1.35, 1.3))
	body.linear_damp = 0
	body.linear_velocity = Vector3(0, 0, -2)
	await frames(85)
	check(body.position.z < -1.0, "Known solution must physically pass through the opening")
	# An unrotated shrunk shape is stopped by the actual wall, not a puzzle rule.
	place(0, 0.65, Vector3(0, 1.35, 1.3))
	body.linear_velocity = Vector3(0, 0, -2)
	await frames(85)
	check(body.position.z > 0.6, "Shrinking without XW rotation must physically hit the wall")
	body.linear_damp = 1
	body.gravity_scale = 1
	# Released, light artifact can rest on the plate without activating it.
	place(90, 0.8, Vector3(0, 1.2, -2.6))
	for i in range(150):
		await physics_frame
		room.plate.tick(body, 1.0 / 60.0)
	check(room.plate.supported_mass > 1.9, "Plate must recognize native supported contact")
	check(not room.plate.active, "Light artifact must not activate plate")
	# Heavy support needs settling, not transient overlap or a held object.
	place(90, 1.2, Vector3(0, 1.5, -2.6))
	body.held = true
	for i in range(150):
		await physics_frame
		room.plate.tick(body, 1.0 / 60.0)
	check(not room.plate.active, "Held artifact must not activate plate")
	body.held = false
	for i in range(55):
		await physics_frame
		room.plate.tick(body, 1.0 / 60.0)
	check(room.plate.active and room.door.opened, "Settled 6.912 kg artifact must open exit")
	await frames(2)
	check(room.door.collision.disabled, "Unlocked exit must actually disable its obstruction")
	# Completion and unload/reset behavior belong to the separate room host.
	room.player.position = Vector3(4, 0.05, -5.2)
	room._physics_process(1.0 / 60.0)
	check(room.completed, "Walking to the exit marker should complete the puzzle")
	place(90, 1.2, Vector3(2.2, 2.0, -2.6))
	await frames(3)
	room.plate.tick(body, 1.0 / 60.0)
	check(not room.plate.active and not room.door.opened, "Removing supported load must close exit")
	room.reset_room()
	await frames(2)
	check(is_equal_approx(body.mass, 4) and body.angle == 0 and body.size_multiplier == 1, "Reset must restore artifact parameters")
	check(not room.completed and not room.plate.active and not room.door.opened, "Reset must restore puzzle state")
	check(not room.player.holding, "Reset must drop any grab")
	if "--screenshot" in OS.get_cmdline_user_args():
		# Wait for transforms/HUD to reach the rendered frame after reset.
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/artifact_puzzle_preview.png")
	print("Artifact puzzle integration: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	room.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
