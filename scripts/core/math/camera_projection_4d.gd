extends RefCounted
## Pure convex 4D camera projection; no nodes, physics, UI or file IO.
## Matrix projection first; optional perspective views its W=0 embedding.
## In perspective mode, +W in camera space is depth. Clip before dividing.
const Math4D = preload("res://scripts/core/math/transform_4d.gd")
var enabled := false
var position := Vector4(0, 0, 0, -8)
var focal := 8.0
var near_depth := 0.5
var far_depth := 100.0
var fov_degrees := 90.0
const Hull = preload("res://scripts/core/geometry/convex_hull_3d.gd")

var look_at_target := true
var target := Vector4.ZERO

## Stage 1 always uses the original shared rotation and editable matrix.
## Stage 2 embeds that result at W=0 and views it with an independent camera.
func project(vertices: Array[Vector4], rows: Array[Vector4], world_to_view: PackedFloat64Array) -> PackedVector3Array:
	var points := PackedVector3Array()
	var camera_frame := viewing_frame()
	for vertex in vertices:
		var p := Math4D.apply(world_to_view, vertex)
		points.append(Vector3(rows[0].dot(p), rows[1].dot(p), rows[2].dot(p)))
	if not enabled: return points
	if near_depth <= 0 or far_depth <= near_depth: return PackedVector3Array()
	var slope := tan(deg_to_rad(clampf(fov_degrees, 1, 175)) * 0.5)
	# Inside: normal.dot(camera_point) + offset >= 0.
	var planes := [
		[Vector4(0,0,0,1), -near_depth], [Vector4(0,0,0,-1), far_depth],
		[Vector4(1,0,0,slope), 0.0], [Vector4(-1,0,0,slope), 0.0],
		[Vector4(0,1,0,slope), 0.0], [Vector4(0,-1,0,slope), 0.0],
		[Vector4(0,0,1,slope), 0.0], [Vector4(0,0,-1,slope), 0.0]]
	# Work in the embedded solid's original 3D coordinates. Rebuilding topology
	# after each cut provides cap edges for the next cut, including when no
	# original vertices lie inside the final frustum.
	for plane in planes:
		points = clip_plane(points, plane[0], plane[1], camera_frame)
		if points.is_empty(): return points
	var result := PackedVector3Array()
	for point in points:
		var p := Math4D.apply(camera_frame, Vector4(point.x, point.y, point.z, 0) - position)
		result.append(Vector3(p.x, p.y, p.z) * (focal / maxf(p.w, near_depth)))
	return result

func clip_plane(points: PackedVector3Array, normal: Vector4, offset: float, frame: PackedFloat64Array) -> PackedVector3Array:
	var inside := PackedVector3Array()
	for point in points:
		var p := Math4D.apply(frame, Vector4(point.x, point.y, point.z, 0) - position)
		var distance := normal.dot(p) + offset
		if distance >= 0: inside.append(point)
	if inside.is_empty() or inside.size() == points.size(): return inside
	var hull := Hull.build(points)
	# Hull deduplicates/reindexes points; evaluate distances against its vertices.
	for edge in hull.edges:
		var a: Vector3 = hull.vertices[edge[0]]
		var b: Vector3 = hull.vertices[edge[1]]
		var da := normal.dot(Math4D.apply(frame, Vector4(a.x,a.y,a.z,0)-position)) + offset
		var db := normal.dot(Math4D.apply(frame, Vector4(b.x,b.y,b.z,0)-position)) + offset
		if (da < 0) != (db < 0): inside.append(a.lerp(b, da / (da-db)))
	return inside

## Minimal proper rotation from the viewing direction to camera +W.
## Target coincident with camera falls back to straight ahead; antipodal uses XW.
func viewing_frame() -> PackedFloat64Array:
	var result := Math4D.identity()
	if not look_at_target: return result
	var direction := target - position
	if direction.length_squared() < 1e-12: return result
	direction = direction.normalized()
	var bisector := direction + Vector4(0, 0, 0, 1)
	if bisector.length_squared() < 1e-12:
		result[0] = -1
		result[18] = -1
		return result
	bisector = bisector.normalized()
	for row in range(4):
		for col in range(4):
			result[row * 5 + col] -= 2 * bisector[row] * bisector[col]
	for col in range(4): result[15 + col] *= -1
	return result

func depth_direction(_unused: PackedFloat64Array = PackedFloat64Array()) -> Vector4:
	var frame := viewing_frame()
	return Vector4(frame[15], frame[16], frame[17], frame[18])

func viewing_depth(_unused: PackedFloat64Array = PackedFloat64Array()) -> float:
	return (position - target).dot(depth_direction())

func set_viewing_depth(value: float, _unused: PackedFloat64Array = PackedFloat64Array()) -> void:
	# Looking at the target: stop just before it rather than flip through it.
	if look_at_target: value = minf(value, -0.05)
	position += depth_direction() * (value - viewing_depth())
