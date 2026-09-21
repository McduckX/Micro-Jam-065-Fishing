# Micro Jam 065 — Fishing: Initial Planning Response

## Context

`Micro-Jam-065-Fishing` is a 48-hour jam project (Godot 4.7.2, GL Compatibility, web export to itch.io) with one developer and two artists. The approved design (`GameDesign.md`) is complete and detailed, but the repository currently contains **almost no implementation** — a Godot project file, a background blueprint image, and a two-node scene.

The purpose of this document is to establish, before any gameplay code is written: what exists, what the design requires, where the schedule risk is, and a pass-by-pass order of work whose earliest passes produce a playable vertical slice. No gameplay systems are implemented yet.

Three decisions were resolved up front with the user:

- **Content volume:** implement the chains exactly as authored (6–7 targets per cycle, 25 targets total). Scope concern was raised and the user reaffirmed full fidelity. Mitigation is architectural, not a silent cut — see §5.
- **Web display:** keep `canvas_items` + `expand`. No change to `project.godot` display settings.
- **Art pipeline:** Pass 1 adds explicit binary attributes to `.gitattributes`, sets the background texture to lossy import, and excludes `assets/temp/` from the export preset.

---

## 1. Repository Assessment

**Health: clean but essentially empty.** No parse errors, no broken references, no orphaned resources. Nothing needs repair; everything needs building.

