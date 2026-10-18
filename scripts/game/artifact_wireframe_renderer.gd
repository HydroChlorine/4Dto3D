extends "res://scripts/rendering/shape_renderer.gd"
## The sandbox's wireframe adapter, with compact four-axis reference guides.
const W_COLOR := Color("ffd166")

func build_reference_axes() -> void:
	var directions := [Vector3.RIGHT, Vector3.UP, Vector3.BACK, Vector3(0.65, 0.45, -0.55)]
	var colors := [Color("b85a65"), Color("64a877"), Color("678dc5"), W_COLOR]
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for axis in range(4):
		mesh.surface_set_color(colors[axis])
		mesh.surface_add_vertex(Vector3.ZERO)
		mesh.surface_add_vertex(directions[axis] * 2.25)
	mesh.surface_end()
	var guide := MeshInstance3D.new()
	guide.mesh = mesh
	var guide_material := material(Color.WHITE)
	guide_material.vertex_color_use_as_albedo = true
	guide.material_override = guide_material
	add_child(guide)
	for axis in range(4):
		var label := Label3D.new()
		label.text = ["X", "Y", "Z", "W"][axis]
		label.position = directions[axis] * 2.45
		label.font_size = 38
		label.pixel_size = 0.012
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.modulate = colors[axis]
		add_child(label)

func update_highlight(_shape, _positions: PackedVector3Array, _selected_vertex: int) -> void:
	# This read-only view has no selected vertex or editor highlight.
	pass

func render_4d(shape, rotated: Array[Vector4], positions: PackedVector3Array) -> void:
	super.render(shape, positions, -1)
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	for edge in shape.edges:
		var delta := rotated[edge.y] - rotated[edge.x]
		var w_amount := absf(delta.w) / maxf(delta.length(), 0.000001)
		var color := Color("74ddff").lerp(W_COLOR, w_amount)
		vertices.append_array(PackedVector3Array([positions[edge.x], positions[edge.y]]))
		colors.append_array(PackedColorArray([color, color]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	wire.mesh = mesh
	var wire_material := material(Color.WHITE)
	wire_material.vertex_color_use_as_albedo = true
	wire.material_override = wire_material
