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
var _base_emission_energy : float = 0.5
var _highlight_emission   : float = 2.0
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

func _physics_process(delta: float) -> void:
	if is_grabbed and _holder:
		# Move toward hand smoothly (soft attach — feels nice in VR)
		var target_pos : Vector3 = _holder.global_position + _grab_offset
		var diff := target_pos - global_position
		linear_velocity = diff / max(delta, 0.001) * 0.8
		angular_velocity = Vector3.ZERO
		# Keep upright while held
		var current_basis := global_transform.basis
		var up := Vector3.UP
		var target_basis := Basis.looking_at(-current_basis.z, up)
		global_transform.basis = current_basis.slerp(target_basis, 8.0 * delta)

# ── grab / release API (called by VR hand) ───────────────────────────────────
func grab(hand: Node3D) -> void:
	if is_grabbed:
		return
	is_grabbed = true
	_holder = hand
	_grab_offset = global_position - hand.global_position
	# Reduce gravity while held
	gravity_scale = 0.0
	linear_damp = 8.0
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
	gravity_scale = 3.0
	linear_damp = 2.0
	# Un‑highlight
	_set_highlight(false)
	released.emit(self)

# ── helpers ───────────────────────────────────────────────────────────────────
func _set_highlight(on: bool) -> void:
	if _mesh and _mesh.material_override:
		var mat := _mesh.material_override as StandardMaterial3D
		if mat:
			mat.emission_energy_multiplier = _highlight_emission if on else _base_emission_energy

func snap_to(peg_node: Node, stack_y: float) -> void:
	current_peg = peg_node
	# Smoothly tween into place
	var target := Vector3(peg_node.global_position.x, stack_y, peg_node.global_position.z)
	# Zero velocities and disable gravity briefly
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	gravity_scale = 0.0
	freeze = true

	var tw := create_tween()
	tw.set_ease(Tween.EASE_OUT)
	tw.set_trans(Tween.TRANS_BACK)
	tw.tween_property(self, "global_position", target, 0.2)
	# Also fix rotation to be flat
	var flat_basis := Basis.IDENTITY
	tw.parallel().tween_property(self, "global_transform:basis", flat_basis, 0.2)
	tw.tween_callback(_finish_snap)

func _finish_snap() -> void:
	freeze = false
	gravity_scale = 3.0
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
