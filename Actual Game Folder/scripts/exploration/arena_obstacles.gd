extends Node

# scatters random obstacle blobs into the arena tilemap on battle start
@export var tilemap_path: NodePath
@export var source_id: int = 1
@export var obstacle_tile: Vector2i = Vector2i(4, 23)
@export var count: int = 5
@export var blob: int = 2 # obstacle size in cells
@export var interior_half: Vector2i = Vector2i(20, 10) # open area half-extent in cells
@export var edge_margin: int = 3 # keep off the walls
@export var safe_radius: int = 5 # keep the player spawn clear

func _ready() -> void:
	var tml := get_node_or_null(tilemap_path) as TileMapLayer
	if tml == null:
		return
	var placed := 0
	var tries := 0
	while placed < count and tries < count * 30:
		tries += 1
		var ox := randi_range(-interior_half.x + edge_margin, interior_half.x - edge_margin - blob)
		var oy := randi_range(-interior_half.y + edge_margin, interior_half.y - edge_margin - blob)
		if abs(ox) <= safe_radius and abs(oy) <= safe_radius:
			continue
		for dx in blob:
			for dy in blob:
				tml.set_cell(Vector2i(ox + dx, oy + dy), source_id, obstacle_tile)
		placed += 1
