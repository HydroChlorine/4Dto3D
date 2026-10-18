extends RefCounted
## Action-based lesson state. Presentation and input remain in the host/player.
enum Step { WALK_PAD, SWITCH_OUT, WALK_ARTIFACT, GRAB, RETURN_PAD, SWITCH_BACK, ROTATE, SHRINK, PASS, ENLARGE, PLACE, EXIT, COMPLETE }
const PRACTICE := Vector3(0, 0, 6.0)
const EXCHANGE := Vector3(0, 0, 4.7)
var step := Step.WALK_PAD
var elapsed := 0.0

func reset() -> void:
	step = Step.WALK_PAD
	elapsed = 0.0

func next() -> void:
	step += 1
	elapsed = 0.0

func on_switch(view: String) -> void:
	if step == Step.SWITCH_OUT and view == "WYZ": next()
	elif step == Step.SWITCH_BACK and view == "XYZ": next()

func configure_controls(player) -> void:
	player.grab_enabled = step >= Step.GRAB
	player.rotation_enabled = step >= Step.ROTATE
	player.resize_enabled = step >= Step.SHRINK

func tick(player, artifact, basis, plate, delta: float) -> void:
	elapsed += delta
	match step:
		Step.WALK_PAD:
			if basis.at_pad(): next()
		Step.WALK_ARTIFACT:
			if flat_distance(player.position, artifact.position) < 2.4: next()
		Step.GRAB:
			if player.holding: next()
		Step.RETURN_PAD:
			if player.holding and basis.at_pad(): next()
		Step.ROTATE:
			if player.holding and artifact.angle >= 85 and flat_distance(player.position, PRACTICE) < 0.85: next()
		Step.SHRINK:
			if player.holding and artifact.size_multiplier <= 0.85:
				var size: Vector3 = artifact.dimensions_at(artifact.angle, artifact.size_multiplier, artifact.view_basis)
				if size.x < 1.35 and size.y < 1.37: next()
		Step.PASS:
			var depth: float = artifact.dimensions_at(artifact.angle, artifact.size_multiplier, artifact.view_basis).z
			if artifact.position.z + depth * 0.5 < -0.38: next()
		Step.ENLARGE:
			if player.holding and artifact.mass >= 6.0: next()
		Step.PLACE:
			if plate.active: next()
		Step.EXIT:
			if not plate.active:
				step = Step.PLACE
			elif player.position.x > 2.8 and player.position.z < -4.8: next()
	configure_controls(player)

static func flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func title() -> String:
	return ["Find the exchange ring", "Choose another three dimensions", "Explore the WYZ room", "Pick up the artifact", "Carry it to the exchange ring", "Return with the artifact", "Rotate through the fourth dimension", "Change the size you can touch", "Guide the projection through", "Make the artifact heavier", "Let the plate carry its weight", "Walk through the open exit", "Experience complete"][step]

func instruction(player, artifact) -> String:
	if step in [Step.RETURN_PAD, Step.SWITCH_BACK, Step.ROTATE, Step.SHRINK, Step.PASS, Step.ENLARGE] and not player.holding:
		return "Aim at the artifact and press E to pick it up again. H recalls it if you cannot reach it."
	match step:
		Step.WALK_PAD: return "Use WASD and the mouse to walk onto the illuminated EXCHANGE ring ahead."
		Step.SWITCH_OUT: return "Stay on the ring. Press F to switch from XYZ to WYZ."
		Step.WALK_ARTIFACT: return "Walk toward the illuminated artifact ahead. The marker shows where to go."
		Step.GRAB: return "Aim the crosshair at the narrow cyan artifact. Press E to pick it up."
		Step.RETURN_PAD: return "Keep carrying it. Walk back to the EXCHANGE ring behind you."
		Step.SWITCH_BACK: return "Stay on the ring while holding the artifact. Press F to return to XYZ."
		Step.ROTATE:
			if flat_distance(player.position, PRACTICE) >= 0.85: return "Carry the artifact back to the PRACTICE ring. This gives it room to change shape."
			return "Hold C until XW is at least 85°. Watch the artifact and the top-right wireframe. Z rotates back."
		Step.SHRINK: return "Hold Down Arrow (or scroll down) until size is 0.85 or less. The artifact comes nearer and shrinks."
		Step.PASS: return "Walk toward the cyan opening. Aim through its illuminated center and keep carrying the artifact until it clears the wall."
		Step.ENLARGE: return "Aim above the gold plate. Hold Up Arrow (or scroll up) to push it farther and enlarge it to at least 6 kg."
		Step.PLACE:
			if player.holding: return "Center the artifact above the gold plate, then press E to release it. Keep the player on this side of the wall."
			if artifact.mass < 6.0: return "It is too light. Press E to pick it up; hold Up Arrow to reach 6 kg, then release onto the plate."
			return "Let it settle on the plate for 0.6 seconds. If you missed, press E to pick it up and try again."
		Step.EXIT: return "Leave the artifact on the plate. Walk right to the gold exit, through the door, then to the far illuminated marker."
		Step.COMPLETE: return "You selected a view, carried a 4D artifact, changed its projection, and used perspective resizing. R restarts the experience."
	return ""

