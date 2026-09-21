extends Resource
class_name RhythmPattern
## An authored sequence of RhythmNotes — see GameDesign.md §11/§12.
##
## Pass 7 scope: one manually authored test phrase (resources/rhythm/
## test_phrase.tres). Real per-target phrases and the combined-finale
## concatenation arrive in Pass 14.

@export var notes: Array[RhythmNote] = []
## Backing track for this phrase — RhythmUI starts it 1 second into the
## sequence (see rhythm_ui.gd), not immediately, to land in sync with the
## notes' authored timing. Optional: a pattern with no audio simply plays
## silent (test_phrase/test_phrase_short have none).
@export var audio: AudioStream
