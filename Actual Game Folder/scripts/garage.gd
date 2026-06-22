extends Node2D

#This is the garage's code, want to buy upgrades? this is the spot!(Deck building part) - Made by cube
#How can we buy stuff? I was thinking enemies would drop some sort of coins/parts that we can use
#Currently the shop does nothing its only an extra scene


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func _on_leave_pressed() -> void:
	#I did not understand how you make it so you can enter and leave on the same spot, so 
	#for now i am just using the change scene func
	SceneManager.change_screen(SceneManager.SceneKey.GREEN_FIELD) # Replace with function body.
