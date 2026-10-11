extends Node3D
## Sandbox host for native 3D physics of projected 4D convex solids.
## Does not use or change the independent 4D collision/physics backend.
const Model = preload("res://scripts/sandbox/procedural/object_view_model.gd")
const Card = preload("res://scripts/sandbox/procedural/object_card.gd")
const Body = preload("res://scripts/sandbox/projected_physics/projected_body.gd")
const Catalog = preload("res://scripts/io/shape_catalog.gd")
const UITheme = preload("res://scripts/sandbox/procedural/procedural_theme.gd")
var entries: Array = []
var selected := -1
var time := 0.0
var running := true
var active := true
var selector: OptionButton
var editor: VBoxContainer
var status: Label
var panel: PanelContainer
var camera: Camera3D
var pending: Array[Callable] = []
var view_angles := Vector3.ZERO
var view_sliders: Array[HSlider] = []
var view_matrix := Body.Math4D.identity()
var camera_4d := preload("res://scripts/core/math/camera_projection_4d.gd").new()
var grabber := preload("res://scripts/sandbox/projected_physics/grab_controller.gd").new()
var grab_status: Label

func _ready() -> void:
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("101722")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.5
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.shadow_enabled = true
	add_child(sun)
	camera = Camera3D.new()
	camera.set_script(preload("res://scripts/sandbox/fly_camera.gd"))
	add_child(camera)
	reset_camera()
	camera.current = true
	grabber.camera = camera
	add_child(grabber)
	grabber.picked.connect(func(body):
		for i in range(entries.size()):
			if entries[i].body == body: select_shape(i))
	build_floor()
	build_ui()
	add_shape(0, Vector4(-2, 5, 0, 0))
	add_shape(3, Vector4(2, 8, 0, 1))

func reset_camera() -> void:
	camera.position = Vector3(13, 10, 18)
	camera.look_at(Vector3(0, 3, 0))

func build_floor() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.name = "Floor"
	floor_body.position.y = -0.5
	add_child(floor_body)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(40, 1, 40)
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("526475")
	material.roughness = 0.9
	mesh.material_override = material
	floor_body.add_child(mesh)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box.size
	collision.shape = shape
	floor_body.add_child(collision)

func button(parent: Node, text: String, action: Callable) -> Button:
	var result := Button.new()
	result.text = text
	result.pressed.connect(action)
	parent.add_child(result)
	return result

func build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	panel = PanelContainer.new()
	panel.theme = UITheme.create()
	layer.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	panel.offset_left = 20
	panel.offset_right = 640
	panel.offset_top = 16
	panel.offset_bottom = -16
	var scroll := ScrollContainer.new()
	panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	var title := Label.new()
	title.text = "Projected world · 3D physics"
	title.add_theme_font_size_override("font_size", 23)
	box.add_child(title)
	var help := Label.new()
	help.text = "4D fields author the shape; Godot simulates its 3D pose.\nExpressions use t (seconds); rotations use degrees.\nRMB look · WASD fly · Q/E down/up · Shift faster"
	help.add_theme_font_size_override("font_size", 14)
	box.add_child(help)
	var controls := HBoxContainer.new()
	box.add_child(controls)
	var pause := button(controls, "Pause", func():
		running = not running
		update_suspension())
	pause.pressed.connect(func(): pause.text = "Pause" if running else "Run")
	button(controls, "Reset simulation", func(): pending.append(reset_simulation))
	button(controls, "Reset camera", reset_camera)
	build_grab_controls(box)
	build_view_controls(box)
	build_camera_4d_controls(box)
	var add_row := HBoxContainer.new()
	box.add_child(add_row)
	var catalog := OptionButton.new()
	for entry in Catalog.ENTRIES: catalog.add_item(entry.name)
	catalog.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_row.add_child(catalog)
	button(add_row, "Add shape", func(): pending.append(func(): add_shape(catalog.selected, Vector4(0, 6, 0, 0))))
	selector = OptionButton.new()
	selector.item_selected.connect(select_shape)
	box.add_child(selector)
	editor = VBoxContainer.new()
	box.add_child(editor)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(status)
	var collapse := button(layer, "◀", func(): panel.visible = not panel.visible)
	collapse.position = Vector2(0, 160)
	collapse.theme = UITheme.create()
	collapse.pressed.connect(func(): collapse.text = "◀" if panel.visible else "▶")

