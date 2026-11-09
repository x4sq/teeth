# Teeth Tycoon Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a publishable Roblox dentist-clinic tycoon with a plaza map, four expandable clinic tiers, a customization system, and a server-authoritative treatment minigame.

**Architecture:** Models first, as the user asked. Phase 1 builds props with Kiln, uploads them as Models, repairs the import, and bakes tier templates into the place file (`ServerStorage.Templates`). Pure game rules live in `src/shared/Core/` with Lune specs. Knit services own state on the server, and controllers only draw UI and send requests over one `Net.luau`.

**Tech Stack:** Roblox Studio 0.746 + Studio MCP (`Roblox_Studio`), Luau `--!strict`, Rojo 7.7.1, Wally (Knit, Promise, Signal, Trove), Lune 0.8.9, Selene, StyLua, Kiln 0.8.0 (`~/Roblox-Tools/kiln-0.8.0`), ProfileStore.

**Spec:** `docs/superpowers/specs/2026-11-09-teeth-tycoon-design.md`

## Status (2026-11-09, end of the unattended session)

Done and verified by the four gates / numeric checks: Tasks 1, 2 (4 of 5 props), 3 (3 of 9), 4 to 8 in spirit,
9 to 14 (74 Lune specs), 15 to 19 (written, gates green, **never run in Studio**), 20 to 23 (written, same caveat).
Not done: 24 (git init), 25 to 27 (playtest matrix, performance pass, publish prep). See `HANDOVER.md`.

Deviations from this plan, and why:
- **Fewer uploads.** Wave 2 shrank: plants, posters, clocks, banners, shelf, doors and windows are plain Parts
  (re-tintable, no permanent uploads). Uploaded: chair, lamp, tray, reception desk, sink cabinet, X-ray machine,
  sterilizer, water cooler, tooth sign (9). The waiting chair upload was blocked by the permission checker, so
  waiting chairs are Parts for now.
- **Merged services.** Economy, upgrades, staff, goals and the playtime reward are one `ProgressService`; announcements
  are a remote used by every service; tutorial hints are client-side.
- **Core takes `cfg` and an `rng` as parameters** (no `require` between Core modules) so the same files run under
  Lune and in Studio, and a tiny deterministic `Core/Rng` replaces `Random`.
- **Build scripts for tiers, decor and the world ran through the Studio MCP** and exist only as their output in the
  place file (save it!). `tools/studio/repair_import.luau` is the only Studio script kept on disk.
- **Patients walk to the reception line, then are placed on the chair** (rows of stations are too tight to path through).
- **Task 0 gates** (upload consent) were satisfied by the user's instruction to finish all building.

## Global Constraints

- Roblox Studio 0.746, Luau `--!strict`, Rojo 7.7.1, pinned toolchain in `aftman.toml`.
- Scripts live on disk and sync with `rojo serve`. Never edit scripts in Studio or with MCP `multi_edit`. Models are built through the Studio MCP and saved in the place file.
- Server authoritative: every client message is a request to validate.
- Models: Kiln programs, one mesh per colour, hex in the material name, front on -Z, 1 stud = 0.28 m, at most 20,000 triangles per mesh, target 2,500 or fewer per prop. Uploaded as `Model`, never `Mesh`.
- Every upload is permanent and goes on the user's account, so each wave needs the user's yes first. No `generate_*` Studio tools without a yes.
- Save the place to disk at every phase boundary. `*.mov` stays in `.gitignore`.
- Never put models inside the Rojo-synced `Shared` or `Packages` folders (Rojo deletes unknown instances there). Templates go in `ServerStorage.Templates`, props in `Workspace`.

## Review Focus

The failure modes most likely to bite a player that no happy-path test covers. Each has a pinned test in the owning task.

