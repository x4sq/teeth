# Handover (2026-11-09)

What was built while you were away, what is verified, what is not, and what to do first.

## Do this first

1. **Save the place** in Studio (File, Save). The world (`Workspace.World`), the clinic tiers
   (`ServerStorage.Templates.Tiers`), the props and the decor are only in the place file.
2. `cd ~/Desktop/Teethyz && rojo serve`, then Studio's Rojo panel, **Connect**, accept the sync.
   (Rojo will not delete the world or templates: they aren't in a Rojo-managed folder.)
3. Optional but recommended: Game Settings, Security, **Enable Studio Access to API Services**, so saving
   works while testing in Studio. Without it, ProfileStore uses an in-memory mock (the game still works,
   progress just isn't kept between runs).
4. Press Play and work through the test matrix below. Look at the Output window first.

## What exists

| Area | State |
|---|---|
| Art style | **Clean low poly** (user's choice, spec `docs/superpowers/specs/2026-11-09-lowpoly-redesign.md`). 31 faceted Kiln meshes uploaded and approved (`assets/lowpoly-manifest.json`), imported into `ServerStorage.Templates.{Props,Kit}` and repaired (colours, anchoring, pivot, yaw, collision), every one size-checked against its build record. The older rounded set in `assets/manifest.json` is superseded (assets still on the account, unused). |
| Clinic tiers | `Tier0` to `Tier3` (1, 3, 5, 8 chairs) rebuilt from `Shell0..3` (checker floor, thick walls, framed windows, wainscot, base band, cornice, striped awning, gabled porch roof, sign frame, planters; T2+ columns and an X-ray room partition; T3 a hollow tower with turrets and the tooth mascot) plus the low-poly props at the old placements. Shell meshes do not collide: invisible `Colliders` Parts do the walls, floor, partition and columns. Wall-decor and queue attachments were moved clear of windows and columns. Seen in screenshots (Tier 0 inside and out, Tier 3 outside). |
| Decor | 8 items in `ServerStorage.Templates.Decor`: plant, shelf and water cooler are the new low-poly models; tooth statue and the four wall pieces (poster, clock, banner, diploma) are flat-shaded Parts that already match the style. |
| World | Plaza (rings, spokes, fountain, 12 benches, 6 lamps, 6 flower beds, 3 cafe sets, bushes, trees, 4 hidden spawns); 6 plots on a ring facing it, each with a two-tone lot, yard, path, fences, hedges, a gate, mailbox, trees and front-yard planting; a forest ring and invisible edge walls. Seen in screenshots. |
| Lighting | Brightness 2.4, soft atmosphere, light colour grading (Lighting is stored in the place, not by Rojo). |
| Rules | `src/shared/Core`: mouth, payout, patients, upgrades, tiers, goals, staff, customize, rate limit, data repair. **74 Lune specs, all passing.** |
| Server | Data (ProfileStore), plots, clinics, patients, treatment (server-owned mouth and payouts), progress (cash, upgrades, hiring, goals, playtime reward), shop. |
| Client | HUD, treatment minigame (scrub, floss, hold-and-tap), menus (upgrades, hire, clinic, style, shop), sounds. |
| Gates | `rojo build`, `lune run test`, `selene`, `stylua --check`: all green. |

## What is NOT verified (be skeptical here)

**Nothing has been played in Studio.** Rojo needed your click to connect, so none of the scripts have
ever run. Everything in `src/server` and `src/client` is checked only by Rojo, Selene (syntax and lint)
and the Lune specs of the pure rules. Expect first-run bugs in Roblox-API-facing code. Most likely places:

- Patient avatars: `CreateHumanoidModelFromDescription` needs internet; the lying-on-chair pose offset
  (`LIE_OFFSET` in `PatientService.luau`) is a guess and will probably need nudging.
- Patient walking: door to reception line, then placed on the chair (not path-finding to the chair).
- ProximityPrompt on chairs: trigger size and distance.
- Minigame input on a real mouse and on touch (`TreatmentController.luau`); hit areas and thresholds
  (`SCRUB_DISTANCE`, `FLOSS_DISTANCE`, `HOLD_SECONDS`) are untuned.
- UI layout at phone sizes (HUD and menus use `UIScale`, untested).
- Sounds use Roblox built-in `rbxasset://sounds/...` files; if any is missing it is silently quiet.
- **Camera inside clinics**: the shell walls don't collide (the invisible colliders are ignored by the camera), so
  `default.project.json` sets `StarterPlayer.DevCameraOcclusionMode = Invisicam`, which fades walls between the
  camera and the player. This has never run; if the camera looks wrong indoors, try `Zoom` or a custom camera.
- **Tier 1 and the porch columns** were checked by numbers only (fits, slots, collider layout), not by
  eye. Tiers 0, 2 and 3 were seen in screenshots. New meshes load a moment after first use: if a
  screenshot shows an empty building, take it again.
- **Wall decor and windows**: attachments were moved off the windows by hand; if a poster still overlaps a
  window frame on some tier, move that `DecorWallN` attachment in the template.
- The build scripts for the place are in `tools/studio/` (`repair_lowpoly`, `build_tiers`, `build_world`).
  They run in Studio via the command bar, not through Rojo; they are a record, and re-running them on an
  already-built place is not needed.

## Test matrix (fill in as you play; UNTESTED until measured)

| Row | Result |
|---|---|
| Output shows both build stamps (server and client) | UNTESTED |
| You get a plot and a clinic (Tier 0) appears on it, facing the plaza | UNTESTED |
| A patient spawns, walks in, lies on the chair; chair prompt appears | UNTESTED |
| Toothbrush, floss, filler (hold then tap) work with the mouse | UNTESTED |
| Same on a phone-size viewport with touch | UNTESTED |
| Submit stays grey below 80% and turns green at 80% | UNTESTED |
| Cash rises by the amounts shown; goal card advances | UNTESTED |
| Upgrade a tool; hire a dentist; expand to Tier 1 (3 chairs, Pliers unlock) | UNTESTED |
| Zombie patient: 30 s timer, red tint, "got away" message on timeout | UNTESTED |
| Style menu: recolour walls/floor, place and remove decor; survives rejoin | UNTESTED |
| Rejoin keeps cash, tools, tier, colours, decor | UNTESTED |
| Two players get two different plots; a 7th player waits for a free plot | UNTESTED |
| Leave mid-treatment: no stuck chair, no double payout | UNTESTED |

## Known gaps and decisions for you

- **Steal mechanic: not built** (decision D1). The reference's "Toothbrush Bat" was never seen in use, so it
  isn't specified. Recommended: leave it out of V1.
- **Uploads**: 31 low-poly models are now permanent assets on your account (you approved them). Nothing else
  has been uploaded and nothing is published.
- **Robux products are disabled** (ids are 0 in `GameConfig.products`; the shop shows "Soon"). Create the
  products in the Creator Dashboard and paste the ids in.
- **Name** is still "Teeth Tycoon" (temporary). **Nothing is published.**
- Optional: `luau-lsp` (type-aware analysis) would catch wrong API names; I was blocked from installing it.

## If something breaks

- No clinic: look for `[PlotService]` or `[ClinicService]` warnings (missing `Workspace.World.Plots` or
  `ServerStorage.Templates.Tiers.Tier0`). Both must exist; if the place was reopened without saving, they
  are gone.
- No patients: look for `[PatientService]` warnings; avatar creation needs internet access.
- Every number you may want to change is in `src/shared/Config/GameConfig.luau`; no balance change needs a code edit.
