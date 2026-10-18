extends SceneTree
## Walkthrough integration: real grabs, view clearance, native contacts, and lesson progression.
const Scene = preload("res://scenes/guided_experience.tscn")
const Artifact = preload("res://scripts/game/projected_artifact.gd")
const Basis4D = preload("res://scripts/game/view_basis_4d.gd")
const Director = preload("res://scripts/game/guided/experience_director.gd")
var room
var failures := 0
var walking := Vector3.ZERO

func _initialize() -> void:
	call_deferred("verify")

func check(condition: bool, message: String) -> bool:
	if not condition:
		failures += 1
		push_error(message)
		print("State: step=%s view=%s player=%s artifact=%s angle=%.2f size=%.3f mass=%.3f held=%s notice=%s" % [room.director.step, room.basis_controller.current, room.player.position, room.artifact.position, room.artifact.angle, room.artifact.size_multiplier, room.artifact.mass, room.player.holding, room.notice])
	return condition

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	# Headless Windows cannot capture a cursor or dispatch window input. Feed action
	# events to the normal handlers and walk via the same native capsule motion.
	if DisplayServer.get_name() == "headless":
		room.player._unhandled_input(event)
		room._unhandled_input(event)
		match code:
			KEY_W: walking.z = -1.0 if pressed else 0.0
			KEY_S: walking.z = 1.0 if pressed else 0.0
			KEY_A: walking.x = -1.0 if pressed else 0.0
			KEY_D: walking.x = 1.0 if pressed else 0.0

func tick(count: int) -> void:
	for i in range(count):
		await physics_frame
		if DisplayServer.get_name() == "headless" and walking != Vector3.ZERO:
			room.player.velocity = walking.normalized() * 3.5
			room.player.move_and_slide()
		room._physics_process(1.0 / 60.0)

func aim_at(point: Vector3) -> void:
	room.player.camera.look_at(point)
	room.player.pitch = room.player.camera.rotation.x

func capture(label: String) -> void:
	if "--screenshots" not in OS.get_cmdline_user_args(): return
	room.update_hud()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/guided_%s.png" % label)

