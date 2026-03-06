extends Node
## GameManager — win detection, move counting, and reset.

var _move_count : int = 0
var _win_label  : Label3D = null
var _has_won    : bool = false

const NUM_DISCS := 5
const TARGET_PEG_INDEX := 2  # rightmost peg is the goal

func _ready() -> void:
	# Create a floating 3D label above the table for feedback
	_win_label = Label3D.new()
	_win_label.name = "WinLabel"
	_win_label.text = ""
	_win_label.font_size = 72
	_win_label.pixel_size = 0.002
	_win_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_win_label.modulate = Color(1.0, 0.9, 0.3)
	_win_label.outline_size = 12
	_win_label.position = Vector3(0, 1.55, 0)
	_win_label.visible = false
	get_tree().current_scene.add_child.call_deferred(_win_label)

	# Also create a move counter label
	var counter := Label3D.new()
	counter.name = "MoveCounter"
	counter.text = "Moves: 0"
	counter.font_size = 36
	counter.pixel_size = 0.002
	counter.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	counter.modulate = Color(0.8, 0.85, 0.95)
	counter.outline_size = 8
	counter.position = Vector3(0, 1.40, 0)
	get_tree().current_scene.add_child.call_deferred(counter)

	# Connect to disc signals
	await get_tree().process_frame
	await get_tree().process_frame
	var main_node := get_tree().current_scene
	for disc in main_node.discs:
		if disc.has_signal("released"):
			disc.released.connect(_on_disc_released)

func _on_disc_released(_disc: RigidBody3D) -> void:
	_move_count += 1
	var counter := get_tree().current_scene.get_node_or_null("MoveCounter")
	if counter:
		counter.text = "Moves: %d" % _move_count

func check_win() -> void:
	if _has_won:
		return
	var main_node := get_tree().current_scene
	if main_node.pegs.size() <= TARGET_PEG_INDEX:
		return
	var target_peg : Node = main_node.pegs[TARGET_PEG_INDEX]
	if target_peg.disc_count() == NUM_DISCS:
		_has_won = true
		_show_win()

func _show_win() -> void:
	if _win_label:
		var optimal := int(pow(2, NUM_DISCS)) - 1
		_win_label.text = "YOU WIN!\nMoves: %d  (optimal: %d)" % [_move_count, optimal]
		_win_label.visible = true
		# Little celebration — pulse the label
		var tw := _win_label.create_tween()
		tw.set_loops(3)
		tw.tween_property(_win_label, "scale", Vector3(1.15, 1.15, 1.15), 0.3)
		tw.tween_property(_win_label, "scale", Vector3.ONE, 0.3)

func _unhandled_input(event: InputEvent) -> void:
	# Press R to reset (keyboard debug)
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		reset_game()

func reset_game() -> void:
	_has_won = false
	_move_count = 0
	if _win_label:
		_win_label.visible = false
	var counter := get_tree().current_scene.get_node_or_null("MoveCounter")
	if counter:
		counter.text = "Moves: 0"

	# Reload the scene
	get_tree().reload_current_scene()
