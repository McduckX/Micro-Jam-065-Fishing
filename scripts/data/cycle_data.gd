extends Resource
class_name CycleData
## One cycle's full catch chain — see GameDesign.md §14. Pass 9 scope: only
## Cycle 1 is authored; multi-cycle progression and region unlocking are
## Pass 11/12's job, so GameDirector holds a single CycleData for now
## rather than an array of four.

@export var starting_bait: TargetData
@export var chain: Array[TargetData] = []
## Inert until Pass 10 wires up the real cycle timer — kept here now since
## it's inherently a per-cycle value (the original architecture notes name
## it as one of CycleData's core fields alongside starting_bait/chain).
@export var timer_duration: float = 120.0
## Pass 12: the RegionGate (by node name, e.g. "RegionLeft") that unlocks
## once this cycle's final creature is fed to the whirlpool — data-driven
## per GameDesign.md §3's fixed Top/Left/Bottom/Right unlock order, same
## reasoning as chain being an inspector array since Pass 9. Empty for the
## last cycle: nothing left to unlock, feeding it wins instead.
@export var unlocks_region_name: StringName = ""
