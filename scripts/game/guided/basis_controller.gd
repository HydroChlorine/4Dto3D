extends RefCounted
## Destination masks stay queryable even when their region is not visible.
const Basis4D = preload("res://scripts/game/view_basis_4d.gd")
const Artifact = preload("res://scripts/game/projected_artifact.gd")
const PAD := Vector3(0, 0, 4.7)
const PAD_RADIUS := 0.75
signal changed(view: String)
var current := "XYZ"
var artifact_home := "WYZ"
var message := ""
var player
var artifact
var regions: Dictionary = {}

func at_pad() -> bool:
	return Vector2(player.position.x - PAD.x, player.position.z - PAD.z).length() <= PAD_RADIUS and absf(player.position.y) < 0.2

func shape_clear(shape: Shape3D, pose: Transform3D, mask: int, excluded: Array[RID]) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = pose
	query.collision_mask = mask
	query.exclude = excluded
	return player.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func destination_clear(target: String) -> bool:
	var mask := Basis4D.environment_mask(target)
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.245
	capsule.height = 1.69
	var pose: Transform3D = player.global_transform
	pose.origin += Vector3.UP * 0.85
	if not shape_clear(capsule, pose, mask, [player.get_rid(), artifact.get_rid()]):
		message = "The destination is obstructed. Move toward the center of the exchange ring."
		return false
	if player.holding or artifact_home == target:
		var shape := ConvexPolygonShape3D.new()
		shape.margin = 0.001
		# A small inset permits established resting contact, but not penetration.
		var points := Artifact.projected_points(artifact.angle, artifact.size_multiplier, target)
		for i in range(points.size()):
			for axis in range(3): points[i][axis] = move_toward(points[i][axis], 0.0, 0.002)
		shape.points = points
		if not shape_clear(shape, artifact.global_transform, mask | 2, [artifact.get_rid()]):
			message = "The artifact would intersect something in the other view. Lift it clear and try F again."
			return false
	return true

func switch_view() -> bool:
	message = ""
	if not at_pad():
		message = "Walk onto the illuminated exchange ring before pressing F."
		return false
	var target := "WYZ" if current == "XYZ" else "XYZ"
	if not destination_clear(target): return false
	if player.holding: artifact_home = target
	current = target
	player.velocity = Vector3.ZERO
	apply_view()
	changed.emit(current)
	return true

func apply_view() -> void:
	for view in regions: regions[view].visible = view == current
	var mask := Basis4D.environment_mask(current)
	player.environment_collision_mask = mask
	player.collision_mask = mask
	var present := artifact_home == current
	artifact.visible = present
	artifact.freeze = not present
	artifact.collision_layer = 4 if present else 0
	artifact.collision_mask = (mask | 2) if present else 0
	if present:
		artifact.view_basis = current
		artifact.commit_shape(artifact.angle, artifact.size_multiplier)
		# Avoid a burst of momentum when changing the collision solid.
		artifact.linear_velocity = Vector3.ZERO
		artifact.angular_velocity = Vector3.ZERO
		# Preserve hold distance/scale relationship, rather than starting a new grab.
		artifact.held = player.holding

func reset() -> void:
	current = "XYZ"
	artifact_home = "WYZ"
	message = ""
	apply_view()
