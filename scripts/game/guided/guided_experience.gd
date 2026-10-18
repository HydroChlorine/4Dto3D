extends "res://scripts/game/artifact_puzzle.gd"
## Independent guided host; the free-play room and sandbox remain runnable unchanged.
const Region = preload("res://scripts/game/guided/basis_region.gd")
const BasisController = preload("res://scripts/game/guided/basis_controller.gd")
const Director = preload("res://scripts/game/guided/experience_director.gd")
const Marker = preload("res://scripts/game/guided/destination_marker.gd")
var xyz_region := Region.new()
var wyz_region := Region.new()
var basis_controller := BasisController.new()
var director := Director.new()
var destination_marker := Marker.new()
var explanation_label := Label.new()
var controls_label := Label.new()
var basis_label := Label.new()
var direction_label := Label.new()
var hint_label := Label.new()
var transition := ColorRect.new()
var switch_pending := false
var recover_pending := false
var flash_time := 0.0
var notice_time := 0.0
var notice := ""

func _ready() -> void:
	build_lighting()
	build_room()
	artifact.view_basis = "WYZ"
	add_child(artifact)
	player.artifact = artifact
	add_child(player)
	plate.position = Vector3(0, 0.1, -2.6)
	xyz_region.add_child(plate)
	door.position = Vector3(4, 1.5, 0)
	xyz_region.add_child(door)
	plate.activation_changed.connect(door.set_open)
	add_child(destination_marker)
	build_hud()
	basis_controller.player = player
	basis_controller.artifact = artifact
	basis_controller.regions = {"XYZ": xyz_region, "WYZ": wyz_region}
	basis_controller.changed.connect(on_view_changed)
	reset_room()

func build_room() -> void:
	xyz_region.name = "XYZRegion"
	wyz_region.name = "WYZRegion"
	wyz_region.view_basis = "WYZ"
	add_child(xyz_region)
	add_child(wyz_region)
	super.build_room()
	var wall := Color("514665")
	wyz_region.add_box("WFloor", Vector3(0, -0.15, 1), Vector3(14, 0.3, 16), Color("302a46"))
	wyz_region.add_box("WLeft", Vector3(-7.15, 2.5, 1), Vector3(0.3, 5, 16), wall)
	wyz_region.add_box("WRight", Vector3(7.15, 2.5, 1), Vector3(0.3, 5, 16), wall)
	wyz_region.add_box("WBack", Vector3(0, 2.5, 9), Vector3(14, 5, 0.3), wall)
	wyz_region.add_box("WFront", Vector3(0, 2.5, -7), Vector3(14, 5, 0.3), wall)
	wyz_region.add_box("WCeiling", Vector3(0, 5.15, 1), Vector3(14, 0.3, 16), Color("211e33"))
	wyz_region.add_box("ArtifactPlinth", Vector3(0, 0.15, 0.5), Vector3(1.8, 0.3, 1.8), Color("9989bb"))
	for horizontal in [-4.0, 4.0]:
		wyz_region.add_box("WColumn", Vector3(horizontal, 1.6, 0), Vector3(0.6, 3.2, 0.6), Color("83729c"))
	add_region_label(wyz_region, "WYZ / THE OTHER VIEW", Vector3(0, 3.1, 0), Color("cdb2ff"))
	add_region_label(wyz_region, "horizontal W · vertical Y · forward Z", Vector3(0, 2.5, 0), Color("d5c9ea"), 28)
	# A small aim point sits above the aperture center to allow for spring sag.
	var aim := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.035
	sphere.height = 0.07
	aim.mesh = sphere
	aim.position = Vector3(0, 1.42, -0.45)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("baffff")
	aim.material_override = material
	xyz_region.add_child(aim)

func block(label: String, center: Vector3, dimensions: Vector3, color: Color) -> StaticBody3D:
	return xyz_region.add_box(label, center, dimensions, color)

func world_label(text: String, location: Vector3, color: Color = Color.WHITE, size: int = 40) -> void:
	if text == "03 / WALK HERE": return # The moving lesson marker supplies this destination.
	add_region_label(xyz_region, text, location, color, size)

func add_region_label(region: Node3D, text: String, location: Vector3, color: Color, size: int = 40) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = location
	label.modulate = color
	label.font_size = size
	label.outline_size = 5
	region.add_child(label)

func panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.06, 0.1, 0.93)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	style.corner_radius_top_left = 8
	style.corner_radius_bottom_right = 8
	return style

func build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	transition.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(transition)
	var panel := PanelContainer.new()
	panel.position = Vector2(22, 20)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", panel_style())
	layer.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(column)
	for label in [objective, readout, explanation_label, hint_label]:
		label.custom_minimum_size.x = 420
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(label)
	objective.add_theme_font_size_override("font_size", 23)
	objective.add_theme_color_override("font_color", Color("83e8ec"))
	readout.add_theme_font_size_override("font_size", 19)
	explanation_label.add_theme_font_size_override("font_size", 16)
	explanation_label.add_theme_color_override("font_color", Color("bbccde"))
	hint_label.add_theme_font_size_override("font_size", 15)
	hint_label.add_theme_color_override("font_color", Color("f5cc83"))
	var badge := PanelContainer.new()
	badge.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	badge.offset_left = -135
	badge.offset_right = 135
	badge.offset_top = 20
	badge.offset_bottom = 82
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_theme_stylebox_override("panel", panel_style())
	layer.add_child(badge)
	basis_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	basis_label.add_theme_font_size_override("font_size", 17)
	badge.add_child(basis_label)
	controls_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	controls_label.offset_left = 22
	controls_label.offset_right = -22
	controls_label.offset_top = -64
	controls_label.offset_bottom = -18
	controls_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls_label.add_theme_font_size_override("font_size", 16)
	controls_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	controls_label.add_theme_constant_override("outline_size", 4)
	layer.add_child(controls_label)
	direction_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	direction_label.offset_left = -280
	direction_label.offset_right = 280
	direction_label.offset_top = -110
	direction_label.offset_bottom = -76
	direction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	direction_label.add_theme_color_override("font_color", Color("a8ffff"))
	direction_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	direction_label.add_theme_constant_override("outline_size", 4)
	layer.add_child(direction_label)
	var crosshair := Label.new()
	crosshair.text = "+"
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.offset_left = -5
	crosshair.offset_top = -12
	crosshair.add_theme_font_size_override("font_size", 23)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(crosshair)
	layer.add_child(artifact_preview)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F: switch_pending = true
		elif event.keycode == KEY_H: recover_pending = true

func on_view_changed(view: String) -> void:
	director.on_switch(view)
	flash_time = 0.4
	if view == "XYZ" and player.holding:
		set_notice("Your position stayed fixed. The artifact widened: XYZ shows its long X side instead of its short W side. Its source shape and mass are unchanged.")
	else:
		set_notice("View changed to %s. Your position and viewing direction stayed fixed." % view)

func set_notice(text: String) -> void:
	notice = text
	notice_time = 4.0

func reset_room() -> void:
	completed = false
	player.reset_player()
	player.position = Vector3(0, 0.05, 7.4)
	artifact.view_basis = "WYZ"
	artifact.reset_artifact(Transform3D(Basis.IDENTITY, Vector3(0, 1.3, 0.5)))
	plate.reset_plate()
	door.set_open(false)
	director.reset()
	basis_controller.reset()
	director.configure_controls(player)
	switch_pending = false
	recover_pending = false
	notice_time = 0.0
	flash_time = 0.0
	update_hud()

func recover_artifact() -> void:
	player.drop()
	if basis_controller.current == "WYZ":
		artifact.view_basis = "WYZ"
		artifact.reset_artifact(Transform3D(Basis.IDENTITY, Vector3(0, 1.3, 0.5)))
		director.step = Director.Step.WALK_ARTIFACT
	else:
		if director.step < Director.Step.ROTATE:
			set_notice("The artifact is in the WYZ room. Follow the exchange-ring instruction to reach it.")
			return
		player.reset_player()
		player.position = Director.PRACTICE + Vector3.UP * 0.05
		artifact.view_basis = "XYZ"
		artifact.reset_artifact(Transform3D(Basis.IDENTITY, Vector3(0, 1.3, 3)))
		director.step = Director.Step.ROTATE
	basis_controller.artifact_home = basis_controller.current
	basis_controller.apply_view()
	plate.reset_plate()
	door.set_open(false)
	completed = false
	director.configure_controls(player)
	set_notice("Artifact recalled. This section has restarted; your earlier view-selection progress is kept.")

