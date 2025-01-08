#include <stdint.h>
#include <godot_cpp/classes/image_texture.hpp>
#include <godot_cpp/classes/bit_map.hpp>
#include "utilities.hpp"

#define FONT_SHEET_COLS 16
#define FONT_SHEET_ROWS 8

struct color
{
	uint8_t r;
	uint8_t g;
	uint8_t b;
};

class DisplayBuffer
{
public:
	godot::PackedByteArray byte_array;
	uint8_t *bytes;
	uint16_t width;
	uint16_t height;

	godot::Ref<godot::BitMap> font_bitmap; // spritesheet of all characters
	uint8_t font_w;						   // width of each char
	uint8_t font_h;						   // height of each char

	// changes depending on small/big/huge font
	int8_t screen_offset_y = 0;
	int8_t font_offset_y = 0;
	uint8_t waveform_max = 0;

	// cached color from fullscreen draw_rect call
	uint8_t bg_r = 0;
	uint8_t bg_g = 0;
	uint8_t bg_b = 0;

	uint8_t bg_alpha = 0xFF;

	godot::PackedColorArray colors;

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

		if (r == bg_r && g == bg_g && b == bg_b)
		{
			bytes[offset + 3] = bg_alpha;
		}
		else
		{
			bytes[offset + 3] = 0xFF;
		}
	}

	void append_color(uint8_t r, uint8_t g, uint8_t b)
	{
		if (colors.size() < 16)
		{
			godot::Color color = godot::Color::hex((uint32_t(r) << 24) | (uint32_t(g) << 16) | (uint32_t(b) << 8) | uint32_t(0xFF));
			colors.append(color);
			// if (!colors.has(color))
			// {
			// 	colors.append(color);
			// 	// print("adding color: %02X%02X%02X", r, g, b);
			// }
		}
	}

	color get_pixel(uint16_t x, uint16_t y)
	{
		if (x >= width)
		{
			x = width - 1;
		}
		if (y >= height)
		{
			y = height - 1;
		}

		int offset = (x + y * width) * 4;
		return color{
			bytes[offset + 0],
			bytes[offset + 1],
			bytes[offset + 2]};
	}

	void set_background_alpha(uint8_t a);

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