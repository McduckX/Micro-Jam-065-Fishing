extends RefCounted
class_name RunState
## Pass 8 test-chain bookkeeping — current bait and position in a hardcoded
## chain of creature names. A plain class, not a node: there's no reason for
## a scene here, matching the ControlMode/PathRegistry precedent of "plain
## class when there's nothing to own beyond a few fields."
##
## Every intermediate catch becomes bait (GameDesign.md §13) and the only
## creature that's ever "correct" to feed the monster is the last one in the
## chain — so is_chain_complete() being true IS "currently carrying the
## correct food." No separate comparison is needed anywhere.
##
## Pass 9 replaces this wholesale with real CycleData/TargetData resources;
## nothing here is meant to survive that rewrite.

var chain: Array[String]
var index: int = 0
var current_bait: String


func _init(starting_bait: String, creature_chain: Array[String]) -> void:
	current_bait = starting_bait
	chain = creature_chain


## Advances current_bait to the next chain entry — call once per successful
## catch, in chain order.
func catch_current() -> void:
	current_bait = chain[index]
	index += 1


func is_chain_complete() -> bool:
	return index >= chain.size()
