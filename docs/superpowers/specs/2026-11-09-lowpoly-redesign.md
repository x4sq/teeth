# Low-poly redesign (2026-11-09)

Supersedes the look described in the original design. The map layout (central plaza, six plots on a ring facing it)
stays; everything that is drawn changes.

## Why

The first build was a prototype: walls and floors were flat blocks of Parts, props were smooth and rounded,
the plaza was a plain disc, the UI used emoji and pill shapes. The user wants a clean low-poly look with almost
everything modelled as meshes.

## Style rules

- **Faceted, not smooth.** Chamfered boxes, 6 to 8 sided cylinders, 6x4 spheres, 4 to 8 sided cones. Every curved
  shape goes through `creaseNormals(geo, { angle: 5 })`, because Kiln's spheres, cylinders and cones export SMOOTH
  normals otherwise (measured: 0% to 50% flat; with creaseNormals 100%).
- **Small bold palette, no textures.** See `PAL` in `tools/art/prelude.js` (teal, deep teal, mint, cream, coral, sun
  yellow, wood, grass, leaf, terracotta). Colour lives in the material name (`Slot_RRGGBB`) so every mesh keeps its
  `TintSlot` for the customization system.
- **Silhouette first.** Roofs, awnings, turrets, pilasters, planters, finials: shapes you can read from the camera.
- **UI matches.** Flat colours, hard offset shadows, bevel strips, 3px ink outlines, corner radius capped at 8,
  diamond letter badges instead of icons, no emoji, no images.

## Asset list (31 meshes, all built and checked locally)

| Group | Assets |
|---|---|
| Props (10) | DentalChair, DentalLamp, InstrumentTray, ReceptionDesk, SinkCabinet, XRayMachine, Sterilizer, WaterCooler, ToothSign, WaitingChair (restyled from `art/kiln/` through the build tool) |
| Building shells (4) | Shell0 to Shell3 (`art/lowpoly/Shell.kiln.js`, one program, `--define=TIER=n`): checker floors, thick walls with framed windows and a doorway, wainscot and rail, base band, cornice, striped awning, gabled porch roof, sign frame, planters; T2 columns, pilasters and an X-ray room partition; T3 a hollow tower with turrets |
| Plaza (9) | PlazaCore (rings and spokes), FountainRing, Bench, StreetLamp, TreeRound, TreePine, Bush, FlowerBed, CafeSet |
| Plot (5) | PlotGround (two-tone lot, yard, path), Fence26, Hedge26, GatePosts, Mailbox |
| Interior (3) | RugRunner, PlantLP, ShelfLP |

Triangle counts: 66 to 1,332 per prop or piece, shells 3.6k to 10.1k. All far below Roblox's 20,000 per mesh.

## Pipeline (all in files)

`tools/art/build_prop.mjs <source> <Name> [--legacy] [--define=K=V]` prepends `tools/art/prelude.js`, renders with Kiln,
converts with `kiln_to_roblox.mjs` into `~/Roblox-Tools/work/upload/LP_<Name>.glb` and records size, origin and one
reference mesh centre in `art/lowpoly/_build/<Name>.json` (used to fix Studio's import yaw and pivot).

## Status (2026-11-09)

Done: 31 GLBs uploaded (ids in `assets/lowpoly-manifest.json`), imported and repaired; tiers, world and decor rebuilt
in the place (`tools/studio/*.luau` record how); lighting retuned; `ClinicService` tints `Floor2` as the chosen
`Floor` colour 7% darker; camera occlusion set to Invisicam; UI redone. Verified by numbers for all four tiers and
by screenshot for the plaza, plot, Tier 0 and Tier 3.

Still to do: playtest everything (the scripts have never run in Studio, see `HANDOVER.md`), and look at Tiers 1 and 2
by eye.

Lessons worth keeping:

- The importer drops colours (so colour lives in the mesh name, `Slot_RRGGBB`) and shifts each model so its lowest
  point is y = 0: a design frame with the floor centred on y = 0 needs the shell placed 0.2 low.
- Shell meshes are single combined meshes per colour, so their box collision would fill the building: they are
  `CanCollide = false` and invisible `Part` colliders do the walls. The same goes for the gate and the cafe set.
- Round discs (plaza rings, fountain) use `Hull` collision; `Box` would add invisible square corners.
- New meshes render empty for a moment on first use; screenshot again.
