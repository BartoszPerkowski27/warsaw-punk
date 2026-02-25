extends Node

enum State { PLAYER_TURN, ENEMY_TURN }

var current_state = State.PLAYER_TURN
var units = []         # lista wszystkich jednostek
var current_unit_index = 0

func _ready():
	units = get_tree().get_nodes_in_group("units")
	start_turn()

func start_turn():
	var unit = units[current_unit_index]
	unit.start_turn()  # każda jednostka ma swoją metodę start_turn()
	
func end_turn():
	current_unit_index = (current_unit_index + 1) % units.size()
	start_turn()
