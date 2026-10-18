extends StaticBody3D
## Plate drives the door; the door has no knowledge of artifact or input rules.
var opened := false
var collision := CollisionShape3D.new()
var visual := MeshInstance3D.new()

func _ready() -> void:
	name = "ExitDoor"
	collision_layer = 1
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.8, 3.0, 0.7)
	collision.shape = shape
	add_child(collision)
	var mesh := BoxMesh.new()
	mesh.size = shape.size
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("dfaa56")
	visual.material_override = material
	add_child(visual)

func set_open(value: bool) -> void:
	opened = value
	collision.set_deferred("disabled", value)

func _process(delta: float) -> void:
	visual.position.y = move_toward(visual.position.y, 3.2 if opened else 0.0, delta * 3.0)
