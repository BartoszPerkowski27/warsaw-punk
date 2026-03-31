## player_unit.gd
extends "res://Unit.gd"

enum State { WAITING, SELECTING_MOVE, MOVING, SELECTING_ATTACK, ATTACKING, DONE }

var state: State = State.WAITING
var highlight_nodes: Array = []

@export var highlight_scene: PackedScene
@export var camera_path: NodePath
var camera: Camera3D

func _ready() -> void:
	super._ready()
	if camera_path:
		camera = get_node_or_null(camera_path)
	if camera == null:
		# Znajdź kamerę automatycznie jeśli nie ustawiono ścieżki
		camera = get_viewport().get_camera_3d()
	print("[Player] Kamera: %s" % ("OK" if camera else "BRAK - kliknięcie nie zadziała!"))
	print("[Player] GridManager: %s" % ("OK" if grid_manager else "BRAK!"))
	print("[Player] W grupie players: %s" % is_in_group("players"))

func _unhandled_input(event: InputEvent) -> void:
	if not is_active:
		return

	if event.is_action_pressed("ui_cancel"):
		_cancel_action()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var clicked_cell: Vector2i = _raycast_to_grid()
		print("[Player] Kliknięto komórkę: %s, stan: %s" % [clicked_cell, State.keys()[state]])
		if clicked_cell == Vector2i(-1, -1):
			return
		match state:
			State.SELECTING_MOVE:
				_try_move(clicked_cell)
			State.SELECTING_ATTACK:
				_try_attack(clicked_cell)

	if event.is_action_pressed("ui_accept"):
		if state != State.WAITING and state != State.MOVING and state != State.ATTACKING:
			end_turn()

func start_turn() -> void:
	print("[Player] start_turn() wywołane!")
	super.start_turn()
	state = State.SELECTING_MOVE
	_show_reachable_cells()

func end_turn() -> void:
	state = State.DONE
	_clear_highlights()
	super.end_turn()

func _cancel_action() -> void:
	_clear_highlights()
	state = State.SELECTING_MOVE
	_show_reachable_cells()

func _show_reachable_cells() -> void:
	_clear_highlights()
	if has_moved:
		_show_attack_targets()
		return
	var reachable: Array = grid_manager.get_reachable_cells(grid_pos, move_range)
	print("[Player] Dostępne pola ruchu: %d" % reachable.size())
	_spawn_highlights(reachable, Color(0.2, 0.6, 1.0, 0.6))

func _try_move(target_cell: Vector2i) -> void:
	var reachable: Array = grid_manager.get_reachable_cells(grid_pos, move_range)
	if target_cell not in reachable:
		print("[Player] Pole %s poza zasięgiem" % target_cell)
		return
	state = State.MOVING
	_clear_highlights()
	await move_to_cell(target_cell)
	state = State.SELECTING_ATTACK
	_show_attack_targets()

func _show_attack_targets() -> void:
	_clear_highlights()
	if has_attacked:
		return
	var targets: Array = _get_enemies_in_range()
	print("[Player] Wrogowie w zasięgu ataku: %d" % targets.size())
	var cells: Array = []
	for t in targets:
		cells.append(t.grid_pos)
	_spawn_highlights(cells, Color(1.0, 0.2, 0.2, 0.7))

func _try_attack(target_cell: Vector2i) -> void:
	if has_attacked:
		return
	var target: Node = grid_manager.get_unit_at(target_cell)
	if target == null or target == self:
		return
	if not target.is_in_group("enemies"):
		return
	state = State.ATTACKING
	_clear_highlights()
	await attack_unit(target)
	state = State.DONE
	print("[Gracz] Naciśnij Enter/Space aby zakończyć turę")

func _get_enemies_in_range() -> Array:
	var enemies: Array = []
	for dx in range(-attack_range, attack_range + 1):
		for dy in range(-attack_range, attack_range + 1):
			if abs(dx) + abs(dy) > attack_range:
				continue
			var cell: Vector2i = grid_pos + Vector2i(dx, dy)
			var unit: Node = grid_manager.get_unit_at(cell)
			if unit != null and unit != self and unit.is_in_group("enemies"):
				enemies.append(unit)
	return enemies

func _spawn_highlights(cells: Array, color: Color) -> void:
	if highlight_scene == null:
		return
	for cell: Vector2i in cells:
		var node: Node3D = highlight_scene.instantiate()
		get_parent().add_child(node)
		node.global_position = grid_manager.grid_to_world(cell)
		highlight_nodes.append(node)

func _clear_highlights() -> void:
	for node in highlight_nodes:
		node.queue_free()
	highlight_nodes.clear()

func _raycast_to_grid() -> Vector2i:
	if camera == null:
		push_warning("[Player] Brak kamery!")
		return Vector2i(-1, -1)
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var ray_from: Vector3 = camera.project_ray_origin(mouse_pos)
	var ray_dir: Vector3 = camera.project_ray_normal(mouse_pos)
	if abs(ray_dir.y) < 0.001:
		return Vector2i(-1, -1)
	var t: float = -ray_from.y / ray_dir.y
	if t < 0:
		return Vector2i(-1, -1)
	var hit_point: Vector3 = ray_from + ray_dir * t
	return grid_manager.world_to_grid(hit_point)