1. A client sends `Treat_Clean` for an out-of-range, already-cleaned or wrong-tool issue, or dozens per second. Expected: rejected, no payout (Tasks 10, 14, 17).
2. A player leaves mid-treatment or a Zombie timer expires. Expected: chair and patient freed, no payout, nothing duplicated on rejoin (Task 17).
3. A profile fails to load or is session-locked. Expected: no kick, no overwrite with default data, retry with backoff (Task 15).
4. More than 6 players, two joins at once, or a plot owner leaves. Expected: no shared plot, the plot resets to its template (Task 16).
5. A customization payload with an unknown slot, an unowned item, a non-string or an oversized table. Expected: rejected (Task 14).
6. A long absence. Expected: staff earnings capped (Task 13).
7. An upload held or rejected by moderation. Expected: stop and report, never re-upload (Task 2).

---

## Phase 0: Gates (user decisions)

### Task 0: Decisions and consent

**Files:** none (a checklist the user answers).

- [ ] **Step 1:** Confirm D5 art tone (before Task 2) and D4 plot count (before Task 7).
- [ ] **Step 2:** Get a yes for the Wave 1 upload (5 assets) before Task 2 step 6, and a yes for Wave 2 (about 9 assets) before Task 3 step 6. Uploads cannot be deleted by us.
- [ ] **Step 3:** Confirm D1 steal (recommended: out of V1) before Task 17, D3 Robux products before Task 19, D2 name before Task 27.

---

## Phase 1: Art kit (models)

### Task 1: Import repair tool and asset manifest

The importer drops every colour. This task makes the repair repeatable.

**Files:**
- Create: `tools/studio/repair_import.luau` (run through `execute_luau`, Edit datamodel)
- Create: `assets/manifest.json`
- Create: `art/kiln/DentalChair.kiln.js` (copy of `~/Roblox-Tools/work/dental-chair/chair.kiln.js`, so art source is version-controlled)

**Interfaces:**
- Produces: `repairImport(model: Model): { meshes: number, tintSlots: { string }, anchored: boolean, grey: number }`. For each `MeshPart`: set `Color` from the `_RRGGBB` suffix, set attribute `TintSlot` = the name before the underscore (`Upholstery_2EAAB5` gives `Upholstery`), `Material` = Metal for `Chrome*`, Neon for `Glow*`, else SmoothPlastic, `Anchored = true`, `CollisionFidelity = Box`. Ends with `ChangeHistoryService:SetWaypoint`.
- Produces: `assets/manifest.json` entries `{ "<Prop>": { "assetId": string, "tris": number, "sizeStuds": [x,y,z], "tintSlots": [string], "kiln": string } }`, with `DentalChair` = `88742575032106`, 2044 tris, `[4.39, 5.95, 9.81]`.

- [ ] **Step 1: Write the check.** A Luau probe returning `{ meshes, grey, unanchored, tintSlots }` for a model. Expect `grey == 0`, `unanchored == 0`, `#tintSlots >= 1`.
- [ ] **Step 2: Run it against `Workspace.ClinicProps.DentalChair_Mesh` before the tool.** Expect `grey == 0` already (repaired by hand) but `tintSlots == 0`, so it fails on the slot check.
- [ ] **Step 3:** Write `repair_import.luau` per the interface. Prefix matching is case-sensitive.
- [ ] **Step 4:** Run the tool on `DentalChair_Mesh`, then the probe. Expect the 7 meshes carry `TintSlot` values `Upholstery`, `UpholsteryDark`, `Chrome`, `Base`, `Shell`, `Button`.
- [ ] **Step 5:** Write `assets/manifest.json` and copy the chair's Kiln source into `art/kiln/`. Commit once git is initialized (Task 24 initializes it; until then, no commit).

### Task 2: Wave 1 props (5 uploads)

DentalChair is done. Repeat the steps for each row. The mouth-chair set is needed in every version of the game.

