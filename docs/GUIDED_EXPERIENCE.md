# Fourth: guided experience

Open **`scenes/guided_experience.tscn`** in Godot and press **F6** (Run Current
Scene). F5 still launches the original sandbox. The free-play puzzle remains
`scenes/artifact_puzzle.tscn`; neither existing scene has been replaced.

From the project directory you can also run:

```powershell
& 'C:\path\to\Godot.exe' --path . res://scenes/guided_experience.tscn
```

## Walkthrough

Instructions advance when their action is completed, with a highlighted floor
ring, light column, destination label, distance, and off-screen direction hint.
The current instruction stays visible with a short explanation of the concept.

1. Walk onto the exchange ring with WASD and mouse look.
2. Press F to select the WYZ view. Your apparent position and viewing direction
   stay fixed while the surroundings change.
3. Follow the marker to the narrow artifact. Aim at it and press E to pick it up.
4. Carry it back to the exchange ring. Press F while holding it to return to XYZ.
   The artifact becomes wider because X replaces W as its visible horizontal axis.
5. Step back to the practice ring and hold C to rotate in XW, reaching at least
   85 degrees. Z rotates back. The top-right wireframe exposes the W direction.
6. Hold Down Arrow (or scroll down) until size is at most 0.85.
7. Walk to the opening marker while aiming through the small cyan point. Raise or
   lower your aim as the HUD requests. Keep moving until the **whole** artifact
   clears the wall; the player stays on the near side.
8. Aim above the gold plate and hold Up Arrow (or scroll up) to move the artifact
   farther away and enlarge it to at least 6 kg. Lift clear of surfaces if growth
   is blocked. You may keep resizing and adjust your position to center it over
   the plate after the release instruction appears.
9. Press E to drop it onto the plate. It must be released, fully supported on top,
   sufficiently heavy, and settled for 0.6 seconds.
10. Leave the load on the plate. Walk through the gold exit and to its far marker.

The HUD introduces controls as they become relevant. Rotation and resizing are
locked until their respective lessons; dropping and reacquiring an object remain
available after pickup is introduced. Mouse-wheel controls remain supported.

- **H:** recall the artifact and repeat the current section. In WYZ this returns
  it to its plinth. After returning to XYZ this places the player and artifact at
  the practice area and restarts the manipulation lessons, retaining the earlier
  view-selection progress.
- **R:** restart the entire experience in XYZ, with the artifact back in WYZ.
- **Esc:** drop the object and release the cursor. Click to capture the cursor again.

## Coordinate and carrying rules

The two ordered projection frames are:

```text
XYZ: (x,y,z,w) -> (x,y,z)
WYZ: (x,y,z,w) -> (w,y,z)
```

Y remains vertical and Z remains forward. View selection does not rotate the
artifact's source geometry. XW rotation changes that geometry's orientation;
uniform perspective resizing changes its physical size and assigned mass.

Rooms are **authored basis-specific regions**, each embedded in 4D and projected
with the core matrix code. Selecting a view also selects its visible region and
environment collision mask. This explicit region rule prevents unrelated geometry
from overlapping or collapsing into the same space. It is not a claim that changing
coordinates alone teleports a person, nor a continuous simulation of an entire 4D
building. The lesson explains this distinction.

Unheld artifacts remain in their home region, hidden, frozen, and non-colliding
when it is inactive. Held artifacts transfer to the destination region while
preserving apparent 3D pose, source dimensions, XW angle, uniform size, mass, and
the grab's distance/size baseline. Their local mesh and collider are rebuilt using
the destination projection. This transfer is an explicit interaction rule.

F is available only at the appropriate lesson steps and only on the exchange
platform. The destination is queried before switching: both the player capsule
and the artifact's **destination** shape must fit. Rejected switches preserve the
current view and display recovery instructions. A small resting-contact inset
allows ordinary contact without permitting substantial overlap. Regions remain
queryable on separate masks even when inactive; inactive environment bodies have
no collision mask that could initiate contact with active bodies.

Physics remains native 3D Jolt. The artifact validator now supports the analytic
XYZ and WYZ extents of the centered hyperrectangle, including intermediate XW
rotation maxima. Arbitrary frames, unrestricted 3D tumbling, other source shapes,
or more rotation planes require extending that validator.

Mass remains `4 * size^3` kg in both views. With the original 1.4 × 1.4 opening,
any passing object weighs less than 2.68 kg. The 6 kg pressure plate therefore
requires enlargement after the wall. This is a gameplay mass convention, not mass
calculated from the volume of an arbitrary projection.

## Code and verification

- `scripts/game/view_basis_4d.gd`: ordered frame matrices, embedding, and masks.
- `scripts/game/guided/basis_region.gd`: embedded room geometry and projected boxes.
- `scripts/game/guided/basis_controller.gd`: destination checks and view/ownership changes.
- `scripts/game/guided/experience_director.gd`: action-based lesson progression and text.
- `scripts/game/guided/destination_marker.gd`: collision-free illuminated destinations.
- `scripts/game/guided/guided_experience.gd`: scene, HUD, input, recovery, and composition.

The shared player and artifact retain free-play defaults. The guided host inherits
the original room construction while supplying separate regions and lesson logic.
The independent 4D physics engine and the sandbox demo are not involved.

```powershell
& 'C:\path\to\Godot.exe' --headless --path . --script tests/verify_guided_experience.gd
& 'C:\path\to\Godot.exe' --headless --path . --script tests/verify_artifact_puzzle.gd
& 'C:\path\to\Godot.exe' --headless --path . --script tests/verify_projected_demo.gd
```

The guided integration test covers both projection formulas, intermediate rotation
bounds, inactive-room ownership, clearance rejection for player and expanded
artifact, pose/mass/grab preservation, action locks, complete delivery, plate, exit,
recovery, and restart. Walking is scripted through native capsule movement in
headless mode, where Windows cannot capture the cursor. Grabbing and manipulation
use the same input handlers and physics as the scene. For rendered walkthrough
captures, omit `--headless` and append `-- --screenshots`; images are written into
the ignored `.godot/` folder. Visual feel and unusual input sequences still benefit
from playtesting.
