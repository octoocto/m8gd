extends M8Scene

var m8_client
func initialize(_display: M8SceneDisplay):
    super(_display)
    # %TextureRect.texture = _display.m8_display_texture
    %TextureRect.texture = _display.m8_client.get_display_texture()
    m8_client = _display.m8_client

func _process(_delta):

    RenderingServer.set_default_clear_color(m8_client.get_background_color())

    var window_size = DisplayServer.window_get_size()
    var texture = %TextureRect.texture
    var intscale := 1

    while ((intscale + 1) * texture.get_size().x <= window_size.x and (intscale + 1) * texture.get_size().y <= window_size.y):
        intscale += 1

    %TextureRect.custom_minimum_size = intscale * texture.get_size();
