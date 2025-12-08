@tool
extends SettingBase


@export_enum("Arrows", "Dropdown") var setting_type := 0:
	set(value):
		setting_type = value
		_update()

@export var items: PackedStringArray

@export var value := -1:
	set(p_value):
		value = clampi(p_value, 0, items.size() - 1) if items.size() else -1
		await _update()
		emit_changed()


func _ready() -> void:
	super()
	%ButtonLeft.pressed.connect(func() -> void: value -= 1)
	%ButtonRight.pressed.connect(func() -> void: value += 1)
	%OptionButton.item_selected.connect(func(p_value: int) -> void:
		value = p_value
	)
	_update()


func _update() -> void:

	if not is_inside_tree(): await ready

	modulate = Color.WHITE if enabled else Color.from_hsv(0, 0, 0.25)

	if setting_name == "":
		%LabelName.visible = false
	else:
		%LabelName.visible = true
		%LabelName.text = setting_name

	%LabelName.custom_minimum_size.x = setting_name_min_width

	%ButtonLeft.visible = false
	%ButtonRight.visible = false
	%LabelValue.visible = false
	%OptionButton.visible = false

	match setting_type:
		0: # arrows
			%ButtonLeft.visible = true
			%ButtonLeft.disabled = !enabled or value <= 0

			%ButtonRight.visible = true
			%ButtonRight.disabled = !enabled or value >= items.size() - 1

			%LabelValue.visible = true
			%LabelValue.text = items[value] if items.size() > 0 else ""
		1: # dropdown
			%OptionButton.visible = true
			if items.size():
				%OptionButton.clear()
				for item: String in items:
					%OptionButton.add_item(item)
				%OptionButton.selected = value
