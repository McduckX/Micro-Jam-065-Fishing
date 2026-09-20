class_name PathRegistry
## Stateless utility for picking a random eligible Path2D from one or more
## region root nodes — see GameDesign.md §9 ("A target randomly selects an
## eligible path from the currently unlocked regions").
##
## No state to own, so this is a plain static-function class rather than a
## Node — a scene/instance for it would be an unnecessary abstraction.
##
## Pass 4 scope: called with a single hardcoded region (no unlocked-region
## tracking exists yet — that arrives in Pass 11). Each region root is
## expected to have a child named "Paths" whose children are the eligible
## Path2D nodes for that region.


## Gathers every Path2D under `region.get_node("Paths")` for each region in
## `regions`, and returns one at random. Returns null if none are found.
static func pick_random_path(regions: Array[Node2D]) -> Path2D:
	var candidates: Array[Path2D] = []
	for region in regions:
		var paths_node := region.get_node_or_null("Paths")
		if not paths_node:
			continue
		for child in paths_node.get_children():
			if child is Path2D:
				candidates.append(child)

	if candidates.is_empty():
		return null
	return candidates[randi() % candidates.size()]
