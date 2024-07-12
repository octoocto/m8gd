#include "gdm8.hpp"
#include "utilities.hpp"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <bitset>

using namespace godot;

void M8GDClient::on_disconnect()
{
	print("disconnecting from port");
	m8gd->display_buffer->clear(0, 0, 0);
	m8gd->update_texture();
	m8gd->emit_signal("device_disconnected");
}

void M8GDClient::on_draw_rect(
	uint16_t x, uint16_t y,
	uint16_t w, uint16_t h,
	uint8_t r, uint8_t g, uint8_t b)
{
	m8gd->display_buffer->draw_rect(x, y, w, h, r, g, b);
}

void M8GDClient::on_draw_rect(
	uint16_t x, uint16_t y,
	uint16_t w, uint16_t h)
{
	m8gd->display_buffer->draw_rect(x, y, w, h);
}

void M8GDClient::on_draw_rect(
	uint16_t x, uint16_t y,
	uint8_t r, uint8_t g, uint8_t b)
{
	m8gd->display_buffer->draw_rect(x, y, r, g, b);
}

void M8GDClient::on_draw_rect(uint16_t x, uint16_t y)
{
	m8gd->display_buffer->draw_rect(x, y);
}

void M8GDClient::on_draw_char(
	char c,
	uint16_t x, uint16_t y,
	uint8_t fg_r, uint8_t fg_g, uint8_t fg_b,
	uint8_t bg_r, uint8_t bg_g, uint8_t bg_b)
{
	m8gd->display_buffer->draw_char(c, x, y, fg_r, fg_g, fg_b, bg_r, bg_g, bg_b);
}

void M8GDClient::on_draw_waveform(
	uint16_t x, uint16_t y,
	uint8_t r, uint8_t g, uint8_t b,
	const uint8_t *points, uint16_t start, uint16_t end)
{
	m8gd->display_buffer->draw_waveform(x, y, r, g, b, points, start, end);
}

void M8GDClient::on_key_pressed(uint8_t keybits)
{
	m8gd->emit_signal("keystate_changed", (int)keybits);
}

void M8GDClient::on_system_info(
	libm8::HardwareModel model,
	uint8_t fw_major, uint8_t fw_minor, uint8_t fw_patch,
	libm8::Font font)
{
	m8gd->set_model(model, fw_major, fw_minor, fw_patch, font);
}

void M8GD::_bind_methods()
{
	ClassDB::bind_static_method("M8GD", D_METHOD("list_devices"), &M8GD::list_devices);

	ClassDB::bind_method(D_METHOD("load_font", "bitmap"), &M8GD::load_font);

	ClassDB::bind_method(D_METHOD("update_texture"), &M8GD::update_texture);
	ClassDB::bind_method(D_METHOD("get_display_texture"), &M8GD::get_display_texture);

	ClassDB::bind_method(D_METHOD("get_background_color"), &M8GD::get_background_color);

	ClassDB::bind_method(D_METHOD("send_keyjazz", "note", "velocity"), &M8GD::send_keyjazz);
	ClassDB::bind_method(D_METHOD("send_input", "input_code"), &M8GD::send_input);
	ClassDB::bind_method(D_METHOD("send_theme_color", "index", "color"), &M8GD::send_theme_color);
	ClassDB::bind_method(D_METHOD("send_enable_display"), &M8GD::send_enable_display);
	ClassDB::bind_method(D_METHOD("send_disable_display"), &M8GD::send_disable_display);
	ClassDB::bind_method(D_METHOD("send_reset_display"), &M8GD::reset_display);

	ClassDB::bind_method(D_METHOD("read_serial_data"), &M8GD::read);
	ClassDB::bind_method(D_METHOD("is_connected"), &M8GD::is_connected);

	ClassDB::bind_method(D_METHOD("disconnect"), &M8GD::disconnect);
	ClassDB::bind_method(D_METHOD("connect", "preferred_device"), &M8GD::connect);

	ADD_SIGNAL(MethodInfo("system_info", PropertyInfo(Variant::STRING, "hardware"), PropertyInfo(Variant::STRING, "firmware")));
	ADD_SIGNAL(MethodInfo("font_changed", PropertyInfo(Variant::INT, "model"), PropertyInfo(Variant::STRING, "font")));
	ADD_SIGNAL(MethodInfo("keystate_changed", PropertyInfo(Variant::INT, "keystate")));
	ADD_SIGNAL(MethodInfo("device_disconnected"));
}

M8GD::M8GD()
{
	display_buffer = nullptr;

	set_display_size(320, 240);

	print("created m8gd instance");
}

M8GD::~M8GD()
{
	print("destructing m8gd instance");
	delete display_buffer;
	disconnect();
}

void M8GD::set_model(libm8::HardwareModel model)
{
	if (model == libm8::MODEL_02)
	{
		set_display_size(libm8::RES_MODEL_02[0], libm8::RES_MODEL_02[1]);
	}
	else // model 01 res also applies to beta and headless
	{
		set_display_size(libm8::RES_MODEL_01[0], libm8::RES_MODEL_01[1]);
	}
	sys_model = int(model);
}

