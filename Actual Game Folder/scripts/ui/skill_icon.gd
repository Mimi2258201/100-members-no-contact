extends Control
class_name SkillIcon

enum Icon { DASH }

const HOTKEY_STRIP := 14.0

var _icon: int = Icon.DASH
var _fill: float = 1.0
var _locked: bool = false
var _key_label: Label

func _ready() -> void:
	custom_minimum_size = Vector2(48, 48)
	clip_contents = true
	_key_label = Label.new()
	_key_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_key_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_key_label.add_theme_font_size_override("font_size", 8)
	_key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_key_label.offset_bottom = -2.0
	add_child(_key_label)

func setup(hotkey: String, icon_kind: int) -> void:
	_icon = icon_kind
	if _key_label:
		_key_label.text = hotkey
	queue_redraw()

func set_state(fill: float, locked: bool) -> void:
	_fill = clampf(fill, 0.0, 1.0)
	_locked = locked
	if _key_label:
		_key_label.modulate = _icon_color()
	queue_redraw()

func _accent() -> Color:
	if _locked:
		return Color(0.85, 0.3, 0.3)
	if _fill < 1.0:
		return Color(0.55, 0.6, 0.7)
	return Color(0.35, 0.95, 0.5)

func _icon_color() -> Color:
	if _locked:
		return Color(1.0, 0.7, 0.7)
	if _fill < 1.0:
		return Color(0.8, 0.85, 0.9, 0.7)
	return Color(1.0, 1.0, 1.0)

func _draw() -> void:
	var sz := size
	var accent := _accent()
	draw_rect(Rect2(Vector2.ZERO, sz), Color(0.12, 0.13, 0.17, 0.9), true)
	if not _locked and _fill >= 1.0:
		draw_rect(Rect2(Vector2.ZERO, sz), Color(accent.r, accent.g, accent.b, 0.2), true)
	_draw_glyph(sz, _icon_color())
	if _fill < 1.0:
		var center := sz * 0.5
		var radius := sz.length()
		var remaining := (1.0 - _fill) * TAU
		var pts := PackedVector2Array([center])
		var steps := 36
		for i in steps + 1:
			var a := -PI / 2.0 + remaining * (float(i) / float(steps))
			pts.append(center + Vector2(cos(a), sin(a)) * radius)
		draw_colored_polygon(pts, Color(0, 0, 0, 0.5))
	draw_rect(Rect2(Vector2.ZERO, sz), accent, false, 2.0)

func _draw_glyph(sz: Vector2, col: Color) -> void:
	match _icon:
		Icon.DASH:
			_draw_dash_glyph(sz, col)

func _draw_dash_glyph(sz: Vector2, col: Color) -> void:
	var cx := sz.x * 0.5
	var cy := (sz.y - HOTKEY_STRIP) * 0.5 # center above the hotkey badge
	var hh := sz.y * 0.17
	var cw := sz.x * 0.18
	var gap := sz.x * 0.16
	# total glyph spans (gap + cw); center that span on cx
	var left := cx - (gap + cw) * 0.5
	for i in 2:
		var tip := left + cw + i * gap
		draw_polyline(PackedVector2Array([
			Vector2(tip - cw, cy - hh),
			Vector2(tip, cy),
			Vector2(tip - cw, cy + hh),
		]), col, 3.0, true)
