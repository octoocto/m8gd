@tool
extends Control

const MAX_ITEMS := 10

@onready var main: M8SceneDisplay

@onready var anim_tween: Tween # tween for scroll animation

@onready var current_item: HBoxContainer # last added item in the key overlay list
@onready var current_keystate: int = -1 # bitfield of the pressed keys for the current item
@onready var current_times: int = 0 # amount of times to display for the current item
@onready var current_item_count: int = 0 # amount of elements in the current item

func init(p_main: M8SceneDisplay) -> void:
	main = p_main
	main.m8_key_changed.connect(func(key: String, pressed: bool):
		if pressed:
			if main.m8_keystate == current_keystate:
				inc_item()
				return
			elif key in ["up", "down", "left", "right"]:
				if (main.m8_is_key_pressed(main.M8K_SHIFT) or
					main.m8_is_key_pressed(main.M8K_EDIT)) and current_times == 1 and current_item_count == 1:
					print("updating item")
					update_item()
					return
			add_item()
	)

##
## Add a new item to the key overlay list. Sets the current item to the added item.
##
func add_item():
	if is_instance_valid(current_item):
		current_item.modulate.a = 0.5
	current_item = HBoxContainer.new()
	current_times = 1
	current_item_count = 0
	%VBoxContainer.add_child(current_item)
	update_item()
	if anim_tween: anim_tween.kill()
	%Control.position.y += 30
	anim_tween = create_tween()
	anim_tween.tween_property( %Control, "position:y", -40, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

##
## Update the current item in the key overlay list.
##
func update_item():
	if !is_inside_tree() or !is_instance_valid(current_item):
		return
	for child in current_item.get_children():
		current_item.remove_child(child)
	current_item_count = 0
	current_keystate = main.m8_keystate

	if main.m8_is_key_pressed(main.M8K_SHIFT):
		add_element("SHIFT")
	if main.m8_is_key_pressed(main.M8K_OPTION):
		add_element("OPTION")
	if main.m8_is_key_pressed(main.M8K_EDIT):
		add_element("EDIT")
	if main.m8_is_key_pressed(main.M8K_PLAY):
		add_element("PLAY")
	if main.m8_is_key_pressed(main.M8K_UP):
		add_element("UP")
	if main.m8_is_key_pressed(main.M8K_DOWN):
		add_element("DOWN")
	if main.m8_is_key_pressed(main.M8K_LEFT):
		add_element("LEFT")
	if main.m8_is_key_pressed(main.M8K_RIGHT):
		add_element("RIGHT")
	
	if current_times > 1:
		var times_label := Label.new()
		times_label.text = "x%d" % current_times
		current_item.add_child(times_label)

	if %VBoxContainer.get_children().size() > MAX_ITEMS:
		var child = %VBoxContainer.get_child(0)
		child.queue_free()
		%VBoxContainer.remove_child(child)

##
## Increment the displayed number of times the item was pressed for the current item.
##
func inc_item():
	current_times += 1
	update_item()

##
## Adds an element (key text, and plus sign if needed) to the current item.
##
func add_element(text: String):
	if !is_instance_valid(current_item):
		return
	var panel := PanelContainer.new()
	# panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color.BLACK)

	if current_item_count > 0:
		var plus_label := Label.new()
		plus_label.text = "+"
		current_item.add_child(plus_label)

	panel.add_child(label)
	current_item.add_child(panel)
	current_item_count += 1