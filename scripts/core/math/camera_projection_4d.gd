extends RefCounted
## Pure convex 4D camera projection; no nodes, physics, UI or file IO.
## In perspective mode, +W in camera space is depth. Clip before dividing.
const Math4D = preload("res://scripts/core/math/transform_4d.gd")
var enabled := false
var position := Vector4(0, 0, 0, -8)
var focal := 8.0
var near_depth := 0.5

func project(vertices: Array[Vector4], rows: Array[Vector4], world_to_view: PackedFloat64Array) -> PackedVector3Array:
	var viewed: Array[Vector4] = []
	for vertex in vertices:
		viewed.append(Math4D.apply(world_to_view, vertex - position if enabled else vertex))
	var points := PackedVector3Array()
	if not enabled:
		for p in viewed: points.append(Vector3(rows[0].dot(p), rows[1].dot(p), rows[2].dot(p)))
		return points
	var front: Array[Vector4] = []
	var back: Array[Vector4] = []
	for p in viewed:
		if p.w >= near_depth: front.append(p)
		else: back.append(p)
	# All crossing vertex pairs include all actual convex-hull edges, without
	# requiring face/cell topology. Extra intersections lie inside the same hull.
	var clipped: Array[Vector4] = front.duplicate()
	for a in front:
		for b in back:
			clipped.append(a.lerp(b, (a.w - near_depth) / (a.w - b.w)))
	for p in clipped:
		points.append(Vector3(rows[0].dot(p), rows[1].dot(p), rows[2].dot(p)) * (focal / p.w))
	return points
