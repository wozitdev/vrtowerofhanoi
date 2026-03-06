extends Node3D
## Main scene builder — constructs the entire Tower of Hanoi VR world at runtime.

# ── tunables ──────────────────────────────────────────────────────────────────
const NUM_DISCS         := 5
const TABLE_SIZE        := Vector3(2.0, 0.08, 1.2)   # width, height, depth
const TABLE_HEIGHT      := 0.75                        # metres above floor
const PEG_RADIUS        := 0.025
const PEG_HEIGHT        := 0.45
const PEG_SPACING       := 0.55                        # centre‑to‑centre
const DISC_HEIGHT       := 0.04
const DISC_MIN_RADIUS   := 0.06
const DISC_MAX_RADIUS   := 0.18

# Colors for the discs (rainbow‑ish)
const DISC_COLORS := [
	Color(0.90, 0.25, 0.20),  # red
	Color(0.95, 0.60, 0.15),  # orange
	Color(0.95, 0.85, 0.20),  # yellow
	Color(0.30, 0.75, 0.35),  # green
	Color(0.25, 0.50, 0.90),  # blue
]

var game_manager : Node
var pegs : Array[Node] = []      # 3 peg nodes
var discs : Array[RigidBody3D] = []

# ── lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	_build_environment()
	_build_xr_rig()
	_build_table()
	_build_pegs()
	_build_discs()
	_build_boundary_walls()
	_add_game_manager()

# ── environment ───────────────────────────────────────────────────────────────
func _build_environment() -> void:
	# World environment
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.12, 0.13, 0.18)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.35, 0.40)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.3

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	# Key light (sun‑like)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.96, 0.90)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-50, -30, 0)
	add_child(sun)

	# Fill light
	var fill := DirectionalLight3D.new()
	fill.light_color = Color(0.6, 0.7, 0.9)
	fill.light_energy = 0.4
	fill.rotation_degrees = Vector3(-30, 150, 0)
	add_child(fill)

	# Floor plane (visual only, so the player has ground reference)
	var floor_body := StaticBody3D.new()
	var floor_col := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(10, 0.02, 10)
	floor_col.shape = floor_shape
	floor_body.add_child(floor_col)

	var floor_mesh := MeshInstance3D.new()
	var floor_box := BoxMesh.new()
	floor_box.size = Vector3(10, 0.02, 10)
	floor_mesh.mesh = floor_box
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.15, 0.16, 0.20)
	floor_mat.roughness = 0.9
	floor_mesh.material_override = floor_mat
	floor_body.add_child(floor_mesh)
	floor_body.position.y = -0.01
	add_child(floor_body)

# ── XR rig ────────────────────────────────────────────────────────────────────
func _build_xr_rig() -> void:
	var xr_origin := XROrigin3D.new()
	xr_origin.name = "XROrigin3D"

	var camera := XRCamera3D.new()
	camera.name = "XRCamera3D"
	xr_origin.add_child(camera)

	# Left hand
	var left := XRController3D.new()
	left.name = "LeftHand"
	left.tracker = "left_hand"
	var left_script = load("res://scripts/vr_hand.gd")
	left.set_script(left_script)
	_add_hand_visuals(left, Color(0.3, 0.5, 0.9, 0.6))
	xr_origin.add_child(left)

	# Right hand
	var right := XRController3D.new()
	right.name = "RightHand"
	right.tracker = "right_hand"
	var right_script = load("res://scripts/vr_hand.gd")
	right.set_script(right_script)
	_add_hand_visuals(right, Color(0.9, 0.5, 0.3, 0.6))
	xr_origin.add_child(right)

	# Position the rig so the player stands in front of the table
	xr_origin.position = Vector3(0, 0, 0.6)
	add_child(xr_origin)

	# Initialise OpenXR
	var xr_interface := XRServer.find_interface("OpenXR")
	if xr_interface and xr_interface.initialize():
		get_viewport().use_xr = true
	else:
		push_warning("OpenXR not available — running in flat‑screen debug mode")

func _add_hand_visuals(controller: XRController3D, color: Color) -> void:
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = "HandMesh"
	var sphere := SphereMesh.new()
	sphere.radius = 0.03
	sphere.height = 0.06
	mesh_inst.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.3
	mat.metallic = 0.2
	mesh_inst.material_override = mat
	controller.add_child(mesh_inst)

