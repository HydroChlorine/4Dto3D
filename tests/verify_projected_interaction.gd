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
	assert(body.held and body.freeze)
	controller.move_safely(body.position + Vector3.UP * 2, 1.5)
	assert(body.position.y > original.origin.y + 1)
	assert(is_equal_approx(body.size_multiplier, 1.5))
	assert(body.collider.shape.points == body.scaled_points(1.5))
	controller.cancel()
	assert(not body.held and body.global_transform.is_equal_approx(original))
	assert(is_equal_approx(body.size_multiplier, 1.0))
	controller.begin(body, body.position, demo.camera.position)
	controller.move_safely(body.position + Vector3.UP, 1.2)
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
	print("Interaction smoke passed: perspective, near clipping, drag, resize, cancel, drop, reset")
	quit()
