extends StaticBody3D
## Gameplay load sensor: settled, released artifact genuinely supported on top.
signal activation_changed(active: bool)
const REQUIRED_MASS := 6.0
var active := false
var supported_mass := 0.0
var settling_time := 0.0
var status := "Deliver the artifact"
var visual := MeshInstance3D.new()
var material := StandardMaterial3D.new()

func _ready() -> void:
	name = "PressurePlate"
	collision_layer = 1
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.6, 0.2, 2.4)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	add_child(collision)
	var mesh := BoxMesh.new()
	mesh.size = shape.size
	visual.mesh = mesh
	material.albedo_color = Color("e4ad53")
	visual.material_override = material
	add_child(visual)

func tick(artifact, delta: float) -> void:
	var half: Vector3 = artifact.dimensions_at(artifact.angle, artifact.size_multiplier, artifact.view_basis) * 0.5
	var local: Vector3 = artifact.global_position - global_position
	var above := absf(local.x) + half.x < 1.3 and absf(local.z) + half.z < 1.2
	var bottom: float = artifact.global_position.y - half.y
	var on_top := absf(bottom - (global_position.y + 0.1)) < 0.055
	var touching: bool = artifact.get_colliding_bodies().has(self)
	var supported: bool = above and on_top and touching and not artifact.held
	supported_mass = artifact.mass if supported else 0.0
	var heavy_enough := supported_mass >= REQUIRED_MASS
	var settled: bool = artifact.linear_velocity.length() < 0.15
	settling_time = settling_time + delta if heavy_enough and settled else 0.0
	set_active(settling_time >= 0.6)
	if artifact.held and above: status = "Release the artifact onto the plate"
	elif supported and not heavy_enough: status = "Too light — enlarge the artifact"
	elif active: status = "Load accepted — exit unlocked"
	elif heavy_enough: status = "Let the artifact settle…"
	else: status = "Deliver the artifact"
	visual.position.y = move_toward(visual.position.y, -0.045 if active else 0.0, delta * 0.15)

func set_active(value: bool) -> void:
	if active == value: return
	active = value
	material.albedo_color = Color("76efa1") if active else Color("e4ad53")
	activation_changed.emit(active)

func reset_plate() -> void:
	settling_time = 0.0
	supported_mass = 0.0
	status = "Deliver the artifact"
	visual.position.y = 0
	set_active(false)
