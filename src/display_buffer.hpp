#include <stdint.h>
#include <godot_cpp/classes/image_texture.hpp>
#include <godot_cpp/classes/bit_map.hpp>

#define FONT_SHEET_COLS 16
#define FONT_SHEET_ROWS 8

class DisplayBuffer
{
public:
	godot::PackedByteArray byte_array;
	uint8_t *bytes;
	uint16_t width;
	uint16_t height;

	godot::Ref<godot::BitMap> font_bitmap;
	uint8_t font_w;
	uint8_t font_h;

	// changes depending on small/big/huge font
	int8_t screen_offset_y = 0;
	int8_t font_offset_y = 0;
	uint8_t waveform_max = 0;

	// cached color from fullscreen draw_rect call
	uint8_t bg_r = 0;
	uint8_t bg_g = 0;
	uint8_t bg_b = 0;

	DisplayBuffer(int width, int height);
	~DisplayBuffer();

	void set_pixel(
		uint16_t x, uint16_t y,
		uint8_t r, uint8_t g, uint8_t b)
	{
		if (x >= width || y >= height)
			return;
		int offset = (x + y * width) * 4; // start index of 4-byte chunk
		bytes[offset + 0] = r;
		bytes[offset + 1] = g;
		bytes[offset + 2] = b;
		bytes[offset + 3] = 0xFF;
	}

	void set_font(godot::Ref<godot::BitMap> bitmap)
	{
		font_bitmap = bitmap;
		if (bitmap != nullptr)
		{
			font_w = bitmap->get_size().x / FONT_SHEET_COLS;
			font_h = bitmap->get_size().y / FONT_SHEET_ROWS;
		}
	}

	void draw_rect(
		int x, int y,
		int w, int h,
		uint8_t r, uint8_t g, uint8_t b);

	void draw_char(
		uint8_t ch,
		int x, int y,
		uint8_t fg_r, uint8_t fg_g, uint8_t fg_b,
		uint8_t bg_r, uint8_t bg_g, uint8_t bg_b);

	void draw_waveform(
		int x, int y,
		uint8_t r, uint8_t g, uint8_t b,
		const uint8_t *points, uint16_t wf_size);

	/// @brief Clear buffer with specified color in RGB8
	void clear(uint8_t r, uint8_t g, uint8_t b)
	{
		draw_rect(0, 0, width, height, r, g, b);
	}

	void clear_bg()
	{
		draw_rect(0, 0, width, height, bg_r, bg_g, bg_b);
	}
};