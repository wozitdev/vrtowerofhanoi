extends XRController3D
## VR Hand — handles grabbing and releasing discs with subtle magnetism.

const GRAB_DISTANCE     := 0.15   # how close we need to be to grab
const MAGNET_DISTANCE   := 0.20   # snap radius when releasing near a peg
const HAPTIC_GRAB       := 0.3    # rumble intensity on grab
const HAPTIC_SNAP       := 0.5    # rumble intensity on snap
const HAPTIC_DENY       := 0.15   # light buzz when invalid placement

var _held_disc : RigidBody3D = null
var _source_peg : Node = null     # peg the disc was picked from (for return-on-fail)

func _ready() -> void:
	# Connect XR input events
	button_pressed.connect(_on_button_pressed)
	button_released.connect(_on_button_released)

func _on_button_pressed(action: String) -> void:
	if action in ["grip_click", "grip", "trigger_click", "trigger", "select_button"]:
		_try_grab()

func _on_button_released(action: String) -> void:
	if action in ["grip_click", "grip", "trigger_click", "trigger", "select_button"]:
		_try_release()

# ── grab logic ────────────────────────────────────────────────────────────────
func _try_grab() -> void:
	if _held_disc != null:
		return   # already holding something

	var best_disc : RigidBody3D = null
	var best_dist : float = GRAB_DISTANCE
	var main_node := get_tree().current_scene

	# Find the closest grabbable disc among the main scene's disc list
	for disc in main_node.discs:
		if disc.is_grabbed:
			continue

		# Only allow grabbing the top disc of a peg
		if disc.current_peg and not disc.current_peg.is_top(disc):
			continue

		var dist := global_position.distance_to(disc.global_position)
		if dist < best_dist:
			best_dist = dist
			best_disc = disc

	if best_disc:
		_source_peg = best_disc.current_peg
		_held_disc = best_disc
		_held_disc.grab(self)
		# Haptic feedback
		trigger_haptic_pulse("haptic", 0.0, HAPTIC_GRAB, 0.1, 0.0)

# ── release logic with magnetism ─────────────────────────────────────────────
func _try_release() -> void:
	if _held_disc == null:
		return

	_held_disc.release()

	# Find the nearest peg within magnet distance (XZ only, like the working example)
	var best_peg : Node = null
	var best_dist : float = MAGNET_DISTANCE
	var main_node := get_tree().current_scene
	for peg_node in main_node.pegs:
		var disc_xz := Vector2(_held_disc.global_position.x, _held_disc.global_position.z)
		var peg_xz  := Vector2(peg_node.global_position.x, peg_node.global_position.z)
		var dist := disc_xz.distance_to(peg_xz)
		if dist < best_dist:
			best_dist = dist
			best_peg = peg_node

	if best_peg and best_peg.can_accept(_held_disc):
		# Valid placement — snap to peg
		best_peg.place_disc(_held_disc)
		trigger_haptic_pulse("haptic", 0.0, HAPTIC_SNAP, 0.15, 0.0)
		# Only count as a move if the disc changed pegs
		if best_peg != _source_peg:
			var gm = main_node.game_manager
			if gm and gm.has_method("record_move"):
				gm.record_move()
		# Check for win
		var gm = main_node.game_manager
		if gm and gm.has_method("check_win"):
			gm.check_win()
	elif _source_peg and _source_peg.can_accept(_held_disc):
		# Invalid or too far — return disc to its original peg (only if still legal)
		trigger_haptic_pulse("haptic", 0.0, HAPTIC_DENY, 0.08, 0.0)
		_source_peg.place_disc(_held_disc)
	else:
		# Can't go back either — let disc drop
		trigger_haptic_pulse("haptic", 0.0, HAPTIC_DENY, 0.08, 0.0)
		_held_disc.drop_free()

	_held_disc = null
	_source_peg = null
