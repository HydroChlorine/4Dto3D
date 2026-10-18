# Fourth: standalone artifact puzzle

For the separate narrated, action-guided XYZ/WYZ walkthrough, see
[Guided experience](GUIDED_EXPERIENCE.md).

Open `scenes/artifact_puzzle.tscn` in Godot and press **F6** (Run Current Scene).
F5 still launches the original sandbox; its demo and startup have not changed.

Alternatively, from the project directory:

```powershell
& 'C:\path\to\Godot.exe' --path . res://scenes/artifact_puzzle.tscn
```

## Controls and objective

- WASD / mouse: walk / look. E or left click: grab / release.
- While holding, Z / C continuously rotate the source in XW, from 0 to 90 degrees.
- Hold Down Arrow or scroll down to bring the target nearer and shrink the artifact;
  hold Up Arrow or scroll up to move it farther away and enlarge it. Arrow controls
  work continuously while held. Physical obstacles can stop the actual movement.
- R resets the room. Esc drops the artifact and releases the cursor; click to recapture.

Rotate **and** shrink the artifact, then push it through the cyan opening. Walk
toward the opening while holding it to reach the far side. Lift it clear of the
floor and wall before enlarging. Drop at least 6 kg onto the gold pressure plate,
then walk through the unlocked gold exit and reach its far marker. The plate needs
0.6 seconds of settled, released support. Removing its load closes the door.

Known solution: XW = 90 degrees, size approximately 0.8 to pass; enlarge to at least
1.145 afterward (1.2 gives useful headroom). The first pickup is easiest by aiming
slightly downward at the cyan artifact.

The small top-right HUD shows the artifact's 16 vertices and 32 edges using an
oblique projection that exposes W. It follows the accepted XW rotation, including
when an obstacle blocks rotation. Edges become gold as their direction aligns with
W; the X/Y/Z/W guides stay fixed. Its scale and camera stay fixed so rotation remains
readable while the physical object is carried or resized. This explanatory view
reuses the core tesseract, transform, and projection code and the sandbox wireframe
renderer; it has no physics or input of its own.

## Rules and implementation

The source hyperrectangle has full XYZW side lengths (3.6, 1.6, 1.2, 0.6).
The aperture is 1.4 × 1.4, from Y=0.65 to 2.05, in a 0.7-thick wall. At angle a
and uniform size s, projected width is s(3.6 cos(a) + 0.6 sin(a)); height is 1.6s.
Size is bounded to [0.65, 1.5]. Shrinking alone leaves width at least 2.34;
rotation alone leaves height 1.6. At a=90°, s=0.8, the projection is 0.48 × 1.28.

Mass is 4s³ kg, independent of 4D rotation. Any artifact small enough to pass
weighs at most 4(1.4/1.6)³ = 2.6796875 kg, below the plate's 6 kg threshold.
Ordinary 3D tumbling is locked to keep the introductory puzzle about XW rotation.

`scripts/game/` contains the standalone room, player/grab adapter, projected body,
load sensor, and door. Only geometry/math/rendering code is reused from the repo;
no sandbox demo or editor model is instantiated. The body uses the existing core
4D transform and XYZ projection functions and shares one accepted point cloud
between its visible convex hull and native Godot convex collider. Native body scale
stays identity. The scene uses the project's configured Jolt 3D physics.

Rotation and scaling share rate-limited collision validation. A conservative box
encloses the entire proposed XW angle interval (including its interior width
maximum) and size interval. Blocked requests are reduced by binary search. This
validator relies on the centered hyperrectangle, locked 3D rotation, and one plane;
it must be extended before enabling other planes or other source geometry. A 2 mm
contact tolerance avoids blocking ordinary resting contacts. Rigid-body CCD handles
translation, not arbitrary deformation. This remains a small gameplay prototype.

The plate checks native contact, bottom height, full footprint containment, released
state, assigned mass, and settling speed. This is a gameplay supported-mass sensor,
not a measurement of transient impact forces or a general stacked-body load solver.

Run the focused integration check:

```powershell
& 'C:\path\to\Godot.exe' --headless --path . --script tests/verify_artifact_puzzle.gd
```