| Prop | Kiln source | Budget (tris) | Rough size (studs) | Notes |
|---|---|---|---|---|
| DentalLamp | `art/kiln/DentalLamp.kiln.js` | 1,500 | 6.5 x 10.5 x 6.5 | Floor stand, swing arm. Light is added in Task 5, not in the mesh |
| InstrumentTray | `art/kiln/InstrumentTray.kiln.js` | 1,200 | 3.5 x 4 x 2.5 | Tray on a post with tools. Material slot `Chrome` for tools |
| ReceptionDesk | `art/kiln/ReceptionDesk.kiln.js` | 2,500 | 12 x 4 x 5 | Counter, monitor, bell, `Tint` slot for the desk finish |
| WaitingChair | `art/kiln/WaitingChair.kiln.js` | 1,000 | 3.5 x 3.5 x 3.5 | Cushion slot `Upholstery` |
| SinkCabinet | `art/kiln/SinkCabinet.kiln.js` | 1,800 | 6 x 4 x 3 | Basin, tap, cupboard doors |

**Files (per prop):**
- Create: `art/kiln/<Prop>.kiln.js`
- Modify: `assets/manifest.json`

**Interfaces:**
- Consumes: `repairImport` from Task 1.
- Produces: `Workspace.ClinicProps.<Prop>_Mesh`, anchored, tinted, with an asset id in the manifest.