## Three continuous viewing rotations; zero keeps each existing projection unchanged.
## For default XYZ, XW=90 maps W to display X, YW=90 maps W to Y, etc.
func build_view_controls(box: VBoxContainer) -> void:
	var section := VBoxContainer.new()
	box.add_child(section)
	var label := Label.new()
	label.text = "Shared 4D view · mix XYZ with W"
	section.add_child(label)
	for axis in range(3):
		var row := HBoxContainer.new()
		section.add_child(row)
		var name_label := Label.new()
		name_label.text = ["X ↔ W", "Y ↔ W", "Z ↔ W"][axis]
		name_label.custom_minimum_size.x = 70
		row.add_child(name_label)
		var slider := HSlider.new()
		slider.min_value = -180
		slider.max_value = 180
		slider.step = 0.5
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(slider)
		var value_label := Label.new()
		value_label.custom_minimum_size.x = 65
		value_label.text = "0°"
		row.add_child(value_label)
		slider.value_changed.connect(func(value):
			view_angles[axis] = value
			value_label.text = "%.1f°" % value
			update_view_matrix())
		view_sliders.append(slider)
	button(section, "Reset view to XYZ", func():
		for slider in view_sliders: slider.value = 0)

func update_view_matrix() -> void:
	grabber.cancel()
	var rotation := Body.Math4D.new()
	rotation.angles[2] = -view_angles.x
	rotation.angles[4] = -view_angles.y
	rotation.angles[5] = -view_angles.z
	view_matrix = rotation.rotation_matrix()
	# Geometry mutation waits until the physics tick, including when paused.
	for entry in entries: entry.body.view_rotation = view_matrix

func add_shape(index: int, start: Vector4) -> void:
	var model := Model.new(index)
	model.color = Color.from_hsv(fmod(entries.size() * 0.23 + 0.53, 1.0), 0.6, 0.9)
	# Explicit demo defaults: custom geometry loads, its procedural presets do not.
	model.initialize_defaults({"position": {"X": start.x, "Y": start.y, "Z": start.z, "W": start.w}}, time)
	var body := Body.new()
	body.model = model
	body.view_rotation = view_matrix
	body.camera_4d = camera_4d
	add_child(body)
	body.update_geometry(time, true)
	var card := Card.new()
	editor.add_child(card)
	card.setup(model, body.renderer, true)
	card.apply_requested.connect(func(current): pending.append(func(): apply_card(current, body)))
	card.style_changed.connect(func(_current): body.renderer.update_style(model))
	card.remove_requested.connect(func(_current): pending.append(func(): remove_shape(body)))
	var fixed := CheckBox.new()
	fixed.text = "Fixed in 3D (no falling)"
	fixed.toggled.connect(func(value): pending.append(func(): body.fixed = value; body.refresh_freeze()))
	card.body.add_child(fixed)
	entries.append({"body": body, "card": card})
	refresh_selector(entries.size() - 1)
	update_suspension()

func apply_card(card, body) -> void:
	grabber.cancel()
	if not is_instance_valid(body): return
	if not body.model.apply_sources(card.draft(), time):
		card.show_error(body.model.error_field, body.model.error)
		return
	card.clear_errors()
	for key in card.fields: card.fields[key].text = body.model.sources[key]
	# Applying explicitly places the shape at its authored pose, even if unchanged.
	body.update_geometry(time, true)

func remove_shape(body) -> void:
	if grabber.held == body: grabber.cancel()
	for i in range(entries.size()):
		if entries[i].body != body: continue
		entries[i].card.queue_free()
		body.freeze = true
		body.queue_free()
		entries.remove_at(i)
		refresh_selector(mini(i, entries.size() - 1))
		return

func refresh_selector(index: int) -> void:
	selector.clear()
	for i in range(entries.size()): selector.add_item("%s #%d" % [entries[i].body.model.node_name, i + 1])
	select_shape(index)

func select_shape(index: int) -> void:
	selected = index
	if index >= 0: selector.select(index)
	for i in range(entries.size()):
		entries[i].card.visible = i == index
		entries[i].body.renderer.set_selected(i == index)