func finish() -> void:
	for code in [KEY_C, KEY_DOWN, KEY_UP, KEY_W, KEY_S, KEY_A, KEY_D]: key(code, false)
	print("Guided experience: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	room.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

func verify() -> void:
	room = Scene.instantiate()
	root.add_child(room)
	room.set_physics_process(false)
	await tick(5)
	var player = room.player
	var body = room.artifact
	var controller = room.basis_controller
	check(not body.visible and body.freeze and body.collision_layer == 0, "Artifact must initially remain in its WYZ room")
	check(not player.grab_enabled and not player.rotation_enabled and not player.resize_enabled, "Only movement should be available initially")
	await capture("start")
	check(not room.try_switch(), "Lesson must reject switching before reaching the ring")
	# Verify actual source geometry/projection, including the WYZ envelope's interior maximum.
	for view in ["XYZ", "WYZ"]:
		for angle in [0.0, 30.0, 80.5377, 90.0]:
			var points := Artifact.projected_points(angle, 0.8, view)
			var bounds := AABB(points[0], Vector3.ZERO)
			for point in points: bounds = bounds.expand(point)
			check(bounds.size.is_equal_approx(Artifact.dimensions_at(angle, 0.8, view)), "Both projection matrices must match analytic dimensions")
	body.angle = 70
	check(is_equal_approx(body.envelope(90, 1).x, Vector2(3.6, 0.6).length()), "WYZ rotation must include its interior width maximum")
	body.angle = 0
	var source: Array[Vector4] = room.wyz_region.entries[6].vertices_4d
	check(source[0].x == 0 and source[0].w != 0, "WYZ room must store geometry embedded in W, rather than X")
	check(Basis4D.project(source, "XYZ")[0].x == 0, "Changing projection must actually change stored geometry's output")
	# Walk to the pad; headless mode drives native capsule motion directly.
	key(KEY_W, true)
	for i in range(100):
		await tick(1)
		if room.director.step == Director.Step.SWITCH_OUT: break
	key(KEY_W, false)
	await tick(2)
	if not check(room.director.step == Director.Step.SWITCH_OUT, "Walking onto ring must unlock the view-switch instruction"):
		await finish()
		return
	var player_pose: Transform3D = player.global_transform
	var camera_rotation: Vector3 = player.camera.rotation
	key(KEY_F, true)
	key(KEY_F, false)
	await tick(2)
	if not check(controller.current == "WYZ", "F on ring must switch to WYZ"):
		await finish()
		return
	check(player.global_transform.is_equal_approx(player_pose) and player.camera.rotation == camera_rotation, "View switch must preserve player position and viewing direction")
	check(body.visible and body.view_basis == "WYZ" and body.collision_mask == 10 and player.collision_mask == 8, "WYZ must activate its room, artifact, and collision masks")
	check(not room.xyz_region.visible and room.wyz_region.visible, "Only the selected region should be visible")
	await tick(30)
	await capture("wyz")
	# Unheld artifact remains in its original room and reappears on a revisit.
	var stored_position: Vector3 = body.position
	check(controller.switch_view(), "Controller should permit an unheld return at the shared pad")
	check(not body.visible and controller.artifact_home == "WYZ", "Unheld artifact must not follow the player")
	await tick(3)
	check(controller.switch_view(), "Returning to WYZ should restore the unheld artifact, including resting contact")
	check(body.visible and body.position.distance_to(stored_position) < 0.03, "Unheld object should retain its stored position")
	# Approach it with real movement, then pick with E and a real ray query.
	key(KEY_W, true)
	for i in range(80):
		await tick(1)
		if room.director.step == Director.Step.GRAB: break
	key(KEY_W, false)
	await tick(2)
	check(room.director.step == Director.Step.GRAB, "Approaching artifact must reveal pickup instruction")
	aim_at(body.global_position)
	key(KEY_E, true)
	key(KEY_E, false)
	await tick(40)
	if not check(player.holding, "E must grab the artifact in WYZ through its active collision mask"):
		await finish()
		return
	check(room.director.step == Director.Step.RETURN_PAD, "Grabbing must reveal return-to-ring instruction")
	var untouched_size: float = body.size_multiplier
	key(KEY_C, true)
	key(KEY_DOWN, true)
	await tick(12)
	key(KEY_C, false)
	key(KEY_DOWN, false)
	check(body.angle == 0 and body.size_multiplier == untouched_size, "Rotation and resizing should wait until their lessons")
	key(KEY_S, true)
	for i in range(90):
		await tick(1)
		if room.director.step == Director.Step.SWITCH_BACK: break
	key(KEY_S, false)
	await tick(3)
	check(room.director.step == Director.Step.SWITCH_BACK and controller.at_pad(), "Returning while holding must enable the second switch")
	# Destination obstacles must reject a switch without mutating either pose.
	var obstruction = room.xyz_region.add_box("BlockedArrival", player.position + Vector3.UP * 0.85, Vector3(0.8, 1.5, 0.8), Color.RED)
	await tick(2)
	check(not room.try_switch() and controller.current == "WYZ", "An obstructed destination must reject switching")
	obstruction.queue_free()
	await tick(3)
	obstruction = room.xyz_region.add_box("BlockedExpansion", body.position + Vector3(1.4, 0, 0), Vector3(0.25, 0.25, 0.25), Color.RED)
	await tick(2)
	check(not room.try_switch() and controller.current == "WYZ", "Artifact's expanded XYZ projection must also fit before transfer")
	obstruction.queue_free()
	await tick(3)
	player_pose = player.global_transform
	var object_pose: Transform3D = body.global_transform
	var old_mass: float = body.mass
	var old_distance: float = player.distance
	var old_start_distance: float = player.starting_distance
	if not check(room.try_switch(), "Held artifact should return to XYZ when destination clears"):
		await finish()
		return
	check(player.global_transform.is_equal_approx(player_pose), "Held transfer must not move the player")
	check(body.global_transform.is_equal_approx(object_pose) and player.holding and body.held, "Transfer must retain apparent artifact pose and grab")
	check(body.mass == old_mass and body.size_multiplier == untouched_size, "View changes must preserve size and assigned mass")
	check(player.distance == old_distance and player.starting_distance == old_start_distance, "Perspective grab baseline must survive a view change")
	check(body.view_basis == "XYZ" and controller.artifact_home == "XYZ", "Held object must now belong to XYZ")
	check(is_equal_approx(body.points[0].x, -1.8), "Artifact should visibly widen from W length to X length")
	check(room.director.step == Director.Step.ROTATE, "Return should unlock the rotation lesson")
	await capture("return")
	# Walk back to the practice ring before rotating, as the HUD instructs.
	key(KEY_S, true)
	for i in range(100):
		await tick(1)
		if player.position.z >= 5.8: break
	key(KEY_S, false)
	await tick(5)
	aim_at(player.camera.global_position + Vector3(0, -0.15, -player.distance))
	key(KEY_C, true)
	await tick(90)
	key(KEY_C, false)
	check(room.director.step == Director.Step.SHRINK and body.angle >= 85, "Actual C input at practice ring must unlock resizing")
	await capture("rotate")
	key(KEY_DOWN, true)
	for i in range(70):
		await tick(1)
		if body.size_multiplier <= 0.82: break
	key(KEY_DOWN, false)
	await tick(8)
	check(room.director.step == Director.Step.PASS and body.size_multiplier <= 0.85, "Down Arrow must shrink and unlock the opening lesson")
	# Walk toward the opening with native collision; only aim is scripted.
	key(KEY_W, true)
	for i in range(180):
		aim_at(player.camera.global_position + Vector3(0, -0.15, -player.distance))
		await tick(1)
		if player.position.z <= 0.9: break
	key(KEY_W, false)
	await tick(80)
	if not check(room.director.step == Director.Step.ENLARGE, "Held projection must physically pass wall before enlargement lesson"):
		await capture("blocked_gap")
		await finish()
		return
	await capture("passed")
	# Up Arrow is the same distance/size rule as the wheel. Move back as it grows
	# to keep the physical target over the plate instead of pushing it too far.
	key(KEY_UP, true)
	for i in range(120):
		player.position.z = maxf(0.65, player.distance - 2.6)
		aim_at(player.camera.global_position + Vector3(0, 0, -player.distance))
		await tick(1)
		if body.size_multiplier >= 1.3: break
	key(KEY_UP, false)
	player.position.z = maxf(0.65, player.distance - 2.6)
	await tick(70)
	check(room.director.step == Director.Step.PLACE and body.mass >= 6, "Perspective enlargement must unlock release instruction")
	check(not room.plate.active, "Held artifact must not prematurely activate plate")
	key(KEY_E, true)
	key(KEY_E, false)
	await tick(180)
	check(room.plate.active and room.door.opened and room.director.step == Director.Step.EXIT, "Released heavy artifact must settle and reveal exit instruction")
	await capture("plate")
	# Walk to the door and through it; do not teleport the player past the wall.
	key(KEY_D, true)
	for i in range(100):
		await tick(1)
		if player.position.x >= 4.0: break
	key(KEY_D, false)
	key(KEY_W, true)
	for i in range(180):
		await tick(1)
		if room.completed: break
	key(KEY_W, false)
	check(room.completed and room.director.step == Director.Step.COMPLETE, "Walking through unlocked exit must complete experience")
	await capture("complete")
	# Recovery and full restart must not leave wrong masks, stale held state, or a live plate.
	room.recover_artifact()
	check(room.director.step == Director.Step.ROTATE and not player.holding and body.visible, "H recovery should restart only the manipulation section")
	check(not room.plate.active and not room.door.opened, "Recovery must unload plate and close exit")
	room.reset_room()
	check(room.director.step == Director.Step.WALK_PAD and controller.current == "XYZ", "Restart must restore initial lesson and view")
	check(controller.artifact_home == "WYZ" and not body.visible and body.freeze and body.collision_layer == 0, "Restart must leave artifact in original room")
	check(not player.holding and not player.rotation_enabled and not player.resize_enabled, "Restart must clear grab and restore lesson locks")
	await finish()