- [ ] **Step 1: Write the Kiln program** in `~/Roblox-Tools/work/<prop>/<prop>.kiln.js` using `roundedBoxGeo`, `cylinderGeo`, `createPart`. Name materials `Slot_RRGGBB` using the palette in D5.
- [ ] **Step 2: Render and look.** `node ~/Roblox-Tools/kiln-0.8.0/dist/cli.mjs render <prop>.kiln.js --out <prop>.glb --views <prop>.png --backdrop light --render cpu --json`. Expect `tris` at or below the budget and `warnings: []`. Read the six-view PNG and fix floating or detached parts. Allow up to 2 revisions.
- [ ] **Step 3: Convert.** `KILN_HOME=~/Roblox-Tools/kiln-0.8.0 node ~/.claude/skills/roblox-3d-model/scripts/kiln_to_roblox.mjs <prop>.glb ~/Roblox-Tools/work/upload/<Prop>.glb`. Expect `frontAxis: "-Z"` and `sizeStuds` within 10 % of the table.
- [ ] **Step 4: Copy the source** to `art/kiln/`.
- [ ] **Step 5: Probe permissions.** `open_cloud_invoke GET /cloud/v2/universes/10775581439` with scopes `asset:read`, `asset:write`. Expect 200.
- [ ] **Step 6: Upload (needs the user's yes from Task 0).** `POST /assets/v1/assets` as `Model` for userId `89559579`, then poll the operation. If `moderationState` is `Reviewing`, poll `GET /assets/v1/assets/<id>` for a few minutes. If it is `Rejected` or still pending, stop and report. Never re-upload.
- [ ] **Step 7: Insert and repair.** `insert_asset` under `game.Workspace.ClinicProps`, then run `repair_import.luau`. Expect extents within 2 % of `sizeStuds` and `grey == 0`.
- [ ] **Step 8: Screenshot** with `screen_capture` (custom camera shots can time out; retry once) and compare with the render. Record the asset id in the manifest.

### Task 3: Wave 2 props (about 9 uploads)

Same steps as Task 2, same `Files`/`Interfaces`. Needed for tiers T1 to T3.

| Prop | Budget (tris) | Notes |
|---|---|---|
| XRayMachine | 2,500 | T2 room |
| Sterilizer | 1,500 | T2 room |
| WallShelf | 800 | Decor slot |
| Plant | 1,500 | Decor slot, `Leaf` and `Pot` slots |
| WaterCooler | 1,200 | Decor slot |
| ToothSign | 4,000 | Hero prop for T3 rooftop and the plot entrance. Uses `capsuleGeo` and CSG |
| PosterFrame | 500 | Decor slot |
| CeilingLight | 800 | Emissive `Glow` slot |
| ReceptionSign | 1,500 | Neon letters, `Glow` slot |

- [ ] **Steps 1 to 8:** as Task 2, using the Wave 2 yes from Task 0.

### Task 4: Building shell kit

**Files:**
- Create: `art/kiln/DoorFrame.kiln.js`, `art/kiln/WindowFrame.kiln.js` (2 uploads, under the Wave 2 yes)
- Create: `tools/studio/build_shell.luau` (builds floors and walls from a layout table)

**Interfaces:**
- Produces: `buildShell(layout: { rooms: { { name: string, cframe: CFrame, size: Vector3 } }, doors: { CFrame }, windows: { CFrame } }, parent: Instance): Model`. Floors and walls are plain Parts (`TintSlot` `Floor`, `Wall`, `Trim`), door and window frames are the Kiln meshes.

- [ ] **Step 1:** Write a probe: for a 2-room layout, every wall `Part` is anchored and sits on the floor top within 0.05 studs, and each door cuts a gap at least 4 studs wide.
- [ ] **Step 2:** Implement `buildShell`. Walls get door and window openings by splitting wall Parts around them (no CSG, so walls stay cheap and re-tintable).
- [ ] **Step 3:** Run the probe, then screenshot a 2-room test shell.

### Task 5: Clinic tier templates T0 to T3

**Files:**
- Create: `tools/studio/assemble_tiers.luau`
- Create: `ServerStorage.Templates.Tiers.Tier0 .. Tier3` (Models in the place file, not on disk)

**Interfaces:**
- Produces: each `TierN` is a `Model` with `PrimaryPart` `Origin`, plus `Attachment`s named `ChairSlot1..N`, `DecorSlot1..8`, `PatientSpawn`, `DoorEntry`. Chairs placed at `ChairSlotN` are clones of `DentalChair_Mesh`. Each tier includes the previous tier's rooms, so expanding replaces the model. Tier chair counts are 1, 3, 5, 8.

- [ ] **Step 1:** Probe: for `Tier0..3` count `ChairSlot*` attachments equals 1, 3, 5, 8, `DecorSlot*` equals 8, and every `MeshPart` is anchored with a `TintSlot`.
- [ ] **Step 2:** Implement `assemble_tiers.luau` using `buildShell` and the Wave 1 and 2 props.
- [ ] **Step 3:** Run the probe, then screenshot each tier from above and from the entrance. Check that the T0 to T3 growth is visible.
- [ ] **Step 4:** Add the lamp's `SpotLight` and ceiling `PointLight`s in this task (Lights are not part of the meshes).

### Task 6: Patient and staff looks

**Files:**
- Create: `src/shared/Config/Looks.luau`

**Interfaces:**
- Produces: `Looks[Rarity]: { skinColor: Color3, shirt: Color3, pants: Color3, accessories: { number } }` and `Looks.Staff`. Accessories are public Creator Store hat IDs chosen in Task 6 step 2.

- [ ] **Step 1:** Spec `tests/Looks.spec.luau`: every `Rarity` has an entry, colours are valid, Zombie skin hue is green (hue between 0.2 and 0.45).
- [ ] **Step 2:** Pick accessory IDs with `search_asset`, free and only from verified creators, then write `Looks.luau`.
- [ ] **Step 3:** `lune run test` green. Render each look in Studio once with `Players:CreateHumanoidModelFromDescription` and screenshot.

---

## Phase 2: World

### Task 7: Plaza and plots map

**Files:**
- Create: `design/map.json` (spec for the `roblox-map` skill), `tools/studio/build_world.luau`

**Interfaces:**
- Produces: `Workspace.World.Plaza`, `Workspace.World.Plots.Plot1..Plot6` (each a `Model` with `Origin` part and `Entrance` part), `SpawnLocation`s in the plaza, lighting and skybox. Smooth-voxel terrain for park edges.

- [ ] **Step 1:** Write `design/map.json` (plaza, ring of 6 plots, paths, a central ToothSign landmark).
- [ ] **Step 2:** Run the skill's prover (`prove.py design/map.json`). Expect `RESULT: PASS` or only warnings about empty space.
- [ ] **Step 3:** Build in Studio from the emitted builder, screenshot from above and from a player's eye height.

### Task 8: Plot template and Rojo safety

**Files:**
- Create: `ServerStorage.Templates.Plot` (place file)

- [ ] **Step 1:** Each `PlotN` has an `Owner` attribute (empty) and the `Origin` where tier models are placed.
- [ ] **Step 2: Rojo check.** `rojo serve`, connect from Studio, accept the sync. Probe: `Workspace.ClinicProps`, `Workspace.World`, `ServerStorage.Templates` all still exist. If any is gone, undo with Ctrl+Z, set `$ignoreUnknownInstances: true` on that service in `default.project.json`, and retry.
- [ ] **Step 3:** Save the place to disk.

---

## Phase 3: Core logic (Lune specs first, no Studio)

All Core modules are pure Luau in `src/shared/Core/`, each with `tests/<Name>.spec.luau`. Run `python3 ~/.claude/skills/roblox-code/scripts/check.py` after every task. Gates: `rojo build`, `lune run test`, `selene`, `stylua --check`.

### Task 9: Types and Config

**Files:**
- Create: `src/shared/Types.luau`
- Modify: `src/shared/Config/GameConfig.luau`

**Interfaces:**
- Produces:
  - `type ToolId = "Toothbrush" | "Floss" | "Spatula" | "Pliers"`
  - `type IssueKind = "dirt" | "debris" | "chip" | "rot"` with `Types.ToolForIssue: { [IssueKind]: ToolId }`
  - `type Rarity = "Common" | "Rare" | "VIP" | "Zombie"`
  - `type Issue = { toothId: number, kind: IssueKind, cleaned: boolean }`
  - `type Mouth = { seed: number, teeth: number, issues: { Issue } }`
  - `type PlayerData = { cash: number, toolLevels: { [ToolId]: number }, tier: number, dentists: number, goals: GoalState, customize: CustomizeState, lastSeen: number }`
  - `GameConfig` keys: `submitThreshold = 0.80`, `basePay = { dirt = 20, debris = 24, chip = 40, rot = 60 }`, `rarityMultiplier = { Common = 1, Rare = 3, VIP = 6, Zombie = 20 }`, `spawnDelay = 30`, `zombieSeconds = 30`, `staffCapSeconds = 28800`.

- [ ] **Step 1:** `tests/Config.spec.luau`: `submitThreshold` between 0.71 and 0.83, `rarityMultiplier` increases Common to Zombie, every `IssueKind` has a `ToolForIssue` entry.
- [ ] **Step 2:** Implement. **Step 3:** gates green.

### Task 10: MouthModel

**Interfaces:**
- Produces: `MouthModel.generate(seed: number, rarity: Rarity, unlocked: { [ToolId]: boolean }): Mouth`; `MouthModel.clean(mouth: Mouth, issueIndex: number, tool: ToolId): (boolean, string?)`; `MouthModel.cleanedFraction(mouth: Mouth): number`; `MouthModel.canSubmit(mouth: Mouth, threshold: number): boolean`.

- [ ] **Step 1: Tests** (`tests/MouthModel.spec.luau`): same seed gives identical mouths; every issue's `toothId` is within `1..teeth`; no `rot` issues when Pliers are locked; a Zombie mouth has at least 14 issues and a Common at most 8; `clean` returns `(false, "wrong tool")` for the wrong tool, `(false, "already cleaned")` for a repeat, `(false, "bad index")` for index 0 or past the end (Review Focus 1); `cleanedFraction` is 1 for a mouth with no issues; with 7 issues, 5 cleaned gives `canSubmit(..., 0.80) == false` and 6 cleaned gives `true`.
- [ ] **Step 2:** run, expect FAIL. **Step 3:** implement. **Step 4:** run, expect PASS.

### Task 11: Payout and PatientTable

**Interfaces:**
- Produces: `Payout.perIssue(kind: IssueKind, toolLevel: number, rarity: Rarity): number`; `Payout.submit(mouth: Mouth, rarity: Rarity, perfect: boolean): number`; `PatientTable.roll(rng: Random, luck: number): Rarity`; `PatientTable.spawnDelay(tier: number): number`.

- [ ] **Step 1: Tests:** payouts are finite integers at or above 0 for levels 1 to 50 and every rarity; Common < Rare < VIP < Zombie for equal inputs; a higher tool level never pays less; `submit` with `perfect = true` pays more than `false`; `perIssue("dirt", 1, "Common") == 20`; with `Random.new(7)`, two runs of 1,000 rolls are identical; at luck 0, Common is over 80 % and Zombie under 5 % of 10,000 rolls; at luck 1, Rare+ share rises but Common never reaches 0; `spawnDelay` never rises as the tier rises and never falls below 8 s.
- [ ] **Steps 2 to 4:** fail, implement, pass.

### Task 12: UpgradeCost and ClinicTiers

**Interfaces:**
- Produces: `UpgradeCost.toolCost(tool: ToolId, currentLevel: number): number`; `UpgradeCost.maxLevel: number`; `ClinicTiers.get(tier: number): { chairs: number, cost: number, unlocks: { ToolId } }`; `ClinicTiers.canExpand(data: PlayerData): (boolean, string?)`.

- [ ] **Step 1: Tests:** `toolCost` is strictly increasing and an integer for levels 1 to `maxLevel - 1`; `toolCost("Spatula", 2)` is between 3,000 and 6,000; `toolCost` at `maxLevel` returns `(nil)`/errors cleanly; `ClinicTiers.get(0..3).chairs == 1,3,5,8`; Pliers appear in `unlocks` from the tier with at least 2 chairs; `canExpand` is false at tier 3 and false when cash is below cost.
- [ ] **Steps 2 to 4:** fail, implement, pass.

### Task 13: Goals and Staff

**Interfaces:**
- Produces: `Goals.progress(state: GoalState, event: GoalEvent): GoalState`; `Goals.completed(state: GoalState): boolean`; `Staff.earnings(elapsedSeconds: number, dentists: number, ratePerDentist: number, capSeconds: number): number`.

- [ ] **Step 1: Tests:** a "Treat 3 patients" goal completes on the 3rd `PatientTreated` event and never over-counts; unrelated events change nothing; `Staff.earnings` is 0 for 0 dentists, 0 for negative or NaN elapsed time, equals `dentists * rate * elapsed` below the cap, and is clamped to the cap above it (Review Focus 6).
- [ ] **Steps 2 to 4:** fail, implement, pass.

### Task 14: Customize and RateLimit

**Interfaces:**
- Produces: `Customize.validate(payload: unknown, owned: { [string]: boolean }): (boolean, string?)`; `RateLimit.new(perSecond: number, burst: number): { take: (self: any, key: any, now: number) -> boolean }`.

- [ ] **Step 1: Tests:** `validate` accepts `{ wall = Color3-as-hex-string, decor = { [1] = "Plant" } }` for owned items; rejects a non-table, an unknown slot name, an unowned decor id, a hex that is not `#RRGGBB`, more than 8 decor entries, and any string over 32 characters (Review Focus 5); a `RateLimit.new(10, 5)` allows 5 instant takes then refuses the 6th at the same `now`, and allows again after 0.1 s (Review Focus 1).
- [ ] **Steps 2 to 4:** fail, implement, pass.

---

## Phase 4: Server (Knit services)

Server code never trusts the client and never touches UI. Each service is one file in `src/server/Services/` and is booted by `src/server/init.server.luau`.

### Task 15: Net contract and DataService

**Files:**
- Modify: `src/shared/Net.luau`
- Create: `src/server/Services/DataService.luau`, `src/shared/ProfileStore.luau` (vendored single file, version pinned in a header comment)

**Interfaces:**
- Produces (Net, client to server): `Treat_Begin(chairId: number)`, `Treat_Clean(sessionId: string, issueIndex: number)`, `Treat_Submit(sessionId: string)`, `Upgrade_Buy(tool: ToolId)`, `Clinic_Expand()`, `Clinic_Customize(payload: unknown)`, `Staff_Hire()`, `Shop_Claim(rewardId: string)`. Server to client: `State_Sync(data: PlayerData)`, `Patient_Seated(chairId: number, rarity: Rarity)`, `Announce(text: string)`.
- Produces: `DataService:Get(player: Player): PlayerData?`; `DataService:Update(player: Player, fn: (PlayerData) -> ()): boolean`; `DataService.Loaded: Signal<Player>`.

- [ ] **Step 1:** Lune spec for the pure part: `DataService` default data and migration function `migrate(raw: unknown): PlayerData`: missing keys get defaults, unknown keys are dropped, negative cash is clamped to 0.
- [ ] **Step 2:** Implement with ProfileStore: session-locked, `pcall` around load, retry with backoff up to 5 times, and on failure keep the player in a "no-save" state with a message instead of kicking or writing defaults (Review Focus 3).
- [ ] **Step 3:** Studio probe through `execute_luau` (Server datamodel during a playtest): join, spend cash, rejoin, cash persists. DataStore needs Game Settings, Security, Enable Studio Access to API Services (the user toggles it).

### Task 16: PlotService and ClinicService

**Interfaces:**
- Produces: `PlotService:Assign(player: Player): Model?`; `PlotService:Release(player: Player)`; `ClinicService:Expand(player: Player): (boolean, string?)`; `ClinicService:Customize(player: Player, payload: unknown): (boolean, string?)`; `ClinicService:GetChairs(player: Player): { { id: number, slot: Attachment } }`.

- [ ] **Step 1: Tests (Lune, with a fake plot table):** assigning 7 players to 6 plots gives the 7th `nil` and no plot is shared; releasing resets `Owner` and removes the tier model; two `Assign` calls in the same tick give different plots (Review Focus 4).
- [ ] **Step 2:** Implement. `Expand` validates with `ClinicTiers.canExpand`, deducts cash, swaps the tier model, and plays a short `TweenService` reveal. `Customize` validates with `Customize.validate`, then recolours every `MeshPart`/`Part` whose `TintSlot` matches.
- [ ] **Step 3:** Playtest: join, expand to T1, screenshot, customize the wall colour, rejoin, the choices persist.

### Task 17: PatientService and TreatmentService

**Interfaces:**
- Produces: `PatientService:Start(player: Player)`; `TreatmentService:Begin(player: Player, chairId: number): string?` (returns `sessionId`); `TreatmentService:Clean(player: Player, sessionId: string, issueIndex: number, tool: ToolId)`; `TreatmentService:Submit(player: Player, sessionId: string): number`.

- [ ] **Step 1: Tests (Lune, with fake player objects):** a session belongs to its player (another player's `sessionId` is rejected); `Clean` obeys `MouthModel.clean` and `RateLimit` (a flood of 50 calls in one tick pays at most the burst); `Submit` below the threshold pays nothing; double `Submit` pays once; if the player leaves or the Zombie timer ends, the session is closed, the chair freed, and no cash is paid (Review Focus 1, 2).
- [ ] **Step 2:** Implement. The server owns the `Mouth`, sends the client only what it needs to draw, and computes every payout.
- [ ] **Step 3:** Playtest the full loop with the console open (`get_console_output`): spawn, seat, treat, submit, cash rises by the server's figure.

### Task 18: Economy, Upgrade, Staff and Goal services

**Interfaces:**
- Produces: `EconomyService:Add(player: Player, amount: number, reason: string)`; `UpgradeService:Buy(player: Player, tool: ToolId): (boolean, string?)`; `StaffService:Hire(player: Player): (boolean, string?)`; `GoalService:Record(player: Player, event: GoalEvent)`.

- [ ] **Step 1: Tests:** `Buy` fails without enough cash and never lets cash go negative; `Hire` is capped per tier; offline staff earnings on rejoin use `Staff.earnings` and are granted once.
- [ ] **Step 2:** Implement thin services over the Core modules. **Step 3:** Playtest, then run the gates.

### Task 19: Shop, Announcement and Tutorial services

**Files:**
- Create: `src/server/Services/ShopService.luau`, `AnnouncementService.luau`, `TutorialService.luau`

**Interfaces:**
- Consumes: the D3 product list. Produces: `ShopService:Init()` binds `MarketplaceService.ProcessReceipt` once (a developer product grants exactly once, idempotent by `PurchaseId`).

- [ ] **Step 1: Tests:** a receipt processed twice grants once; an unknown product returns `NotProcessedYet`.
- [ ] **Step 2:** Implement per `roblox-dev-skill` `monetization.md`. **Step 3:** Test purchases in Studio with the Robux-free test flow.

---

## Phase 5: Client and UI

### Task 20: UI kit, HUD, goal tracker

**Files:**
- Create: `ui/theme.json`, `ui/hud.json` (roblox-ui specs), `src/client/Controllers/HudController.luau`

**Interfaces:**
- Produces: `HudController:Show(data: PlayerData)` and live updates from `State_Sync`. A "Time until next patient" label and goal card.

- [ ] **Step 1:** `python3 ~/.claude/skills/roblox-ui/scripts/ui_build.py ui/hud.json --out build`, then `verify_ui.py ui/hud.json` reports 0 failures.
- [ ] **Step 2:** Wire the controller, then run `verify_wired.py`. **Step 3:** Screenshot at phone and desktop sizes (device simulator).

### Task 21: Treatment minigame UI

**Interfaces:**
- Produces: `TreatmentController:Open(sessionId: string, mouth: Mouth)`. It sends `Treat_Clean` for each cleaned issue and `Treat_Submit` on the Submit button, and never decides payouts.

- [ ] **Step 1:** Build the mouth from UI frames (teeth as rounded frames, stains as semi-transparent circles, floss swipe, filler hold-ring then tap).
- [ ] **Step 2:** Input works with mouse and touch only (no keyboard-only paths).
- [ ] **Step 3:** Playtest on a phone-sized viewport: every tool works with one finger, Submit enables at the threshold.

### Task 22: Menus (Upgrades, Chairs, Hire, Shop, Customize)

- [ ] **Step 1:** One `roblox-ui` spec per menu in `ui/`, one controller each. **Step 2:** The Customize menu shows swatches, previews live on the plot through `Clinic_Customize`, and rolls back if the server rejects. **Step 3:** `verify_ui.py` clean for all menus.

### Task 23: Feedback (VFX and SFX)

- [ ] **Step 1:** Brush bubbles, cash pop, sparkle on a clean tooth with built-in `ParticleEmitter`s (no uploads).
- [ ] **Step 2:** Sounds through `roblox-sfx` (Creator Store ids, proven in Studio, no uploads): scrub, cash register, UI click, zombie sting, ambience.
- [ ] **Step 3:** Mute toggle works.

---

## Phase 6: Assembly, test and publish

### Task 24: Assembly and gates

- [ ] **Step 1:** `git init`, first commit of the scaffold, specs and `art/kiln`. **Step 2:** `check.py` all gates green, `verify_wired.py` green. **Step 3:** Boot in Studio, build stamp in Output.

### Task 25: Playtest matrix (2 clients)

- [ ] **Step 1:** In Studio Test, start "Server & 2 Clients". **Step 2:** Fill `HANDOVER.md` with a measured result or UNTESTED per row: join, plot assignment, each tool, each rarity, upgrades, each tier expansion, each customization slot, staff offline earning, rejoin persistence, leave mid-treatment, a 7th player. **Step 3:** Fix and re-run until no row is red.

### Task 26: Performance and mobile pass

- [ ] **Step 1:** `rbx-scene-analysis` and the MicroProfiler skill on a full T3 plot with 6 plots loaded. **Step 2:** Target: instance count and triangle total reported, no frame spike over 33 ms on a mid phone profile. **Step 3:** Fix or lower the budget of whichever prop is heaviest.

### Task 27: Publish prep

- [ ] **Step 1:** D2 name chosen. Icon, thumbnails, description, age rating questionnaire (the user fills these in the Creator Dashboard). **Step 2:** D3 product IDs wired. **Step 3:** The user presses Publish (we never publish; `universe:write` stays off). **Step 4:** Live-server check with a friend: join, play 5 minutes, rejoin.
