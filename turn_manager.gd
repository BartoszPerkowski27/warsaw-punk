## turn_manager.gd

extends Node

signal turn_started(unit: Node)
signal round_started(round_number: int)
signal combat_ended(winner: String)

@export var auto_collect_units: bool = true
@export var start_delay: float = 0.5

var units: Array = []
var current_index: int = -1
var current_round: int = 0
var combat_active: bool = false

func _ready() -> void:
	await get_tree().create_timer(start_delay).timeout
	if auto_collect_units:
		_collect_units_from_groups()
	print("[TurnManager] Znaleziono jednostek: %d" % units.size())
	for u in units:
		print("  - %s (gracz: %s)" % [u.unit_name, u.is_in_group("players")])
	start_combat()

func _collect_units_from_groups() -> void:
	for node in get_tree().get_nodes_in_group("players"):
		if node.has_method("start_turn"):
			add_unit(node)
	for node in get_tree().get_nodes_in_group("enemies"):
		if node.has_method("start_turn"):
			add_unit(node)

func add_unit(unit: Node) -> void:
	units.append(unit)
	# Sygnały bez parametrów — używamy Callable z bind()
	unit.turn_ended.connect(_on_unit_turn_ended.bind(unit))
	unit.died.connect(_on_unit_died.bind(unit))

func start_combat() -> void:
	if units.is_empty():
		push_warning("[TurnManager] Brak jednostek! Sprawdź grupy 'players' i 'enemies'.")
		return
	combat_active = true
	current_round = 0
	current_index = -1
	print("[TurnManager] Start walki!")
	_next_turn()

func _next_turn() -> void:
	if not combat_active:
		return
	units = units.filter(func(u): return u.has_method("is_alive") and u.is_alive())
	if _check_combat_end():
		return
	current_index = (current_index + 1) % units.size()
	if current_index == 0:
		current_round += 1
		emit_signal("round_started", current_round)
		print("─── Runda %d ───" % current_round)
	var active_unit: Node = units[current_index]
	print("[TurnManager] Tura: %s" % active_unit.unit_name)
	emit_signal("turn_started", active_unit)
	active_unit.start_turn()

func _on_unit_turn_ended(unit: Node) -> void:
	print("[TurnManager] Zakończono turę: %s" % unit.unit_name)
	if unit == current_unit():
		_next_turn()

func _on_unit_died(unit: Node) -> void:
	print("[TurnManager] %s pokonany!" % unit.unit_name)

func _check_combat_end() -> bool:
	var players_alive: Array = units.filter(func(u): return u.is_in_group("players"))
	var enemies_alive: Array = units.filter(func(u): return u.is_in_group("enemies"))
	if players_alive.is_empty():
		_end_combat("enemy")
		return true
	if enemies_alive.is_empty():
		_end_combat("player")
		return true
	return false

func _end_combat(winner: String) -> void:
	combat_active = false
	emit_signal("combat_ended", winner)
	print("=== %s ===" % ("ZWYCIĘSTWO!" if winner == "player" else "GAME OVER"))

func current_unit() -> Node:
	if units.is_empty() or current_index < 0:
		return null
	return units[current_index]
