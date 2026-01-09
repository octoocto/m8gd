@tool
class_name OverlayKeycast
extends OverlayBase

const MAX_ITEMS := 10 + 3  # including sample items

const KEY_ITEM := preload("res://overlays/overlay_keys_item.tscn")

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
@export_range(100, 800) var style_font_weight := 400:
	set(value):
		style_font_weight = value
		_update()
@export var style_font_size := 16:
	set(value):
		style_font_size = value
		_update()

@onready var anim_tween: Tween  # tween for scroll animation

@onready var current_fade_tween: Tween  # tween for scroll animation

@onready var current_item: OverlayKeysItem  # last added item in the key overlay list
@onready var current_keystate: int = -1  # bitfield of the pressed keys for the current item

@onready var control_offset: Control = %ControlOffset
@onready var control: Control = %Control
@onready var vbox: VBoxContainer = %VBoxContainer


func _overlay_init() -> void:
	visibility_changed.connect(
		func() -> void:
			if not visible:
				clear()
	)
	Events.device_key_pressed.connect(
		func(key: int, pressed: bool) -> void:
			if not pressed:
				return

			if is_instance_valid(current_item):
				if main.m8c.get_key_state() == current_keystate:
					inc_current_item()
					return
				elif key in [LibM8.KEY_UP, LibM8.KEY_DOWN, LibM8.KEY_LEFT, LibM8.KEY_RIGHT]:
					if (
						main.m8_is_key_pressed(LibM8.KEY_SHIFT)
						and current_item.pressed_times == 1
						and current_item.keys_pressed == 1
					):
						update_current_item()
						return

			# add a new item
			add_item()
	)
	Events.config_preset_value_changed.connect(
		func(_profile_name: String, section: String, _property: String, _value: Variant) -> void:
			if section == main.config.SECTION_COLORS:
				_update()
	)
	_update()


func _process(delta: float) -> void:
	super(delta)
	if Engine.is_editor_hint():
		return
	(%ItemSample1 as OverlayKeysItem).visible = _draw_bounds
	(%ItemSample2 as OverlayKeysItem).visible = _draw_bounds
	(%ItemSample3 as OverlayKeysItem).visible = _draw_bounds


##
## Delete all items.
##
func clear() -> void:
	for child in %VBoxContainer.get_children():
		if child != %ItemSample1 and child != %ItemSample2 and child != %ItemSample3:
			%VBoxContainer.remove_child(child)
			child.queue_free()


##
## Add a new item to the key overlay list. Sets the current item to the added item.
##
func add_item() -> void:
	# fade out the last item
	if is_instance_valid(current_item):
		var last_item := current_item

		var fade_callback := func(value: float) -> void:
			if last_item != null and is_instance_valid(last_item):
				last_item.modulate.a = value
				if value == 0.0:
					last_item.queue_free()

		var fade_tween := create_tween()
		fade_tween.tween_method(fade_callback, 0.5, 0.0, 5.0)

	current_item = KEY_ITEM.instantiate()
	%VBoxContainer.add_child(current_item)
	update_current_item()

	# remove front item if over max
	if %VBoxContainer.get_children().size() > MAX_ITEMS:
		var child := %VBoxContainer.get_child(3)
		%VBoxContainer.remove_child(child)

	_restart_fade_tween()


func _restart_fade_tween() -> void:
	if current_fade_tween:
		current_fade_tween.kill()
	current_fade_tween = create_tween()
	current_fade_tween.tween_property(current_item, "modulate:a", 1, 0.0).set_ease(Tween.EASE_IN)
	current_fade_tween.tween_property(current_item, "modulate:a", 0, 10.0).set_ease(Tween.EASE_IN)
	current_fade_tween.tween_callback(
		func() -> void:
			if is_instance_valid(current_item):
				current_item.queue_free()
	)


##
## Update the current item in the key overlay list.
##
func update_current_item() -> void:
	if not is_inside_tree() or not is_instance_valid(current_item):
		return

	current_keystate = main.m8c.get_key_state()
	update_item(current_item)
	current_item.pressed_u = main.m8_is_key_pressed(LibM8.KEY_UP)
	current_item.pressed_d = main.m8_is_key_pressed(LibM8.KEY_DOWN)
	current_item.pressed_l = main.m8_is_key_pressed(LibM8.KEY_LEFT)
	current_item.pressed_r = main.m8_is_key_pressed(LibM8.KEY_RIGHT)
	current_item.pressed_o = main.m8_is_key_pressed(LibM8.KEY_OPTION)
	current_item.pressed_e = main.m8_is_key_pressed(LibM8.KEY_EDIT)
	current_item.pressed_s = main.m8_is_key_pressed(LibM8.KEY_SHIFT)
	current_item.pressed_p = main.m8_is_key_pressed(LibM8.KEY_PLAY)
	_restart_fade_tween()


func update_item(item: OverlayKeysItem) -> void:
	if not is_inside_tree() or not is_instance_valid(item):
		return

	item.style_background_enabled = style_background_enabled
	item.style_corner_radius = style_corner_radius
	item.style_border_width_bottom = style_border_width_bottom
	item.style_padding = style_padding

	item.color_d = main.config.get_color_highlight(main.config.KEY_COLOR_HIGHLIGHT_DIR)
	item.color_o = main.config.get_color_highlight(main.config.KEY_COLOR_HIGHLIGHT_OPTION)
	item.color_e = main.config.get_color_highlight(main.config.KEY_COLOR_HIGHLIGHT_EDIT)
	item.color_s = main.config.get_color_highlight(main.config.KEY_COLOR_HIGHLIGHT_SHIFT)
	item.color_p = main.config.get_color_highlight(main.config.KEY_COLOR_HIGHLIGHT_PLAY)

	item.style_font_family = style_font_family
	item.style_font_weight = style_font_weight
	item.style_font_size = style_font_size


##
## Increment the displayed number of times the item was pressed for the current item.
##
func inc_current_item() -> void:
	if !is_inside_tree() or !is_instance_valid(current_item):
		return
	current_item.pressed_times += 1
	update_current_item()


func _update() -> void:
	if not is_inside_tree():
		return

	control_offset.size = size
	control_offset.position = position_offset
	control.size = Vector2(0, size.y)
	control.position = Vector2.ZERO
	vbox.size = size
	vbox.position = Vector2.ZERO
	anchors_preset = anchors_preset

	for item in vbox.get_children():
		update_item(item as OverlayKeysItem)
