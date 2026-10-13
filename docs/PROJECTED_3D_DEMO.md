# Projected 3D physics demo

Open the **3D Physics Demo** tab. The initial tesseract and 16-cell fall onto a normal 3D floor. Hold RMB to look; WASD flies, Q/E moves down/up, Shift increases speed. The sidebar can collapse.

Select one shape to edit its 4D position, six rotation planes (degrees), scale, anchor or 3×4 projection. Fields support expressions in `t`, including rotation `30*t` and projection `sin(t)`. Apply & place shape commits the draft, restores that body to its current authored pose, and clears its native velocities—even if the fields have not changed. Add/remove shapes using the catalog. Custom files supply geometry; this demo intentionally starts from its own transform defaults rather than loading saved procedural presets.

The shape's projected convex hull is both its visible solid and its collision shape. Each object has its own projection. Three shared viewing sliders (X↔W, Y↔W, Z↔W) rotate the 4D world before each object’s projection. At zero, default matrices show XYZ; with only X↔W at 90°, the default mapping shows W,Y,Z. Rotation order is XW, YW, ZW. Custom per-object projection matrices remain active. The floor, camera and gravity remain in 3D. There is no player or square controller. Fixed bodies act as obstacles; other bodies use native Godot gravity, friction and bounce. Pause stops time and freezes native bodies. Reset returns to t=0 and the authored poses, with zero 3D velocities. Inactive tabs freeze their native physics bodies as well as their scripts.

## Ownership

- `scripts/core`: existing pure 4D transform and projection mathematics, unchanged.
- `scripts/sandbox/projected_physics/projected_body.gd`: native RigidBody3D adapter. Samples authored vertices, centers their projected point cloud, updates the existing solid-hull renderer and ConvexPolygonShape3D. Unchanged geometry is cached.
- `scripts/sandbox/projected_physics/demo.gd`: floor, lighting, camera, selection, expression cards, playback controls, physics-tick command queue.
- `scripts/sandbox/app_shell.gd`: isolated viewport/world and activation lifecycle.

The independent 4D physics engine is not involved in this demo. Godot solves collisions after projection in 3D. A native body transform adds simulated movement/rotation to the centered authored shape. During playback and live slider changes, projected center deltas preserve accumulated simulated motion. Explicit Apply instead restores the authored pose and clears native velocities; the same Y=10 can therefore place a fallen shape at that height repeatedly (with default projection). Reset clears that simulated transform. The fields describe authored geometry, not a live readout of native body position.

Hull/collider changes run together at physics ticks. Collapsed projections remain visible, but have no collider and are frozen until a valid volume returns. Visibility is visual only; use Remove to remove a collider. Convex hulls fill concavities in custom geometry.

Live shape deformation does not provide surface velocities to the rigid-body solver. Fast changes can introduce overlaps and sudden responses; native continuous collision detection does not guarantee swept deformation contacts. Large changing hulls may be expensive. This is a small-scene prototype, not deformable-body simulation.

## Verification

`tests/verify_projected_demo.gd` exercises native falling/floor contact, pause, authored translation and projection edits, degenerate collision suspension, reset, and tab activation. Run with Godot headless and `--script tests/verify_projected_demo.gd`.

## Grabbing and perspective resizing

Left-drag a visible solid in the viewport. A camera ray selects its native collider and keeps the hit point under the cursor. The mouse wheel changes holding distance (up = farther). Release to drop with its current velocity; Esc restores the pre-grab pose, size and velocities. Fixed objects cannot be pulled. Resume the simulation to drag physically; pause freezes held bodies too. The selected object follows the click, and the sidebar reports its live native position and size multiplier.

The mode menu offers constant-size dragging and perspective grabbing (default). Perspective grabbing maintains `size = initial_size * distance / initial_distance`, bounded to 0.05–20×. Size is baked into the hull vertices and collider rather than scaling a RigidBody3D node. It persists after release and subsequent 4D projection edits; Reset simulation returns it to 1×. Apply & place shape preserves this multiplier while replacing native pose/velocity.