func explanation() -> String:
	match step:
		Step.WALK_PAD: return "You begin in XYZ: horizontal X, vertical Y, and forward Z. W is a fourth spatial coordinate, separate from time."
		Step.SWITCH_OUT: return "XYZ displays (x,y,z). WYZ displays (w,y,z). Changing the visible dimensions can make the room seem to jump while you stay still."
		Step.WALK_ARTIFACT: return "W now occupies the horizontal axis. Y and Z stayed the same. In this experience, each room belongs to one view, so switching reveals a different region."
		Step.GRAB: return "This hyperrectangle has side lengths X=3.6, Y=1.6, Z=1.2, W=0.6. It looks narrow because this view shows W instead of X."
		Step.RETURN_PAD, Step.SWITCH_BACK: return "Our carrying rule transfers held objects between views. The artifact keeps its 4D dimensions, rotation, size, and mass; its visible projection can change."
		Step.ROTATE: return "XW rotation mixes X and W: x′ = x cosθ − w sinθ. The XYZ view keeps x′ and omits w′. Near 90°, the short W side becomes the visible width."
		Step.SHRINK: return "Rotation changed width, but height is still 1.6 × size. The opening is only 1.4 high. Perspective resizing scales all three visible dimensions together."
		Step.PASS: return "The projected solid is also the 3D collider. A visual fit needs real clearance. Raise or lower your aim to align with the opening."
		Step.ENLARGE: return "Assigned mass = 4 × size³ kg. An artifact that fits the gap weighs less than 2.68 kg. Size 1.2 weighs 6.91 kg; switching views alone never changes mass."
		Step.PLACE: return "The plate requires at least 6 kg resting on top. Holding the artifact above it, touching its side, or briefly hitting it does not count."
		Step.EXIT: return "The supported artifact keeps the exit open. Its 4D source and 3D physical projection are separate parts of the experience."
		Step.COMPLETE: return "View selection changes which coordinates are shown. Rotation changes the source orientation. Resizing changes uniform size and assigned mass. These are three distinct operations."
	return ""

func destination(artifact) -> Vector3:
	match step:
		Step.WALK_PAD, Step.SWITCH_OUT, Step.RETURN_PAD, Step.SWITCH_BACK: return EXCHANGE
		Step.WALK_ARTIFACT, Step.GRAB: return Vector3(artifact.position.x, 0, artifact.position.z)
		Step.ROTATE, Step.SHRINK: return PRACTICE
		Step.PASS: return Vector3(0, 0, 0.9)
		Step.ENLARGE, Step.PLACE: return Vector3(0, 0.21, -2.6)
		Step.EXIT, Step.COMPLETE: return Vector3(4, 0, -5.4)
	return EXCHANGE

func destination_title() -> String:
	if step in [Step.SWITCH_OUT, Step.SWITCH_BACK]: return "EXCHANGE · F"
	if step in [Step.WALK_PAD, Step.RETURN_PAD]: return "EXCHANGE"
	if step == Step.WALK_ARTIFACT: return "ARTIFACT"
	if step == Step.GRAB: return "ARTIFACT · E"
	if step <= Step.SHRINK: return "PRACTICE"
	if step == Step.PASS: return "OPENING"
	if step <= Step.PLACE: return "PLATE · 6 kg"
	return "EXIT"
