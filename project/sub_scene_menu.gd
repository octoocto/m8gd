extends PanelContainer

const PROP_MODE := "__ss_mode"
const PROP_ANCHOR := "__ss_anchor"
const PROP_POS := "__ss_pos"
const PROP_SIZE := "__ss_size"

const DEF_MODE := 0
const DEF_ANCHOR := 0
const DEF_POS := Vector2i(0, 0)
const DEF_SIZE := Vector2i(640, 480)

@onready var container: SubViewportContainer
@onready var viewport: SubViewport
@onready var main: M8SceneDisplay

func _setprop(property: String, value: Variant) -> void:
	main.menu_scene.config_set_property(property, value)

func _getprop(property: String, default: Variant=null) -> Variant:
	return main.menu_scene.config_get_property(property, default)

func init(p_main: M8SceneDisplay) -> void:

	main = p_main
	container = main.get_node("%SubSceneContainer")
	viewport = main.get_node("%SubSceneRoot")

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
		_setprop(PROP_ANCHOR, %Option_Anchor.get_selected_id())
	)

	%Spin_PosX.value_changed.connect(func(value: float) -> void:
		container.position.x=int(value)
		var pos: Vector2i=_getprop(PROP_POS)
		pos.x=int(value)
		_setprop(PROP_POS, pos)
	)

	%Spin_PosY.value_changed.connect(func(value: float) -> void:
		container.position.y=int(value)
		var pos: Vector2i=_getprop(PROP_POS)
		pos.y=int(value)
		_setprop(PROP_POS, pos)
	)

	%Spin_SizeW.value_changed.connect(func(value: float) -> void:
		viewport.size.x=int(value)
		container.size.x=int(value)
		var siz: Vector2i=_getprop(PROP_SIZE)
		siz.x=int(value)
		_setprop(PROP_SIZE, siz)
	)

	%Spin_SizeH.value_changed.connect(func(value: float) -> void:
		viewport.size.y=int(value)
		container.size.y=int(value)
		var siz: Vector2i=_getprop(PROP_SIZE)
		siz.y=int(value)
		_setprop(PROP_SIZE, siz)
	)
		
	main.menu.get_node("%Option_SubSceneMode").item_selected.connect(func(_idx: int) -> void:
		_setprop(PROP_MODE, main.menu.get_node("%Option_SubSceneMode").get_selected_id())
	)

	%ButtonFinish.pressed.connect(func() -> void:
		visible=false
		main.menu.visible=true
	)

	get_viewport().size_changed.connect(func() -> void:
		update_fields()
	)

	main.m8_scene_changed.connect(func(_scene_path: String, _scene: M8Scene) -> void:

		_getprop(PROP_MODE, DEF_MODE)
		_getprop(PROP_ANCHOR, DEF_ANCHOR)
		_getprop(PROP_POS, DEF_POS)
		_getprop(PROP_SIZE, DEF_SIZE)

		main.menu.get_node("%Option_SubSceneMode").selected=_getprop(PROP_MODE)
		main.menu.get_node("%Option_SubSceneMode").item_selected.emit( - 1)
		%Option_Anchor.selected=_getprop(PROP_ANCHOR)
		%Spin_PosX.value_changed.emit(_getprop(PROP_POS).x)
		%Spin_PosY.value_changed.emit(_getprop(PROP_POS).y)
		%Spin_SizeW.value_changed.emit(_getprop(PROP_SIZE).x)
		%Spin_SizeH.value_changed.emit(_getprop(PROP_SIZE).y)

		update_fields()
	)

func update_fields() -> void:
	%Spin_PosX.value = container.position.x
	%Spin_PosY.value = container.position.y
	%Spin_SizeW.value = container.size.x
	%Spin_SizeH.value = container.size.y