void M8GD::set_model(libm8::HardwareModel model,
					 uint8_t fw_1, uint8_t fw_2, uint8_t fw_3, uint8_t font)
{
	static uint8_t font_last = 0xFF;

	switch (model)
	{
	case libm8::MODEL_HEADLESS:
		sys_hardware = "headless";
		break;
	case libm8::MODEL_BETA:
		sys_hardware = "beta";
		break;
	case libm8::MODEL_01:
		sys_hardware = "model_01";
		break;
	case libm8::MODEL_02:
		sys_hardware = "model_02";
		break;
	}

	sys_firmware = godot::vformat("%d.%d.%d", fw_1, fw_2, fw_3);

	// resize display buffer if different model
	if ((int)model != sys_model)
	{
		set_model(model);
		emit_signal("system_info", sys_hardware, sys_firmware);
	}

	// emit "font_changed" if requested font is different
	if (font_last == 0xFF || font != font_last)
	{
		font_last = font;
		emit_signal("font_changed", get_model_name(model), font);

		// change font parameters

		print("requested font: %d", font);

		libm8::FontParameters font_params = libm8::get_font_params(model, font);

		display_buffer->x_offset = font_params.screen_x_offset;
		display_buffer->y_offset = font_params.screen_y_offset;
		display_buffer->font_y_offset = font_params.font_y_offset;
		display_buffer->waveform_max = font_params.waveform_max;
	}
}

void M8GD::set_display_size(uint16_t width, uint16_t height)
{
	print("setting display buffer size to (%d, %d)", width, height);

	if (display_buffer != nullptr)
	{
		delete display_buffer;
	}

	display_buffer = new DisplayBuffer(width, height);
	display_buffer->set_font(font_bitmap);
	display_image = Image::create(width, height, false, Image::FORMAT_RGBA8);

	if (display_texture == nullptr)
	{
		display_texture = ImageTexture::create_from_image(display_image);
	}
	else
	{
		display_texture->set_image(display_image);
	}
}

void M8GD::update_texture()
{
	display_image->set_data(display_buffer->width, display_buffer->height, false, Image::FORMAT_RGBA8, display_buffer->bytes);
	display_texture->update(display_image);
}

Ref<ImageTexture> M8GD::get_display_texture()
{
	return display_texture;
}

Color M8GD::get_background_color()
{
	return Color(
		display_buffer->bg_r / 255.0,
		display_buffer->bg_g / 255.0,
		display_buffer->bg_b / 255.0,
		1.0);
}

void M8GD::load_font(Ref<BitMap> bitmap)
{
	font_bitmap = bitmap;
	display_buffer->set_font(bitmap);
	print("loaded font with size (%d, %d)", bitmap->get_size().x, bitmap->get_size().y);
}

void M8GD::reset_display()
{
	m8_client.send_reset_display();
}

void M8GD::enable_and_reset_display()
{
	m8_client.send_enable_display();
	m8_client.send_reset_display();
}

bool M8GD::read()
{
	libm8::Error error = m8_client.read();

	if (error != libm8::OK)
	{
		printerr("read() failed, error code = %d", error);
		return false;
	}

	return true;
}

bool M8GD::is_connected()
{
	return m8_client.is_connected();
}

void M8GD::send_keyjazz(uint8_t note, uint8_t velocity)
{
	m8_client.send_keyjazz(note, velocity);
}

void M8GD::send_input(uint8_t keystate)
{
	m8_client.send_control_keys(keystate);
}

void M8GD::send_theme_color(uint8_t index, Color color)
{
	// ERR_FAIL_COND_MSG(index > 12, vformat("Invalid color index %d", index));

	const uint32_t rgba32 = color.to_rgba32();
	uint8_t *rgba = (uint8_t *)&rgba32;
	libm8::Error err = m8_client.send_theme_color(index, rgba[3], rgba[2], rgba[1]);
	print("set theme color at idx %d to %02X %02X %02X", index, rgba[3], rgba[2], rgba[1]);

	ERR_FAIL_COND_MSG(err != libm8::OK, vformat("Failed to send command, error code = %d", err));
}

void M8GD::send_enable_display()
{
	m8_client.send_enable_display();
}

void M8GD::send_disable_display()
{
	m8_client.send_disable_display();
}

godot::TypedArray<godot::String> M8GD::list_devices()
{
	TypedArray<String> port_names;
	struct sp_port **port_list;

	enum sp_return result = sp_list_ports(&port_list);

	if (result != SP_OK)
	{
		printerr("failed to list ports!");
		return port_names;
	}

	for (int i = 0; port_list[i] != nullptr; i++)
	{
		struct sp_port *port = port_list[i];
		char *port_name = sp_get_port_name(port);

		if (libm8::is_m8_serial_port(port))
		{
			port_names.append(port_name);
		}
	}

	sp_free_port_list(port_list);

	return port_names;
}

void M8GD::disconnect()
{
	m8_client.disconnect();
}

bool M8GD::connect(String target_port_name)
{
	print("connecting to port \"%s\"...", target_port_name);

	return m8_client.connect(target_port_name) == libm8::OK;
}
