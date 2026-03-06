extends StaticBody3D
## Peg — one of the three rods.  Tracks its disc stack and handles snapping.

const DISC_HEIGHT := 0.04

var peg_index : int = 0
var _stack : Array = []   # bottom → top order; each element is a disc RigidBody3D

var _surface_y : float = -1.0   # Y of the table surface (computed lazily)
const _PEG_HEIGHT := 0.45

func _ready() -> void:
	peg_index = get_meta("peg_index", 0)

func _get_surface_y() -> float:
	if _surface_y < 0.0:
		# Peg centre is at surface_y + PEG_HEIGHT/2
		_surface_y = global_position.y - _PEG_HEIGHT * 0.5
	return _surface_y

## Called once by main.gd to set the initial stack (largest first).
func init_stack(ordered_discs: Array) -> void:
	_stack = ordered_discs.duplicate()
	for disc in _stack:
		disc.current_peg = self

## Can this disc be placed here? (empty peg, or top disc is larger)
func can_accept(disc: RigidBody3D) -> bool:
	if _stack.is_empty():
		return true
	var top : RigidBody3D = _stack.back()
	return disc.disc_radius < top.disc_radius

## Y position for the next disc placed on this peg.
func next_stack_y() -> float:
	return _get_surface_y() + DISC_HEIGHT * 0.5 + _stack.size() * DISC_HEIGHT

## Place a disc on this peg (assumes can_accept was checked).
func place_disc(disc: RigidBody3D) -> void:
	var y := next_stack_y()
	_stack.append(disc)
	disc.snap_to(self, y)

## Remove the disc from the stack (only the top disc should be removed).
func remove_disc(disc: RigidBody3D) -> void:
	if disc in _stack:
		_stack.erase(disc)

## Is this disc the topmost on the peg?
func is_top(disc: RigidBody3D) -> bool:
	if _stack.is_empty():
		return false
	return _stack.back() == disc

## How many discs are currently on this peg?
func disc_count() -> int:
	return _stack.size()

func get_top_disc() -> RigidBody3D:
	if _stack.is_empty():
		return null
	return _stack.back()
