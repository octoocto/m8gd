extends PanelContainer

@onready var container: SubViewportContainer
@onready var viewport: SubViewport

func init(main: M8SceneDisplay) -> void:

	var config := main.config
	container = main.get_node("%SubSceneContainer")
	viewport = main.get_node("%SubSceneRoot")

	%Spin_PosX.value_changed.connect(func(value: float) -> void:
		container.position.x=int(value)
		config.subscene_pos.x=int(value)
	)
	%Spin_PosX.value = config.subscene_pos.x

	%Spin_PosY.value_changed.connect(func(value: float) -> void:
		container.position.y=int(value)
		config.subscene_pos.y=int(value)
	)
	%Spin_PosY.value = config.subscene_pos.y

	%Spin_SizeW.value_changed.connect(func(value: float) -> void:
		viewport.size.x=int(value)
		container.size.x=int(value)
		config.subscene_size.x=int(value)
	)
	%Spin_SizeW.value = config.subscene_size.x

	%Spin_SizeH.value_changed.connect(func(value: float) -> void:
		viewport.size.y=int(value)
		container.size.y=int(value)
		config.subscene_size.y=int(value)
	)
	%Spin_SizeH.value = config.subscene_size.y

	%Option_Anchor.add_item("Top Left", 0)
	%Option_Anchor.set_item_metadata(0, Control.PRESET_TOP_LEFT)
	%Option_Anchor.add_item("Top Right", 1)
	%Option_Anchor.set_item_metadata(1, Control.PRESET_TOP_RIGHT)
	%Option_Anchor.add_item("Bottom Left", 2)
	%Option_Anchor.set_item_metadata(2, Control.PRESET_BOTTOM_LEFT)
	%Option_Anchor.add_item("Bottom Right", 3)
	%Option_Anchor.set_item_metadata(3, Control.PRESET_BOTTOM_RIGHT)
	%Option_Anchor.add_item("Center", 4)
	%Option_Anchor.set_item_metadata(4, Control.PRESET_CENTER)
	%Option_Anchor.add_item("Left Wide", 5)
	%Option_Anchor.set_item_metadata(5, Control.PRESET_LEFT_WIDE)
	%Option_Anchor.add_item("Right Wide", 6)
	%Option_Anchor.set_item_metadata(6, Control.PRESET_RIGHT_WIDE)

	%Option_Anchor.item_selected.connect(func(_idx: int) -> void:
		container.anchors_preset= %Option_Anchor.get_selected_metadata()
		update_fields()
		config.subscene_anchor= %Option_Anchor.get_selected_id()
	)
	%Option_Anchor.selected = config.subscene_anchor
	%Option_Anchor.item_selected.emit( - 1)

	%ButtonFinish.pressed.connect(func() -> void:
		visible=false
		main.menu.visible=true
	)

	get_viewport().size_changed.connect(func() -> void:
		update_fields()
	)

func update_fields() -> void:
	%Spin_PosX.value = container.position.x
	%Spin_PosY.value = container.position.y
	%Spin_SizeW.value = container.size.x
	%Spin_SizeH.value = container.size.y