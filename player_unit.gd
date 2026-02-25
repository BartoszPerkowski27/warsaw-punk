extends CharacterBody3D

var movement_points = 1
var action_points = 1
var is_active = false

@onready var grid_map = get_node("/root/Node3D/GridMap")  # dostosuj ścieżkę!

@export var max_movement_points = 1
@export var max_action_points = 1

func start_turn():
	is_active = true
	movement_points = max_movement_points
	action_points = max_action_points

func _input(event):
	# reaguj tylko gdy aktywna tura gracza
	if not is_active:
		return
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		try_move_to_mouse()

func try_move_to_mouse():
	if movement_points <= 0:
		print("Brak punktów ruchu!")
		return
	
	# rzuć promień z kamery w miejsce kliknięcia
	var camera = get_viewport().get_camera_3d()
	var mouse_pos = get_viewport().get_mouse_position()
	
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_end = ray_origin + camera.project_ray_normal(mouse_pos) * 1000
	
	var space = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collision_mask = 1
	query.exclude = [self]

	var result = space.intersect_ray(query)

	if result:
		var hit_pos = result.position
		var local_pos = grid_map.to_local(hit_pos)
		var cell = grid_map.local_to_map(local_pos)
		move_to_cell(cell)


func move_to_cell(cell: Vector3i):
	# sprawdź czy komórka ma kafelek (czyli istnieje)
	if grid_map.get_cell_item(cell) == GridMap.INVALID_CELL_ITEM:
		print("Pusta komórka!")
		return
	
	move() # zużyj punkt ruchu
	
	# pobierz pozycję środka komórki i przesuń postać
	var target_pos = grid_map.map_to_local(cell)
	target_pos.y = position.y  # zachowaj wysokość postaci
	
	# płynny ruch przez Tween
	var tween = create_tween()
	tween.tween_property(self, "position", target_pos, 0.3)

func move():
	movement_points -= 1
	
func end_turn():
	print("Tura gracza zakończona")
	is_active = false
