extends PanelContainer
## Fixed-scale explanatory projection; never changes the physical artifact.
const Artifact = preload("res://scripts/game/projected_artifact.gd")
const Tesseract = preload("res://scripts/core/geometry/generators/tesseract.gd")
const Transform4D = preload("res://scripts/core/math/transform_4d.gd")
const Projection4D = preload("res://scripts/core/math/projection_4d.gd")
const Wireframe = preload("res://scripts/game/artifact_wireframe_renderer.gd")
var source := Tesseract.new()
var renderer := Wireframe.new()
var projection := Projection4D.new()
var angle_label := Label.new()
var last_angle := INF

func _ready() -> void:
	name = "Artifact4DPreview"
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -302
	offset_right = -22
	offset_top = 20
	offset_bottom = 254
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.035, 0.06, 0.1, 0.9)
	background.content_margin_left = 12
	background.content_margin_right = 12
	background.content_margin_top = 10
	background.content_margin_bottom = 10
	background.corner_radius_top_right = 8
	background.corner_radius_bottom_left = 8
	add_theme_stylebox_override("panel", background)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	angle_label.add_theme_font_size_override("font_size", 15)
	column.add_child(angle_label)
	var container := SubViewportContainer.new()
	container.custom_minimum_size = Vector2(256, 170)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(container)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(256, 170)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.gui_disable_input = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)
	viewport.add_child(renderer)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 5.6
	camera.position = Vector3(4, 3, 6)
	viewport.add_child(camera)
	camera.look_at(Vector3.ZERO)
	camera.current = true
	var legend := Label.new()
	legend.text = "Fixed scale · gold shows W"
	legend.add_theme_font_size_override("font_size", 13)
	legend.add_theme_color_override("font_color", Color("b8ccdf"))
	column.add_child(legend)
	# An oblique view preserves W separation that the gameplay XYZ view discards.
	projection.rows = [Vector4(1, 0, 0, 0.65), Vector4(0, 1, 0, 0.45), Vector4(0, 0, 1, -0.55)]
	for i in range(source.vertices.size()):
		for axis in range(4): source.vertices[i][axis] *= Artifact.DIMENSIONS[axis] * 0.5
	show_angle(0.0)

func show_angle(degrees: float) -> void:
	if is_equal_approx(last_angle, degrees): return
	last_angle = degrees
	angle_label.text = "4D / oblique wireframe   %.0f°" % degrees
	var transform4d := Transform4D.new()
	transform4d.angles[2] = degrees
	var rotated := transform4d.transform_vertices(source.vertices)
	renderer.render_4d(source, rotated, projection.project(rotated))
