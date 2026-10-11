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

Left-drag a visible solid in the viewport. A camera ray selects its native collider and keeps the hit point under the cursor. The mouse wheel changes holding distance (up = farther). Release to drop with zero velocity; Esc restores the pre-grab pose, size and velocities. Fixed objects remain fixed after release. Grabbing works while paused too. The selected object follows the click, and the sidebar reports its live native position and size multiplier.

The mode menu offers constant-size dragging and perspective grabbing (default). Perspective grabbing maintains `size = initial_size * distance / initial_distance`, bounded to 0.05–20×. Size is baked into the hull vertices and collider rather than scaling a RigidBody3D node. It persists after release and subsequent 4D projection edits; Reset simulation returns it to 1×. Apply & place shape preserves this multiplier while replacing native pose/velocity.

**Auto distance** aims a ray at the environment (excluding the held body), then attempts to fit the whole resized collider along that direction. Without a ray hit, its target distance is 40 units. Manual wheel distance is bounded to 0.3–80 units. Each move checks up to 12 intermediate poses/sizes and refines the first blocked interval. This avoids obvious placement through the floor/walls, but is a bounded heuristic rather than exact deforming-shape CCD. Very thin obstacles or initial penetrations may need further work after playtesting. Constant-size movement and resizing share this placement path.

While held, a body's native physics and authored geometry sampling are suspended. Other bodies and time continue. On release, authored time expressions resume at the current t. Editing camera/view settings, applying fields, resetting, or leaving the tab cancels the grab. The grab changes native 3D pose and uniform size only; it does not infer a 4D position from the 3D mouse ray.

## Optional 4D perspective camera

Enable **4D perspective camera** beneath the shared view sliders. It starts at `(0,0,0,-8)`, looking along camera-space +W, with focal distance 8 and near depth 0.5. Change its X/Y/Z/W fields or drag the W slider to move in fourth-depth. The existing XW/YW/ZW view sliders rotate the world-to-camera frame. The normal fly camera still renders the resulting 3D scene; its movement is independent.

The pure math component `scripts/core/math/camera_projection_4d.gd` takes transformed 4D vertices and the per-object matrix rows. In perspective mode it subtracts the camera position, applies the shared viewing rotation, clips the convex solid against `camera_w >= near_depth`, then multiplies the matrix-projected coordinates by `focal / camera_w`. Crossing vertex pairs provide near-plane intersection points without requiring 4D face/cell topology. In linear mode the camera position is inactive and the original matrix behavior is preserved.

An object entirely behind the near plane is hidden and loses its collider; it recovers when it returns to view. A partially clipped object becomes a closed projected convex solid with a cap. Near-plane clipping avoids division by zero, but approaching the plane can still make objects large. The floor and gravity are unaffected. Reprojection preserves the accumulated native 3D physics offset/rotation, so this is a hybrid 4D-authored/3D-physics demo, not a fully 4D camera/player physics simulation. Large clipped vertex clouds can be expensive; use simple shapes for initial experiments.

Interaction code lives in `scripts/sandbox/projected_physics/grab_controller.gd`, independent of the control panel. It uses native Godot space queries during physics ticks. The body adapter owns one shared hull/collider rebuilding path for projection and grabbed scaling.

Focused smoke verification: `tests/verify_projected_interaction.gd` covers fourth-depth scaling, near clipping, grab/resize/cancel/drop, collider scaling, hidden-object recovery, and reset. These checks do not replace mouse/visual playtesting.
