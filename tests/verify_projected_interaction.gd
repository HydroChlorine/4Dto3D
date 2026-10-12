extends SceneTree
## Focused smoke checks for camera clipping and native grab lifecycle.
func _initialize() -> void:
	call_deferred("verify")

func verify() -> void:
	var projection = preload("res://scripts/core/math/camera_projection_4d.gd").new()
	var math = preload("res://scripts/core/math/transform_4d.gd")
	var rows: Array[Vector4] = [Vector4(1,0,0,0), Vector4(0,1,0,0), Vector4(0,0,1,0)]
	var vertices: Array[Vector4] = [Vector4(1,2,3,0)]
	projection.enabled = true
	assert(projection.project(vertices, rows, math.identity())[0].is_equal_approx(Vector3(1,2,3)))
	projection.position.w = -4
	assert(projection.project(vertices, rows, math.identity())[0].is_equal_approx(Vector3(2,4,6)))
	projection.position.w = 1
	assert(projection.project(vertices, rows, math.identity()).is_empty())
	vertices = [Vector4(0,0,0,0), Vector4(1,0,0,2)]
	var clipped = projection.project(vertices, rows, math.identity())
	assert(clipped.size() == 2)
	for p in clipped: assert(p.is_finite())
	var demo = preload("res://scripts/sandbox/projected_physics/demo.gd").new()
	root.add_child(demo)
	demo.running = false
	demo.update_suspension()
	await physics_frame
	var body = demo.entries[0].body
	var controller = demo.grabber
	var original: Transform3D = body.global_transform
	controller.begin(body, body.position, demo.camera.position)
	assert(body.held)
	body.suspended = false
	body.refresh_freeze()
	controller.resize_toward(1.5, 0.2)
	assert(is_equal_approx(body.size_multiplier, 1.5))
	assert(body.collider.shape.points == body.scaled_points(1.5))
	controller.cancel()
	assert(not body.held and body.global_transform.is_equal_approx(original))
	assert(is_equal_approx(body.size_multiplier, 1.0))
	controller.begin(body, body.position, demo.camera.position)
	controller.resize_toward(1.2, 0.2)
	assert(is_equal_approx(body.mass, pow(1.2, 3)))
	controller.release()
	assert(not body.held and is_equal_approx(body.size_multiplier, 1.2))
	demo.camera_4d.enabled = true
	body.update_geometry(0)
	assert(body.valid_volume)
	demo.camera_4d.position.w = 10
	body.update_geometry(0)
	assert(body.collider.shape == null and not body.renderer.visible)
	demo.camera_4d.position.w = -8
	body.update_geometry(0)
	assert(body.valid_volume and body.renderer.visible)
	demo.reset_simulation()
	assert(is_equal_approx(body.size_multiplier, 1.0))
	# Native contact allows sideways motion across the infinite floor.
	demo.set_physics_process(false)
	body.suspended = false
	body.refresh_freeze()
	body.position = Vector3(-4, 1.01, 0)
	controller.begin(body, body.position, demo.camera.position)
	assert(not body.freeze and body.lock_rotation)
	var start_x: float = body.position.x
	for i in range(90):
		controller.pull_toward(Vector3(-1, 1, 0), 1.0 / 60.0)
		await physics_frame
	assert(body.position.x > start_x + 1.0, "Held body slides along floor")
	assert(body.position.y > 0.8, "Native contact prevents floor penetration")
	controller.release()
	assert(not body.lock_rotation)
	var light = controller.spring_force(Vector3.RIGHT, Vector3.ZERO, 1, 1.0/60.0)
	var heavy = controller.spring_force(Vector3.RIGHT, Vector3.ZERO, 10, 1.0/60.0)
	assert(light.length() > heavy.length() / 10.0, "Heavy object accelerates less")
	body.base_mass = 3
	body.set_size_multiplier(2)
	assert(is_equal_approx(body.mass, 24))
	print("Interaction smoke passed: perspective, near clipping, drag, resize, cancel, drop, reset")
	quit()
