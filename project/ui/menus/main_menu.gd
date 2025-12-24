@tool
class_name MainMenu
extends MenuBase

@onready var tab_container: TabContainer = %TabContainer

@onready var display_rect: TextureRect = %DisplayRect

@onready var label_current_scene: UILabel2 = %LabelCurrentScene

@onready var menu_root: Control = %MenuRoot

@onready var menu_scene: MenuBase = %MenuScene
@onready var menu_overlays: MenuBase = %MenuOverlays
@onready var menu_shaders: MenuBase = %MenuShaders
@onready var menu_colors: MenuBase = %MenuColors
@onready var menu_devices: MenuDevices = %MenuDevices
@onready var menu_input: InputMenu = %MenuInput
@onready var menu_video: MenuBase = %MenuVideo
@onready var menu_audio: MenuBase = %MenuAudio
@onready var menu_presets: MenuBase = %MenuPresets
@onready var menu_debug: MenuBase = %MenuDebug

@onready var button_goto_scene: UIButton = %ButtonGotoScene
@onready var button_goto_overlays: UIButton = %ButtonGotoOverlays
@onready var button_goto_shaders: UIButton = %ButtonGotoShaders
@onready var button_goto_colors: UIButton = %ButtonGotoColors
@onready var button_goto_devices: UIButton = %ButtonGotoDevices
@onready var button_goto_input: UIButton = %ButtonGotoInput
@onready var button_goto_video: UIButton = %ButtonGotoVideo
@onready var button_goto_audio: UIButton = %ButtonGotoAudio
@onready var button_goto_presets: UIButton = %ButtonGotoPresets
@onready var button_goto_debug: UIButton = %ButtonGotoDebug

@onready var opt_load_scene: UIOptionButton = %OptionLoadScene

@onready var button_back: UIButton = %ButtonBack

@onready var button_exit: UIButton = %ButtonExit
@onready var button_close: UIButton = %ButtonClose

@onready var header: UIHeader = %Header

@onready var label_tooltip: UILabel = %LabelTooltip

var menu_stack: Array[MenuBase] = []


func _on_menu_init() -> void:
	custom_minimum_size = Vector2i(320, 240)

	button_exit.pressed.connect(func() -> void: main.quit())
	button_close.pressed.connect(func() -> void: visible = false)
	# for i in tab_container.get_tab_count():
	# 	var tab := tab_container.get_tab_control(i)
	# 	if tab.has_method("get_tab_title"):
	# 		tab_container.set_tab_title(i, tab.get_tab_title())
	display_rect.texture = main.m8_client.get_display()

	_init_scene_loader()

	_connect_goto(button_goto_scene, menu_scene)
	_connect_goto(button_goto_overlays, menu_overlays)
	_connect_goto(button_goto_shaders, menu_shaders)
	_connect_goto(button_goto_colors, menu_colors)
	_connect_goto(button_goto_devices, menu_devices)
	_connect_goto(button_goto_input, menu_input)
	_connect_goto(button_goto_video, menu_video)
	_connect_goto(button_goto_audio, menu_audio)
	_connect_goto(button_goto_presets, menu_presets)
	_connect_goto(button_goto_debug, menu_debug)

	button_back.pressed.connect(_back)

	Events.scene_loaded.connect(
		func(scene_path: String, _scene: M8Scene) -> void:
			var scene_name := main.get_scene_name(scene_path)
			label_current_scene.text = scene_name
			label_current_scene.hint_text = scene_path.replace("res://", "(builtin) ")
	)

	Events.gui_mouse_entered.connect(
		func(ui_element: UIBase) -> void:
			if ui_element.hint_text != "":
				label_tooltip.text = ui_element.hint_text
	)

	Events.gui_mouse_exited.connect(func(_ui_element: UIBase) -> void: label_tooltip.text = "")


func menu_show() -> void:
	super()
	if menu_stack.size() == 0:
		menu_root.show()
	_on_changed()


func _connect_goto(button: UIButton, menu: Control) -> void:
	button.pressed.connect(
		func() -> void:
			menu.show()
			menu_stack.append(menu)
			_on_changed()
	)


func _back() -> void:
	if menu_stack.size() == 0:
		return

	menu_stack.pop_back()

	if menu_stack.size():
		menu_stack[-1].show()
	else:
		menu_root.show()

	_on_changed()


func _on_changed() -> void:
	var menu_stack_names: Array = menu_stack.map(
		func(m: MenuBase) -> String: return m.name.trim_prefix("Menu")
	)
	menu_stack_names.push_front("Main Menu")
	header.text = " > ".join(menu_stack_names)

	button_back.visible = menu_stack.size() > 0


func _init_scene_loader() -> void:
	var _setup_as_button := func() -> void:
		# ensure this function gets called after _setup_as_list
		await get_tree().process_frame
		opt_load_scene.clear()
		opt_load_scene.add_item("Change Scene...")
		opt_load_scene.set_item_icon(0, ICON_LOAD)

	var _setup_as_list := func() -> void:
		opt_load_scene.clear()

		for scene_path: String in main.get_scene_paths():
			var idx: int = opt_load_scene.item_count
			var scene_name := main.get_scene_name(scene_path)
			opt_load_scene.add_item(scene_name, idx)
			opt_load_scene.set_item_metadata(idx, scene_path)

		opt_load_scene.select(-1)

	opt_load_scene.pressed.connect(_setup_as_list)
	opt_load_scene.get_popup().popup_hide.connect(_setup_as_button)
	opt_load_scene.item_selected.connect(
		func(idx: int) -> void:
			if idx != -1:
				main.load_scene(opt_load_scene.get_item_metadata(idx) as String)
			_setup_as_button.call()
	)
	_setup_as_button.call()
