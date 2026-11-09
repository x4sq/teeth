# Teeth Tycoon (working title)

A Roblox dentist-clinic tycoon. Each player runs a clinic on their own plot around a central plaza:
patients arrive, you clean and repair their teeth in a quick minigame, and the cash buys better tools,
more chairs, hired dentists, a bigger building and a look of your own.

Design: `docs/superpowers/specs/2026-11-09-teeth-tycoon-design.md`.
Plan: `docs/superpowers/plans/2026-11-09-teeth-tycoon.md`.
**Status and first steps: `HANDOVER.md`.**

## Run it

First time on a fresh clone: `aftman install && wally install` (installs the pinned tools and the Knit packages).

1. Open the place "teeth" in Roblox Studio and **save it** (File, Save): the world, the clinic tiers and
   the decor live in the place file.
2. In this folder: `rojo serve`. In Studio, open the Rojo panel and click **Connect**, then accept the sync.
3. Press Play. The Output should show `[Teeth Tycoon] Server started - BUILD v1` and
   `[Teeth Tycoon] Client started - BUILD v1`. If it doesn't, Studio is not running this code: check
   that Rojo is connected.

## Checks (no Studio needed)

```bash
export PATH="$HOME/.aftman/bin:$PATH"
python3 ~/.claude/skills/roblox-code/scripts/check.py   # rojo build, lune specs, selene, stylua
```

All four must be green before anything else.

## Layout

| Path | What it is |
|---|---|
| `src/shared/Core/` | Pure game rules (mouth, payout, patients, goals, customize, data repair). Tested by `tests/*.spec.luau` under Lune. |
| `src/shared/Config/` | `GameConfig` (every tunable) and `Looks` (patient appearance). |
| `src/shared/Net.luau` | Every remote event, declared in one place. |
| `src/server/Services/` | Knit services. They own all state and validate every client request. |
| `src/server/ProfileStore.luau` | Vendored session-locked saving library (Apache-2.0, unmodified). |
| `src/client/Controllers/` | Knit controllers: HUD, treatment minigame, menus, sound, state. |
| `src/client/UI.luau` | Shared UI look and constructors. |
| `art/kiln/` | Source programs for every 3D prop (Kiln, text to GLB). |
| `assets/manifest.json` | Roblox asset id of every uploaded model. |
| `tools/studio/` | Luau scripts run through the Studio MCP (e.g. `repair_import.luau`). |

## Rules this project follows

- Scripts live on disk and sync through Rojo. Don't edit scripts in Studio.
- The server decides all money and progress; the client only sends requests.
- Models are made in Kiln, uploaded as Models, then repaired after import (`tools/studio/repair_import.luau`):
  Studio drops every colour, and the colour is restored from the hex in each mesh's name.
- Uploads are permanent assets on the creator's account. Ask before adding more.
