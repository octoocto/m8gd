@tool
extends OmniLight3D

@export var viewport_texture: ViewportTexture

const COLOR_SAMPLE_POINT_1 := Vector2i(0, 0)
const COLOR_SAMPLE_POINT_2 := Vector2i(19, 66)

# Called when the node enters the scene tree for the first time.
func _ready():
	_update()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta):
	_update()
	
func _update():
	#var texture = light_projector
	#light_projector = null
	#light_projector = texture
	if viewport_texture != null:
			
		var image = viewport_texture.get_image()
		if image != null:
			var color_1 := image.get_pixelv(COLOR_SAMPLE_POINT_1)
			var color_2 := image.get_pixelv(COLOR_SAMPLE_POINT_2)
			light_color = color_1.lerp(color_2, 0.25).lightened(0.25)
