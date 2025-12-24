@tool
class_name OverlayKeysItem extends HBoxContainer

@export var pressed_u := false:
	set(value):
		pressed_u = value
		_update()
@export var pressed_d := false:
	set(value):
		pressed_d = value
		_update()
@export var pressed_l := false:
	set(value):
		pressed_l = value
		_update()
@export var pressed_r := false:
	set(value):
		pressed_r = value
		_update()
@export var pressed_o := false:
	set(value):
		pressed_o = value
		_update()
@export var pressed_e := false:
	set(value):
		pressed_e = value
		_update()
@export var pressed_s := false:
	set(value):
		pressed_s = value
		_update()
@export var pressed_p := false:
	set(value):
		pressed_p = value
		_update()

@export var pressed_times := 1:
	set(value):
		pressed_times = value
		_update()

@export_category("Style: Background")

@export var style_background_enabled := true:
	set(value):
		style_background_enabled = value
		_update()
@export var style_corner_radius := 4:
	set(value):
		style_corner_radius = value
		_update()
@export var style_border_width_bottom := 2:
	set(value):
		style_border_width_bottom = value
		_update()
@export var style_padding := Vector2i(8, -1):
	set(value):
		style_padding = value
		_update()

@export_category("Style: Font")

@export var style_font_family := "":
	set(value):
		style_font_family = value
		_update()
@export var style_font_weight := 400:
	set(value):
		style_font_weight = value
		_update()
@export var style_font_size := 16:
	set(value):
		style_font_size = value
		_update()

@export_category("Style: Colors")

@export var color_d := Color.WHITE:
	set(value):
		color_d = value
		_update()
@export var color_o := Color.WHITE:
	set(value):
		color_o = value
		_update()
@export var color_e := Color.WHITE:
	set(value):
		color_e = value
		_update()
@export var color_s := Color.WHITE:
	set(value):
		color_s = value
		_update()
@export var color_p := Color.WHITE:
	set(value):
		color_p = value
		_update()

var _style_box: StyleBox
var _label_settings: LabelSettings

var keys_pressed := 0


func _ready() -> void:
	_update()


