class_name OverlayKeys extends OverlayBase

const MAX_ITEMS := 10

enum Style {Boxed, Simple}

@export var overlay_style := Style.Boxed:
	set(value):
		overlay_style = value
		_update_colors()

@export var panel_directional: StyleBox
@export var panel_shift: StyleBox
@export var panel_play: StyleBox
@export var panel_option: StyleBox
@export var panel_edit: StyleBox

@export var label_directional: LabelSettings
@export var label_shift: LabelSettings
@export var label_play: LabelSettings
@export var label_option: LabelSettings
@export var label_edit: LabelSettings

var color_directional := Color.WHITE:
	set(value):
		color_directional = value
		_set_color(value, panel_directional, label_directional)

var color_shift := Color.WHITE:
	set(value):
		color_shift = value
		_set_color(value, panel_shift, label_shift)

var color_play := Color.WHITE:
	set(value):
		color_play = value
		_set_color(value, panel_play, label_play)

var color_option := Color.WHITE:
	set(value):
		color_option = value
		_set_color(value, panel_option, label_option)

var color_edit := Color.WHITE:
	set(value):
		color_edit = value
		_set_color(value, panel_edit, label_edit)

@onready var anim_tween: Tween # tween for scroll animation

@onready var current_fade_tween: Tween # tween for scroll animation

@onready var current_item: HBoxContainer # last added item in the key overlay list
@onready var current_keystate: int = -1 # bitfield of the pressed keys for the current item
@onready var current_times: int = 0 # amount of times to display for the current item
@onready var current_item_count: int = 0 # amount of elements in the current item


func _ready() -> void:
	visibility_changed.connect(func() -> void:
		if not visible:
			clear()
	)

func init(p_main: Main) -> void:
	main = p_main
	main.m8_client.key_pressed.connect(func(key: int, pressed: bool) -> void:
		if pressed:
			if main.m8_client.get_key_state() == current_keystate:
				# increment last item
				inc_item()
				return
			elif key in [M8GD.M8_KEY_UP, M8GD.M8_KEY_DOWN, M8GD.M8_KEY_LEFT, M8GD.M8_KEY_RIGHT]:
				# update last item
				if (main.m8_is_key_pressed(M8GD.M8_KEY_SHIFT) or
					main.m8_is_key_pressed(M8GD.M8_KEY_SHIFT)) and current_times == 1 and current_item_count == 1:
					print("updating item")
					update_item()
					return
			# add a new item
			add_item()
	)

	_update()

func _draw() -> void:
	if draw_bounds:
		draw_rect(Rect2(position_offset, size), Color.WHITE, false)

func _process(_delta: float) -> void:
	queue_redraw()

func overlay_get_properties() -> Array[String]:
	return ["overlay_style"]

##
## Delete all items.
##
func clear() -> void:
	for child in %VBoxContainer.get_children():
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

	current_item = HBoxContainer.new()
	current_times = 1
	current_item_count = 0
	%VBoxContainer.add_child(current_item)
	update_item()

	# if anim_tween: anim_tween.kill()
	# anim_tween = create_tween()
	# %Control.position.y += 30
	# anim_tween.tween_property(%Control, "position:y", -40, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	if current_fade_tween: current_fade_tween.kill()
	current_fade_tween = create_tween()
	current_fade_tween.tween_property(current_item, "modulate:a", 0, 10.0).set_ease(Tween.EASE_IN)
	current_fade_tween.tween_callback(func() -> void:
		if is_instance_valid(current_item):
			current_item.queue_free()
	)

##
## Update the current item in the key overlay list.
##
func update_item() -> void:
	if !is_inside_tree() or !is_instance_valid(current_item):
		return
	for child in current_item.get_children():
		current_item.remove_child(child)
	current_item_count = 0
	current_keystate = main.m8_client.get_key_state()

	if main.m8_is_key_pressed(M8GD.M8_KEY_UP):
		add_element("UP", panel_directional, label_directional)
	if main.m8_is_key_pressed(M8GD.M8_KEY_DOWN):
		add_element("DOWN", panel_directional, label_directional)
	if main.m8_is_key_pressed(M8GD.M8_KEY_LEFT):
		add_element("LEFT", panel_directional, label_directional)
	if main.m8_is_key_pressed(M8GD.M8_KEY_RIGHT):
		add_element("RIGHT", panel_directional, label_directional)
	if main.m8_is_key_pressed(M8GD.M8_KEY_OPTION):
		add_element("OPTION", panel_option, label_option)
	if main.m8_is_key_pressed(M8GD.M8_KEY_EDIT):
		add_element("EDIT", panel_edit, label_edit)
	if main.m8_is_key_pressed(M8GD.M8_KEY_SHIFT):
		add_element("SHIFT", panel_shift, label_shift)
	if main.m8_is_key_pressed(M8GD.M8_KEY_PLAY):
		add_element("PLAY", panel_play, label_play)
	
	if current_times > 1:
		var times_label := Label.new()
		times_label.text = "x%d" % current_times
		current_item.add_child(times_label)

	if %VBoxContainer.get_children().size() > MAX_ITEMS:
		var child := %VBoxContainer.get_child(0)
		%VBoxContainer.remove_child(child)

##
## Increment the displayed number of times the item was pressed for the current item.
##
func inc_item() -> void:
	current_times += 1
	update_item()

##
## Adds an element (key text, and plus sign if needed) to the current item.
##
func add_element(text: String, style: StyleBox, label_style: LabelSettings) -> void:
	if !is_instance_valid(current_item):
		return

	var panel := PanelContainer.new()
	var label := Label.new()
	label.text = text

	panel.add_theme_stylebox_override("panel", style)
	label.label_settings = label_style

	if current_item_count > 0:
		var plus_label := Label.new()
		plus_label.text = "+"
		current_item.add_child(plus_label)

	panel.add_child(label)
	current_item.add_child(panel)
	current_item_count += 1
func _set_color(color: Color, panel: StyleBox, label: LabelSettings) -> void:
	if overlay_style == 0: # boxed style

		panel.bg_color = color
		panel.border_width_bottom = 2

		if color.get_luminance() > 0.5:
			label.font_color = Color.BLACK
		else:
			label.font_color = Color.WHITE

	else: # unboxed style

		panel.bg_color = Color(0, 0, 0, 0)
		panel.border_width_bottom = 0

		color.v = max(color.v, 0.5)
		label.font_color = color

func _update_colors() -> void:
	color_directional = color_directional
	color_shift = color_shift
	color_play = color_play
	color_option = color_option
	color_edit = color_edit


func _update() -> void:
	if is_inside_tree():
		%ControlOffset.size = size
		%ControlOffset.position = position_offset
		%Control.size = Vector2(0, size.y)
		%Control.position = Vector2.ZERO
		%VBoxContainer.size = size
		%VBoxContainer.position = Vector2.ZERO
		anchors_preset = anchors_preset