func reset_simulation() -> void:
	grabber.cancel()
	time = 0.0
	for entry in entries:
		entry.body.size_multiplier = 1.0
		entry.body.update_geometry(time, true)

func update_suspension() -> void:
	for entry in entries:
		entry.body.suspended = not running or not active
		entry.body.refresh_freeze()

func deactivate() -> void:
	grabber.cancel()
	active = false
	update_suspension()

func activate() -> void:
	active = true
	update_suspension()

func _physics_process(delta: float) -> void:
	var commands := pending.duplicate()
	pending.clear()
	for command in commands: command.call()
	if running and active: time += delta
	for entry in entries:
		if not entry.body.held: entry.body.update_geometry(time)
	grabber.physics_tick()
	grab_status.text = grabber.message
	status.text = "t = %.2f s · %d shapes · gravity: −Y\nReset restores authored poses and clears 3D velocities." % [time, entries.size()]
	if selected >= 0 and selected < entries.size():
		var body = entries[selected].body
		status.text += "\nLive 3D position: (%.2f, %.2f, %.2f) · size ×%.2f" % [body.position.x, body.position.y, body.position.z, body.size_multiplier]
		if not body.error.is_empty(): status.text += "\n" + body.error

func build_grab_controls(box: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	box.add_child(row)
	var mode := OptionButton.new()
	mode.add_item("Drag (constant size)")
	mode.add_item("Perspective grab (resize)")
	mode.select(1)
	mode.item_selected.connect(func(index):
		grabber.cancel()
		grabber.perspective_resize = index == 1)
	row.add_child(mode)
	var automatic := CheckBox.new()
	automatic.text = "Auto distance"
	automatic.tooltip_text = "Aim at a surface; fit the entire held solid before it. Off: use wheel."
	automatic.toggled.connect(func(value): grabber.automatic_distance = value)
	row.add_child(automatic)
	grab_status = Label.new()
	grab_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	grab_status.text = grabber.message
	box.add_child(grab_status)

func build_camera_4d_controls(box: VBoxContainer) -> void:
	var toggle := CheckBox.new()
	toggle.text = "4D perspective camera"
	toggle.tooltip_text = "Project through fourth-depth before native 3D rendering. Changes colliders too."
	box.add_child(toggle)
	var controls := VBoxContainer.new()
	controls.visible = false
	box.add_child(controls)
	toggle.toggled.connect(func(value):
		grabber.cancel()
		camera_4d.enabled = value
		controls.visible = value)
	var hint := Label.new()
	hint.text = "Camera position in 4D · +W is viewing depth
Existing view sliders rotate this camera's frame."
	hint.add_theme_font_size_override("font_size", 14)
	controls.add_child(hint)
	var row := HBoxContainer.new()
	controls.add_child(row)
	var positions: Array[SpinBox] = []
	for axis in range(4):
		var label := Label.new()
		label.text = ["X", "Y", "Z", "W"][axis]
		row.add_child(label)
		var field := SpinBox.new()
		field.min_value = -100
		field.max_value = 100
		field.step = 0.25
		field.value = camera_4d.position[axis]
		field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		field.custom_minimum_size.x = 90
		field.value_changed.connect(func(value):
			grabber.cancel()
			camera_4d.position[axis] = value)
		row.add_child(field)
		positions.append(field)
	var depth := HSlider.new()
	depth.min_value = -30
	depth.max_value = 15
	depth.step = 0.05
	depth.value = -8
	depth.tooltip_text = "Move the 4D camera along world W"
	controls.add_child(depth)
	depth.value_changed.connect(func(value): positions[3].value = value)
	positions[3].value_changed.connect(func(value): depth.set_value_no_signal(value))
	var settings := HBoxContainer.new()
	controls.add_child(settings)
	for property in ["focal", "near_depth"]:
		var label := Label.new()
		label.text = "Focal" if property == "focal" else "Near depth"
		settings.add_child(label)
		var field := SpinBox.new()
		field.min_value = 0.1
		field.max_value = 30 if property == "focal" else 5
		field.step = 0.1
		field.value = camera_4d.get(property)
		field.value_changed.connect(func(value):
			grabber.cancel()
			camera_4d.set(property, value))
		settings.add_child(field)
	button(controls, "Reset 4D camera position", func():
		for axis in range(4): positions[axis].value = -8 if axis == 3 else 0)
