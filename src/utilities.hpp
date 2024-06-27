#pragma once

#include <godot_cpp/variant/utility_functions.hpp>

template <typename... VarArgs>
static void print(const godot::String &p_text, const VarArgs... p_args)
{
    godot::String msg = "libm8gd: " + godot::vformat(p_text, p_args...);
    godot::UtilityFunctions::print(msg);
}

template <typename... VarArgs>
static void printerr(const godot::String &p_text, const VarArgs... p_args)
{
    godot::String msg = "libm8gd: " + godot::vformat(p_text, p_args...);
    godot::UtilityFunctions::printerr(msg);
}

static void printerr_bytes(uint8_t *bytes, uint32_t size)
{
    godot::String msg = "  ";
    for (uint16_t a = 0; a < size; a++)
    {
        msg += godot::vformat("0x%02X ", bytes[a]);
    }
    printerr(msg);
}