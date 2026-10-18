extends Node3D
## Authored 3D chart embedded in R4. Visibility is an explicit region rule.
const Basis4D = preload("res://scripts/game/view_basis_4d.gd")
var view_basis := "XYZ"
var entries: Array[Dictionary] = []

func add_box(label: String, center: Vector3, dimensions: Vector3, color: Color) -> StaticBody3D:
	var vertices: Array[Vector4] = []
	for corner in range(8):
		var point := center
		for axis in range(3): point[axis] += dimensions[axis] * (0.5 if corner & (1 << axis) else -0.5)
		vertices.append(Basis4D.embed(point, view_basis))
	var projected := Basis4D.project(vertices, view_basis)
	var bounds := AABB(projected[0], Vector3.ZERO)
	for point in projected: bounds = bounds.expand(point)
	var body := StaticBody3D.new()
	body.name = label
	body.position = bounds.get_center()
	body.collision_layer = Basis4D.environment_mask(view_basis)
	body.collision_mask = 0 # Inactive-region bodies cannot initiate collision pairs.
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = bounds.size
	collision.shape = shape
	body.add_child(collision)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = bounds.size
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	visual.material_override = material
	body.add_child(visual)
	add_child(body)
	entries.append({"vertices_4d": vertices, "body": body})
	return body
