extends SceneTree
## Native compound adapter checks; core reparenting stays in Scene4D.
func _initialize() -> void:
	call_deferred("verify")

func verify() -> void:
	var demo = preload("res://scripts/sandbox/projected_physics/demo.gd").new()
	root.add_child(demo)
	demo.running = false
	demo.update_suspension()
	var a = demo.entries[0]
	var b = demo.entries[1]
	var before = demo.graph.world_vertices(b.id, demo.graph.sample(0))
	demo.reparent_node(b.id, a.id)
	demo._physics_process(0)
	assert(demo.graph.world_vertices(b.id, demo.graph.sample(0)) == before)
	assert(a.body.parts.size() == 2 and b.body.absorbed)
	assert(b.body.collider.shape == null and b.body.freeze)
	assert(a.body.scaled_collision_parts(1).size() == 2)
	assert(is_equal_approx(a.body.mass, 2))
	assert(not demo.graph.can_parent(a.id, b.id))
	# Geometry translation leaves descendants alone; Group translation moves them.
	var draft: Dictionary = a.body.model.sources.duplicate()
	draft["position.0"] = "8"
	assert(a.body.model.apply_sources(draft, 0))
	assert(demo.graph.world_vertices(b.id, demo.graph.sample(0)) == before)
	draft = a.group_model.sources.duplicate()
	draft["position.0"] = "3"
	assert(a.group_model.apply_sources(draft, 0))
	var after = demo.graph.world_vertices(b.id, demo.graph.sample(0))
	assert((after[0] - before[0]).is_equal_approx(Vector4(3,0,0,0)))
	demo.update_assemblies()
	assert(a.body.parts.size() == 2)
	await physics_frame
	await physics_frame
	# Probe the gap between parts: a single enclosing hull would fill this space.
	var query := PhysicsShapeQueryParameters3D.new()
	var probe := SphereShape3D.new()
	probe.radius = 0.1
	query.shape = probe
	query.transform.origin = Vector3(8, 6.5, 0)
	assert(demo.get_world_3d().direct_space_state.intersect_shape(query).is_empty())
	query.transform.origin = Vector3(11, 5, 0)
	assert(not demo.get_world_3d().direct_space_state.intersect_shape(query).is_empty())
	a.body.set_size_multiplier(2)
	assert(is_equal_approx(a.body.mass, 16))
	demo.reparent_node(b.id, 0)
	demo._physics_process(0)
	assert(not b.body.absorbed and b.body.valid_volume)
	assert(a.body.parts.size() == 1 and b.body.parts.size() == 1)
	assert(demo.graph.world_vertices(b.id, demo.graph.sample(0)) == after)
	# Removal promotes children while retaining their authored world transforms.
	demo.reparent_node(b.id, a.id)
	demo._physics_process(0)
	demo.remove_shape(a.body)
	assert(demo.graph.entries[b.id].parent == 0)
	assert(not b.body.absorbed and b.body.valid_volume)
	assert(demo.graph.world_vertices(b.id, demo.graph.sample(0)) == after)
	demo.queue_free()
	await process_frame
	print("Projected hierarchy checks passed")
	quit()