# ── table ─────────────────────────────────────────────────────────────────────
func _build_table() -> void:
	var table := StaticBody3D.new()
	table.name = "Table"

	# Collision
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = TABLE_SIZE
	col.shape = shape
	table.add_child(col)

	# Visual
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = TABLE_SIZE
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.22, 0.12)
	mat.roughness = 0.75
	mat.metallic = 0.05
	mesh.material_override = mat
	table.add_child(mesh)

	table.position = Vector3(0, TABLE_HEIGHT, 0)
	add_child(table)

	# Table legs
	for x_sign in [-1, 1]:
		for z_sign in [-1, 1]:
			var leg := _make_table_leg()
			leg.position = Vector3(
				x_sign * (TABLE_SIZE.x * 0.42),
				TABLE_HEIGHT - TABLE_SIZE.y * 0.5 - 0.35,
				z_sign * (TABLE_SIZE.z * 0.38)
			)
			add_child(leg)

func _make_table_leg() -> StaticBody3D:
	var leg := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.06, 0.70, 0.06)
	col.shape = shape
	leg.add_child(col)

	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.06, 0.70, 0.06)
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.30, 0.18, 0.10)
	mat.roughness = 0.8
	mesh.material_override = mat
	leg.add_child(mesh)
	return leg

# ── pegs ──────────────────────────────────────────────────────────────────────
func _build_pegs() -> void:
	var peg_script = load("res://scripts/peg.gd")
	var surface_y : float = TABLE_HEIGHT + TABLE_SIZE.y * 0.5

	for i in range(3):
		var peg := StaticBody3D.new()
		peg.name = "Peg%d" % i
		peg.set_script(peg_script)

		# Collision cylinder for the peg rod
		var col := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = PEG_RADIUS
		shape.height = PEG_HEIGHT
		col.shape = shape
		peg.add_child(col)

		# Visual cylinder
		var mesh := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = PEG_RADIUS
		cyl.bottom_radius = PEG_RADIUS
		cyl.height = PEG_HEIGHT
		mesh.mesh = cyl
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.70, 0.55, 0.30)
		mat.roughness = 0.5
		mat.metallic = 0.1
		mesh.material_override = mat
		peg.add_child(mesh)

		# Base plate (purely cosmetic)
		var base_mesh := MeshInstance3D.new()
		var base_cyl := CylinderMesh.new()
		base_cyl.top_radius = DISC_MAX_RADIUS + 0.03
		base_cyl.bottom_radius = DISC_MAX_RADIUS + 0.03
		base_cyl.height = 0.015
		base_mesh.mesh = base_cyl
		var base_mat := StandardMaterial3D.new()
		base_mat.albedo_color = Color(0.55, 0.40, 0.22)
		base_mat.roughness = 0.7
		base_mesh.material_override = base_mat
		base_mesh.position.y = -PEG_HEIGHT * 0.5 + 0.007
		peg.add_child(base_mesh)

		# Snap area (larger invisible cylinder for magnetism detection)
		var snap_area := Area3D.new()
		snap_area.name = "SnapArea"
		var snap_col := CollisionShape3D.new()
		var snap_shape := CylinderShape3D.new()
		snap_shape.radius = DISC_MAX_RADIUS + 0.08
		snap_shape.height = PEG_HEIGHT + 0.15
		snap_col.shape = snap_shape
		snap_area.add_child(snap_col)
		# Put snap area on layer 2
		snap_area.collision_layer = 2
		snap_area.collision_mask = 2
		peg.add_child(snap_area)

		# Position
		var x_offset : float = (i - 1) * PEG_SPACING
		peg.position = Vector3(x_offset, surface_y + PEG_HEIGHT * 0.5, 0)

		peg.set_meta("peg_index", i)
		add_child(peg)
		pegs.append(peg)

