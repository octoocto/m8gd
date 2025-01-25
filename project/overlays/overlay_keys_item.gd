@tool
extends HBoxContainer

@export var pressed_u := false:
	set(value): pressed_u = value; _update()
@export var pressed_d := false:
	set(value): pressed_d = value; _update()
@export var pressed_l := false:
	set(value): pressed_l = value; _update()
@export var pressed_r := false:
	set(value): pressed_r = value; _update()
@export var pressed_o := false:
	set(value): pressed_o = value; _update()
@export var pressed_e := false:
	set(value): pressed_e = value; _update()
@export var pressed_s := false:
	set(value): pressed_s = value; _update()
@export var pressed_p := false:
	set(value): pressed_p = value; _update()

@export var pressed_times := 1:
	set(value): pressed_times = value; _update()

@export_category("Style: Background")

@export var style_background_enabled := true:
	set(value): style_background_enabled = value; _update()
@export var style_corner_radius := 4:
	set(value): style_corner_radius = value; _update()
@export var style_border_width_bottom := 2:
	set(value): style_border_width_bottom = value; _update()
@export var style_padding := Vector2i(8, -1):
	set(value): style_padding = value; _update()

@export_category("Style: Font")

@export var style_font_family := "":
	set(value): style_font_family = value; _update()
@export var style_font_weight := 400:
	set(value): style_font_weight = value; _update()
@export var style_font_size := 16:
	set(value): style_font_size = value; _update()

@export_category("Style: Colors")

@export var color_d := Color.WHITE:
	set(value): color_d = value; _update()
@export var color_o := Color.WHITE:
	set(value): color_o = value; _update()
@export var color_e := Color.WHITE:
	set(value): color_e = value; _update()
@export var color_s := Color.WHITE:
	set(value): color_s = value; _update()
@export var color_p := Color.WHITE:
	set(value): color_p = value; _update()

var _style_box: StyleBox
var _label_settings: LabelSettings

var keys_pressed := 0


func _ready() -> void:
	_update()
	
