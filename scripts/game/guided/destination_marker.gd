extends Node3D
## Collision-free illuminated destination; the HUD also points to off-screen goals.
var caption := Label3D.new()
var material := StandardMaterial3D.new()

func _ready() -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.57
	torus.outer_radius = 0.64
	ring.mesh = torus
	ring.position.y = 0.035
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("79eff0")
	ring.material_override = material
	add_child(ring)
	var beam := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.61
	cylinder.bottom_radius = 0.61
	cylinder.height = 1.2
	beam.mesh = cylinder
	beam.position.y = 0.6
	var beam_material := StandardMaterial3D.new()
	beam_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_material.albedo_color = Color(0.35, 0.94, 0.95, 0.065)
	beam.material_override = beam_material
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(beam)
	var light := OmniLight3D.new()
	light.position.y = 0.5
	light.light_color = Color("79eff0")
	light.light_energy = 0.5
	light.omni_range = 3.0
	add_child(light)
	caption.position.y = 2.05
	caption.font_size = 28
	caption.pixel_size = 0.0035
	caption.outline_size = 3
	caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	caption.modulate = Color("a8ffff")
	add_child(caption)

func point_to(destination: Vector3, text: String) -> void:
	position = destination
	caption.text = text