func try_switch() -> bool:
	if director.step not in [Director.Step.SWITCH_OUT, Director.Step.SWITCH_BACK]:
		set_notice("Follow the current instruction. F becomes available at the exchange step.")
		return false
	if director.step == Director.Step.SWITCH_BACK and not player.holding:
		set_notice("Pick up the artifact with E before returning. H recalls it if it is out of reach.")
		return false
	var accepted := basis_controller.switch_view()
	if not accepted: set_notice(basis_controller.message)
	return accepted

func _physics_process(delta: float) -> void:
	if player.reset_requested: reset_room()
	if recover_pending:
		recover_pending = false
		recover_artifact()
	if switch_pending:
		switch_pending = false
		try_switch()
	director.configure_controls(player)
	player.tick(delta)
	if basis_controller.current == "XYZ": plate.tick(artifact, delta)
	director.tick(player, artifact, basis_controller, plate, delta)
	completed = director.step == Director.Step.COMPLETE
	if artifact.visible and artifact.position.y < -5: recover_artifact()
	notice_time = maxf(0.0, notice_time - delta)
	flash_time = maxf(0.0, flash_time - delta)
	transition.color = Color(0.025, 0.04, 0.07, flash_time * 1.6)
	update_hud()

func update_hud() -> void:
	artifact_preview.visible = artifact.visible and director.step >= Director.Step.GRAB
	artifact_preview.show_angle(artifact.angle)
	objective.text = "%02d / %02d  %s" % [mini(director.step + 1, 12), 12, director.title()]
	readout.text = director.instruction(player, artifact)
	explanation_label.text = director.explanation()
	basis_label.text = "%s VIEW\n%s" % [basis_controller.current, "(w, y, z)" if basis_controller.current == "WYZ" else "(x, y, z)"]
	var hint := ""
	if artifact.visible and director.step >= Director.Step.GRAB:
		hint = "XW %.0f° · size ×%.2f · %.2f kg" % [artifact.angle, artifact.size_multiplier, artifact.mass]
	if director.step == Director.Step.PASS:
		var half := Artifact.dimensions_at(artifact.angle, artifact.size_multiplier, artifact.view_basis) * 0.5
		if half.x * 2 > 1.38: hint += "\nToo wide. Hold C to rotate toward 90°."
		if half.y * 2 > 1.38: hint += "\nToo tall. Hold Down Arrow to shrink below size 0.85."
		elif artifact.position.y - half.y < 0.65: hint += "\nRaise your aim: the artifact is below the sill."
		elif artifact.position.y + half.y > 2.05: hint += "\nLower your aim: the artifact is above the opening."
	if artifact.blocked: hint += "\nShape change blocked. Lift away from the floor or wall."
	if notice_time > 0: hint += "\n" + notice
	hint_label.text = hint.strip_edges()
	hint_label.visible = not hint_label.text.is_empty()
	var controls := "WASD move · Mouse look"
	if player.grab_enabled: controls += " · E / click grab or drop"
	if player.rotation_enabled: controls += " · Z / C rotate XW"
	if player.resize_enabled: controls += " · ↑ ↓ / wheel distance + size"
	if director.step in [Director.Step.SWITCH_OUT, Director.Step.SWITCH_BACK]: controls += " · F switch view"
	var recovery_controls := "H recall artifact · " if director.step >= Director.Step.WALK_ARTIFACT else ""
	controls_label.text = controls + "\n" + recovery_controls + "R restart · Esc release cursor"
	var goal: Vector3 = director.destination(artifact)
	destination_marker.point_to(goal, director.destination_title())
	destination_marker.visible = not completed
	destination_marker.caption.visible = Director.flat_distance(player.position, goal) > 1.1
	var camera := player.camera
	var local := camera.to_local(goal + Vector3.UP * 0.5)
	var screen := camera.unproject_position(goal + Vector3.UP * 0.5)
	var rect := get_viewport().get_visible_rect().grow(-60)
	var arrow := ""
	if local.z >= 0: arrow = "Turn around ← " if local.x < 0 else "Turn around → "
	elif not rect.has_point(screen): arrow = "← " if local.x < 0 else "→ "
	direction_label.text = "%s%s · %.1f m" % [arrow, director.destination_title(), Director.flat_distance(player.position, goal)]
	direction_label.visible = not completed and Director.flat_distance(player.position, goal) > 0.85
