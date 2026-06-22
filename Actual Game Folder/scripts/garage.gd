extends Node2D

#This is the garage's code, want to buy upgrades? this is the spot!(Deck building part) - Made by cube
#How can we buy stuff? I was thinking enemies would drop some sort of coins/parts that we can use
#Currently the shop does nothing its only an extra scene

#var purchase_made := true

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func _on_leave_pressed() -> void:
	SceneManager.pop_scene()

# makes the mechanic animated sprite2d change to show the smiling frame (not working yet)
#func shopkeep_smile():
	#if purchase_made == true:
		#$"after purchase smile timer".start()
		#print("smile")
		#$"CanvasLayer/TextureRect/mechanic animiated sprite2d".frame = 2
#
#
#func _on_after_purchase_smile_timer_timeout() -> void:
	#$"CanvasLayer/TextureRect/mechanic animiated sprite2d".frame = 0
