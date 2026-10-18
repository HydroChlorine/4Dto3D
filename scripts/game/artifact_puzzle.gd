extends Node3D
## Standalone room. Intentionally does not instantiate or modify the sandbox demo.
const Artifact = preload("res://scripts/game/projected_artifact.gd")
const Player = preload("res://scripts/game/puzzle_player.gd")
const Plate = preload("res://scripts/game/pressure_plate.gd")
const Door = preload("res://scripts/game/puzzle_door.gd")
const ArtifactPreview = preload("res://scripts/game/artifact_preview.gd")
var artifact := Artifact.new()
var player := Player.new()
var plate := Plate.new()
var door := Door.new()
var readout := Label.new()
var objective := Label.new()
var artifact_preview := ArtifactPreview.new()
var completed := false
var reset_pending := false

func _ready() -> void:
	build_lighting()
	build_room()
	add_child(artifact)
	player.artifact = artifact
	add_child(player)
	plate.position = Vector3(0, 0.1, -2.6)
	add_child(plate)
	door.position = Vector3(4, 1.5, 0)
	add_child(door)
	plate.activation_changed.connect(door.set_open)
	build_hud()
	reset_room()

func build_lighting() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("101b2c")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("bed5ef")
	environment.ambient_light_energy = 0.65
	world.environment = environment
	add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-65, -25, 0)
	light.light_energy = 1.1
	light.shadow_enabled = true
	add_child(light)

func block(label: String, center: Vector3, dimensions: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = label
	body.position = center
	body.collision_layer = 1
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions
	collision.shape = shape
	body.add_child(collision)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	visual.material_override = material
	body.add_child(visual)
	add_child(body)
	return body

func world_label(text: String, location: Vector3, color: Color = Color.WHITE, size: int = 40) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = location
	label.modulate = color
	label.font_size = size
	label.outline_size = 5
	add_child(label)

func build_room() -> void:
	var wall := Color("34485f")
	block("Floor", Vector3(0, -0.15, 1), Vector3(14, 0.3, 16), Color("243344"))
	block("LeftBoundary", Vector3(-7.15, 2.5, 1), Vector3(0.3, 5, 16), wall)
	block("RightBoundary", Vector3(7.15, 2.5, 1), Vector3(0.3, 5, 16), wall)
	block("BackBoundary", Vector3(0, 2.5, 9), Vector3(14, 5, 0.3), wall)
	block("FarBoundary", Vector3(0, 2.5, -7), Vector3(14, 5, 0.3), wall)
	block("Ceiling", Vector3(0, 5.15, 1), Vector3(14, 0.3, 16), Color("1b2939"))
	# Four frame sections preserve the actual aperture; no hull spans its hole.
	block("WallLeft", Vector3(-3.85, 2.5, 0), Vector3(6.3, 5, 0.7), wall)
	block("WallMiddle", Vector3(1.9, 2.5, 0), Vector3(2.4, 5, 0.7), wall)
	block("WallRight", Vector3(5.95, 2.5, 0), Vector3(2.1, 5, 0.7), wall)
	block("OpeningSill", Vector3(0, 0.325, 0), Vector3(1.4, 0.65, 0.7), wall)
	block("OpeningLintel", Vector3(0, 3.525, 0), Vector3(1.4, 2.95, 0.7), wall)
	block("ExitLintel", Vector3(4, 4, 0), Vector3(1.8, 2, 0.7), wall)
	# A bright frame makes the opening readable from the starting viewpoint.
	block("GapTrimLeft", Vector3(-0.74, 1.35, 0.39), Vector3(0.08, 1.56, 0.08), Color("56d9dd"))
	block("GapTrimRight", Vector3(0.74, 1.35, 0.39), Vector3(0.08, 1.56, 0.08), Color("56d9dd"))
	world_label("01 / THREAD THE ARTIFACT", Vector3(0, 3.15, 0.43), Color("83e8ec"), 45)
	world_label("1.4 m × 1.4 m", Vector3(0, 2.5, 0.43), Color("c4d9eb"), 32)
	world_label("02 / LOAD ≥ 6 kg", Vector3(0, 0.6, -4.1), Color("f6c773"), 42)
	world_label("EXIT", Vector3(4, 3.5, 0.43), Color("f6c773"), 46)
	world_label("03 / WALK HERE", Vector3(4, 1.7, -6.7), Color("8df0b2"), 48)

func build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(22, 20)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.035, 0.06, 0.1, 0.9)
	background.content_margin_left = 20
	background.content_margin_right = 20
	background.content_margin_top = 16
	background.content_margin_bottom = 16
	background.corner_radius_top_left = 8
	background.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", background)
	layer.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	var title := Label.new()
	title.text = "FOURTH / a projection puzzle"
	title.add_theme_font_size_override("font_size", 25)
	column.add_child(title)
	objective.add_theme_color_override("font_color", Color("83e8ec"))
	objective.custom_minimum_size.x = 440
	objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(objective)
	readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(readout)
	var instructions := Label.new()
	instructions.text = "WASD  walk     Mouse  look     E / click  grab or drop\nZ / C  rotate XW while held     Wheel / ↑ ↓  distance + size\n↓ / wheel down: nearer / smaller     ↑ / wheel up: farther / larger\nR  reset room     Esc  release cursor / drop"
	instructions.add_theme_font_size_override("font_size", 15)
	column.add_child(instructions)
	var crosshair := Label.new()
	crosshair.text = "+"
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.offset_left = -5
	crosshair.offset_top = -12
	crosshair.add_theme_font_size_override("font_size", 23)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(crosshair)
	layer.add_child(artifact_preview)

func reset_room() -> void:
	completed = false
	player.reset_player()
	artifact.reset_artifact(Transform3D(Basis.IDENTITY, Vector3(-2.1, 1.05, 3)))
	plate.reset_plate()
	door.set_open(false)
	reset_pending = false
	update_hud()

func _physics_process(delta: float) -> void:
	if reset_pending or player.reset_requested:
		reset_room()
	player.tick(delta)
	plate.tick(artifact, delta)
	if artifact.position.y < -5: reset_room()
	if door.opened and player.position.z < -4.8 and player.position.x > 2.8:
		completed = true
	update_hud()

func update_hud() -> void:
	artifact_preview.show_angle(artifact.angle)
	if completed: objective.text = "Solved! You folded, resized, and weighted the artifact.  R to replay."
	elif plate.active: objective.text = "03 / Plate active. Walk through the gold exit to the far marker."
	elif artifact.position.z < -0.35 - Artifact.dimensions_at(artifact.angle, artifact.size_multiplier).z * 0.5:
		objective.text = "02 / Enlarge beyond the wall. Release ≥ 6 kg onto the gold plate."
	else: objective.text = "01 / Rotate AND shrink the artifact to pass it through the cyan opening."
	var manipulation := "Held" if player.holding else "Aim at the artifact to pick it up"
	if artifact.blocked and player.holding: manipulation += " · shape change blocked — lift away from surfaces"
	readout.text = "XW  %05.1f°     Size  ×%.2f     Mass  %.2f kg\nPlate  %.2f / 6.00 kg · %s\n%s" % [artifact.angle, artifact.size_multiplier, artifact.mass, plate.supported_mass, plate.status, manipulation]

func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
