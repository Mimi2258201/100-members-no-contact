extends Node

# Persistent meta-progression: coins earned in battle and the permanent upgrade
# levels bought with them. Saved to disk so it survives quitting. Battles bank
# coins here; the garage spends them; AutoTop.apply() reads the levels on launch.

const SAVE_PATH := "user://progress.save"

# upgrade id -> tuning. per_level is what one level adds to the stat.
const DEFS := {
	"flywheel": {"name": "Heavier Flywheel", "desc": "+12 max spin", "base_cost": 8, "cost_step": 6, "max_level": 6, "per_level": 12.0},
	"motor": {"name": "Overclocked Motor", "desc": "+70 top speed", "base_cost": 8, "cost_step": 6, "max_level": 6, "per_level": 70.0},
	"blade": {"name": "Sharper Blade", "desc": "+0.35 dmg, +14 dash", "base_cost": 10, "cost_step": 8, "max_level": 6, "per_level": 1.0},
	"frame": {"name": "Reinforced Frame", "desc": "+30 max HP", "base_cost": 10, "cost_step": 8, "max_level": 6, "per_level": 30.0},
}
const ORDER := ["flywheel", "motor", "blade", "frame"]

signal changed

var coins: int = 0
var upgrades: Dictionary = {}

func _ready() -> void:
	load_progress()

func level(id: String) -> int:
	return int(upgrades.get(id, 0))

func cost(id: String) -> int:
	var d: Dictionary = DEFS[id]
	return int(d.base_cost) + int(d.cost_step) * level(id)

func is_maxed(id: String) -> bool:
	return level(id) >= int(DEFS[id].max_level)

func can_buy(id: String) -> bool:
	return DEFS.has(id) and not is_maxed(id) and coins >= cost(id)

func buy(id: String) -> bool:
	if not can_buy(id):
		return false
	coins -= cost(id)
	upgrades[id] = level(id) + 1
	save_progress()
	changed.emit()
	return true

func add_coins(amount: int) -> void:
	if amount <= 0:
		return
	coins += amount
	save_progress()
	changed.emit()

# applied to an AutoTop before its base _ready sets _health, so HP starts full
func apply(top: Player) -> void:
	var lvl := func(id): return float(level(id))
	top.spin_cap += DEFS.flywheel.per_level * lvl.call("flywheel")
	top.starting_spin_velocity += DEFS.flywheel.per_level * lvl.call("flywheel")
	top.max_top_speed += DEFS.motor.per_level * lvl.call("motor")
	top.enemy_damage_factor += 0.35 * lvl.call("blade")
	top.dash_damage += 14.0 * lvl.call("blade")
	top.max_health += DEFS.frame.per_level * lvl.call("frame")

func save_progress() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_var({"coins": coins, "upgrades": upgrades})

func load_progress() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var data = f.get_var()
	if data is Dictionary:
		coins = int(data.get("coins", 0))
		upgrades = data.get("upgrades", {})
