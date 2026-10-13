extends SceneTree
func _initialize() -> void:
	var camera = preload("res://scripts/core/math/camera_projection_4d.gd").new()
	var math = preload("res://scripts/core/math/transform_4d.gd")
	var rows: Array[Vector4] = [Vector4(1,0,0,0),Vector4(0,1,0,0),Vector4(0,0,1,0)]
	var points: Array[Vector4] = []
	for i in range(8): points.append(Vector4(20 if i&1 else -20,20 if i&2 else -20,20 if i&4 else -20,0))
	camera.enabled = true
	camera.look_at_target = false
	var output = camera.project(points, rows, math.identity())
	assert(not output.is_empty(), "Must clip enclosing solid even with all original vertices outside")
	for p in output: assert(p.abs().max_axis_index() >= 0 and maxf(absf(p.x),maxf(absf(p.y),absf(p.z))) <= 8.001)
	camera.position.x = 50
	assert(camera.project(points, rows, math.identity()).is_empty())
	camera.position.x = 0
	camera.far_depth = 7
	assert(camera.project(points, rows, math.identity()).is_empty())
	camera.far_depth = 100
	camera.fov_degrees = 60
	output = camera.project(points, rows, math.identity())
	assert(not output.is_empty())
	for p in output: assert(maxf(absf(p.x),maxf(absf(p.y),absf(p.z))) <= 8*tan(PI/6)+0.001)
	print("Frustum smoke passed: partial cuts, all-vertices-outside intersection, side rejection, far rejection, FOV")
	quit()
