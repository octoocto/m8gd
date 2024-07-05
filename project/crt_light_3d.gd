extends OmniLight3D

@export var viewport_texture: ViewportTexture

const COLOR_SAMPLE_POINT_1 := Vector2i(0, 0)
const COLOR_SAMPLE_POINT_2 := Vector2i(19, 66)

func _ready() -> void:
	_update()

func _physics_process(_delta: float) -> void:
	_update()
	
func _update() -> void:
	#var texture = light_projector
	#light_projector = null
	#light_projector = texture
	if viewport_texture != null:
			
		var image := viewport_texture.get_image()
		if image != null:
			var color_1 := image.get_pixelv(COLOR_SAMPLE_POINT_1)
			var color_2 := image.get_pixelv(COLOR_SAMPLE_POINT_2)
			light_color = color_1.lerp(color_2, 0.25).lightened(0.25)