func _update() -> void:
	if not is_inside_tree(): return

	if style_background_enabled:
		_style_box = StyleBoxFlat.new()

		_style_box.anti_aliasing = false

		_style_box.corner_radius_bottom_left = style_corner_radius
		_style_box.corner_radius_bottom_right = style_corner_radius
		_style_box.corner_radius_top_left = style_corner_radius
		_style_box.corner_radius_top_right = style_corner_radius

		_style_box.border_width_bottom = style_border_width_bottom

		_style_box.content_margin_left = style_padding.x
		_style_box.content_margin_right = style_padding.x
		_style_box.content_margin_top = style_padding.y
		_style_box.content_margin_bottom = style_padding.y

	else:
		_style_box = StyleBoxEmpty.new()

	_label_settings = LabelSettings.new()
	_label_settings.font_size = style_font_size
	_label_settings.font = SystemFont.new()
	if style_font_family != "":
		_label_settings.font.font_names = [style_font_family]
	_label_settings.font.font_weight = style_font_weight

	var style_box_u := _style_box.duplicate()
	var style_box_d := _style_box.duplicate()
	var style_box_l := _style_box.duplicate()
	var style_box_r := _style_box.duplicate()
	var style_box_o := _style_box.duplicate()
	var style_box_e := _style_box.duplicate()
	var style_box_s := _style_box.duplicate()
	var style_box_p := _style_box.duplicate()

	var label_settings_u := _label_settings.duplicate()
	var label_settings_d := _label_settings.duplicate()
	var label_settings_l := _label_settings.duplicate()
	var label_settings_r := _label_settings.duplicate()
	var label_settings_o := _label_settings.duplicate()
	var label_settings_e := _label_settings.duplicate()
	var label_settings_s := _label_settings.duplicate()
	var label_settings_p := _label_settings.duplicate()

	if style_background_enabled:
		style_box_u.bg_color = color_d
		style_box_u.border_color = color_d.darkened(0.5)
		label_settings_u.font_color = Color.BLACK if color_d.get_luminance() > 0.5 else Color.WHITE
		style_box_d.bg_color = color_d
		style_box_d.border_color = color_d.darkened(0.5)
		label_settings_d.font_color = Color.BLACK if color_d.get_luminance() > 0.5 else Color.WHITE
		style_box_l.bg_color = color_d
		style_box_l.border_color = color_d.darkened(0.5)
		label_settings_l.font_color = Color.BLACK if color_d.get_luminance() > 0.5 else Color.WHITE
		style_box_r.bg_color = color_d
		style_box_r.border_color = color_d.darkened(0.5)
		label_settings_r.font_color = Color.BLACK if color_d.get_luminance() > 0.5 else Color.WHITE
		style_box_o.bg_color = color_o
		style_box_o.border_color = color_o.darkened(0.5)
		label_settings_o.font_color = Color.BLACK if color_o.get_luminance() > 0.5 else Color.WHITE
		style_box_e.bg_color = color_e
		style_box_e.border_color = color_e.darkened(0.5)
		label_settings_e.font_color = Color.BLACK if color_e.get_luminance() > 0.5 else Color.WHITE
		style_box_s.bg_color = color_s
		style_box_s.border_color = color_s.darkened(0.5)
		label_settings_s.font_color = Color.BLACK if color_s.get_luminance() > 0.5 else Color.WHITE
		style_box_p.bg_color = color_p
		style_box_p.border_color = color_p.darkened(0.5)
		label_settings_p.font_color = Color.BLACK if color_p.get_luminance() > 0.5 else Color.WHITE
	else:
		label_settings_u.font_color = _color_clamp_brightness(color_d)
		label_settings_d.font_color = _color_clamp_brightness(color_d)
		label_settings_l.font_color = _color_clamp_brightness(color_d)
		label_settings_r.font_color = _color_clamp_brightness(color_d)
		label_settings_o.font_color = _color_clamp_brightness(color_o)
		label_settings_e.font_color = _color_clamp_brightness(color_e)
		label_settings_s.font_color = _color_clamp_brightness(color_s)
		label_settings_p.font_color = _color_clamp_brightness(color_p)

	%Up.set("theme_override_styles/panel", style_box_u)
	%Down.set("theme_override_styles/panel", style_box_d)
	%Left.set("theme_override_styles/panel", style_box_l)
	%Right.set("theme_override_styles/panel", style_box_r)
	%Option.set("theme_override_styles/panel", style_box_o)
	%Edit.set("theme_override_styles/panel", style_box_e)
	%Shift.set("theme_override_styles/panel", style_box_s)
	%Play.set("theme_override_styles/panel", style_box_p)

	%Up.get_node("Label").label_settings = label_settings_u
	%Down.get_node("Label").label_settings = label_settings_d
	%Left.get_node("Label").label_settings = label_settings_l
	%Right.get_node("Label").label_settings = label_settings_r
	%Option.get_node("Label").label_settings = label_settings_o
	%Edit.get_node("Label").label_settings = label_settings_e
	%Shift.get_node("Label").label_settings = label_settings_s
	%Play.get_node("Label").label_settings = label_settings_p

	%UpPlus.label_settings = _label_settings.duplicate()
	%DownPlus.label_settings = _label_settings.duplicate()
	%LeftPlus.label_settings = _label_settings.duplicate()
	%RightPlus.label_settings = _label_settings.duplicate()
	%OptionPlus.label_settings = _label_settings.duplicate()
	%EditPlus.label_settings = _label_settings.duplicate()
	%ShiftPlus.label_settings = _label_settings.duplicate()
	%Times.label_settings = _label_settings.duplicate()

	var num_pressed := (
		int(pressed_u) + int(pressed_d) + int(pressed_l) + int(pressed_r) +
		int(pressed_o) + int(pressed_e) + int(pressed_s) + int(pressed_p)
	)

	keys_pressed = num_pressed

	%UpPlus.visible = false
	%DownPlus.visible = false
	%LeftPlus.visible = false
	%RightPlus.visible = false
	%OptionPlus.visible = false
	%EditPlus.visible = false
	%ShiftPlus.visible = false


	%Shift.visible = pressed_s
	if pressed_s and num_pressed > 1: %ShiftPlus.visible = true; num_pressed -= 1
	%Up.visible = pressed_u
	if pressed_u and num_pressed > 1: %UpPlus.visible = true; num_pressed -= 1
	%Down.visible = pressed_d
	if pressed_d and num_pressed > 1: %DownPlus.visible = true; num_pressed -= 1
	%Left.visible = pressed_l
	if pressed_l and num_pressed > 1: %LeftPlus.visible = true; num_pressed -= 1
	%Right.visible = pressed_r
	if pressed_r and num_pressed > 1: %RightPlus.visible = true; num_pressed -= 1
	%Option.visible = pressed_o
	if pressed_o and num_pressed > 1: %OptionPlus.visible = true; num_pressed -= 1
	%Edit.visible = pressed_e
	if pressed_e and num_pressed > 1: %EditPlus.visible = true; num_pressed -= 1
	%Play.visible = pressed_p

	%Times.visible = pressed_times > 1
	%Times.text = "x%d" % pressed_times

func _color_clamp_brightness(color: Color) -> Color:
	color.v = max(color.v, 0.7)
	return color