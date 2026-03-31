## grid_manager.gd
## Dołącz do Node w scenie głównej. Zarządza siatką, zajętością i A*.
## Ustaw rozmiar gridu przez eksportowane zmienne.

class_name GridManager
extends Node

signal cell_highlighted(cell: Vector2i)
signal path_calculated(path: Array[Vector2i])

@export var grid_width: int = 10
@export var grid_height: int = 10
@export var cell_size: float = 1.0          # rozmiar kafelka w jednostkach świata

## Kafelki zablokowane (ściany, przeszkody) — ustaw ręcznie lub wczytaj z GridMap
var blocked_cells: Dictionary = {}          # Vector2i -> true
## Mapa zajętości: Vector2i -> Unit (null jeśli wolne)
var occupancy: Dictionary = {}

# ─── Konwersja współrzędnych ──────────────────────────────────────────────────

func world_to_grid(world_pos: Vector3) -> Vector2i:
	return Vector2i(
		int(floor(world_pos.x / cell_size)),
		int(floor(world_pos.z / cell_size))
	)

func grid_to_world(cell: Vector2i) -> Vector3:
	return Vector3(
		(cell.x + 0.5) * cell_size,
		0.0,
		(cell.y + 0.5) * cell_size
	)

# ─── Zapytania o siatkę ───────────────────────────────────────────────────────

func is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < grid_width and cell.y >= 0 and cell.y < grid_height

func is_walkable(cell: Vector2i) -> bool:
	return is_in_bounds(cell) and not blocked_cells.has(cell) and not occupancy.has(cell)

func is_walkable_ignore_unit(cell: Vector2i, ignore_unit) -> bool:
	"""Ignoruje jednostkę przy sprawdzaniu wolności pola (np. AI sprawdza dojście do gracza)."""
	if not is_in_bounds(cell) or blocked_cells.has(cell):
		return false
	var occ = occupancy.get(cell)
	return occ == null or occ == ignore_unit

func get_neighbors(cell: Vector2i) -> Array[Vector2i]:
	var dirs: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0),
		Vector2i(0, 1), Vector2i(0, -1)
	]
	var result: Array[Vector2i] = []
	for d in dirs:
		var n := cell + d
		if is_in_bounds(n):
			result.append(n)
	return result

# ─── Zajętość ─────────────────────────────────────────────────────────────────

func occupy(cell: Vector2i, unit) -> void:
	occupancy[cell] = unit

func free_cell(cell: Vector2i) -> void:
	occupancy.erase(cell)

func get_unit_at(cell: Vector2i):
	return occupancy.get(cell, null)

# ─── Zasięg ruchu (BFS) ───────────────────────────────────────────────────────

func get_reachable_cells(origin: Vector2i, move_range: int) -> Array[Vector2i]:
	var visited: Dictionary = {}
	var queue: Array = [[origin, 0]]
	var result: Array[Vector2i] = []

	visited[origin] = true

	while not queue.is_empty():
		var current = queue.pop_front()
		var cell: Vector2i = current[0]
		var dist: int = current[1]

		if dist > 0:
			result.append(cell)

		if dist >= move_range:
			continue

		for neighbor in get_neighbors(cell):
			if not visited.has(neighbor) and is_walkable(neighbor):
				visited[neighbor] = true
				queue.append([neighbor, dist + 1])

	return result

# ─── Pathfinding A* ──────────────────────────────────────────────────────────

func find_path(from: Vector2i, to: Vector2i, ignore_unit = null) -> Array[Vector2i]:
	"""Zwraca ścieżkę (bez punktu startowego) lub pustą tablicę gdy niedostępne."""
	if from == to:
		return []

	var open: Dictionary = {}         # cell -> {g, f, parent}
	var closed: Dictionary = {}

	var start_node := {"g": 0, "f": _heuristic(from, to), "parent": null}
	open[from] = start_node

	while not open.is_empty():
		# Znajdź węzeł z najmniejszym f
		var current: Vector2i
		var best_f := INF
		for cell in open:
			if open[cell]["f"] < best_f:
				best_f = open[cell]["f"]
				current = cell

		if current == to:
			return _reconstruct_path(open, closed, current, from)

		var node = open[current]
		open.erase(current)
		closed[current] = node

		for neighbor in get_neighbors(current):
			if closed.has(neighbor):
				continue

			var walkable := (
				ignore_unit != null and is_walkable_ignore_unit(neighbor, ignore_unit)
			) or (ignore_unit == null and (is_walkable(neighbor) or neighbor == to))

			if not walkable:
				continue

			var g_new: int = node["g"] + 1
			if open.has(neighbor) and open[neighbor]["g"] <= g_new:
				continue

			open[neighbor] = {"g": g_new, "f": g_new + _heuristic(neighbor, to), "parent": current}

	return []  # brak ścieżki

func _heuristic(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)

func _reconstruct_path(open: Dictionary, closed: Dictionary, end: Vector2i, start: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var current := end
	var all_nodes := open.merged(closed)

	while current != start:
		path.push_front(current)
		var parent = all_nodes[current]["parent"]
		if parent == null:
			break
		current = parent

	return path