**Auto distance** aims a ray at the environment (excluding the held body), then attempts to fit the whole resized collider along that direction. Without a ray hit, its target distance is 40 units. Manual wheel distance is bounded to 0.3–80 units. Movement uses a capped damped spring force through the body center. Godot handles friction, sliding and pushing. Orientation is locked while held and its previous lock setting is restored on release. There is no mass-compensated gravity cancellation: heavy bodies lag and may be too heavy to lift. Resizing is rate-limited and checked separately with convex overlap queries; blocked growth does not stop movement. This does not provide exact swept-deformation collision detection.

While held, native physics remains active; only authored geometry sampling is suspended. Other bodies and time continue. On release, authored time expressions resume at the current t. Editing camera/view settings, applying fields, resetting, or leaving the tab cancels the grab. The grab changes native 3D pose and uniform size only; it does not infer a 4D position from the 3D mouse ray.

## Optional second-stage 4D camera

The mode selector now offers matrix-only projection or **Matrix → 4D camera → 3D**. Both always apply authored 4D transforms, shared source rotations, and the editable per-shape 3×4 matrix. The camera mode embeds each resulting point `(u,v,s)` at `(u,v,s,0)` and projects that embedded shape through a separate 4D camera. No original fourth-depth survives stage one.

Default camera `(0,0,0,-8)` and focal 8 reproduce the matrix output exactly. Camera XYZW fields use embedded-space coordinates. Look at target is on by default; its target XYZ lies on W=0. Moving sideways while looking toward the target foreshortens the embedded shape. At W=0, looking from outside toward it yields an edge-on, lower-dimensional image; its volume collider is suspended. This is projection, not extraction of a cross-section.

Viewing depth moves along this camera's own forward direction. With look-at enabled, it stops short of crossing the target. Reset places the camera eight units back along W from the target. Turning look-at off uses a fixed +W view. Shared XW/YW/ZW sliders act only on the original source before the matrix, not on the second camera. Matrix fields remain editable in both modes.

Near-plane clipping occurs before perspective division. The final solid and collider use the same resulting convex hull. The existing native 3D physics pose is still applied afterward; it is not lifted back into the embedding. Ground and gravity remain native 3D. Dense hulls crossing the near plane can be expensive.

Pure camera math lives in `scripts/core/math/camera_projection_4d.gd`. Smoke checks cover straight-on identity, matrix participation, depth scaling, edge-on collapse and local camera movement.

## Grab mass and force

Each shape has **Base mass (kg at size ×1)**. Current native mass is `base_mass * size_multiplier^3`; doubling uniform grab size makes it eight times heavier. Base mass is editable from 0.01 to 1000 kg. The sidebar reports live mass alongside native position and size. Reset returns size to one and therefore mass to base mass. Cancel restores the pre-grab size/mass.

This rule applies to the uniform grab size multiplier, not every change in the projected hull's volume. Camera motion, authored 4D scale, and projection distortion do not silently change the base mass. Native inertia is recalculated from the resized collider and its mass.

The assisted grab uses stiffness 900 and force cap 2000 N at 1 kg, adjustable with the Grab strength slider (0.25–4×). Above 1 kg, stiffness and force cap grow as mass^0.8. This makes heavy objects manageable while their response frequency still decreases with mass; native collision mass is unchanged. Damping is critical, and an implicit spring step stabilizes tiny resized masses. The body remains under gravity with its regular contact friction. Release preserves momentum; Esc restores pre-grab pose and velocities. Floor-slide and mass-scaling behavior have focused smoke coverage.

## Full camera frustum

The optional second-stage camera now clips against all eight boundaries before perspective division: near, far, and ±X/±Y/±Z side planes. **FOV°** is shared across the three image directions (default 90°); **Far** defaults to 100. Focal remains output magnification. A valid depth range requires `0 < Near < Far`; an invalid range produces no solid.

Clipping is performed on the embedded 3D convex solid, rebuilding its hull edges between plane cuts so new cap edges participate in subsequent clipping. This preserves partial intersections even when all original vertices are outside the final frustum. The pure hull utility is now shared in `scripts/core/geometry/convex_hull_3d.gd`; the rendering path retains a compatibility alias.

The final visible solid and collider both shrink when clipped and disappear when fully outside. Linear matrix-only mode remains unclipped. `tests/verify_camera_frustum.gd` checks partial cuts, enclosing geometry, lateral and far rejection, and FOV bounds.
