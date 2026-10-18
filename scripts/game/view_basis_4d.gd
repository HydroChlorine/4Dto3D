extends RefCounted
## Ordered visible axes. Selecting a projection is distinct from rotating a model.
const Projection4D = preload("res://scripts/core/math/projection_4d.gd")
const XYZ := "XYZ"
const WYZ := "WYZ"

static func rows(view: String) -> Array[Vector4]:
	var result: Array[Vector4] = [Vector4(1, 0, 0, 0), Vector4(0, 1, 0, 0), Vector4(0, 0, 1, 0)]
	if view == WYZ: result[0] = Vector4(0, 0, 0, 1)
	return result

static func embed(point: Vector3, view: String) -> Vector4:
	return Vector4(0, point.y, point.z, point.x) if view == WYZ else Vector4(point.x, point.y, point.z, 0)

static func project(vertices: Array[Vector4], view: String) -> PackedVector3Array:
	var projection := Projection4D.new()
	projection.rows = rows(view)
	return projection.project(vertices)

static func environment_mask(view: String) -> int:
	return 8 if view == WYZ else 1
