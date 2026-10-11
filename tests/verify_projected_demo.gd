extends SceneTree
## Native 3D integration test: floor contact, projection updates and tab suspension.
func _initialize() -> void:
	call_deferred("verify")

func verify() -> void:
	var demo = preload("res://scripts/sandbox/projected_physics/demo.gd").new()
	root.add_child(demo)
	assert(demo.entries.size() == 2)
	var body = demo.entries[0].body
	assert(body.valid_volume)
	for i in range(240): await physics_frame
	assert(body.position.y > 0.7 and body.position.y < 1.4, "Projected tesseract should settle on the floor")
	demo.running = false
	demo.update_suspension()
	var resting: Vector3 = body.position
	for i in range(10): await physics_frame
	assert(body.position.is_equal_approx(resting))
	var draft: Dictionary = body.model.sources.duplicate()
	draft["position.0"] = "3"
	draft["projection.3"] = "0.5"
	assert(body.model.apply_sources(draft, demo.time))
	body.update_geometry(demo.time)
	assert(body.position.x > resting.x + 4.9)
	assert(body.collider.shape is ConvexPolygonShape3D)
	draft = body.model.sources.duplicate()
	for i in range(12): draft["projection.%d" % i] = "0"
	assert(body.model.apply_sources(draft, demo.time))
	body.update_geometry(demo.time)
	assert(not body.valid_volume and body.freeze and body.collider.shape == null)
	draft["projection.0"] = "1"
	draft["projection.5"] = "1"
	draft["projection.10"] = "1"
	assert(body.model.apply_sources(draft, demo.time))
	demo.reset_simulation()
	assert(body.valid_volume and body.position.is_equal_approx(Vector3(3,5,0)))
	# Reapplying the same authored position must place a fallen body again.
	var card = demo.entries[0].card
	for key in card.fields: card.fields[key].text = body.model.sources[key]
	card.fields["position.1"].text = "10"
	demo.apply_card(card, body)
	assert(is_equal_approx(body.position.y, 10.0))
	body.position.y = 1.0
	body.linear_velocity = Vector3.DOWN * 4
	demo.apply_card(card, body)
	assert(is_equal_approx(body.position.y, 10.0) and body.linear_velocity == Vector3.ZERO)
	# Shared XW=90 changes default XYZ into W,Y,Z for both solids.
	demo.view_sliders[0].value = 90
	for entry in demo.entries: entry.body.update_geometry(demo.time)
	assert(absf(body.authored_center.x) < 0.0001)
	assert(is_equal_approx(demo.entries[1].body.authored_center.x, 1.0))
	assert(body.valid_volume and body.collider.shape != null)
	demo.view_sliders[0].value = 0
	body.update_geometry(demo.time)
	assert(is_equal_approx(body.authored_center.x, 3.0))
	demo.deactivate()
	assert(body.freeze)
	demo.running = true
	demo.activate()
	assert(not body.freeze)
	print("Projected demo: floor, edits, degeneracy, reset, repeated placement, shared sliders and suspension passed")
	quit()
