#include <stdint.h>
#include <godot_cpp/classes/image_texture.hpp>
#include <godot_cpp/classes/bit_map.hpp>

#define FONT_SHEET_COLS 16
#define FONT_SHEET_ROWS 8

class DisplayBuffer
{
public:
    godot::PackedByteArray bytes;
    int width;
    int height;

    godot::Ref<godot::BitMap> font_bitmap;
    int font_w;
    int font_h;

    // changes depending on small/big font
    int font_y_offset = 0;
    int x_offset = 0;
    int y_offset = 0;

    // cached color from fullscreen draw_rect call
    uint8_t bg_r = 0;
    uint8_t bg_g = 0;
    uint8_t bg_b = 0;

    DisplayBuffer(int width, int height);
    ~DisplayBuffer();

    void inline set_pixel(
        uint8_t *data,
        const uint16_t &x, const uint16_t &y,
        const uint8_t &r, const uint8_t &g, const uint8_t &b)
    {
        if (x >= width || y >= height)
            return;
        int offset = (x + y * width) * 4; // start index of 4-byte chunk
        data[offset + 0] = r;
        data[offset + 1] = g;
        data[offset + 2] = b;
        data[offset + 3] = 0xFF;
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
        uint16_t x, uint16_t y,
        uint16_t w, uint16_t h,
        uint8_t r, uint8_t g, uint8_t b);

    void draw_char(
        uint8_t ch,
        uint16_t x, uint16_t y,
        uint8_t fg_r, uint8_t fg_g, uint8_t fg_b,
        uint8_t bg_r, uint8_t bg_g, uint8_t bg_b);

    void draw_waveform(
        uint16_t x, uint16_t y,
        uint8_t r, uint8_t g, uint8_t b,
        uint8_t *points, uint16_t start, uint16_t end);

    /// @brief Clear buffer with specified color in RGB8
    void clear(uint8_t r, uint8_t g, uint8_t b)
    {
        draw_rect(0, 0, width, height, r, g, b);
    }
};