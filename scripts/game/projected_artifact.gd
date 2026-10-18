extends RigidBody3D
## Game adapter: 4D source -> accepted projected solid -> native 3D physics.
const Transform4D = preload("res://scripts/core/math/transform_4d.gd")
const Projection4D = preload("res://scripts/core/math/projection_4d.gd")
const Renderer = preload("res://scripts/rendering/solid_hull_renderer.gd")
const ViewBasis = preload("res://scripts/game/view_basis_4d.gd")
const DIMENSIONS := Vector4(3.6, 1.6, 1.2, 0.6)
const MIN_SIZE := 0.65
const MAX_SIZE := 1.5
const BASE_MASS := 4.0
var angle := 0.0
var view_basis := "XYZ"
var size_multiplier := 1.0
var held := false
var blocked := false
var collider := CollisionShape3D.new()
var renderer := Renderer.new()
var points := PackedVector3Array()
var style := {"visible": true, "color": Color("56d9dd"), "show_edges": true}

func _ready() -> void:
	name = "Artifact"
	collision_layer = 4
	collision_mask = 3
	lock_rotation = true # Ordinary tumbling would bypass the introductory puzzle.
	continuous_cd = true
	linear_damp = 1.0
	contact_monitor = true
	max_contacts_reported = 16
	var material := PhysicsMaterial.new()
	material.friction = 0.8
	material.bounce = 0.0
	physics_material_override = material
	add_child(renderer)
	add_child(collider)
	commit_shape(0.0, 1.0)

static func dimensions_at(degrees: float, factor: float, view: String = "XYZ") -> Vector3:
	var radians := deg_to_rad(degrees)
	var width := DIMENSIONS.x * cos(radians) + DIMENSIONS.w * sin(radians)
	if view == "WYZ": width = DIMENSIONS.x * sin(radians) + DIMENSIONS.w * cos(radians)
	return Vector3(width, DIMENSIONS.y, DIMENSIONS.z) * factor

static func projected_points(degrees: float, factor: float, view: String = "XYZ") -> PackedVector3Array:
	var transform4d := Transform4D.new()
	transform4d.angles[2] = degrees
	var vertices: Array[Vector4] = []
	for corner in range(16):
		var vertex := Vector4.ZERO
		for axis in range(4):
			vertex[axis] = DIMENSIONS[axis] * (0.5 if corner & (1 << axis) else -0.5)
		vertices.append(vertex)
	var projected := ViewBasis.project(transform4d.transform_vertices(vertices), view)
	for i in range(projected.size()): projected[i] *= factor
	return projected

func commit_shape(degrees: float, factor: float) -> void:
	angle = degrees
	size_multiplier = factor
	points = projected_points(angle, size_multiplier, view_basis)
	var shape := ConvexPolygonShape3D.new()
	shape.margin = 0.001
	shape.points = points
	collider.shape = shape
	renderer.render(style, points)
	mass = BASE_MASS * pow(size_multiplier, 3.0)
	sleeping = false

## Exact enclosing box for XW rotation, conservatively enlarged for simultaneous scale.
## Supports XYZ/WYZ views of the centered hyperrectangle, with locked 3D rotation.
func envelope(degrees: float, factor: float) -> Vector3:
	var lower := minf(angle, degrees)
	var upper := maxf(angle, degrees)
	var peak := rad_to_deg(atan2(DIMENSIONS.w, DIMENSIONS.x))
	if view_basis == "WYZ": peak = rad_to_deg(atan2(DIMENSIONS.x, DIMENSIONS.w))
	var width := maxf(dimensions_at(lower, 1.0, view_basis).x, dimensions_at(upper, 1.0, view_basis).x)
	if peak >= lower and peak <= upper: width = Vector2(DIMENSIONS.x, DIMENSIONS.w).length()
	return Vector3(width, DIMENSIONS.y, DIMENSIONS.z) * maxf(size_multiplier, factor)

func change_fits(degrees: float, factor: float) -> bool:
	var bounds := envelope(degrees, factor)
	var current := dimensions_at(angle, size_multiplier, view_basis)
	# Nested shrinkage cannot introduce a new penetration, even while resting.
	if bounds.x <= current.x + 0.000001 and bounds.y <= current.y + 0.000001 and bounds.z <= current.z + 0.000001:
		return true
	var shape := BoxShape3D.new()
	# Permit resting contact within 2 mm; puzzle clearance is much larger.
	shape.size = bounds - Vector3.ONE * 0.004
	shape.margin = 0.001
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = global_transform
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func request_shape(degrees: float, factor: float, delta: float) -> void:
	degrees = move_toward(angle, clampf(degrees, 0.0, 90.0), 65.0 * delta)
	factor = move_toward(size_multiplier, clampf(factor, MIN_SIZE, MAX_SIZE), 0.7 * delta)
	blocked = false
	if is_equal_approx(angle, degrees) and is_equal_approx(size_multiplier, factor): return
	var fraction := 1.0
	if not change_fits(degrees, factor):
		blocked = true
		var low := 0.0
		var high := 1.0
		for iteration in range(10):
			var middle := (low + high) * 0.5
			if change_fits(lerpf(angle, degrees, middle), lerpf(size_multiplier, factor, middle)): low = middle
			else: high = middle
		fraction = low
	if fraction > 0.001:
		commit_shape(lerpf(angle, degrees, fraction), lerpf(size_multiplier, factor, fraction))

func reset_artifact(pose: Transform3D) -> void:
	held = false
	blocked = false
	global_transform = pose
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	commit_shape(0.0, 1.0)
