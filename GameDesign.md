1. Project Overview
   Project type: 2D top-down game
   Engine: Godot 4.7.2
   Target platform: Web build for itch.io
   Jam: Micro Jam 065
   Theme: Fishing
   Prerequisite: Everything is bait
   Team: One developer and two artists
   Tone: Eerie, absurd, and non-disturbing
   The player controls a boat on an increasingly accessible ocean map. A massive whirlpool monster occupies the center and demands a specific creature as food.
   To obtain that creature, the player must complete a fixed chain of catches. Every successfully caught fish, creature, or object automatically becomes the bait for the next target.
   The player must complete the chain, catch the requested creature, and deliver it to the whirlpool monster before the cycle timer expires.
   There are four cycles. Completing all four wins the game.

2. Core Gameplay Loop
   Each cycle follows this structure:
   The whirlpool monster requests a specific creature.
   The player receives that cycle’s starting bait.
   The next required target spawns on an eligible authored path.
   A directional HUD indicator points toward the moving target.
   The player navigates the boat toward the target.
   The player casts the current bait near or ahead of the target.
   The target notices and approaches the bait.
   The player hooks the target.
   A short rhythm sequence begins.
   Success catches the target.
   The caught target automatically replaces the current bait.
   The process repeats for the next target in the chain.
   The final target uses a combined rhythm sequence containing the patterns taught by the previous catches.
   The player returns to the central monster.
   The player explicitly feeds it by pressing E, or reaches the inner center while carrying the correct food.
   The next region unlocks and the next cycle begins.
   If the timer expires, the whirlpool expands across the map and pulls the player into the monster.

3. World Structure
   Stage
   One large stage
   Stage resolution: 3524 × 3106
   Game viewport: 1920 × 1080
   One central whirlpool monster
   Four regions arranged around the center in an X-like structure
   Region order
   Top
   Left
   Bottom
   Right
   Progression
   Cycle 1: Top
   Cycle 2: Top + Left
   Cycle 3: Top + Left + Bottom
   Cycle 4: Entire map
   Previously unlocked regions remain available. Targets may appear in any currently unlocked region.
   Locked regions are concealed by a visual barrier and blocked by collision walls. Unlocking a region quickly fades away its visual covering and removes its collision boundary.
   The player’s initial location is determined by the placed boat instance or a designated editor marker.

4. Camera
   The camera follows the boat.
   The camera remains north-oriented and does not rotate with the boat.
   At stage boundaries, the camera stops moving.
   The boat continues moving within the visible camera space until it moves away from the boundary.
   Camera smoothing and visual effects may be determined during the camera and polish passes.

5. Boat Movement
   The player is permanently attached to the boat and cannot walk independently.
   Controls
   W: Accelerate forward
   S: Brake, then reverse
   A: Rotate left
   D: Rotate right
   Left Mouse Button: Cast, hook, or recall line
   E: Feed or interact
   Escape: Pause, except during rhythm sequences
   Movement behavior
   The boat uses accessible arcade-style movement.
   Releasing propulsion allows brief coasting before the boat slows.
   The boat can rotate while stationary.
   Forward movement has a maximum speed.
   Reverse movement has a lower maximum speed.
   Pressing S while moving forward brakes before reversing.
   Boat collisions slide along surfaces.
   The boat uses one freely rotating top-down sprite.
   Movement tuning should remain exportable and adjustable.

6. Flute Propulsion
   The fishing rod is also a magical flute that powers the boat.
   A looping flute piece plays while the player holds W or S.
   The loop becomes louder while propulsion input is held.
   The loop becomes quieter when the input is released.
   Forward and reverse use the same loop.
   The volume reacts to player input, not actual velocity.
   The flute’s exact volume response and transitions will be tuned during the audio pass.

7. Whirlpool Monster
   The whirlpool monster remains in the center of the map.
   Current behavior
   The current pulls the boat toward the center.
   It also creates rotational or orbital movement.
   Its force becomes stronger closer to the center.
   The player can escape the outer current using normal acceleration.
   Approaching too close without the correct food triggers death.
   Locked-region collision walls can cause the current to push the player against an inaccessible boundary.
   Hunger behavior
   Each cycle has a separate timer.
   As the timer decreases:
   the whirlpool’s radius grows;
   a red effect becomes increasingly visible at the screen edges;
   the monster’s current occupies more of the map.
   When the timer reaches zero:
   an active rhythm sequence may finish;
   the player cannot recover afterward;
   the whirlpool covers the map;
   player control is removed;
   the boat is pulled into the center;
   the monster eats the player.
   Timer duration will be tuned later.