# ── discs ─────────────────────────────────────────────────────────────────────
func _build_discs() -> void:
	var disc_script = load("res://scripts/disc.gd")
	var surface_y : float = TABLE_HEIGHT + TABLE_SIZE.y * 0.5

	for i in range(NUM_DISCS):
		var t : float = float(i) / float(NUM_DISCS - 1) if NUM_DISCS > 1 else 0.0
		var radius : float = lerpf(DISC_MAX_RADIUS, DISC_MIN_RADIUS, t)
		var color : Color = DISC_COLORS[i % DISC_COLORS.size()]

		var disc := RigidBody3D.new()
		disc.name = "Disc%d" % i
		disc.mass = 0.3
		disc.gravity_scale = 3.0  # snappier feel
		disc.linear_damp = 2.0
		disc.angular_damp = 4.0
		disc.continuous_cd = true
		disc.set_script(disc_script)

		# Collision
		var col := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = DISC_HEIGHT
		col.shape = shape
		disc.add_child(col)

		# Visual
		var mesh := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = radius
		cyl.bottom_radius = radius
		cyl.height = DISC_HEIGHT
		cyl.radial_segments = 32
		mesh.mesh = cyl
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 0.35
		mat.metallic = 0.3
		mat.emission_enabled = true
		mat.emission = color * 0.15
		mat.emission_energy_multiplier = 0.5
		mesh.material_override = mat
		disc.add_child(mesh)

		# Hole visual (dark torus in the centre — faked with a small dark cylinder)
		var hole := MeshInstance3D.new()
		var hole_cyl := CylinderMesh.new()
		hole_cyl.top_radius = PEG_RADIUS + 0.005
		hole_cyl.bottom_radius = PEG_RADIUS + 0.005
		hole_cyl.height = DISC_HEIGHT + 0.002
		hole.mesh = hole_cyl
		var hole_mat := StandardMaterial3D.new()
		hole_mat.albedo_color = Color(0.08, 0.06, 0.04)
		hole_mat.roughness = 0.9
		hole.material_override = hole_mat
		disc.add_child(hole)

		disc.set_meta("disc_index", i)
		disc.set_meta("disc_radius", radius)

		# Stack on peg 0, largest at bottom
		var stack_y : float = surface_y + DISC_HEIGHT * 0.5 + (NUM_DISCS - 1 - i) * DISC_HEIGHT
		disc.position = Vector3(-PEG_SPACING, stack_y, 0)

		add_child(disc)
		discs.append(disc)

	# Register initial disc stack on peg 0
	# (done after a frame so peg scripts are ready)
	await get_tree().process_frame
	if pegs.size() > 0 and pegs[0].has_method("init_stack"):
		# Largest disc first (index NUM_DISCS-1) up to smallest (index 0)
		var ordered_discs : Array = []
		for i in range(NUM_DISCS - 1, -1, -1):
			ordered_discs.append(discs[i])
		pegs[0].init_stack(ordered_discs)

# ── boundary walls (invisible) ───────────────────────────────────────────────
func _build_boundary_walls() -> void:
	var surface_y := TABLE_HEIGHT + TABLE_SIZE.y * 0.5
	var wall_height := PEG_HEIGHT + 0.3
	var half_w := TABLE_SIZE.x * 0.5 + 0.02
	var half_d := TABLE_SIZE.z * 0.5 + 0.02
	var cy := surface_y + wall_height * 0.5

	# Four walls around the table edge
	_add_wall(Vector3(0, cy, -half_d), Vector3(TABLE_SIZE.x + 0.04, wall_height, 0.04))
	_add_wall(Vector3(0, cy, half_d),  Vector3(TABLE_SIZE.x + 0.04, wall_height, 0.04))
	_add_wall(Vector3(-half_w, cy, 0), Vector3(0.04, wall_height, TABLE_SIZE.z + 0.04))
	_add_wall(Vector3(half_w, cy, 0),  Vector3(0.04, wall_height, TABLE_SIZE.z + 0.04))

	# Ceiling (prevents throwing up)
	_add_wall(Vector3(0, surface_y + wall_height, 0), Vector3(TABLE_SIZE.x + 0.04, 0.04, TABLE_SIZE.z + 0.04))

func _add_wall(pos: Vector3, size: Vector3) -> void:
	var wall := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	wall.add_child(col)
	wall.position = pos
	add_child(wall)

# ── game manager ──────────────────────────────────────────────────────────────
func _add_game_manager() -> void:
	game_manager = Node.new()
	game_manager.name = "GameManager"
	var gm_script = load("res://scripts/game_manager.gd")
	game_manager.set_script(gm_script)
	add_child(game_manager)
