extends XRController3D
## VR Hand — handles grabbing and releasing discs with subtle magnetism.

const GRAB_DISTANCE     := 0.15   # how close we need to be to grab
const MAGNET_DISTANCE   := 0.20   # snap radius when releasing near a peg
const HAPTIC_GRAB       := 0.3    # rumble intensity on grab
const HAPTIC_SNAP       := 0.5    # rumble intensity on snap
const HAPTIC_DENY       := 0.15   # light buzz when invalid placement

var _held_disc : RigidBody3D = null
var _is_grip_pressed : bool = false

func _ready() -> void:
	# Connect XR input events
	button_pressed.connect(_on_button_pressed)
	button_released.connect(_on_button_released)

func _on_button_pressed(action: String) -> void:
	if action == "grip_click" or action == "grip" or action == "trigger_click" or action == "trigger":
		_is_grip_pressed = true
		_try_grab()

func _on_button_released(action: String) -> void:
	if action == "grip_click" or action == "grip" or action == "trigger_click" or action == "trigger":
		_is_grip_pressed = false
		_try_release()

# ── grab logic ────────────────────────────────────────────────────────────────
func _try_grab() -> void:
	if _held_disc != null:
		return   # already holding something

	var best_disc : RigidBody3D = null
	var best_dist : float = GRAB_DISTANCE

	# Find the closest grabbable disc
	var discs := get_tree().get_nodes_in_group("") # we'll iterate all discs via parent
	var main_node := get_tree().current_scene
	for child in main_node.get_children():
		if not child is RigidBody3D:
			continue
		var disc := child as RigidBody3D
		if not disc.has_method("grab"):
			continue
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
		_held_disc = best_disc
		_held_disc.grab(self)
		# Haptic feedback
		trigger_haptic_pulse("haptic", 0.0, HAPTIC_GRAB, 0.1, 0.0)

# ── release logic with magnetism ─────────────────────────────────────────────
func _try_release() -> void:
	if _held_disc == null:
		return

	_held_disc.release()

	# Find the nearest peg within magnet distance
	var best_peg : Node = null
	var best_dist : float = MAGNET_DISTANCE
	var main_node := get_tree().current_scene
	for peg_node in main_node.pegs:
		# Distance in XZ only (horizontal) for more forgiving snapping
		var disc_xz := Vector2(_held_disc.global_position.x, _held_disc.global_position.z)
		var peg_xz  := Vector2(peg_node.global_position.x, peg_node.global_position.z)
		var dist := disc_xz.distance_to(peg_xz)
		if dist < best_dist:
			best_dist = dist
			best_peg = peg_node

	if best_peg:
		if best_peg.can_accept(_held_disc):
			best_peg.place_disc(_held_disc)
			trigger_haptic_pulse("haptic", 0.0, HAPTIC_SNAP, 0.15, 0.0)
			# Check for win
			var gm = main_node.game_manager
			if gm and gm.has_method("check_win"):
				gm.check_win()
		else:
			# Invalid placement — give a gentle buzz, disc falls naturally
			trigger_haptic_pulse("haptic", 0.0, HAPTIC_DENY, 0.08, 0.0)

	_held_disc = null

# ── Desktop debug controls (no VR headset) ───────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	# Only for the right hand in debug mode
	if name != "RightHand":
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_is_grip_pressed = true
				_try_grab()
			else:
				_is_grip_pressed = false
				_try_release()
