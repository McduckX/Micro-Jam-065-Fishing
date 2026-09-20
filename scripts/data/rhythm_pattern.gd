extends Resource
class_name RhythmPattern
## An authored sequence of RhythmNotes — see GameDesign.md §11/§12.
##
## Pass 7 scope: one manually authored test phrase (resources/rhythm/
## test_phrase.tres). Real per-target phrases and the combined-finale
## concatenation arrive in Pass 14.

@export var notes: Array[RhythmNote] = []
