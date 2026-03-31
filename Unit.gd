## unit.gd
class_name BaseUnit
extends CharacterBody3D

signal died
signal turn_ended
signal hp_changed(current: int, maximum: int)
signal moved_to(cell: Vector2i)

@export_group("Stats")
@export var unit_name: String = "Unit"
@export var max_hp: int = 10
@export var attack_power: int = 3
@export var defense: int = 1
@export var move_range: int = 4
@export var attack_range: int = 1

@export_group("References")
@export var grid_manager_path: NodePath

var current_hp: int
var grid_pos: Vector2i
var has_moved: bool = false
var has_attacked: bool = false
var is_active: bool = false
var grid_manager: Node

@onready var anim_player: AnimationPlayer = $AnimationPlayer if has_node("AnimationPlayer") else null

func _ready() -> void:
	grid_manager = get_node("/root/GridManager")
	current_hp = max_hp
	grid_pos = grid_manager.world_to_grid(global_position)
	grid_manager.occupy(grid_pos, self)

func move_to_cell(target_cell: Vector2i) -> void:
	if has_moved:
		return
	var path: Array = grid_manager.find_path(grid_pos, target_cell, self)
	if path.is_empty():
		return
	has_moved = true
	grid_manager.free_cell(grid_pos)
	for cell: Vector2i in path:
		var world_target: Vector3 = grid_manager.grid_to_world(cell)
		world_target.y = global_position.y  # zachowaj wysoko015b0107 pod0142ogi z GridMap
		var tween: Tween = create_tween()
		tween.tween_property(self, "global_position", world_target, 0.18)
		await tween.finished
	grid_pos = target_cell
	grid_manager.occupy(grid_pos, self)
	emit_signal("moved_to", grid_pos)
	_play_anim("idle")

func attack_unit(target: Node) -> void:
	if has_attacked:
		return
	if not _in_attack_range_of(target):
		return
	has_attacked = true
	_play_anim("attack")
	await get_tree().create_timer(0.3).timeout
	var damage: int = max(0, attack_power - int(target.get("defense")))
	target.take_damage(damage)
	print("%s atakuje %s za %d obrażeń" % [unit_name, target.get("unit_name"), damage])

func take_damage(amount: int) -> void:
	current_hp = max(0, current_hp - amount)
	emit_signal("hp_changed", current_hp, max_hp)
	_play_anim("hurt")
	if current_hp <= 0:
		_die()

func _in_attack_range_of(target: Node) -> bool:
	var target_pos: Vector2i = target.get("grid_pos")
	var dist: int = abs(grid_pos.x - target_pos.x) + abs(grid_pos.y - target_pos.y)
	return dist <= attack_range

func is_alive() -> bool:
	return current_hp > 0

func start_turn() -> void:
	has_moved = false
	has_attacked = false
	is_active = true
	_play_anim("idle")
	print("=== Tura: %s ===" % unit_name)

func end_turn() -> void:
	is_active = false
	emit_signal("turn_ended")

func _die() -> void:
	grid_manager.free_cell(grid_pos)
	emit_signal("died")
	_play_anim("death")
	await get_tree().create_timer(0.8).timeout
	queue_free()

func _play_anim(anim_name: String) -> void:
	if anim_player and anim_player.has_animation(anim_name):
		anim_player.play(anim_name)