| Area | State | Finding |
|---|---|---|
| Engine | Godot 4.7.2 stable at `c:\exe\Godot_v4.7.2-stable_win64.exe\` | Matches `config/features=("4.7", "GL Compatibility")`. Consistent. |
| Renderer | `gl_compatibility` (desktop + mobile) | Correct choice for web. No change needed. |
| Viewport | 1920×1080, `canvas_items`, `expand` | Matches design §3. Confirmed keep. |
| **Main scene** | **Not set** | `application/run/main_scene` is absent — F5 will prompt for a scene. Pass 1 fixes. |
| **Input actions** | **None defined** | No `[input]` section. WASD / cast / interact / pause are all unmapped. Godot's built-in `ui_*` actions map arrows, not WASD. |
| **Autoloads** | **None** | Good starting point; the plan keeps it that way. |
| **Collision layers** | **Unnamed** | No `[layer_names]` section. |
| **Export presets** | **Missing** | No `export_presets.cfg`. |
| Export templates | `4.7.2.stable` installed, all 8 web variants | Web-only install — correct for this project. Verified after initial inspection. |
| Background texture | Imported `.ctex` is **9.2 MB**, Lossless, 3524×3106 | The single largest item in the build. See §5a. |
| Git | `main`, remote `github.com/McduckX/Micro-Jam-065-Fishing`, 6 commits, clean | No branches beyond `main`. |
| `.gitignore` | `.godot/`, `/android/` | Correct but incomplete — no build-output ignore. |
| `.gitattributes` | `* text=auto eol=lf` | Applies text normalization globally. `text=auto` does detect binaries, but with two artists committing PNG/WAV/OGG this is worth making explicit. |
| `scripts/` | Exists, **empty** | Untracked (Git cannot track empty dirs). Editor cache shows a since-deleted `test.gd`. |
| `addons/`, `resources/` | Exist, **empty** | No plugins installed. Plan adds none. |
| `3d/physics_engine="Jolt Physics"` | Set | Irrelevant to a 2D project. Harmless; leave it. |
| `rendering_device/driver.windows="d3d12"` | Set | Unused under GL Compatibility. Harmless; leave it. |

---

## 2. Existing Project Inventory

**Every file that exists today:**

- [project.godot](project.godot) — 33 lines. Name, icon, 1920×1080 viewport, canvas_items/expand, GL Compatibility.
- [scenes/WorldScene.tscn](scenes/WorldScene.tscn) — **9 lines, 2 nodes.** `WorldScene` (Node2D) → `Background` (Sprite2D at `(1762, 1553)`, the exact centre of a 3524×3106 stage, so the map spans world `(0,0)`–`(3524,3106)`). No script, no collision, no camera, no gameplay.
- [assets/temp/Map_Canvas.png](assets/temp/Map_Canvas.png) — 3524×3106, **15.5 MB, lossless** (`compress/mode=0`, no mipmaps). A hand-drawn blueprint, not final art.
- [icon.svg](icon.svg) — default Godot icon.
- [GameDesign.md](GameDesign.md) — the approved specification, 397 lines.
- [README.md](README.md), [.editorconfig](.editorconfig), [.gitattributes](.gitattributes), [.gitignore](.gitignore), [.vscode/settings.json](.vscode/settings.json).

**Scripts: zero. Scenes: one. Resources: zero. Autoloads: zero. Input actions: zero.**

Empty folder skeleton already present (a good structure to build into): `assets/{audio,characters,environment,temp,ui,vfx}`, `scenes/{fish,levels,player,ui,world}`, `scripts/`, `resources/`, `addons/`.

**What the blueprint confirms** (read directly from the image): four irregular wedge regions in an X arrangement — green top, cream left, blue bottom, pink right — a whirlpool sketched near stage centre (~world `(1700, 1400)`), a red 1920×1080 rectangle showing viewport scale against the stage, and sketched landmasses/islands throughout. **Regions are not axis-aligned quarters.** Region membership must be authored per-object in the editor, not computed from coordinates.

---

## 3. Design Summary

The player pilots a boat on a 3524×3106 ocean. A whirlpool monster at centre demands a creature. Getting it requires a fixed chain of catches where **every catch becomes the bait for the next target** — the theme interpretation. Four cycles; each unlocks a region; finishing all four wins.

**Per-catch loop:** locate target via HUD compass → sail to it → cast bait within range onto valid water → target leaves its path and approaches → click to hook → 4-column WASD rhythm phrase → success catches it and it becomes the new bait.

**Load-bearing mechanics:**
- Arcade boat movement (W accelerate, S brake-then-reverse, A/D rotate, rotates while stationary, slides on collision).
- The rod is a magic flute; a loop's **volume responds to propulsion input, not velocity**.
- The whirlpool pulls inward *and* orbits, strengthens toward centre, grows as the cycle timer drains, and kills at the core — **unless** carrying the correct creature, which converts the core into a successful delivery.
- Boat steering is **disabled** while a line is out and during rhythm, but momentum, current, and hazards keep acting. Pausing is disabled during rhythm.
- Rhythm: tap (circle) + hold (pill) notes, no chords, forgiving windows, Success/Mistake only, no score. Intermediates fail on 1 mistake; finals allow 1 and fail on 2. Result resolves at sequence end, not on the mistake. Same authored sequence on retry.
- Each intermediate teaches one phrase; the final target plays A+B+C+D+E combined.
- Exactly one bait, no inventory. Failure keeps the bait.
- Targets follow **authored paths** that never cross region boundaries; the only randomisation is which eligible path is chosen.

**Explicitly deferred by the design itself** (§23): rhythm judgment rules, sequence durations, tempo/phrase structure, path implementation, hazards, camera smoothing/shake, animation, tutorial, full HUD layout, audio list, title/menu, land-target presentation, victory presentation, accessibility.

---

## 4. Assumptions and Constraints

Flagged as assumptions, not facts. Each is cheap to correct.

**A1.** Stage bounds are world `(0,0)`–`(3524,3106)`, inferred from the `Background` sprite position being exactly half the stated stage size. Camera limits derive from this.
**A2.** Whirlpool centre is roughly world `(1700, 1400)` (read off the blueprint), not exact stage centre. Final position comes from an editor-placed node, so the number never gets hardcoded.
**A3.** Region shapes are irregular wedges. Region membership is authored by placing nodes under a region's subtree — never computed from position.
**A4.** "Valid water" = anywhere not overlapping the land collision layer. There is no separate water volume.
**A5.** Land-based targets (Bear, Cars, Parking Meter, Priest…) use the same `Target` scene on land-category paths; the hook still lands on water near them. Their visual presentation is a deferred design question (§23) assigned to Pass 15.
**A6.** "Boat moves too far from casting position" is measured from the **boat's position at the moment of the cast**, per design §8.
**A7.** The blueprint PNG is a reference, not shippable art. It is excluded from the export preset.
**A8.** Placeholder art (coloured polygons, `ColorRect`, simple shapes) is acceptable through Pass 14; no gameplay pass blocks on art delivery.
**A9.** Rhythm timing runs on an engine-time accumulator initially, not an audio-clock sync. Audio-locked timing is a Pass 16 decision — browser audio latency makes it genuinely risky.
**A10.** I will verify every API name and signature against the 4.7.2 editor at the start of each pass rather than asserting them here. Godot 4.7 is newer than my reliable knowledge; two properties I specifically intend to check are `Camera2D.ignore_rotation` and the exact `PhysicsPointQueryParameters2D` usage (the plan below uses designs that avoid depending on either, as a hedge).

**Hard constraints:** 48 hours, one developer, two artists, web export, `main` stays playable, binary assets cannot be merged.

---

## 5. Risks and Scope Concerns

**Risk 1 — Export templates. RESOLVED.**
`%APPDATA%\Godot\export_templates\4.7.2.stable\` now contains all 8 web variants (`web_release`, `web_nothreads_release`, `web_dlink_*`, plus debug). Web-only install, which is exactly what this project needs. *Remaining action:* still produce a throwaway web build at the Pass 2 checkpoint to confirm the export path end-to-end — an installed template is not the same as a working export.

**Risk 2 — Content volume. Acknowledged and accepted by the user.**
Full chains = 25 target sprites + 25 rhythm phrases + 25 path authorings + 4 combined final sequences (the Cycle 4 final is a 6-phrase concatenation). This is the dominant schedule risk and I will not re-litigate it. *Architectural mitigation:* the chain is an **ordered array inside a `CycleData` resource**. Shortening a chain late is deleting array entries in the inspector — no code change, no scene change, no regression risk. The decision to trim can therefore be deferred to hour 40 and made from real data, and I will surface a recommendation at Pass 14 if phrase authoring is falling behind.

**Risk 3 — Web build size. Measured baseline: the background alone is 9.2 MB in the `.pck` and ~42 MiB of VRAM.** See §5a below for the full treatment and the recommended texture budget.

**Risk 4 — WASD serves two masters.** The same physical keys drive steering and rhythm lanes. If a state transition ever leaves both consumers live, W both accelerates the boat and hits a note. *Mitigation:* a single `ControlMode` enum owned by exactly one node (`GameDirector`); `Boat` and `RhythmUI` are read-only consumers that gate on it. Separate input action names per context (`move_forward` vs `rhythm_up`) so the two intents are never ambiguous. This gets an explicit adversarial test in Pass 6.

**Risk 5 — Shared-file merge conflicts.** `WorldScene.tscn` will be edited by the developer (collision, paths, gates) and the artists (sprite placement) simultaneously. `.tscn` merges badly; Godot 4.7 scene files carry `unique_id` attributes that make conflicts messier. *Mitigation:* artists work in `assets/` and in **separate instanced scenes**, never in the shared world scene; coordinate verbally before touching it.

**Risk 6 — Rhythm feel is unknowable until played.** Note speed, window sizes, and phrase length cannot be designed on paper. *Mitigation:* Pass 6 ships one hardcoded phrase early specifically to get it into hands; every value is `@export`.

**Risk 7 — Browser audio gating.** Browsers block audio until a user gesture. *Mitigation:* the title screen requires a click, which satisfies the gesture before gameplay audio starts.

---

## 5a. Texture Budget and the World-Scale Question

The proposal was: halve the project scale *and* halve the background, then scale back up to 1920×1080. **The two halves of that have opposite answers.** Halving the background image is the single biggest win available. Halving the world/viewport coordinate scale buys nothing and costs jam hours.

### Why they are independent

Under `canvas_items` stretch mode, Godot scales the **canvas transform**, not a low-resolution framebuffer. The game always rasterises at the browser canvas's real pixel size. So the base viewport number is a *coordinate convention*, not a rendering resolution:

- Setting `viewport_width=960` does **not** render at 960px and upscale. It renders at the real canvas size and redefines what "one unit" means.
- It therefore changes **zero** bytes of download and **zero** bytes of VRAM.
- (This is the opposite of `viewport` stretch mode, which *does* render low and upscale the framebuffer — but that produces a chunky pixel-art look, wrong for this art direction. Do not switch.)

What actually determines cost is only: **source image pixel dimensions × import compression mode.** You capture 100% of the benefit by shrinking the *image* and setting `Sprite2D.scale = Vector2(2, 2)`, while leaving the world at 3524×3106.

Meanwhile, renumbering the world has real costs: `GameDesign.md` specifies 3524×3106 and 1920×1080 throughout; the blueprint's red reference rectangle is drawn at that exact ratio; and every tuning value in design §22 (casting range, radii, speeds, drift distance) would need re-deriving. That is hours spent to move numbers around for no measurable gain.

**Recommendation: keep the world at 3524×3106 and the viewport at 1920×1080. Change the textures, not the coordinate system.**

### Measured baseline and projections

| | Pixels | `.pck` size | VRAM (RGBA8) |
|---|---|---|---|
| **Original** — 3524×3106, Lossless | 10.9 M | **9.2 MB** (measured) | **~42 MiB** |
| **Same size, Lossy** (Pass 1 result) | 10.9 M | **0.44 MB** (measured) | ~42 MiB |
| ½ res (1762×1553) + Lossy | 2.7 M | ~0.15 MB *(est., scales with pixel count)* | **~10.4 MiB** |

Lossy import alone took the current (still-a-blueprint) background from 9.2 MB to **440 KB** — a ~21× reduction — measured via a headless reimport (`godot --headless --import`) in Pass 1. Resolution is unchanged, so **VRAM is still ~42 MiB**; only the download shrank. The ½-res VRAM figure remains an estimate to confirm in Pass 15 once final art exists.

Two separate levers, and **compression is the bigger one for download size while resolution is the only one for VRAM.** Use both.

### The visual cost of ½ res

At 2× upscale, a 1920-wide view of the world shows 960 texture pixels stretched across 1920 screen pixels. For a soft, hand-painted watercolour ocean this is genuinely hard to notice — organic gradients upscale gracefully. It would be very noticeable on hard-edged sprites or text.

Which points at the actual best practice: **budget resolution per asset class, not globally.** The eye tracks the boat and the target; the background is peripheral and always in motion.

| Asset class | Resolution | Import mode | Rationale |
|---|---|---|---|
| Background / large environment | **½ world size**, `scale = 2` | **Lossy** | Peripheral, soft, in motion. Dominates budget. |
| Boat, targets, creatures | **1:1** | Lossless | The eye tracks these. Keep crisp. |
| UI, HUD, any text-bearing art | **1:1** | Lossless | Upscaling artefacts are most visible here. |
| VFX / particles | ½ acceptable | Lossy | Transient and usually alpha-blended. |

### Import-setting guidance

- **Lossy (WebP)** is the right default for the background. Big download reduction, decodes to RGBA8, no block artefacts.
- **Avoid VRAM Compressed** for this project despite the tempting 4–8× VRAM saving: under GL Compatibility / WebGL2 the supported formats vary by device, the export can end up shipping multiple format variants, and block compression produces visible banding on exactly the kind of smooth gradients a watercolour ocean is made of. Not worth the risk in a jam.
- **Keep mipmaps off** (they already are) unless the camera ever zooms out — they add ~33% VRAM for no benefit at 1:1.
- **Do not re-save the artists' source PNGs.** Resolution reduction is a delivery-spec change for the artists plus an import setting, never an edit to their files.

### What to tell the artists, today

> Deliver the final ocean background at **1762×1553** (half the stage). Deliver boat, creatures, and UI at **1:1** against the 1920×1080 viewport.

This is the one item here that is time-sensitive, because it changes what they are producing right now.

### Budget target

The Godot 4.7 web release template is ~10.3 MB compressed, which is the floor before any game content. Aim for a **total page payload under ~25 MB**, and treat 40 MB as the hard ceiling — itch.io web games that take a minute to load get closed before they start. With the background handled as above, the project should land comfortably inside that.

*Pass 19 note:* both `web_release` and `web_nothreads_release` templates are installed. The no-threads build is the safer default; thread support needs SharedArrayBuffer, which requires specific COOP/COEP headers and an itch.io upload setting. Verify itch's current behaviour at Pass 19 rather than assuming it.

---

## 6. Proposed Scene and Folder Structure

Builds into the existing empty folders. `scenes/WorldScene.tscn` is **kept in place under its current name and UID** — extended, never renamed — so no reference or UID churn.

```
scenes/
  Main.tscn                  Root. Hosts exactly one screen at a time.
  Game.tscn                  The gameplay screen.
  WorldScene.tscn            EXISTING — extended in place with the world skeleton.
  player/
    Boat.tscn                CharacterBody2D + sprite + collision
    FishingLine.tscn         Line2D + bait/hook Area2D + cast state
  world/
    Whirlpool.tscn           Current field, lethal core, feed zone
    RegionGate.tscn          Cover visual + blocking walls (x4 instances)
    Hazard.tscn              Deferred to Pass 17
  fish/
    Target.tscn              ONE generic scene, driven by TargetData
  ui/
    HUD.tscn                 Timer, bait readout, compass, request bubble
    RhythmUI.tscn            4 lanes, falling notes, hit area
    TitleScreen.tscn  InstructionsScreen.tscn
    PauseMenu.tscn  GameOverScreen.tscn  VictoryScreen.tscn
  levels/                    (left empty — one stage only)

