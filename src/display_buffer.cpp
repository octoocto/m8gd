#include "display_buffer.hpp"
#include "utilities.hpp"

#define CHARS_PER_ROW 94
#define CHARS_PER_COL 1

DisplayBuffer::DisplayBuffer(int width, int height) : width(width), height(height)
{
	byte_array = godot::PackedByteArray();
	byte_array.resize(width * height * 4);
	bytes = byte_array.ptrw();
}

DisplayBuffer::~DisplayBuffer() {}

void DisplayBuffer::set_background_alpha(uint8_t a)
{
	bg_alpha = a;

	// update colors in image buffer
	for (int i = 0; i < width; i++)
	{
		for (int j = 0; j < height; j++)
		{
			color c = get_pixel(i, j);
			set_pixel(i, j, c.r, c.g, c.b);
		}
	}

	// print("set background alpha to %d", a);
}

void DisplayBuffer::draw_rect(int x, int y, int w, int h, uint8_t r, uint8_t g, uint8_t b)
{
	y = y + screen_offset_y;

	// save color as background color if was a fullscreen rect
	if (x == 0 && y <= 0 && w == width && h >= height)
	{
		bg_r = r;
		bg_g = g;
		bg_b = b;
	}

	if (
		(w == 24 && h == 7) ||
		(w == 30 && h == 9) ||
		(w == 36 && h == 11) ||
		(w == 45 && h == 13))
	{
		append_color(r, g, b);
	}

	for (int i = x; i < x + w && x < width; i++)
	{
		for (int j = y; j < y + h && y < height; j++)
		{
			set_pixel(i, j, r, g, b);
		}
	}
}

void DisplayBuffer::draw_char(
	uint8_t ch,
	int x, int y,
	uint8_t fg_r, uint8_t fg_g, uint8_t fg_b,
	uint8_t bg_r, uint8_t bg_g, uint8_t bg_b)
{
	// bitmap only covers unicode 0-127
	if (font_bitmap == nullptr || ch > 127)
		return;

	// starting x/y of glyph in bitmap
	int x0 = (ch % FONT_SHEET_COLS) * font_w;
	int y0 = (ch / FONT_SHEET_COLS) * font_h;

	y += font_offset_y + screen_offset_y;

	// skip drawing bg if fg color = bg color
	bool draw_bg = (fg_r != bg_r || fg_g != bg_g || fg_b != bg_b);

	for (int i = 0; i < font_w; i++)
	{
		for (int j = 0; j < font_h; j++)
		{
			if (font_bitmap->get_bit(x0 + i, y0 + j))
			{
				set_pixel(x + i, y + j, fg_r, fg_g, fg_b);
			}
			else if (draw_bg)
			{
				set_pixel(x + i, y + j, bg_r, bg_g, bg_b);
			}
		}
	}

	// if (fg_r != 0x70 || fg_g != 0xB0 || fg_b != 0x08)
	// {
	// 	append_color(fg_r, fg_g, fg_b);
	// }
	// else
	// {
	// 	print("green size: %d, %d", x, y);
	// }
}

void DisplayBuffer::draw_waveform(
	int x, int y,
	uint8_t r, uint8_t g, uint8_t b,
	const uint8_t *points, uint16_t size)
{
	// store last waveform width for case when waveform width is 0
	static uint16_t last_wf_size = 0;

	int wf_size = size;

	if (wf_size == 0)
	{
		wf_size = last_wf_size;
	}
	last_wf_size = wf_size;

	int offset_x = width - wf_size;

	// clear region with background color
	draw_rect(x + offset_x, y - screen_offset_y, wf_size, waveform_max + 1, bg_r, bg_g, bg_b);

	// draw points in waveform
	for (int i = 0; i < size; i++)
	{
		uint8_t ampl = points[i];
		if (ampl > waveform_max)
		{
			ampl = waveform_max;
		}
		set_pixel(x + offset_x + i, y + ampl, r, g, b);
	}
}