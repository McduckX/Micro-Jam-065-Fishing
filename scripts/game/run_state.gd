extends RefCounted
class_name RunState
## Cycle progress bookkeeping — current bait and position through a
## CycleData's chain of TargetData resources. A plain class, not a node:
## there's no reason for a scene here, matching the ControlMode/PathRegistry
## precedent of "plain class when there's nothing to own beyond a few
## fields."
##
## Every intermediate catch becomes bait (GameDesign.md §13) and the only
## creature that's ever "correct" to feed the monster is the last one in the
## chain — so is_chain_complete() being true IS "currently carrying the
## correct food." No separate comparison is needed anywhere, including for
## a cycle's FinalCreature: GameDirector only activate()s it once the chain
## has reached its entry, which is exactly the same fact one step earlier.
##
## Pass 9: chain/current_bait now hold TargetData instead of creature-name
## Strings — this is the real (if still Cycle-1-only) data model, not
## scaffolding to be thrown away.

var chain: Array[TargetData]
var index: int = 0
var current_bait: TargetData


func _init(starting_bait: TargetData, creature_chain: Array[TargetData]) -> void:
	current_bait = starting_bait
	chain = creature_chain


## Advances current_bait to the next chain entry — call once per successful
## catch, in chain order.
func catch_current() -> void:
	current_bait = chain[index]
	index += 1


func is_chain_complete() -> bool:
	return index >= chain.size()
