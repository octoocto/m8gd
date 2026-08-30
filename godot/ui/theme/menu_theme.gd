extends Theme


func _init() -> void:
	self.default_font = _create_font_from_bitmap(Main.FONT_01_SMALL)


func _create_font_from_bitmap(bm: BitMap) -> FontVariation:
	var image := bm.convert_to_image()
	image.convert(Image.FORMAT_RGBA8)

	for i in image.get_width():
		for j in image.get_height():
			if image.get_pixel(i, j) == Color.BLACK:
				image.set_pixel(i, j, Color.TRANSPARENT)

	var font := FontFile.new()
	var columns := 16
	var rows := 8

	var chr_width := image.get_width() / columns
	var chr_height := image.get_height() / rows

	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	font.generate_mipmaps = false
	font.multichannel_signed_distance_field = false
	font.fixed_size = chr_height
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	font.force_autohinter = false
	font.allow_system_fallback = false
	font.hinting = TextServer.HINTING_NONE
	font.oversampling = 1.0
	font.set_texture_image(0, Vector2i(chr_height, 0), 0, image)

	for i: int in 128:
		var x := i % columns
		var y := i / columns
		font.set_glyph_advance(0, chr_height, i, Vector2(chr_width, 0))
		font.set_glyph_offset(0, Vector2i(chr_height, 0), i, Vector2i(0, -0.5 * chr_height))
		font.set_glyph_size(0, Vector2i(chr_height, 0), i, Vector2(chr_width, chr_height))
		font.set_glyph_uv_rect(
			0,
			Vector2i(chr_height, 0),
			i,
			Rect2(chr_width * x, chr_height * y, chr_width, chr_height),
		)
		font.set_glyph_texture_idx(0, Vector2i(chr_height, 0), i, 0)

	font.set_cache_ascent(0, chr_height, chr_height * 0.5)
	font.set_cache_descent(0, chr_height, chr_height * 0.5)

	var fontvar := FontVariation.new()
	fontvar.base_font = font
	fontvar.spacing_glyph = 2

	return fontvar
