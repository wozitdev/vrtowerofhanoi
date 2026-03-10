extends RigidBody3D
## Disc — a single Tower‑of‑Hanoi ring.
## Knows its size index, whether it's being held, and which peg it sits on.

signal grabbed(disc: RigidBody3D)
signal released(disc: RigidBody3D)

var disc_index   : int   = -1
var disc_radius  : float = 0.1
var is_grabbed   : bool  = false
var current_peg  : Node  = null   # the Peg node this disc sits on (or null)
var _grab_offset : Vector3 = Vector3.ZERO
var _holder      : Node3D  = null  # the VR hand holding us

# ── visual feedback ───────────────────────────────────────────────────────────
var _mesh : MeshInstance3D = null

func _ready() -> void:
	disc_index  = get_meta("disc_index", 0)
	disc_radius = get_meta("disc_radius", 0.1)
	# Locate mesh child for highlight
	for child in get_children():
		if child is MeshInstance3D and child.mesh is CylinderMesh:
			if child.mesh.top_radius > 0.04:  # skip the hole mesh
				_mesh = child
				break
	# Collision layer: 1 = physics world, 2 = snap detection
	collision_layer = 1 | 2
	collision_mask  = 1
	# Start frozen — discs sit still until grabbed
	freeze = true

func _process(delta: float) -> void:
	if is_grabbed and _holder:
		# Directly position the disc at the hand (kinematic tracking)
		global_position = _holder.global_position + _grab_offset
		# Keep disc flat / upright
		global_transform.basis = global_transform.basis.slerp(Basis.IDENTITY, clampf(10.0 * delta, 0.0, 1.0))

# ── grab / release API (called by VR hand) ───────────────────────────────────
func grab(hand: Node3D) -> void:
	if is_grabbed:
		return
	is_grabbed = true
	_holder = hand
	_grab_offset = global_position - hand.global_position
	# Freeze the body so we can position it directly (kinematic)
	freeze = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	# Pop off current peg
	if current_peg and current_peg.has_method("remove_disc"):
		current_peg.remove_disc(self)
		current_peg = null
	# Highlight
	_set_highlight(true)
	grabbed.emit(self)

func release() -> void:
	if not is_grabbed:
		return
	is_grabbed = false
	_holder = null
	# Stay frozen — vr_hand will either snap us or we'll be unfrozen to fall
	# Un‑highlight
	_set_highlight(false)
	released.emit(self)

## Called by vr_hand when the disc isn't snapped to a peg — let it drop.
func drop_free() -> void:
	freeze = false
	gravity_scale = 3.0
	linear_damp = 2.0
	angular_damp = 4.0

# ── helpers ───────────────────────────────────────────────────────────────────
func _set_highlight(on: bool) -> void:
	if _mesh and _mesh.material_override:
		var mat := _mesh.material_override as StandardMaterial3D
		if mat:
			if on:
				mat.emission_enabled = true
				mat.emission = mat.albedo_color * 0.4
				mat.emission_energy_multiplier = 1.0
			else:
				mat.emission_enabled = false

func snap_to(peg_node: Node, stack_y: float) -> void:
	current_peg = peg_node
	var target := Vector3(peg_node.global_position.x, stack_y, peg_node.global_position.z)
	# Keep frozen, tween into position
	freeze = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO

	var tw := create_tween()
	tw.set_ease(Tween.EASE_OUT)
	tw.set_trans(Tween.TRANS_BACK)
	tw.tween_property(self, "global_position", target, 0.18)
	# Flatten rotation
	tw.parallel().tween_property(self, "global_transform:basis", Basis.IDENTITY, 0.18)
	# Stay frozen after snap — disc is resting on the peg
