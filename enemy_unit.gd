## enemy_unit.gd
extends "res://Unit.gd"

enum AIBehavior { AGGRESSIVE, DEFENSIVE, PATROL }

@export var ai_behavior: AIBehavior = AIBehavior.AGGRESSIVE
@export var aggro_range: int = 6
@export var patrol_waypoints: Array = []

var _patrol_index: int = 0

# ─── Tura AI ─────────────────────────────────────────────────────────────────

func start_turn() -> void:
	super.start_turn()
	await get_tree().create_timer(0.4).timeout
	await _execute_ai()
	end_turn()

func _execute_ai() -> void:
	var target: Node = _find_nearest_player()
	if target == null:
		return
	match ai_behavior:
		AIBehavior.AGGRESSIVE:
			await _ai_aggressive(target)
		AIBehavior.DEFENSIVE:
			await _ai_defensive(target)
		AIBehavior.PATROL:
			await _ai_patrol(target)

# ─── Strategie ────────────────────────────────────────────────────────────────

func _ai_aggressive(target: Node) -> void:
	if not has_attacked and _in_range_of(target):
		await attack_unit(target)
	elif not has_moved:
		var dest: Vector2i = _best_move_toward(target)
		if dest != grid_pos:
			await move_to_cell(dest)
		if not has_attacked and _in_range_of(target):
			await attack_unit(target)

func _ai_defensive(target: Node) -> void:
	var dist: int = _manhattan(grid_pos, target.grid_pos)
	if dist > aggro_range:
		return
	await _ai_aggressive(target)

func _ai_patrol(target: Node) -> void:
	if not has_attacked and _in_range_of(target):
		await attack_unit(target)
		return
	if patrol_waypoints.is_empty() or has_moved:
		return
	var wp: Vector2i = patrol_waypoints[_patrol_index]
	var path: Array = grid_manager.find_path(grid_pos, wp, self)
	if path.is_empty() or grid_pos == wp:
		_patrol_index = (_patrol_index + 1) % patrol_waypoints.size()
		return
	var steps: int = min(move_range, path.size())
	var dest: Vector2i = path[steps - 1]
	await move_to_cell(dest)
	if grid_pos == wp:
		_patrol_index = (_patrol_index + 1) % patrol_waypoints.size()

# ─── Pomocnicze ───────────────────────────────────────────────────────────────

func _find_nearest_player() -> Node:
	var nearest: Node = null
	var nearest_dist: int = 999999
	for node in get_tree().get_nodes_in_group("players"):
		if node.has_method("is_alive") and node.is_alive():
			var d: int = _manhattan(grid_pos, node.grid_pos)
			if d < nearest_dist:
				nearest_dist = d
				nearest = node
	return nearest

func _best_move_toward(target: Node) -> Vector2i:
	var reachable: Array = grid_manager.get_reachable_cells(grid_pos, move_range)
	if reachable.is_empty():
		return grid_pos
	var best_cell: Vector2i = grid_pos
	var best_dist: int = _manhattan(grid_pos, target.grid_pos)
	for cell: Vector2i in reachable:
		var d: int = _manhattan(cell, target.grid_pos)
		if d < best_dist:
			best_dist = d
			best_cell = cell
	return best_cell

func _in_range_of(target: Node) -> bool:
	var dist: int = abs(grid_pos.x - target.grid_pos.x) + abs(grid_pos.y - target.grid_pos.y)
	return dist <= attack_range

func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)
