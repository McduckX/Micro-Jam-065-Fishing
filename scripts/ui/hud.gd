extends Control
## Root of the gameplay HUD: compass, bait readout, cycle timer.
##
## Pass 5 scope: compass is live (see compass.gd); the bait and timer
## labels are static placeholder text with nothing to bind yet, since bait
## doesn't exist until Pass 8 and the cycle timer until Pass 10. This script
## is currently a stub — it becomes the place those passes wire real data
## into the existing Label nodes, rather than a new HUD scene.