scripts/                     Mirrors scenes/ exactly
  main.gd
  game/  game_director.gd  run_state.gd  control_mode.gd
  player/  boat.gd  fishing_line.gd
  world/  whirlpool.gd  region_gate.gd  path_registry.gd
  fish/  target.gd
  ui/  hud.gd  rhythm_ui.gd  compass.gd  (one per screen)
  data/  cycle_data.gd  target_data.gd  rhythm_pattern.gd   (class_name Resources)

resources/
  cycles/    cycle_1.tres … cycle_4.tres
  targets/   salmon.tres  bear.tres  …  (25)
  rhythm/    c1_pattern_a.tres  …  c1_final.tres  …

assets/                      ARTIST TERRITORY — no scripts, no gameplay scenes
  characters/ environment/ ui/ vfx/ audio/
  temp/                      Blueprint only. Excluded from export.
```

**World scene skeleton** (added inside the existing `WorldScene.tscn`):

```
WorldScene (Node2D)
├── Background (Sprite2D)          ← ALREADY EXISTS, untouched
├── Land (StaticBody2D)            ← CollisionPolygon2D children, layer "land"
├── Regions (Node2D)
│   ├── RegionTop / RegionLeft / RegionBottom / RegionRight  (RegionGate.tscn)
│   │   ├── Cover (Sprite2D)       ← fades on unlock
│   │   ├── Walls (StaticBody2D)   ← disabled on unlock
│   │   └── Paths (Node2D)         ← Path2D children, grouped "water"/"land"
├── Whirlpool (Whirlpool.tscn)
├── SpawnMarker (Marker2D)         ← authoritative start & respawn position
└── Hazards (Node2D)               ← empty until Pass 17
```

---

## 7. Proposed Minimal Architecture

**Zero autoloads.** Run state lives on a `GameDirector` node inside `Game.tscn`. This is deliberate: "Try Again" must produce a *completely new run* (design §19), and reloading the scene achieves that for free, whereas an autoload would require hand-written reset code for every field — the exact kind of code that ships with one field forgotten. At most one autoload (`Audio`) may be added in Pass 16, and only if cross-screen music continuity demands it.

**Ownership, stated once:**

| Node | Owns |
|---|---|
| `Main` | Which screen is on-screen. Nothing else. |
| `GameDirector` | Cycle index, chain position, current bait, timer, region unlock state, **`ControlMode`**. The single writer of control mode. |
| `Boat` | Physics, momentum, steering. Reads `ControlMode`. Never writes it. |
| `FishingLine` | Cast → fly → submerge → hook-ready → reel. Emits `hook_ready` / `line_recalled`. |
| `Target` | Path patrol, bait detection, approach, flee. Emits `hooked` / `escaped`. |
| `Whirlpool` | `get_current_force(pos)`, radius growth, lethal/feed radius checks. |
| `RhythmUI` | Note spawning, input judging, mistake tally. Emits `sequence_finished(success)`. |
| `HUD` | Display only. Reads; never mutates game state. |

**Deliberate simplifications:**

- **Whirlpool uses maths, not Areas.** `get_current_force(pos)` returns inward + tangential force from distance; lethal and feed checks are distance comparisons in the same physics step. No `Area2D`, no signal ordering, no layer bugs. The boat holds an exported reference — no scene-tree searching per frame.
- **Camera2D is a sibling of the boat, not a child.** Its script copies the boat's position in `_physics_process`. The boat rotates and the camera must not (design §4), and a sibling sidesteps the child-rotation problem entirely rather than depending on a property name I have not verified in 4.7.2 (A10). `limit_left/top/right/bottom` from A1 deliver "camera stops, boat keeps moving in view" with zero custom code.
- **Targets sample curves; they do not reparent.** `Target` stores a `Curve2D` + offset and moves itself via `curve.sample_baked(offset)`. Leaving the path to chase bait is just switching a state enum — no `PathFollow2D` reparenting.
- **One `Target.tscn` for all 25 targets**, configured by a `TargetData` resource. This is where custom Resources earn their place: artists and designers add a target by creating a `.tres`, with no new scene and no new script.
- **Three Resource types only.** `TargetData` (sprite, speeds, detection/hook radii, path category, rhythm pattern), `RhythmPattern` (note list), `CycleData` (requested creature, starting bait, ordered chain, timer, final pattern). Nothing else becomes a Resource unless a pass proves the need.
- **Signals for events, direct references for per-frame reads.** `hooked`, `sequence_finished`, `timer_expired` are signals. Boat→Whirlpool and Camera→Boat are exported references. No `get_node("/root/...")` in hot paths.

**Collision layers** (named in Pass 1): `1 boat · 2 land · 3 region_gate · 4 (reserved) · 5 target · 6 tackle · 7 hazard`.
Boat body layer 1, mask 2|3|7. Land layer 2. Gate walls layer 3. Target layer 5, mask 6. Tackle layer 6, mask 5.

**Input actions** (Pass 1): `move_forward`(W) `move_back`(S) `turn_left`(A) `turn_right`(D) · `rhythm_up`(W) `rhythm_left`(A) `rhythm_down`(S) `rhythm_right`(D) · `cast`(LMB) · `interact`(E) · `pause`(Esc). Steering and rhythm get **distinct action names on the same keys** so the gating in Risk 4 is visible in code rather than implied.

---

## 8. Multi-Pass Implementation Plan

Passes 1–8 build the vertical slice. Each is independently testable and ends at a commit.

> **Deviations from the suggested stage order, with reasons.**
> (a) The **HUD compass moves forward into Pass 5** (with the first target) rather than waiting for the HUD pass. On a 3524×3106 map with a 1920×1080 viewport you can see ~1/5 of the world; without the compass, the target pass is untestable.
> (b) **Rhythm system (Pass 7) is split from rhythm content authoring (Pass 14).** The system needs one phrase to exist; authoring 25 phrases is bulk content work that belongs with the other content passes.
> (c) **Region locking (Pass 11) precedes full four-cycle progression (Pass 12)**, since unlock is a prerequisite of cycle transition, not a parallel feature.
> (d) Repository validation and minimal scaffolding are **merged into Pass 1** — the repo is small enough that separating them would produce a pass with no deliverable.

### VERTICAL SLICE

---

**Pass 1 — Project validation and scaffolding**
*Objective:* make the project runnable, configured, and safe for three people to commit to.
*Player-facing:* F5 launches to a black screen without prompting for a scene.
*Includes:* main scene setting, input map, collision layer names, `.gitattributes`/`.gitignore`, `Main.tscn`/`Game.tscn` shells, world skeleton nodes, background lossy import, **`.pck` size baseline measurement**.
*Excludes:* all gameplay, all art, all UI content.
*Creates:* `scenes/Main.tscn`, `scenes/Game.tscn`, `scripts/main.gd`, `scripts/game/game_director.gd`, `scripts/game/control_mode.gd`.
*Modifies:* `project.godot`, `scenes/WorldScene.tscn` (add skeleton nodes only; `Background` untouched), `.gitattributes`, `.gitignore`, `assets/temp/Map_Canvas.png.import`.
*Editor setup:* set main scene. (Export templates already installed — verified.)
*Tests:* project opens with zero errors; F5 runs; `InputMap` lists all 11 actions; layer names appear in the inspector; re-import the background as Lossy and record the resulting `.ctex` size against the 9.2 MB baseline. **Done — measured via headless reimport: 9.2 MB → 440 KB.**
*Failure points:* re-importing the 15 MB PNG takes a moment; confirm the Lossy quality setting does not visibly band the blueprint (it is only a reference image, so a low bar — not manually inspected yet, worth a glance in-editor).
*Checkpoint:* `chore: project scaffolding, input map, collision layers`.

---

**Placeholder Asset Workflow (standing policy, applies to every remaining pass):**

Whenever a pass needs a visual that isn't final art, the pass flags it here as a **named texture request** with its expected specs — instead of me drawing it as a procedural shape (`Polygon2D`, `ColorRect`, etc.). Scripts and scenes are then built against a `Sprite2D` with a real texture slot from the start, so nothing needs rewiring when final art replaces the placeholder. You commit the placeholder file to the stated path; at the start of implementation I re-check that path exists before building the scene, and say so if it's still missing.

Two exceptions where a placeholder texture isn't requested:
- **Pure collision/logic shapes with no on-screen presence** (e.g. the `Land` StaticBody2D's `CollisionPolygon2D`) — these stay invisible; for Pass 2's "one test shoreline," the collision polygon is simply traced over a coastline already drawn in the existing `Map_Canvas.png` blueprint, so no new asset is needed.
- **Engine-native, non-art elements** (`Camera2D`, `Line2D` for the fishing line, rhythm hit-area geometry) — these render as engine primitives by design, not as sprites.

---

**Pass 2 — Required Placeholder Assets**

| Asset | Path | Spec | Used by |
|---|---|---|---|
| **Boat sprite** | `assets/characters/boat.png` | PNG with alpha. **Facing right (+X / east) at 0° rotation** — bow points right (per the forward-convention note below). Centered pivot (Godot `Sprite2D.centered = true` default — origin at the sprite's geometric center, since rotation and collision both assume that). Suggested size **~128×64px** (roughly 2:1 length:width) as a starting point — exact size doesn't affect any code, only how large the boat reads on screen at the current world scale; resize freely. | `scenes/player/Boat.tscn` |

I'm proposing the **final intended path** (`assets/characters/boat.png`), not a `temp/` staging path — so when finished art replaces this file later, it's a straight file swap with no scene or script changes. Say if you'd rather stage it under `assets/temp/` first instead.

No other new placeholder texture is needed for Pass 2 — the land test-shoreline reuses the existing blueprint art as noted above, and the camera has no visual footprint.

---

**Pre-implementation check for Pass 2 (performed before writing code):**

- Repo re-inspected at `HEAD = 6ed9289` ("Project Scaffolding") — working tree clean, matches Pass 1's reported file list exactly.
- **Repo drift since Pass 1, outside this plan:** commit `f929f33` ("Web Export Template") added `export_presets.cfg` with a `Web` preset — `variant/thread_support=false`, which matches this plan's own §5a recommendation to default to the no-threads template. `exclude_filter=""` does **not** yet exclude `assets/temp/`; that's correctly a Pass 19 concern, not Pass 2, and is already tracked there.
- `assets/{characters,environment,ui}` are still empty — no art has landed. Pass 2 proceeds with placeholder shapes, per assumption A8.
- No blocking design decisions apply to this pass. The three implementation defaults below are jam-standard choices, not open questions — flagged here for visibility, not for a decision gate:
  - `CharacterBody2D.motion_mode` will be set to `FLOATING` (not the default `GROUNDED`), since `GROUNDED` assumes an up-direction/floor/slope model built for platformers and would fight a top-down boat with no gravity.
  - Boat forward convention: **local +X (right) is forward at `rotation = 0`**, matching `Vector2.RIGHT.rotated(rotation)`. Flagged now so the eventual boat sprite (Pass 15) is drawn facing right.
  - Boat spawns by reading `SpawnMarker.position` at `_ready()` rather than duplicating the coordinate — `SpawnMarker` stays the single source of truth per design §3.
  - Collision: boat on layer `1`, mask `2|3|7` (`land`, `region_gate`, `hazard`) per the architecture table in §7; `Land` already carries layer `2`, mask `0` from Pass 1.
- **Result: no open questions block Pass 2. Proceeding to implementation.**

---

**Pass 2 — Boat movement and bounded camera**
*Objective:* prove the core feel — this is the single most replayed interaction in the game.
*Player-facing:* drive a placeholder boat across the ocean; camera follows and stops at the map edges while the boat keeps moving on-screen.
*Includes:* `Boat.tscn` (CharacterBody2D + `move_and_slide`), acceleration/braking/reverse, rotation while stationary, coasting, camera sibling with limits, `SpawnMarker`, land collision for one test shoreline.
*Excludes:* whirlpool, casting, flute audio, full land collision for the whole map.
*Creates:* `scenes/player/Boat.tscn`, `scripts/player/boat.gd`, `scripts/world/follow_camera.gd`.
*Modifies:* `scenes/Game.tscn`, `scenes/WorldScene.tscn`.
*Tests:* W accelerates to max; release coasts then stops; S brakes before reversing; reverse max < forward max; A/D rotate while stopped; camera halts at all four limits; boat slides along collision instead of sticking.
*Failure points:* rotation-vs-velocity frame ordering producing drift; camera limits offset by the sprite's centred origin.
*Checkpoint:* `feat: boat movement and bounded camera` — **and produce a throwaway web build here to validate the export path early.**

---

**Pass 3 — Required Placeholder Assets**

| Asset | Path | Spec | Used by |
|---|---|---|---|
| **Whirlpool sprite** | `assets/environment/whirlpool.png` (or `assets/temp/` if you'd rather stage it, as with the boat) | PNG with alpha. Circular/spiral silhouette, no facing direction (rotation-agnostic — it may still spin visually via a script-driven rotation later, but the art itself doesn't need a "front"). Centered pivot. Suggested diameter **~500–700px** as a starting point, purely for on-screen readability — **the visual size is decoupled from the gameplay radii** (`lethal_radius`, `current_radius` stay exported tuning values on the Whirlpool node, adjusted independently of whatever the sprite's actual pixel size is). | `scenes/world/Whirlpool.tscn` |

No other new placeholder is needed for Pass 3 — death is a freeze + console print (no death-animation asset yet, per the pass's own exclusions), and the current itself has no visual representation beyond the whirlpool sprite (no particle/vfx asset requested here; that's Pass 17/18 polish territory).

---

**Pre-implementation check for Pass 3:**

- Repo re-inspected at `HEAD = e4feb2e` ("boat movement and bounded camera") — clean, matches Pass 2's reported files plus the friction fix, all folded into that one commit as expected.
- No drift since Pass 2 beyond what's already accounted for.
- **One architecture point worth confirming explicitly before writing code**, since Pass 2's friction fix changed how `boat.gd` derives its own state: `get_current_force(pos)` returns a **velocity contribution** (a "water flow" field, units/sec), not a force requiring integration — it's recomputed fresh from the boat's position every physics frame and added directly to `velocity` alongside the existing `forward * speed` term, rather than accumulated into a separate persisted drift variable. This matters because Pass 2's friction fix already re-derives `speed = velocity.dot(forward)` after `move_and_slide()`; a stateless field composes with that cleanly (each frame's push is independent, nothing to reconcile), whereas a persisted external-velocity vector would need an arbitrary rule for splitting post-collision velocity back into "thrust" vs "drift" components. The stateless version is simpler, requires no new state on `Boat`, and still produces a visible inward spiral over many frames purely from the position-dependent field changing as the boat moves — this was the architecture the plan's §7 already specified (`get_current_force(pos)`); this note just confirms it holds up against the newer friction code rather than silently reworking it.
- `Whirlpool` will be found via the same **group-lookup-at-`_ready()`** pattern already established for `GameDirector` (`get_tree().get_first_node_in_group("whirlpool")`), not a literal exported `NodePath`. This is a one-time lookup, not per-frame search, so it satisfies §7's "no scene-tree searching per frame" the same way the existing `game_director` lookup does — flagged since §7's wording says "exported reference," and this is functionally equivalent but implemented as the project's already-established group idiom instead, for consistency.
- **Death ownership stays clean**: `Boat` emits a `died` signal and freezes itself (a local `_is_dead` guard, short-circuiting `_physics_process`); it connects that signal to a new public method on `GameDirector` (found via the same lookup) which sets `control_mode = LOCKED` and prints the placeholder message. `Boat` still never writes `control_mode` directly — `GameDirector` remains its sole writer, per Risk 4.
- One Godot-API hedge (per A10): rather than trust my memory of `Vector2.orthogonal()`'s exact name/behavior in 4.7.2, the tangential/swirl direction is computed by hand as `Vector2(-dir.y, dir.x)` — a guaranteed-correct 90° rotation with no API-name risk.
- Tuning values, all `@export` on `Whirlpool` (a plain `Node2D`, using its own `global_position` as the centre — no separate authored-position variable, consistent with `SpawnMarker`'s editor-placement philosophy): `lethal_radius`, `current_radius` (outer edge of any influence — zero effect beyond this), `max_pull_strength`, `max_tangential_strength` (linear ramp from 0 at `current_radius` to max at `lethal_radius`). No blocking decision — sensible defaults, freely retuned in the inspector, and the plan's own Design Values list (§22) already names all of these as exportable.
- Whirlpool position: placed at the assumption-A2 estimate (~world `1700, 1400`) as an editor-adjustable node, same caveat as before — move it once real art/layout exists.
- **Result: no open questions block Pass 3. Proceeding to implementation.**

---

**Pass 3 — Whirlpool current and lethal centre**
*Player-facing:* the centre visibly pulls and orbits the boat; getting too close kills you; escaping the outer current by accelerating away is possible.
*Includes:* `Whirlpool.tscn`, `get_current_force()`, exported radii/strengths, lethal-core death, placeholder death (freeze + print).
*Excludes:* timer-driven growth, screen-edge red effect, feeding, death animation.
*Creates:* `scenes/world/Whirlpool.tscn`, `scripts/world/whirlpool.gd`.
*Modifies:* `scripts/player/boat.gd`, `scenes/WorldScene.tscn`.
*Tests:* force scales with proximity; orbit is visible; full-throttle escape works from the outer band and fails near the core; death triggers exactly at `lethal_radius`.
*Failure points:* force applied after `move_and_slide` instead of into velocity; tangential sign producing a jittery orbit.
*Checkpoint:* `feat: whirlpool current and lethal core`.

---

**Pass 4 — Required Placeholder Assets**

| Asset | Path | Spec | Used by |
|---|---|---|---|
| **Fish sprite** | `assets/temp/temp_fish.png` (matching the `temp_` staging convention you've used so far) | PNG with alpha. **Facing right (+X) at 0° rotation**, same convention as the boat and consistent going forward for every creature — heading is derived from the path's direction of travel and applied the same way as `Boat`'s rotation. Centered pivot. Any modest size reads fine; exact dimensions don't affect code. | `scenes/fish/Target.tscn` |

No other placeholder needed — the path itself is drawn as an engine-native `Path2D` curve (no art), and detection/hook indicators don't exist until Pass 6.

---

**Pre-implementation check for Pass 4:**

- Repo re-inspected at `HEAD = 09a1668` ("whirlpool current and lethal core") — clean, matches the last two reports exactly.
- `TestShoreline` has moved again since the last report (now roughly world `x:462–712, y:489–1504`) — clear of the whirlpool now, which resolves the overlap flagged in the Pass 3 report without any action needed. Noting it, not calling it a problem.
- **One likely deviation from the plan's file list, to confirm once I'm in the code:** `game_director.gd` probably does **not** need changes this pass. The plan anticipated GameDirector orchestrating target spawning, but Pass 4 explicitly hardcodes one target with no chain/spawn logic yet — `Target` can self-configure at its own `_ready()` (resolve its region via an exported `NodePath`, ask `PathRegistry` for a random eligible path, matching the `spawn_marker_path` idiom already used on `Boat`), and self-register into a group for Pass 5's compass to find later, the same discovery pattern already established for `game_director`/`whirlpool`. This mirrors the Pass 2 case where `Game.tscn` ended up not needing the touch the plan predicted — smaller diff, same result, confirmed against the actual code rather than assumed here.
- `path_registry.gd` will be a small **stateless static utility** (`class_name PathRegistry`, no `extends` needed beyond GDScript's implicit `RefCounted`, a single `static func`) rather than a Node — it has no state to own, so a node/scene for it would be an unnecessary abstraction.
- `Target.tscn`'s root will be a plain `Node2D` for this pass, **not** `Area2D` — detection/hook radii don't exist until Pass 6. I considered adding an inert `Area2D` now to dodge a root-type change later, but changing a `.tscn` root type by hand is a one-line edit either way, so there's no real rework being avoided by adding it early — plain `Node2D` matches what Pass 4 actually needs and nothing more.
- **One Godot-API item to verify at the start of implementation, not assumed now (A10):** whether `Curve2D.closed` exists in 4.7.2, which would give clean seamless looping for free. If it's not there or behaves unexpectedly, the fallback is fully sufficient and requires no API risk: modulo-wrap the sample offset (`fmod(offset, curve.get_baked_length())`) and author each test path's first and last points at (or very near) the same location, so the wrap has no visible position pop. This is the specific failure point the plan already flagged ("`sample_baked` wrapping at the loop seam").
- Heading: derived the same way as `Boat`'s convention (sprite faces +X at rotation 0) by sampling a point slightly ahead on the curve and using `(ahead - current).angle()` — kept consistent with `Vector2.RIGHT.rotated(rotation)` rather than `look_at()`, which carries its own axis convention that isn't guaranteed to match.
- Path placement: the 2–3 authored loops go in roughly world `x:1200–3300, y:100–500` — comfortably inside the blueprint's "top" band, clear of both the whirlpool's current influence (reaches to about `y:525` at its widest) and the relocated `TestShoreline`. Purely a placement convenience, freely adjustable in-editor afterward.
- **Result: no open questions block Pass 4. Proceeding to implementation.**

---

**Pass 4 — One target on one authored path**
*Player-facing:* a placeholder fish patrols a hand-drawn route in the top region.
*Includes:* `Target.tscn`, curve sampling, looping patrol, facing direction, 2–3 authored `Path2D` routes in the top region, `path_registry.gd` for eligible-path selection.
*Excludes:* bait detection, hooking, `TargetData` resources (hardcode one target), other regions.
*Creates:* `scenes/fish/Target.tscn`, `scripts/fish/target.gd`, `scripts/world/path_registry.gd`.
*Modifies:* `scenes/WorldScene.tscn`, `scripts/game/game_director.gd`.
*Tests:* target follows the curve smoothly and loops without a seam pop; a random eligible path is chosen on each run; the path stays inside its region.
*Failure points:* `sample_baked` wrapping at the loop seam; open vs closed curve behaviour.
*Checkpoint:* `feat: authored target paths and patrol`.

---

**Pass 5 — Decision Resolved**

Per §15/§23's deferred "compass appearance / distance display" question, raised with the user before implementation:
- **Rendering:** sprite-based (ring + rotating arrow textures), not a procedural `_draw()`.
- **Distance:** direction only — no numeric or visual distance cue, matching §15's own "not a full minimap" framing.

---

**Pass 5 — Required Placeholder Assets**

| Asset | Path | Spec | Used by |
|---|---|---|---|
| **Compass ring** | `assets/temp/temp_compass_ring.png` | PNG+alpha. Static backdrop — **never rotated**, so orientation doesn't matter. Include the fixed center dot representing the player baked into this same texture (design §15: "a fixed dot in the centre"), since it never moves independently of the ring. Centered pivot. Suggested ~120–160px diameter. | `scenes/ui/HUD.tscn` (`Compass/Ring`) |
| **Compass arrow** | `assets/temp/temp_compass_arrow.png` | PNG+alpha. **Points right (+X) at 0° rotation** — same convention as every other creature/vehicle sprite so far. Centered pivot. Small, e.g. ~40–60px. | `scenes/ui/HUD.tscn` (`Compass/Arrow`) |

---

**Pre-implementation check for Pass 5:**

- Repo re-inspected at `HEAD = bc3df7c` ("authored target paths and patrol") — clean, matches the last report exactly.
- **Confirmed likely deviation:** `scenes/Game.tscn` will not need modification. `Main.tscn` already has an empty `Overlay` `CanvasLayer` reserved since Pass 1 for exactly this purpose (re-read to confirm) — `HUD.tscn` gets instanced there instead, keeping HUD entirely decoupled from `Game`/`GameDirector` for now. Same pattern as the Pass 2 and Pass 4 deviations: the plan's original file-list guess predates the group-lookup idiom that makes tighter coupling unnecessary.
- **One small, justified addition to `boat.gd`:** re-read the file and confirmed `Boat` does not currently self-register into any group (unlike `Target`, `GameDirector`, `Whirlpool`). Adding `add_to_group("boat")` in its `_ready()` so `Compass` can find it via the same deferred group-lookup pattern already established everywhere else — one line, consistent with existing convention, not a new pattern.
- **Node choice for the compass graphic:** `Sprite2D` for `Ring`/`Arrow`, not `TextureRect`/`Control`, even though this is UI. Reason: `Sprite2D`'s default `centered = true` pivot rotates around the visual center for free — the same trick already proven on `Boat`/`Target`/`Whirlpool`. A `Control`-based `TextureRect` would need an explicit `pivot_offset` set to half its size to rotate around center instead of its top-left corner (`Control`'s default pivot), which is a well-known Godot footgun worth just avoiding rather than managing. `Sprite2D` nodes under a `CanvasLayer` are a normal, supported pattern for simple non-interactive HUD graphics — the bait/timer text still uses `Label` (a `Control`), since text genuinely benefits from `Control` layout conventions.
- **Scene shape:** `HUD.tscn` root `Control` (full-rect) containing `Compass` (`Node2D`, fixed screen position, e.g. top-right) with `Ring`/`Arrow` `Sprite2D` children, plus sibling `BaitLabel`/`TimerLabel` (`Label`, static placeholder text like "Bait: —" / "Timer: --:--" — no real data to bind yet, since bait and the cycle timer don't exist until Pass 8/10).
- **No stretch-mode complication:** `canvas_items` + `expand` (locked in at Pass 1) scales `CanvasLayer` contents the same way it scales the world, so placing HUD elements against the 1920×1080 reference frame behaves consistently with everything else already on screen — no special `CanvasLayer` configuration needed.
- **Arrow math needs no camera compensation:** since the camera never rotates (design §4) and both `Boat`/`Target` positions are read in world space, `arrow.rotation = (target.global_position - boat.global_position).angle()` is already correct in screen terms with no extra transform — this is also exactly what makes "does not rotate with the boat" true by construction, since `boat.rotation` is never read for this calculation at all.
- **Result: no open questions remain. Proceeding to implementation.**

---

**Pass 5 — HUD compass**
*Player-facing:* a circular indicator with a centre dot and a rotating arrow pointing at the active target.
*Includes:* `HUD.tscn`, `compass.gd`, placeholder bait readout and timer text.
*Excludes:* final HUD art, speech bubble, distance display *(deferred — design §15)*.
*Creates:* `scenes/ui/HUD.tscn`, `scripts/ui/hud.gd`, `scripts/ui/compass.gd`.
*Modifies:* `scenes/Game.tscn`.
*Tests:* arrow tracks the target while both move; stays correct at all map edges; does not rotate with the boat.
*Checkpoint:* `feat: HUD target compass`.

---

**Pass 6 — Casting, recall, attraction, hook readiness**
*Player-facing:* click to cast within range onto water; the target notices, swims over, and the hook indicator changes to signal "ready".
*Includes:* `FishingLine.tscn`, range clamp, land rejection, bait travel, `Line2D` rendering, click-to-recall, drift-distance auto-cancel, cast cooldown, steering lockout, target detection radius + approach.
*Excludes:* rhythm, catching, failure/flee.
*Creates:* `scenes/player/FishingLine.tscn`, `scripts/player/fishing_line.gd`.
*Modifies:* `scripts/player/boat.gd`, `scripts/fish/target.gd`, `scripts/game/game_director.gd`, `scenes/ui/HUD.tscn`.
*Tests:* out-of-range and on-land clicks rejected with feedback; steering disabled while cast but drift/current continue; drifting past max distance auto-recalls; cooldown blocks immediate recast; target leaves path only when the cast lands inside its detection radius.
*Failure points:* the land point-query (A10 — verify the API first); `ControlMode` not restored on recall, leaving the player unable to steer.
*Checkpoint:* `feat: casting, line recall, and bait attraction`.

---

**Pass 7 — Minimal rhythm sequence**
*Player-facing:* clicking a ready hook opens a 4-lane overlay; one short phrase falls; WASD hits notes; the sequence resolves Success or Mistake.
*Includes:* `RhythmUI.tscn`, `RhythmPattern` resource, tap + hold notes, forgiving windows, immediate hit/miss feedback, mistake tally, end-of-sequence resolution, pause disabled, world visible behind the overlay.
*Excludes:* audio sync *(Pass 16)*, authored content beyond one test phrase, score display.
*Creates:* `scenes/ui/RhythmUI.tscn`, `scripts/ui/rhythm_ui.gd`, `scripts/data/rhythm_pattern.gd`, `resources/rhythm/test_phrase.tres`.
*Modifies:* `scripts/game/game_director.gd`, `scenes/Game.tscn`.
*Tests:* **adversarial — hold W through the entire sequence and confirm the boat does not accelerate** (Risk 4); a mistake does not end the sequence early; the mistake allowance differs correctly for intermediate vs final; the world keeps simulating behind the overlay; Escape does nothing.
*Failure points:* Risk 4; hold-note release timing; frame-rate-dependent note speed.
*Decisions required at this pass:* note-data format, phrase length and tempo, window sizes, countdown presence, empty-input and early-press handling. *(Design §11 defers all of these explicitly; I will present options at the start of the pass.)*
*Checkpoint:* `feat: minimal rhythm sequence`.

---

**Pass 8 — Catch resolution, bait replacement, and slice completion**
*Player-facing:* **the full loop.** Success catches the target, it becomes your bait, the next target spawns. Failure makes it flee and return to its path with your bait intact. A short test chain ends in a temporary "SLICE COMPLETE" state.
*Includes:* catch/failure resolution, flee-then-return, bait swap, next-target spawn, 2–3-step test chain, feed interaction at the whirlpool (E prompt + auto-feed at the core with correct food), temporary completion state.
*Excludes:* real chain data, region unlock, cycle transition, real timer.
*Creates:* `scripts/game/run_state.gd`.
*Modifies:* `game_director.gd`, `target.gd`, `fishing_line.gd`, `whirlpool.gd`, `hud.gd`.
*Tests:* success → bait becomes the caught thing → next target appears; failure → flees fast, returns to path, resumes normal speed, bait unchanged; feeding with the correct creature at the core succeeds instead of killing; with the **wrong** creature the core still kills.
*Failure points:* the auto-feed/lethal-core check ordering — this must be verified in both directions.
*Checkpoint:* `feat: complete catch loop — VERTICAL SLICE`. **Tag this commit.**

---

### CONTENT AND SYSTEMS

**Pass 9 — Data-driven chains.** `TargetData` + `CycleData` resources; migrate the hardcoded test chain; author the full Cycle 1 chain (Worm → Salmon → Bear → Submarine → Pirate Ship → Blue Whale → Kraken) with placeholder art. *This is the pass where the Risk 2 lever becomes real: chain length is an inspector array from here on.*

**Pass 10 — Cycle 1 complete.** Real cycle timer, whirlpool growth as it drains, screen-edge red warning, timer-expiry death sequence (control removed, pulled to centre, eaten). *Resolved with the user: only `current_radius` grows (not `lethal_radius`); the red warning is a procedural shader vignette, not a placeholder art asset; expiry does a scripted pull-in to the whirlpool's centre and then reuses the existing placeholder death — see the `Pass 10:` comments in `game_director.gd`, `whirlpool.gd`, `boat.gd`, and `hud.gd` for the implementation detail, matching Pass 9's practice of documenting decisions inline in code rather than expanding this file further.*

**Pass 11 — Region locking and unlocking.** `RegionGate.tscn` ×4, cover visuals, blocking walls, fade-and-remove unlock, path eligibility restricted to unlocked regions. *Watch for design §7: the current can pin the player against a locked wall — verify this is survivable.*

*Resolved with the user: the cover is hand-traced against each region's wedge boundary (read off `Map_Canvas.png`) rather than a placeholder texture, and layered — animated scrolling-fog `ColorRect`s (`fog_veil.gdshader`, noise sourced from an in-editor `NoiseTexture2D`, no art asset), each clipped to shape by a `Polygon2D` ancestor's `clip_children` (Godot's stencil-based CanvasItem clipping) rather than needing per-layer hand-traced vertices of their own. `TrueBoundary` (`clip_children = CLIP_CHILDREN_AND_DRAW`) draws the flat base tint and clips `FogLayerA`; `ExpandedBoundary` (`clip_children = CLIP_CHILDREN_ONLY`, invisible itself) clips `FogLayerB` to a boundary bled outward past the true edge, so the region reads as thinning mist before the physical wall rather than a hard fog cutoff. Only the two boundary polygons need per-region tracing — reused for the fill, both clip masks, and `Walls/Boundary`'s collision. Mechanism only this pass — nothing calls `unlock()` yet; `RegionTop` starts unlocked, the other three start and stay locked until Pass 12 wires up the between-cycle transition. Traced polygons are a first-pass approximation, meant to be nudged against the blueprint in-editor afterward, same as `TestShoreline`'s precedent.*

*Caught and fixed during implementation: the first integration attempt silently lost every nested override (fog/wall polygons, reparented patrol paths) because Godot requires an explicit `[editable path="Regions/RegionX"]` directive per instance before it will persist edits made to nodes **inside** an instanced scene — without it, the overrides parse without error but are discarded on save (a known, documented Godot behavior, not a bug in this project's code). Confirmed fixed by a scene-tree verification script that loads `WorldScene.tscn` directly and asserts each region's boundary polygons and `RegionTop`'s three patrol paths are actually present (not just "no parse error," which had been passing the whole time regardless).*

**Pass 12 — Four-cycle progression.** Between-cycle sequence (food consumed, monster reacts, timer stops, whirlpool resets, teleport to spawn, brief pause, region fade, request bubble, next bait, timer starts). Cycles 2–4 chain data.

*Resolved with the user: the wanted-poster catch reveal fires on **every** catch (intermediate or a cycle's final creature), not only between cycles — it's `GameDesign.md` §18's "Catch Result" state, distinct from "Feeding Sequence." Two new `ControlMode` values (`CATCH_RESULT`, `BETWEEN_CYCLE`) were added rather than boolean flags bolted onto `LOCKED`, keeping non-interactive states explicit per Risk 4's own reasoning. The shadow/silhouette reveal is a shader (`silhouette.gdshader`, tints a texture near-black using its own alpha as the mask) rather than 22 hand-drawn shadow images, reusing each creature's existing `TargetData.texture`. All fades are delta-lerps in `_process()`, no `Tween`, matching every prior pass.*

*Caught and fixed after initial implementation, via manual playtesting — three separate bugs, each confirmed fixed with a headless integration test that drives the actual state machine rather than just checking for parse errors: (1) feeding the whirlpool froze the boat forever — `try_auto_feed()`'s re-entrancy guard returned `false` for "a feed is already in progress," which `Boat._physics_process()` read as "wrong food, die," racing the death path against the between-cycle sequence that had just legitimately started; fixed by returning `true` for that case instead. (2) a new cycle's first target never spawned — `_advance_to_next_cycle()` reset bait/timer/region-unlock but nothing ever called `TARGET_SCENE.instantiate()` for it, since Cycle 1's first target had always been a scene-authored fixture in `WorldScene.tscn` rather than something `GameDirector` spawns; fixed by extracting `_resolve_catch()`'s spawn logic into a shared `_spawn_or_activate_next()` called from both places. (3) carrying the correct food when the timer expired let a feed race the death pull-in — `can_feed` kept recomputing from the boat's live position every frame even after `_expired`, and since `feed_radius` is deliberately larger than `lethal_radius`, the scripted pull-in swept the boat through the feed zone on its way to the core; fixed by forcing `can_feed` false and refusing `_complete_feed()` outright once `_expired`. Separately, 18 new audio files (`assets/Audio/`) failed to import (`WAVE_FORMAT_EXTENSIBLE` headers, which Godot's WAV importer rejects outright even though the wrapped data was plain PCM) — fixed by rewriting each file's header to standard PCM without touching a single byte of the actual audio, verified via a byte-count check before trusting the rewrite (a first attempt silently truncated the payload to 45 bytes) and a full project reimport showing zero remaining errors.*

**Pass 13 — Game states.** Title, Instructions, Pause (disabled during rhythm), Game Over with Try Again / Main Menu, Victory. Try Again = full scene reload per §19.

**Pass 14 — Rhythm content authoring.** All phrases per cycle plus the combined finals. Bulk content; no new systems. *If phrase authoring is behind schedule at this pass, I will say so and recommend a specific chain trim — the decision stays yours.*

**Pass 15 — Art and animation integration.** Replace placeholders; background, targets, boat, whirlpool, UI. Apply the §5a per-asset-class texture budget: background at ½ res with `Sprite2D.scale = Vector2(2, 2)` and Lossy import, sprites and UI at 1:1 Lossless. Re-measure `.pck` size after integration. *No gameplay changes in this pass.*

**Pass 16 — Audio.** Flute propulsion loop with **input-driven** volume (design §6 — explicitly not velocity-driven), rhythm SFX, monster sounds, music. Decide audio-clock sync here or keep engine-time.

**Pass 17 — Environmental content.** Hazards that knock/slow/accelerate/redirect. *Per design §21, no universal effect framework — only what the chosen hazards need.*

**Pass 18 — Polish, balancing, accessibility.** Tuning pass over every exported value; camera smoothing/shake; rhythm difficulty curve; tutorial clarity.

**Pass 19 — Web export and submission.** Export preset (`assets/temp/` excluded), final `.pck` size check against the §5a budget, threads vs no-threads template decision, browser testing, itch upload, README.

---

## 9. Deferred Decisions Assigned to Their Relevant Passes

Not to be answered now — raised at the start of the owning pass, with 2–4 options and a recommendation.

| Pass | Deferred decision (design §) |
|---|---|
| 5 | Compass appearance; whether it shows distance (§15) |
| 6 | Cast-rejection feedback; hook-ready indicator visual (§8) |
| **7** | **Note data format; phrase length; tempo; window sizes; countdown; empty-input, early-press and hold-release rules (§11) — the largest deferred cluster** |
| 8 | Feed prompt presentation (§16) |
| 10 | Cycle timer duration; whirlpool growth curve; red-warning intensity (§7) |
| 11 | Region cover visual; fade duration (§3) |
| 12 | Request bubble presentation; between-cycle pause length (§17) |
| 13 | Title/menu presentation; tutorial presentation (§23) |
| 14 | Phrase difficulty progression; pauses between combined phrases (§12) |
| 15 | Animation requirements; land-target presentation (§23, A5) |
| 16 | Flute volume response curve; audio list and mixing; rhythm audio sync (§6) |
| 17 | Hazard types, locations, strengths (§21) |
| 18 | Camera smoothing and shake; accessibility settings (§23) |
| 19 | Victory presentation; credits (§20) |

---

## 10. Definition of Done for the Entire Game

The game is done when all of the following are true **in a browser**, not just in the editor:

1. Title → Instructions → gameplay → Game Over / Victory all reachable; Try Again produces a genuinely fresh run.
2. Boat accelerates, brakes, reverses, rotates while stationary, coasts, and slides on collision.
3. Camera follows, stays north-up, and stops at all four stage limits while the boat keeps moving on-screen.
4. The whirlpool pulls and orbits, strengthens inward, grows as the timer drains, and kills at the core.
5. Casting works with range limit, land rejection, line rendering, click-recall, drift auto-cancel, and cooldown.
6. Targets patrol authored paths inside their own region, notice bait, approach, and can be hooked.
7. The rhythm sequence plays tap and hold notes in four lanes with forgiving windows and Success/Mistake only; intermediates fail on 1 mistake, finals on 2.
8. Every catch becomes the next bait. Failures preserve the bait.
9. All four chains are completable; each final creature can be fed by E or by entering the core while carrying it.
10. Each cycle unlocks its region; unlocked regions stay open; targets can appear in any unlocked region.
11. Timer expiry produces the full loss sequence; the core kills without the correct food.
12. Feeding Leviathan wins.
13. Steering and rhythm input are **never** simultaneously active.
14. The flute loop responds to propulsion input.
15. The HUD shows the compass, current bait, timer, and the monster's request.
16. A web build runs in Chrome and Firefox at a playable frame rate with an acceptable load time.
17. `main` is playable and the itch page is live before the deadline.

---

## 11. Recommended First Pass

**Pass 1 — Project validation and scaffolding.**

It is the only pass with no prerequisites, it unblocks every other pass, and it contains the one item that must not wait: **installing the export templates**. It writes no gameplay logic, so it cannot introduce a gameplay regression, and it establishes the Git hygiene the artists need before they start committing binaries.

Suggested order within the pass: start the export-template download first and let it run while the rest proceeds.

---

## 12. Files That the First Pass Would Create or Modify

**Created (5):**
- `scenes/Main.tscn` — root: `SceneHost` (Node) + `Overlay` (CanvasLayer)
- `scenes/Game.tscn` — gameplay shell: instanced `WorldScene` + `GameDirector`
- `scripts/main.gd` — screen swapping only
- `scripts/game/game_director.gd` — stub; owns `ControlMode`
- `scripts/game/control_mode.gd` — `ControlMode` enum (`STEERING`, `LINE_ACTIVE`, `RHYTHM`, `LOCKED`)

**Modified (5):**
- `project.godot` — set `run/main_scene`; add `[input]` (11 actions); add `[layer_names]` (7 2D physics layers). *Display, viewport, and renderer settings unchanged — see §5a for why the coordinate scale stays at 1920×1080 / 3524×3106.*
- `scenes/WorldScene.tscn` — **additive only**: add `Land`, `Regions` (4 empty gates), `SpawnMarker`, `Hazards`. The existing `Background` node and the scene's UID are untouched.
- `.gitattributes` — explicit `binary` rules for `png jpg webp wav ogg mp3 ttf`; keep `eol=lf` for text.
- `.gitignore` — add `builds/`, `*.tmp`, `.import/`. `export_presets.cfg` stays **tracked** (the team needs shared export settings).
- `assets/temp/Map_Canvas.png.import` — `compress/mode` Lossless → Lossy; mipmaps stay off. The PNG itself is not touched (artist source).

**Not touched:** `assets/temp/Map_Canvas.png`, `icon.svg`, `GameDesign.md`, `README.md`, `.editorconfig`, `.vscode/settings.json`.

**Manual editor steps for you:**
1. Confirm `Micro Jam 065: Fishing` opens with zero errors in the Output panel.
2. Confirm F5 launches without a scene prompt.
3. **Tell the artists the delivery resolutions from §5a** — background at 1762×1553, sprites and UI at 1:1. This is the only time-sensitive item, because it changes what they are drawing right now.

**Rollback:** the repo is clean at `6b18cb7`. `git reset --hard 6b18cb7` reverts the entire pass; the only non-Git side effect is the re-import of `Map_Canvas.png`, which Godot regenerates automatically.

---

## Verification (how each pass is proven)

- **Every pass:** open the project, confirm zero errors/warnings in Output, F5, run that pass's manual checklist, commit.
- **From Pass 2 onward:** produce a web build at each checkpoint and note the `.pck` size, so both export breakage and size creep are caught continuously rather than at the deadline.
- **Vertical slice (end of Pass 8):** one unbroken session — spawn, sail, find the target via compass, cast, hook, play the phrase, catch, watch the bait change, repeat for the test chain, feed the monster, reach the completion state. Then deliberately fail a rhythm phrase and confirm the bait survives and the target returns to its path.
- **Risk 4 regression, re-run every pass after 7:** hold W through an entire rhythm sequence and confirm the boat never accelerates.
- **Final (Pass 19):** full playthrough of all four cycles in Chrome and Firefox from the itch.io page, plus one deliberate timer-expiry loss and one Try Again.

---

## Team Workflow

- Artists work only in `assets/`. They do **not** edit `.tscn`, `.tres`, `project.godot`, or scripts without asking first.
- `WorldScene.tscn` is the highest-conflict file in the project. Announce before editing it.
- `main` stays playable. Risky work goes on a short-lived branch; pull before working; push focused commits.
- Binary assets do not merge. Two people editing the same PNG means one loses their work.
