@tool
@icon("res://assets/icon/Label.png")
extends VBoxContainer

@export var text: String = "":
	set(value):
		text = value

		if not is_inside_tree(): await ready

		%Label.text = value
		%RichTextLabel.text = "[b]%s[/b]" % value

@export var panel_style: StyleBox = null:
	set(value):
		panel_style = value

		if not is_inside_tree(): await ready

		%PanelLeft["theme_override_styles/panel"] = value
		%PanelRight["theme_override_styles/panel"] = value

@export var top_spacing := true:
	set(value):
		top_spacing = value

		if not is_inside_tree(): await ready

		%HSeparator.visible = value
