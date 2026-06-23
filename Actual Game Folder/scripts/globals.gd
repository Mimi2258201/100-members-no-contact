extends Node

var current_screen: String = "menu"

var has_beyblade: bool = false

var spin_dash: bool = false
var broken_walls: Dictionary = {}

func mark_wall_broken(id: String) -> void:
	broken_walls[id] = true

func is_wall_broken(id: String) -> bool:
	return broken_walls.has(id)

var defeated_enemies: Dictionary = {}

func mark_enemy_defeated(id: String) -> void:
	defeated_enemies[id] = true

func is_enemy_defeated(id: String) -> bool:
	return defeated_enemies.has(id)

## inventory system framework by sonicjb08 
var inventory_general : Array = []
signal inventory_updated

var player_node : Node = null

func _ready():
	inventory_general.resize(100)


func remove_item():
	inventory_updated.emit()


func add_item(item):
	for i in range (inventory_general.size()):
		if inventory_general[i] != null and inventory_general[i]["type"] == item["type"] and inventory_general[i]["effect"] == item["effect"]:
			inventory_general[i]["quantity"] += item["quantity"]
			inventory_updated.emit()
			return true
		elif inventory_general[i] == null:
			inventory_general[i] = item
			inventory_updated.emit()
			return true
		return false

func player_reference(player):
	player_node = player
