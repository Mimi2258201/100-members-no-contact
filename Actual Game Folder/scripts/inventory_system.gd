@tool
extends Node

## framework by sonicjb08
## i'll try to integrate the armor system with the garage after the basic system gets merged

@export var item_type := ""
@export var item_name := ""
@export var item_texture : Texture
@export var item_effect := ""

var scene_path := "res://Actual Game Folder/scripts/inventory_system.gd"

@onready var item_sprite = $"item sprite"

var player_in_interact_range = false

func pickup_item():
	# item properties
	var item = {
		"quantity" : 1,
		"name" : item_name,
		"type" : item_type,
		"texture" : item_texture,
		"effect" : item_effect,
		"scene_path" : scene_path
	}
	# adds item to inventory if player interacts with it
	if Globals.player_node:
		Globals.add_item(item)
		print(Globals.inventory_general)
		self.queue_free()


func _ready() -> void:
	# sets the texture in game
	if not Engine.is_editor_hint():
		item_sprite.texture = item_texture


func _process(delta: float) -> void:
	# sets the texture in the editor
	if Engine.is_editor_hint():
		item_sprite.texture = item_texture
	if player_in_interact_range and Input.is_action_just_pressed("interact"):
		pickup_item()

# if player is in range, make item interactable
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_interact_range = true
		body.interact_UI.visible = true

# if player is outside of range, make item not interactable
func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_interact_range = false
		body.interact_UI.visible = false