func _update() -> void:
	if not is_inside_tree():
		return

	if style_background_enabled:
		_style_box = StyleBoxFlat.new()
		var style_box := _style_box as StyleBoxFlat

		style_box.anti_aliasing = false

		style_box.corner_radius_bottom_left = style_corner_radius
		style_box.corner_radius_bottom_right = style_corner_radius
		style_box.corner_radius_top_left = style_corner_radius
		style_box.corner_radius_top_right = style_corner_radius

		style_box.border_width_bottom = style_border_width_bottom

		style_box.content_margin_left = style_padding.x
		style_box.content_margin_right = style_padding.x
		style_box.content_margin_top = style_padding.y
		style_box.content_margin_bottom = style_padding.y

	else:
		_style_box = StyleBoxEmpty.new()

	_label_settings = LabelSettings.new()
	_label_settings.font_size = style_font_size
	var font := SystemFont.new()
	_label_settings.font = font
	if style_font_family != "":
		font.font_names = [style_font_family]
	font.font_weight = style_font_weight

	var style_box_u := _style_box.duplicate()
	var style_box_d := _style_box.duplicate()
	var style_box_l := _style_box.duplicate()
	var style_box_r := _style_box.duplicate()
	var style_box_o := _style_box.duplicate()
	var style_box_e := _style_box.duplicate()
	var style_box_s := _style_box.duplicate()
	var style_box_p := _style_box.duplicate()

	var label_settings_u: LabelSettings = _label_settings.duplicate()
	var label_settings_d: LabelSettings = _label_settings.duplicate()
	var label_settings_l: LabelSettings = _label_settings.duplicate()
	var label_settings_r: LabelSettings = _label_settings.duplicate()
	var label_settings_o: LabelSettings = _label_settings.duplicate()
	var label_settings_e: LabelSettings = _label_settings.duplicate()
	var label_settings_s: LabelSettings = _label_settings.duplicate()
	var label_settings_p: LabelSettings = _label_settings.duplicate()

	if style_background_enabled:
		(style_box_u as StyleBoxFlat).bg_color = color_d
		(style_box_u as StyleBoxFlat).border_color = color_d.darkened(0.5)
		label_settings_u.font_color = Color.BLACK if color_d.get_luminance() > 0.5 else Color.WHITE
		(style_box_d as StyleBoxFlat).bg_color = color_d
		(style_box_d as StyleBoxFlat).border_color = color_d.darkened(0.5)
		label_settings_d.font_color = Color.BLACK if color_d.get_luminance() > 0.5 else Color.WHITE
		(style_box_l as StyleBoxFlat).bg_color = color_d
		(style_box_l as StyleBoxFlat).border_color = color_d.darkened(0.5)
		label_settings_l.font_color = Color.BLACK if color_d.get_luminance() > 0.5 else Color.WHITE
		(style_box_r as StyleBoxFlat).bg_color = color_d
		(style_box_r as StyleBoxFlat).border_color = color_d.darkened(0.5)
		label_settings_r.font_color = Color.BLACK if color_d.get_luminance() > 0.5 else Color.WHITE
		(style_box_o as StyleBoxFlat).bg_color = color_o
		(style_box_o as StyleBoxFlat).border_color = color_o.darkened(0.5)
		label_settings_o.font_color = Color.BLACK if color_o.get_luminance() > 0.5 else Color.WHITE
		(style_box_e as StyleBoxFlat).bg_color = color_e
		(style_box_e as StyleBoxFlat).border_color = color_e.darkened(0.5)
		label_settings_e.font_color = Color.BLACK if color_e.get_luminance() > 0.5 else Color.WHITE
		(style_box_s as StyleBoxFlat).bg_color = color_s
		(style_box_s as StyleBoxFlat).border_color = color_s.darkened(0.5)
		label_settings_s.font_color = Color.BLACK if color_s.get_luminance() > 0.5 else Color.WHITE
		(style_box_p as StyleBoxFlat).bg_color = color_p
		(style_box_p as StyleBoxFlat).border_color = color_p.darkened(0.5)
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

	var panel_u: PanelContainer = %Up
	var panel_d: PanelContainer = %Down
	var panel_l: PanelContainer = %Left
	var panel_r: PanelContainer = %Right
	var panel_o: PanelContainer = %Option
	var panel_e: PanelContainer = %Edit
	var panel_s: PanelContainer = %Shift
	var panel_p: PanelContainer = %Play

	var label_u_plus: Label = %UpPlus
	var label_d_plus: Label = %DownPlus
	var label_l_plus: Label = %LeftPlus
	var label_r_plus: Label = %RightPlus
	var label_o_plus: Label = %OptionPlus
	var label_e_plus: Label = %EditPlus
	var label_s_plus: Label = %ShiftPlus
	var label_times: Label = %Times

	panel_u.set("theme_override_styles/panel", style_box_u)
	panel_d.set("theme_override_styles/panel", style_box_d)
	panel_l.set("theme_override_styles/panel", style_box_l)
	panel_r.set("theme_override_styles/panel", style_box_r)
	panel_o.set("theme_override_styles/panel", style_box_o)
	panel_e.set("theme_override_styles/panel", style_box_e)
	panel_s.set("theme_override_styles/panel", style_box_s)
	panel_p.set("theme_override_styles/panel", style_box_p)

	(panel_u.get_node("Label") as Label).label_settings = label_settings_u
	(panel_d.get_node("Label") as Label).label_settings = label_settings_d
	(panel_l.get_node("Label") as Label).label_settings = label_settings_l
	(panel_r.get_node("Label") as Label).label_settings = label_settings_r
	(panel_o.get_node("Label") as Label).label_settings = label_settings_o
	(panel_e.get_node("Label") as Label).label_settings = label_settings_e
	(panel_s.get_node("Label") as Label).label_settings = label_settings_s
	(panel_p.get_node("Label") as Label).label_settings = label_settings_p

	label_u_plus.label_settings = _label_settings.duplicate()
	label_d_plus.label_settings = _label_settings.duplicate()
	label_l_plus.label_settings = _label_settings.duplicate()
	label_r_plus.label_settings = _label_settings.duplicate()
	label_o_plus.label_settings = _label_settings.duplicate()
	label_e_plus.label_settings = _label_settings.duplicate()
	label_s_plus.label_settings = _label_settings.duplicate()
	label_times.label_settings = _label_settings.duplicate()

	var num_pressed := (
		int(pressed_u)
		+ int(pressed_d)
		+ int(pressed_l)
		+ int(pressed_r)
		+ int(pressed_o)
		+ int(pressed_e)
		+ int(pressed_s)
		+ int(pressed_p)
	)

	keys_pressed = num_pressed

	label_u_plus.visible = false
	label_d_plus.visible = false
	label_l_plus.visible = false
	label_r_plus.visible = false
	label_o_plus.visible = false
	label_e_plus.visible = false
	label_s_plus.visible = false

	panel_s.visible = pressed_s
	if pressed_s and num_pressed > 1:
		label_s_plus.visible = true
		num_pressed -= 1
	panel_u.visible = pressed_u
	if pressed_u and num_pressed > 1:
		label_u_plus.visible = true
		num_pressed -= 1
	panel_d.visible = pressed_d
	if pressed_d and num_pressed > 1:
		label_d_plus.visible = true
		num_pressed -= 1
	panel_l.visible = pressed_l
	if pressed_l and num_pressed > 1:
		label_l_plus.visible = true
		num_pressed -= 1
	panel_r.visible = pressed_r
	if pressed_r and num_pressed > 1:
		label_r_plus.visible = true
		num_pressed -= 1
	panel_o.visible = pressed_o
	if pressed_o and num_pressed > 1:
		label_o_plus.visible = true
		num_pressed -= 1
	panel_e.visible = pressed_e
	if pressed_e and num_pressed > 1:
		label_e_plus.visible = true
		num_pressed -= 1
	panel_p.visible = pressed_p

	label_times.visible = pressed_times > 1
	label_times.text = "x%d" % pressed_times


func _color_clamp_brightness(color: Color) -> Color:
	color.v = max(color.v, 0.7)
	return color

