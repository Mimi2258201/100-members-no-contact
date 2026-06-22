extends CanvasLayer

const WIPE_SHADER := preload("res://Actual Game Folder/shaders/circle_wipe.gdshader")
const OPEN_RADIUS := 1.1
const CLOSED_RADIUS := 0.0

var _rect: ColorRect
var _mat: ShaderMaterial

func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	_mat = ShaderMaterial.new()
	_mat.shader = WIPE_SHADER
	_mat.set_shader_parameter("radius", OPEN_RADIUS)
	_rect = ColorRect.new()
	_rect.color = Color.BLACK
	_rect.material = _mat
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.visible = false
	add_child(_rect)

func cover(duration: float = 0.55) -> void:
	_rect.visible = true
	_set_radius(OPEN_RADIUS)
	var tw := create_tween()
	tw.tween_method(_set_radius, OPEN_RADIUS, CLOSED_RADIUS, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await tw.finished

func reveal(duration: float = 0.6) -> void:
	_rect.visible = true
	_set_radius(CLOSED_RADIUS)
	var tw := create_tween()
	tw.tween_method(_set_radius, CLOSED_RADIUS, OPEN_RADIUS, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tw.finished
	_rect.visible = false

func _set_radius(r: float) -> void:
	_mat.set_shader_parameter("radius", r)
