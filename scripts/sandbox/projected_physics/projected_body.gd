extends RigidBody3D
## Godot adapter: 4D authored geometry plus a separate simulated 3D pose.
## Core math remains independent of Godot physics nodes and presentation.
const Renderer = preload("res://scripts/rendering/solid_hull_renderer.gd")
const Math4D = preload("res://scripts/core/math/transform_4d.gd")
var view_rotation := Math4D.identity()
var camera_4d := preload("res://scripts/core/math/camera_projection_4d.gd").new()
var held := false
## Mass at uniform grab size 1. Camera deformation does not redefine density.
var base_mass := 1.0:
	set(value):
		base_mass = maxf(value, 0.01)
		update_mass()
var size_multiplier := 1.0
var rendered_size := -1.0
var local_points := PackedVector3Array()
var model
var renderer := Renderer.new()
var collider := CollisionShape3D.new()
var authored_center := Vector3.ZERO
var initialized := false
var fixed := false
var suspended := false
var valid_volume := false
var last_projected := PackedVector3Array()
var error := ""

func _ready() -> void:
	add_child(renderer)
	add_child(collider)
	continuous_cd = true
	var material := PhysicsMaterial.new()
	material.friction = 0.7
	material.bounce = 0.15
	physics_material_override = material

## Called at physics ticks. Rebuild only when authored projected points change.
## Center the hull locally so native body rotation is around the projected solid.
func update_geometry(time: float, reset_pose: bool = false) -> bool:
	var sample = model.track.sample(time)
	if sample == null:
		error = model.track.error
		return false
	var projection = model.projection_track.sample(time)
	if projection == null:
		error = model.projection_track.error
		return false
	var rows: Array[Vector4] = projection.rows
	var vertices: Array[Vector4] = []
	for vertex in model.shape.vertices: vertices.append(Math4D.apply(sample.matrix, vertex))
	var projected := camera_4d.project(vertices, rows, view_rotation)
	if projected.is_empty():
		# Entire hull behind the 4D near plane: never leave a stale collider.
		valid_volume = false
		collider.shape = null
		renderer.hide()
		last_projected.clear()
		local_points.clear()
		refresh_freeze()
		error = "Outside the 4D viewing frustum, or invalid Near/Far range (no collider)."
		return true
	if projected == last_projected and not reset_pose:
		if not is_equal_approx(rendered_size, size_multiplier): rebuild_solid()
		return true
	var center := Vector3.ZERO
	for point in projected: center += point
	center /= projected.size()
	local_points.clear()
	for point in projected: local_points.append(point - center)
	rebuild_solid()
	if not initialized or reset_pose:
		transform = Transform3D(Basis.IDENTITY, center)
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
	else:
		# Authored displacement is world-space; retain accumulated native motion.
		position += center - authored_center
	authored_center = center
	last_projected = projected.duplicate()
	initialized = true
	sleeping = false
	refresh_freeze()
	error = "" if valid_volume else "Projection has no 3D volume: collision and gravity suspended."
	return true

func refresh_freeze() -> void:
	freeze = fixed or suspended or not valid_volume

## Native body scale stays identity. Bake uniform resizing into mesh and collider.
func rebuild_solid() -> void:
	if local_points.is_empty(): return
	var scaled := scaled_points(size_multiplier)
	renderer.render(model, scaled)
	valid_volume = renderer.hull.dimension == 3
	if valid_volume:
		var shape := ConvexPolygonShape3D.new()
		shape.points = scaled
		collider.shape = shape
	else:
		collider.shape = null
	update_mass()
	rendered_size = size_multiplier
	refresh_freeze()

func scaled_points(factor: float) -> PackedVector3Array:
	var points := PackedVector3Array()
	for p in local_points: points.append(p * factor)
	return points

func set_size_multiplier(value: float) -> void:
	size_multiplier = clampf(value, 0.05, 20.0)
	if not is_equal_approx(rendered_size, size_multiplier): rebuild_solid()

func update_mass() -> void:
	mass = maxf(base_mass * pow(size_multiplier, 3.0), 0.000001)
	if is_inside_tree(): sleeping = false
