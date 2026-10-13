# Projected 3D physics demo

This guide describes the current **3D Physics Demo** workspace. It uses core 4D geometry/projection math but **Godot's native 3D rigid-body physics**. It does not run the independent [4D physics engine](PHYSICS.md).

## Start and controls

The app opens Playground, Procedural 1, and 3D Physics Demo, with Playground selected. Select the demo tab to find a tesseract and 16-cell above an infinite floor at Y=0. Each workspace has its own World3D.

| Control | Behavior |
| --- | --- |
| RMB + mouse | Look with the ordinary 3D fly camera |
| WASD, Q/E, Shift | Fly, move down/up, move faster |
| Left-drag a dynamic shape | Select and physically pull it |
| Mouse wheel while holding | Change distance; up moves farther |
| Release / Esc | Drop with current velocity / restore pre-grab pose, size and velocities |
| Pause | Stop expression time and freeze native bodies; resume to drag physically |
| Reset simulation | Return to t=0, authored poses, zero velocities and grab size ×1 |
| Reset camera | Reset only the ordinary 3D fly camera |
| Sidebar arrow | Collapse or expand controls |

Leaving the tab cancels any grab and freezes its native bodies. Returning resumes according to the Run/Pause setting. The visible floor follows the fly camera horizontally and extends beyond its far distance; a WorldBoundaryShape3D provides infinite collision.

## Shapes and editable fields

Add shapes from the catalog; select one to show its editor. Custom JSON files supply geometry, but this demo uses its own initial transforms rather than importing their saved procedural presets. Remove shape removes that geometry and promotes its children to its parent, preserving their authored 4D poses. Visibility is visual only.

The geometry fields accept expressions in `t` (seconds): position XYZW, six rotation planes in degrees, scale, anchor, and a per-shape 3×4 projection matrix. Shared X↔W/Y↔W/Z↔W sliders rotate the source in that order before the matrix. At zero, the default matrix displays XYZ; X↔W alone at 90° displays WYZ.

**Apply & place shape** commits the fields, restores that assembly's authored pose at the current t, and clears native linear/angular velocity—even when the values are unchanged. It preserves grab size. Thus applying Y=10 repeatedly places a fallen shape there again under the default projection. Fixed bodies do not fall and cannot be pulled.

### 4D hierarchy and compound assemblies

The shape selector is a tree. Drag a shape onto another to parent it; drag it onto **World** to unparent. Click a row to open its editor, and click it again to close. Each shape implicitly has two nodes, exposed as **Geometry** and **Group** tabs:

- Geometry changes only that part's vertices, with its own projection and appearance.
- Group changes that part and all descendants. Group transforms compose in 4D using the same core `Scene4D` as Procedural.
- Reparenting preserves the authored 4D world transform through the core's full matrix offset. It leaves the editable Geometry fields unchanged and rejects cycles or singular parent inverses.

Each root and all its descendants form **one native 3D rigid body**. Each geometry contributes a separate projected convex mesh and collider, preserving spaces between parts. The native rigid bodies are not parented to one another. Grabbing selects and moves the root assembly; select individual parts in the tree to edit them.

Parenting/unparenting resets affected assemblies to their authored poses and clears their native velocities. It does not preserve a fallen or dragged 3D pose by converting it back to 4D. Apply resets the selected part's whole assembly. The root's Fixed checkbox controls the assembly; child Fixed controls are disabled. Base mass is specified per part and summed for the assembly, then multiplied by grab size cubed. Children retain their individual settings when detached.

### Authored pose versus simulated pose

Fields describe the authored 4D geometry, not the body's current 3D physics pose. The live readout shows native position, grab size and mass.

Projection operates on authored vertices. The adapter centers the resulting point cloud, builds its solid/collider locally, and lets a native body transform add simulated movement and rotation. During live reprojection, projected-center deltas preserve accumulated native displacement. Physics motion is **not** mapped back into 4D or into the embedded shape viewed by the second camera.

For example, the default tesseract is authored at approximately (-2,5,0,0). Falling onto the floor does not change that authored Y=5. Camera clipping still acts on the authored projection before the native displacement is applied.

## Projection pipeline

Matrix-only mode:

```text
local 4D vertices → Geometry PRSA → ancestor Group transforms/offsets
→ shared source rotation
→ per-shape 3×4 matrix → 3D convex solid → native 3D body pose
```

**Matrix → 4D camera → 3D** mode:

```text
local 4D vertices → Geometry PRSA → ancestor Group transforms/offsets
→ shared source rotation
→ per-shape 3×4 matrix → embed (u,v,s) as (u,v,s,0)
→ camera coordinates → full frustum clipping → perspective division
→ 3D convex solid → native 3D body pose
```

The ordinary Godot camera then renders the result to the screen. Matrix fields remain active in both modes. The second camera views the already-projected shape at W=0, not the original 4D solid. This is projection, not extraction of a cross-section.

Each part’s final convex solid defines its visible mesh and collider. Concavities within a single part are filled; gaps between separate parts are preserved. A lower-dimensional part remains visible but loses its volume collider; an entirely clipped part is hidden and loses its collider. The assembly freezes only when none of its parts has 3D volume.

## Second-stage 4D camera controls

| Field | Meaning |
| --- | --- |
| Camera X/Y/Z/W | Camera position in the embedded space; increments of 0.1 |
| Target X/Y/Z | Point to look toward, with target W fixed at 0 |
| Look at target | On: derive orientation toward target. Off: fixed +W orientation |
| Viewing depth | Move along the camera's current fourth viewing direction, preserving lateral position |
| Focal | Output magnification; default 8 |
| Near / Far | Allowed camera-space fourth-depth; defaults 0.5 / 100 |
| FOV° | Angular extent shared by image X, Y and Z; default 90° |
| Reset 4D camera position | Place camera at target + (0,0,0,-8) |