8. Casting System
   The player may cast whenever they possess bait.
   Casting flow
   The player clicks the left mouse button at any position; no cast is ever rejected.
   If the clicked position is beyond maximum casting range, the cast clamps to maximum range in the clicked direction instead.
   If the clamped position would land on land, the cast clamps further, landing just short of the shoreline instead — close enough to attract land-based targets toward the water.
   The current bait travels from the boat to the resolved position.
   A line is rendered between the boat and bait.
   The bait reaches the destination and becomes concealed beneath the water.
   A hook indicator appears at the cast location.
   The line remains active until hooked, recalled, or automatically cancelled.
   Casting cancellation
   The player can recall an unhooked line by clicking again.
   The line is automatically recalled if the boat moves too far from the boat’s original casting position.
   After an unsuccessful interaction or recall, a short delay occurs before the player can cast again.

9. Target Behavior
   Each active target uses an authored path or loop.
   Path rules
   The level contains a collection of possible paths.
   Water and land-based targets use compatible path categories.
   Each path remains within one map region.
   Paths never cross between quarters.
   A target randomly selects an eligible path from the currently unlocked regions.
   The path is the only randomized part of target placement.
   Only the currently required target needs to be active.
   Bait attraction
   A target continues following its path until it notices the bait.
   The player must cast inside its detection radius or ahead of its route.
   After noticing the bait, it leaves its path and approaches the hook.
   The hook indicator changes when the target is close enough.
   The player clicks to begin the rhythm sequence.
   If an attempt fails, the target:
   escapes from the hook;
   moves away at an increased speed;
   returns to its assigned path;
   returns to its normal movement speed.
   The player retains their existing bait after failure.
   Final creatures
   Each cycle's final creature (the one fed to the whirlpool) is not a patrol target. It is always present at a fixed position in its home region rather than being spawned and despawned.
   Approaching it too closely is dangerous regardless of which bait is currently held — the exact effect is determined during the environmental-content pass.
   It only responds to a hook attempt once the catch chain has reached it; casting at it before that has no effect beyond being retractable.
   A failed hook attempt against it has no flee behavior — it is stationary by definition and remains hookable for an immediate retry, though a failure-specific consequence may also be added during the environmental-content pass.

10. Boat Behavior While Fishing
    After casting:
    direct boat controls are disabled;
    existing momentum continues;
    the whirlpool continues affecting the boat;
    environmental hazards can affect the boat;
    the world continues operating in real time.
    If the boat moves beyond the allowed distance from its original casting position, the attempt is cancelled and the line returns.
    During the rhythm sequence:
    WASD controls the rhythm columns;
    boat steering remains disabled;
    the boat may continue drifting;
    currents and hazards remain active;
    pausing is disabled;
    the camera continues presenting the active world behind the rhythm interface.

11. Rhythm System
    The rhythm interface is inspired by a four-column falling-note game.
    Columns
    W A S D
    Note types
    Tap note: circle
    Hold note: vertical pill
    Required behavior
    Notes travel from the top toward a hit area.
    No simultaneous notes are required.
    Timing windows should be forgiving.
    Judgments are limited to Success and Mistake.
    Correct and incorrect inputs receive immediate feedback.
    No numerical rhythm score is required.
    Preliminary targets fail if the player makes at least one mistake.
    Final creatures allow one mistake and fail on the second mistake.
    A mistake does not immediately end the rhythm sequence.
    The result is resolved when the sequence finishes.
    Each target always uses the same authored sequence when retried.
    Exact handling of empty inputs, early presses, hold releases, note duration, countdowns, rhythm data, and phrase length will be decided during the rhythm-system pass.

12. Rhythm Progression
    Each intermediate target teaches one manually authored phrase. The final target combines every phrase from that cycle.
    Example:
    Salmon: Pattern A
    Bear: Pattern B
    Salmon-Shaped Submarine: Pattern C
    Pirate Ship: Pattern D
    Blue Whale: Pattern E
    Kraken: A + B + C + D + E
    The combined final sequence should use recognizable versions of the practiced phrases.
    Exact pattern lengths, tempo, pauses between phrases, note density, and difficulty progression will be determined during rhythm content production.

13. Bait Rules
    The player carries exactly one bait.
    There is no inventory.
    Every successful catch automatically becomes the next bait.
    The previous bait is discarded.
    Failed catches do not consume the current bait.
    Feeding the requested creature removes it.
    The next cycle automatically grants its starting bait.
    This is the primary mechanical interpretation of Everything is bait.

14. Catch Chains
    Cycle 1: Kraken
    Starting bait: Worm

Worm
→ Salmon
→ Bear
→ Salmon-Shaped Submarine
→ Pirate Ship
→ Blue Whale
→ Kraken
→ Feed Kraken to the monster
Cycle 2: Scylla
Starting bait: Bacon

