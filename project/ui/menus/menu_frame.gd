@tool
class_name MenuFrameBase
extends MenuBase

@export var title: String = "":
	set(value):
		title = value
		emit_ui_changed()

@export var show_close_button: bool = false:
	set(value):
		show_close_button = value
		emit_ui_changed()

@export var show_exit_button: bool = false:
	set(value):
		show_exit_button = value
		emit_ui_changed()

@onready var header: UIHeader = %Header

@onready var button_exit: UIButton = %ButtonExit
@onready var button_close: UIButton = %ButtonClose

@onready var label_tooltip: UILabel = %LabelTooltip


func _on_menu_init() -> void:
	button_exit.pressed.connect(func() -> void: main.quit())
	button_close.pressed.connect(main.main_menu_show)

	Events.gui_mouse_entered.connect(
		func(ui_element: UIBase) -> void:
			if ui_element.hint_text != "":
				label_tooltip.text = ui_element.hint_text
	)

	Events.gui_mouse_exited.connect(func(_ui_element: UIBase) -> void: label_tooltip.text = "")


func _on_changed() -> void:
	header.text = _format_text(title)
	button_close.visible = show_close_button
	button_exit.visible = show_exit_button
