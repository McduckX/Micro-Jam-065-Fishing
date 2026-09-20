extends Resource
class_name TargetData
## Per-creature identity, tuning, and rhythm phrase — see GameDesign.md §14
## (Catch Chains) and §22 (Design Values). Used two ways: as the spawn
## config for a live Target (or FinalCreature) instance, where every field
## below matters, and, for a cycle's starting_bait, as pure display data
## (display_name + texture) with nothing ever spawned for it — the
## movement/detection/flee/rhythm fields are simply unused in that role.
##
## Pass 9 scope: migrates target.gd's individual @export tunables into this
## resource (see target.gd) and gives GameDirector/RunState something
## data-driven to track instead of hardcoded creature-name strings. Distinct
## per-creature art stays a shared placeholder for now — real art arrives in
## Pass 15; distinct rhythm phrases (rather than sharing one of two test
## phrases) arrive in Pass 14.

@export var display_name: String = ""
@export var texture: Texture2D

@export_group("Movement")
@export var patrol_speed: float = 150.0

@export_group("Detection")
@export var detection_radius: float = 220.0
@export var hook_radius: float = 70.0
@export var hookable_timeout: float = 3.0

@export_group("Flee")
@export var flee_speed_multiplier: float = 2.5
@export var flee_away_duration: float = 0.4
@export var flee_boost_duration: float = 1.0

@export_group("Rhythm")
@export var rhythm_pattern: RhythmPattern
## 0 = fails on the first mistake (intermediate targets); 1 = allows one
## mistake before failing (final creatures) — GameDesign.md §11.
@export var max_mistakes: int = 0

@export_group("Chain Role")
## True only for a cycle's final creature (Kraken, Scylla, Umibozu,
## Leviathan) — tells GameDirector to activate() the matching FinalCreature
## already placed in the world instead of instantiating a new Target.
@export var is_final_creature: bool = false
