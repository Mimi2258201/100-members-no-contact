extends Node2D

#This is the garage's code, want to buy upgrades? this is the spot!(Deck building part) - Made by cube
#How can we buy stuff? I was thinking enemies would drop some sort of coins/parts that we can use
#Currently the shop does nothing its only an extra scene

# Coins now come from the auto-battler (Progress store); the cards below spend them
# on permanent upgrades that apply to your top in every battle. - veroz

@onready var _cards: VBoxContainer = $CanvasLayer/CardsContainer

var _coins_label: Label
var _buttons: Dictionary = {} # upgrade id -> Button

func _ready() -> void:
	_build_shop()
	Progress.changed.connect(_refresh)
	_refresh()

func _build_shop() -> void:
	_coins_label = Label.new()
	_coins_label.position = Vector2(20, 16)
	_coins_label.add_theme_font_size_override("font_size", 26)
	$CanvasLayer.add_child(_coins_label)

	var battle := Button.new()
	battle.text = "BATTLE!"
	battle.position = Vector2(20, 58)
	battle.custom_minimum_size = Vector2(200, 48)
	battle.pressed.connect(_on_battle_pressed)
	$CanvasLayer.add_child(battle)

	# reuse cube's placeholder card buttons, adding more rows if there are extra upgrades
	var existing := _cards.get_children()
	for i in Progress.ORDER.size():
		var id: String = Progress.ORDER[i]
		var btn: Button
		if i < existing.size() and existing[i] is Button:
			btn = existing[i]
		else:
			btn = Button.new()
			_cards.add_child(btn)
		btn.pressed.connect(_on_buy_pressed.bind(id))
		_buttons[id] = btn

func _refresh() -> void:
	_coins_label.text = "COINS: %d" % Progress.coins
	for id in _buttons:
		var btn: Button = _buttons[id]
		var d: Dictionary = Progress.DEFS[id]
		if Progress.is_maxed(id):
			btn.text = "%s  (MAX)" % d.name
			btn.disabled = true
		else:
			btn.text = "%s  Lv.%d   %s   —   %d coins" % [d.name, Progress.level(id), d.desc, Progress.cost(id)]
			btn.disabled = not Progress.can_buy(id)

func _on_buy_pressed(id: String) -> void:
	Progress.buy(id) # the changed signal re-runs _refresh

func _on_battle_pressed() -> void:
	SceneManager.change_screen(SceneManager.SceneKey.AUTO_BATTLE)


func _on_leave_pressed() -> void:
	#I did not understand how you make it so you can enter and leave on the same spot, so
	#for now i am just using the change scene func
	SceneManager.change_screen(SceneManager.SceneKey.GREEN_FIELD) # Replace with function body.