Bacon
→ Frying Pan
→ Bonfire
→ Fire Hydrant
→ Doggy Bowl
→ Dog Treat
→ Scylla
→ Feed Scylla to the monster
Cycle 3: Umibozu
Starting bait: Nickel

Nickel
→ Parking Meter
→ Cars
→ Oil
→ Cauldron
→ Ladle
→ Umibozu
→ Feed Umibozu to the monster
Cycle 4: Leviathan
Starting bait: Bible

Bible
→ Priest
→ Cross
→ Gold
→ Pharaoh
→ Library of Babylon
→ Greed
→ Leviathan
→ Feed Leviathan to the monster
→ Complete the game
Names and spellings can be changed later without altering the underlying architecture.

15. Target Indicator
    The HUD contains a circular target indicator.
    A fixed dot in the center represents the player.
    An arrow rotates around the center.
    The arrow points from the player toward the active target.
    It updates continuously as the player and target move.
    It provides direction but does not function as a full minimap.
    The exact appearance and whether it presents distance information will be decided during the HUD pass.

16. Feeding the Monster
    The player can feed the monster after catching the requested final target.
    Normal feeding
    The player enters the interaction area.
    An interaction prompt appears.
    The player presses E.
    The food is pulled into the monster.
    Automatic feeding
    If the player reaches the dangerous inner center while carrying the correct creature, it counts as a successful delivery rather than a death.
    Approaching the inner center without the correct creature triggers the death sequence.
    Wrong food is never automatically accepted as successful food.

17. Between-Cycle Sequence
    After a successful delivery:
    The requested food is pulled into the monster.
    The monster reacts.
    The timer stops.
    The whirlpool returns to its base size and strength.
    The player is teleported to the original spawn position.
    Gameplay is briefly paused.
    The next region’s covering quickly fades away.
    Its collision boundary is removed.
    A HUD speech bubble presents the next request.
    The player automatically receives the next starting bait.
    The new cycle timer begins.
    Control returns to the player.
    The next request should clearly communicate:
    what the monster wants;
    what bait the player currently has;
    what target the player must find next.
    The exact presentation will be determined during the UI pass.

18. Game States
    The project should support the following states:
    Title
    Instructions
    Cycle Introduction
    Active Navigation
    Cast Active
    Rhythm Sequence
    Catch Result
    Feeding Sequence
    Region Unlock
    Paused
    Game Over
    Victory
    ``
    These states do not necessarily need separate scenes. The implementation should use the simplest reliable architecture.

19. Failure and Restart
    The player loses when:
    the timer expires;
    the whirlpool consumes the player;
    or the player enters the lethal center without the required food.
    A loss transitions to a Game Over screen with:
    Try Again
    Main Menu
    Try Again creates a completely new run:
    return to Cycle 1;
    relock the left, bottom, and right regions;
    reset the catch chains;
    reset the monster;
    restore the initial player position;
    give the Cycle 1 starting bait.

20. Victory
    Successfully feeding Leviathan completes the game.
    The exact ending animation, dialogue, score presentation, final time display, credits behavior, and victory-screen buttons will be determined during the ending pass.

21. Environmental Interactions
    The map may contain environmental elements that:
    knock the boat;
    slow the boat;
    accelerate the boat;
    redirect the boat.
    Exact obstacle types, visuals, locations, strengths, and whether each effect is mandatory will be determined during the environmental-content pass.
    The implementation should avoid creating a large universal effect framework unless the selected environmental content requires it.

22. Design Values
    Exact values should remain editable rather than hardcoded where practical.
    Examples include:
    boat acceleration;
    forward and reverse maximum speeds;
    rotation speed;
    passive deceleration;
    casting range;
    bait travel speed;
    target detection radius;
    hook radius;
    maximum fishing drift distance;
    casting cooldown;
    path movement speeds;
    whirlpool radius;
    whirlpool strength;
    lethal radius;
    cycle timer duration;
    screen-edge warning intensity;
    rhythm note speed;
    timing windows;
    mistake allowance.

23. Deferred Component Questions
    Unresolved details must be handled during the pass that implements the affected component.
    Examples include:
    exact rhythm-note judgment rules;
    rhythm sequence durations;
    musical tempo and phrase structure;
    target path implementation;
    environmental hazards;
    camera smoothing and shake;
    animation requirements;
    tutorial presentation;
    complete HUD layout;
    audio list and mixing;
    title and menu presentation;
    target presentation for land-based objects;
    victory presentation;
    accessibility and settings.
    When a pass reaches an unresolved decision, the implementation assistant must:
    identify the decision;
    explain why it matters now;
    present a small number of practical options;
    recommend the simplest suitable option;
    wait for an answer before implementing that detail.
