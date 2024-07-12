#include "display_buffer.hpp"
#include "utilities.hpp"

#define CHARS_PER_ROW 94
#define CHARS_PER_COL 1

DisplayBuffer::DisplayBuffer(int width, int height) : width(width), height(height)
{
	bytes = godot::PackedByteArray();
	bytes.resize(width * height * 4);
}

DisplayBuffer::~DisplayBuffer() {}

void DisplayBuffer::draw_rect(uint16_t x, uint16_t y, uint16_t w, uint16_t h, uint8_t r, uint8_t g, uint8_t b)
{
	last_r = r;
	last_g = g;
	last_b = b;

	// save color as background color if was a fullscreen rect
	if (x == 0 && y == 0 && w >= width && h >= height)
	{
		bg_r = r;
		bg_g = g;
		bg_b = b;
	}
	else
	{
		x += x_offset;
		y += y_offset;
	}

	uint8_t *data = bytes.ptrw();

	// uint32_t color = rgb_to_rgba(r, g, b);
	for (int i = x; i < x + w && x < width; i++)
	{
		for (int j = y; j < y + h && y < height; j++)
		{
			set_pixel(data, i, j, r, g, b);
		}
	}
}

void DisplayBuffer::draw_rect(uint16_t x, uint16_t y, uint16_t w, uint16_t h)
{
	draw_rect(x, y, w, h, last_r, last_g, last_b);
}

void DisplayBuffer::draw_rect(uint16_t x, uint16_t y, uint8_t r, uint8_t g, uint8_t b)
{
	draw_rect(x, y, 1, 1, r, g, b);
}

void DisplayBuffer::draw_rect(uint16_t x, uint16_t y)
{
	draw_rect(x, y, 1, 1, last_r, last_g, last_b);
}

void DisplayBuffer::draw_char(
	uint8_t ch,
	uint16_t x, uint16_t y,
	uint8_t fg_r, uint8_t fg_g, uint8_t fg_b,
	uint8_t bg_r, uint8_t bg_g, uint8_t bg_b)
{

	// bitmap only covers unicode 0-127
	if (font_bitmap == nullptr || ch > 127)
		return;

	// starting x/y of glyph in bitmap
	int x0 = (ch % FONT_SHEET_COLS) * font_w;
	int y0 = (ch / FONT_SHEET_COLS) * font_h;

	x += x_offset;
	y += font_y_offset + y_offset;

	uint8_t *data = bytes.ptrw();

	for (int i = 0; i < font_w; i++)
	{
		for (int j = 0; j < font_h; j++)
		{
			if (font_bitmap->get_bit(x0 + i, y0 + j))
			{
				set_pixel(data, x + i, y + j, fg_r, fg_g, fg_b);
			}
			else
			{
				set_pixel(data, x + i, y + j, this->bg_r, this->bg_g, this->bg_b);
			}
		}
	}
}

void DisplayBuffer::draw_waveform(
	uint16_t x, uint16_t y,
	uint8_t r, uint8_t g, uint8_t b,
	const uint8_t *points, uint16_t start, uint16_t end)
{
	// store last waveform width for case when waveform width is 0
	static uint16_t last_wf_width = 0;
	uint16_t wf_width = end - start;

	if (wf_width == 0)
	{
		wf_width = last_wf_width;
	}

	int wf_offset = width - (wf_width); // x-offset of waveform

	// clear region with background color
	draw_rect(
		x - x_offset + wf_offset, y - y_offset,
		wf_width, waveform_max,
		bg_r, bg_g, bg_b);

	if (wf_width > 0)
	{
		uint8_t *data = bytes.ptrw();

		for (int i = 0; i < end - start; i++)
		{
			uint8_t ampl = points[i + start];
			if (ampl > waveform_max - 1)
				ampl = waveform_max - 1;
			set_pixel(data, x + i + wf_offset, y + ampl, r, g, b);
		}

		last_wf_width = wf_width;
	}
}