With look-at enabled, the depth slider stops just before the target instead of crossing through it. Position fields remain available for moving around or beyond it. Moving the camera into W=0 and looking along the embedded shape can produce an edge-on image. Shared source sliders do not orient this second camera.

At position (0,0,0,-8), looking toward the origin with focal 8, the unclipped result matches the matrix output. With fixed +W orientation, moving from W=-8 to W=-4 doubles the unclipped coordinates; moving sideways shifts the image without changing depth. Look-at movement also changes viewing angle.

### Perspective and clipping

For a camera-space point `(x,y,z,w)`, perspective produces `focal * (x,y,z) / w`. Geometry is clipped first to:

```text
Near <= w <= Far
abs(x), abs(y), abs(z) <= w * tan(FOV / 2)
```

These eight boundaries keep division away from zero and limit the viewing region. Partially intersecting solids are trimmed and capped; fully outside solids disappear. This changes collision geometry too, unlike an ordinary camera that only clips rendering. Focal changes magnification, while FOV sets the angular boundaries. Invalid Near/Far ranges produce no solid; use `0 < Near < Far`.

A shape can appear squashed because clipping cuts one side, rather than because perspective scales that axis differently. For example, at 90° FOV and depth 5, the visible Y interval is [-5,5]. An authored cube spanning Y=4..6 loses its upper portion. Increasing FOV restores that portion if no other boundary clips it.

## Physical dragging, resizing and mass

A spring pulls the held body's center toward a cursor-derived target. The body stays dynamic, so Godot handles friction, sliding and pushing. Orientation is locked while held and the previous lock setting is restored on release. Native velocity is preserved on drop.

**Drag** keeps the grab size constant. **Perspective grab** requests `initial_size * distance / initial_distance`, bounded to 0.05–20×. Size is baked into the mesh/collider rather than scaling the RigidBody3D node. Growth is rate-limited and overlap-checked at the current pose; blocked growth does not block movement. This is not exact continuous collision detection for deformation.

**Auto distance** chooses a target distance from a ray hit excluding the held body, or 40 units with no hit. Otherwise, the wheel chooses 0.3–80 units. Physical obstruction can prevent reaching that target; it is not guaranteed exact surface placement or exact apparent-size preservation while obstructed.

**Base mass** is mass at grab size ×1. Current mass is `sum(part_base_mass) * size^3`; doubling size makes a body eight times heavier. Reset restores size ×1 and base mass. Camera projection, clipping and authored scale do not automatically recalculate mass from hull volume. Native inertia follows the collider and assigned mass.

**Grab strength** (0.25–4×) adjusts the assisted pull. Defaults are stiffness 900 and a 2000 N force cap at 1 kg. Above 1 kg, both grow as mass^0.8, so heavy objects remain manageable but follow more slowly. Critical damping and an implicit spring calculation stabilize light bodies. This assistance changes the grab, not native collision mass; gravity remains active.

Authored geometry sampling pauses for the entire held assembly. Other shapes and t continue; on release, expressions resume at current t. Camera/view edits, Apply, reset, and tab deactivation cancel the grab. No 3D mouse movement is interpreted as a unique 4D displacement.

## Implementation ownership

| File | Responsibility |
| --- | --- |
| `scripts/core/scene/scene_4d.gd` | Geometry ownership, Group/Geometry tracks and keep-world parenting |
| `scripts/core/math/camera_projection_4d.gd` | Pure two-stage projection, look-at frame, depth movement and frustum clipping |
| `scripts/core/geometry/convex_hull_3d.gd` | Pure convex topology shared by clipping and rendering |
| `scripts/rendering/projected_hull_3d.gd` | Compatibility alias for the core hull utility |
| `scripts/rendering/solid_hull_renderer.gd` | Opaque hull mesh and edge display |
| `scripts/sandbox/projected_physics/projected_body.gd` | Native body adapter, cached projection, centered compound meshes/colliders, assembly size and mass |
| `scripts/sandbox/projected_physics/grab_controller.gd` | Picking, spring pull, resize queries and grab lifecycle |
| `scripts/sandbox/projected_physics/demo.gd` | World, floor, cameras, control panel and physics-tick coordination |
| `scripts/sandbox/app_shell.gd` | Isolated viewports/worlds and tab activation |

Core math has no node, IO or UI dependencies. Native bodies and input belong to adapters. Frustum clipping rebuilds hull topology between cuts so newly created cap edges participate in later cuts, even when no original vertex lies inside the final view.

## Limits and verification

Live deformation does not supply surface velocities to Godot. Abrupt collider changes can cause overlap, popping or sudden responses; native CCD does not solve arbitrary swept deformation. Dense changing hulls can be expensive. This workspace is a prototype, not a deformable-body engine or a recorded 4D-physics simulation.

Run headlessly with `godot --headless --path . --script <test>`:

- `tests/verify_projected_hierarchy.gd`: parenting, transform ownership, compound colliders, mass, unparenting and removal.
- `tests/verify_projected_demo.gd`: floor contact, pose edits, reset, projection changes and tab suspension.
- `tests/verify_projected_interaction.gd`: camera math, grabbing, resizing, cancellation, mass and floor sliding.
- `tests/verify_camera_frustum.gd`: partial clipping, enclosing geometry, FOV and side/far rejection.

These are focused smoke checks; visual feel and unusual collision cases still need playtesting.
