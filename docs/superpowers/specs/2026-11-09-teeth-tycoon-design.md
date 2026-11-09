# Teeth Tycoon (working title): Design

Date: 2026-11-09. Status: draft for the user's review. Plan: `docs/superpowers/plans/2026-11-09-teeth-tycoon.md`.

## Intent

A Roblox dentist-clinic tycoon, a stronger take on "Steal and fix teeth". Each player runs a clinic on their own plot in a shared server. Patients arrive, the player cleans and repairs their teeth in a quick minigame, and cash buys better tools, more chairs, hired dentists, a bigger building and a look of their own.

Why: the user wants a production-ready game ASAP that keeps the reference's proven loop but adds a better map, deeper office customization and real office-expansion upgrades. Mechanics only. All art, names and UI are our own.

## What the reference does (read off a 113 s screen recording, so the builder can compare)

- Patients spawn on a ~30 s countdown ("Time until next patient spawn"). Types: Common ("Braces Nerd", x5 cash), Rare, VIP, Zombie (30 s timer, red screen tint, paid $3,379). A server-wide banner reads "A RARE PATIENT IS HEADING TO <player>'s CLINIC!".
- Treatment is a full-screen mouth minigame: 14 to 16 teeth, a "Mouth Cleaned %" bar, and a tool list showing "N left to clean".
  - Toothbrush: scrub yellow stains and brown spots (floating +$20 to +$24 per tooth on a common patient).
  - Floss: swipe between teeth to clear green food bits.
  - Filler Spatula: hold on a chipped tooth until the ring fills ("KEEP IT!"), then tap the patch ("Perfect!").
  - Pliers: locked until "Chair 2". What they do was never shown.
  - Submit was grey at 71 % and green at 83 %. Submitting paid "Perfect! +$52 Sparkling clean!".
- Economy: cash HUD; Upgrades (tool levels, e.g. "Filler Spatula Lv 2 -> Bonding" at $4,000); Chairs (unlock more, an "Unlock Now" E prompt); Hire (staff treat patients "even while you're away"); Shop (Robux: Starter Bundle, 10 min 2x Cash, Instant Clean "finish now for 2x cash"); Playtime Reward; a goal tracker with cash rewards (Treat 3 patients $600, Upgrade your Filler $300, Fix 3 chipped teeth $400, Treat a VIP patient $500, Cure the Zombie $800); a tutorial nurse with arrows.
- A "Toothbrush Bat" in the hotbar hints at a steal/PvP mechanic. It was never shown, so this design does not specify it (open decision D1).

## Goals

- A new player is treating a patient within 60 s and has bought a first upgrade within 3 minutes.
- The clinic visibly grows through four building tiers.
- Customization changes how the clinic looks with zero new mesh uploads (colour slots plus decor slots).
- Plays on phone, tablet and desktop. Progress saves. Ready to publish.

## Non-goals (V1)

Stealing/PvP, trading, pets, rebirth/prestige, clans, console and VR support, an AI-generated mesh pipeline, custom avatar meshes.

## Anti-goals (a failure even if it technically works)

- Copying the reference's art, names or UI layout one for one.
- Any client-trusted money or progress.
- Pay-to-win that blocks free progression.
- A permanent asset upload the user has not approved.
- Scripts edited anywhere but on disk.
- Building art for a loop nobody has played (mitigated: Phase 1 builds only props every version of the game needs).

## Constraints

- Roblox Studio 0.746, Luau `--!strict`, Rojo 7.7.1, pinned toolchain in `aftman.toml`.
- Scripts live on disk and sync with `rojo serve`. Never edit scripts in Studio or with MCP `multi_edit`. Models are built through the Studio MCP and saved in the place file.
- Server authoritative: every client message is a request to validate.
- Models: authored as Kiln programs (`~/Roblox-Tools/work/<prop>/<prop>.kiln.js`), one mesh per colour, hex in the material name, front on -Z, 1 stud = 0.28 m, at most 20,000 triangles per mesh and a target of 2,500 or fewer per prop. Uploaded as `Model`, never `Mesh`.
- Every upload is permanent and goes on the user's account, so each wave needs the user's yes first. No `generate_*` Studio tools without a yes.
- Save the place to disk at every phase boundary. The 900 MB reference recording stays out of git (`*.mov` in `.gitignore`).

## Decisions

User decided: Roblox/Luau; Rojo with disk as the source of truth; Claude builds the models; 3D models first, then scripts; temporary name for now; same base concepts as the reference plus a better map, office customization and expansion upgrades.

My calls (change freely):
- **Plots:** 6 clinics around a central plaza, one per player. A seventh player waits for a free plot or gets a spectator spawn.
- **Tiers:** T0 Starter Clinic (1 chair), T1 Family Practice (3 chairs, Pliers unlock at the 2nd chair), T2 Dental Center (5 chairs, X-ray room), T3 Dental Tower (8 chairs, lab, rooftop sign). Costs are tuned in Config; first guess 0 / 2,500 / 25,000 / 250,000.
- **Customization:** colour slots (floor, wall, trim, chair upholstery, desk finish, exterior sign) and 8 decor slots per clinic. Recolouring reuses the same meshes, because each mesh already carries a `TintSlot` attribute. Items unlock with cash, goals or Robux.
- **Minigame art:** drawn with UI frames, rounded corners and gradients (no generated images). Revisit if it looks cheap.
- **Patients and staff:** Roblox avatars dressed from `HumanoidDescription` presets (Zombie green with rags, VIP gold suit). No custom character meshes.
- **Submit threshold:** 0.80 (observed between 0.71 and 0.83).
- **Pliers:** pull a "rot" issue (a loose tooth). That is my guess, since the reference never showed it.
- **Persistence:** ProfileStore (session-locked) per `roblox-dev-skill` `datastore-persistence.md`.

Open, needs the user:
- **D1 Steal.** Recommended: leave out of V1, keep the hotbar slot and server hooks. Needed before Phase 4.
- **D2 Name.** Needed before Phase 6 publish.
- **D3 Robux products.** Recommended: 2x Cash pass, Instant Clean developer product, Starter Bundle. Needed before Task 19.
- **D4 Plot count.** Default 6. Needed before Task 7.
- **D5 Art tone.** Default: bright, chunky, teal and white clinic with warm accents. Needed before Task 2.

## Left to the builder

Exact room layouts within each tier, the cost curve and payout numbers (all in `GameConfig`), UI polish, particle and sound choices.
