#include "libm8.hpp"

bool libm8::is_m8_serial_port(sp_port *port)
{
	int usb_vid, usb_pid;
	sp_get_port_usb_vid_pid(port, &usb_vid, &usb_pid);
	return usb_vid == M8_USB_VID && usb_pid == M8_USB_PID;
}

bool libm8::is_m8_serial_port(const char *port_name)
{
	struct sp_port *port;
	sp_get_port_by_name(port_name, &port);
	if (port == nullptr)
		return false;

	bool is_m8 = libm8::is_m8_serial_port(port);
	sp_free_port(port);
	return is_m8;
}

char *libm8::get_serial_port_description(const char *port_name)
{
	struct sp_port *port;
	sp_get_port_by_name(port_name, &port);
	if (port == nullptr)
		return (char*)"";

	char *description = sp_get_port_description(port);
	sp_free_port(port);
	return description;
}

libm8::FontParameters libm8::get_font_params(uint8_t model, uint8_t font)
{
	if (model == MODEL_02)
	{
		switch (font)
		{
		case FONT_SMALL:
			return FONT_02_SMALL;
		case FONT_LARGE:
			return FONT_02_BOLD;
		case FONT_HUGE:
			return FONT_02_HUGE;
		}
	}
	else
	{
		switch (font)
		{
		case FONT_SMALL:
			return FONT_01_SMALL;
		case FONT_LARGE:
			return FONT_01_BIG;
		}
	}
	printerr("unable to find correct font parameters! (model=%d, font=%d)", model, font);
	return FONT_01_SMALL;
}

bool libm8::Client::check_connected()
{
	struct sp_port **port_list;
	bool found = false;

	const enum sp_return result = sp_list_ports(&port_list);
	if (result != SP_OK) {
		printerr("libserialport: failed to list ports");
		return false;
	}

	for (int i = 0; port_list[i] != NULL; i++)
	{
		struct sp_port *port = port_list[i];
		if (is_m8_serial_port(port)) {
			const char *current_port_name = sp_get_port_name(port);
			const char *connected_port_name = sp_get_port_name(m8_port);
			found = strcmp(current_port_name, connected_port_name) == 0;
		}
	}
	sp_free_port_list(port_list);

	return found;
}

libm8::Error libm8::Client::connect(godot::String target_port_name, bool force)
{
	enum sp_return result;

	if (m8_port != nullptr)
		return OK;

	struct sp_port **port_list;

	result = sp_list_ports(&port_list);
	if (result != SP_OK)
		return sp_to_m8(result);

	for (int i = 0; port_list[i] != nullptr; i++)
	{
		struct sp_port *port = port_list[i];
		char *port_name = sp_get_port_name(port);

		if (target_port_name == port_name && (libm8::is_m8_serial_port(port) || force))
		{
			sp_copy_port(port, &m8_port);
		}
	}

	sp_free_port_list(port_list);

	if (m8_port == nullptr)
	{
		printerr("failed to find an M8 with port \"%s\"!", target_port_name);
		return ERR_DEVICE_NOT_FOUND;
	}

	print("opening port \"%s\"...", target_port_name);

	// open M8 port
	result = sp_open(m8_port, SP_MODE_READ_WRITE);
	if (result != SP_OK)
		return sp_to_m8(result);

	// configure M8 port
	result = sp_set_baudrate(m8_port, M8_SP_BAUD_RATE);
	if (result != SP_OK)
		return sp_to_m8(result);

	result = sp_set_bits(m8_port, M8_SP_DATA_BITS);
	if (result != SP_OK)
		return sp_to_m8(result);

	result = sp_set_parity(m8_port, M8_SP_PARITY);
	if (result != SP_OK)
		return sp_to_m8(result);

	result = sp_set_stopbits(m8_port, M8_SP_STOP_BITS);
	if (result != SP_OK)
		return sp_to_m8(result);

	result = sp_set_flowcontrol(m8_port, M8_SP_FLOWCONTROL);
	if (result != SP_OK)
		return sp_to_m8(result);

	print("port successfully opened!");

	send_disable_display();
	std::this_thread::sleep_for(std::chrono::milliseconds(100));
	send_enable_display();
	send_reset_display();
	return OK;
}

libm8::Error libm8::Client::read()
{
	if (!is_connected())
		return libm8::ERR_DEVICE_DISCONNECTED;

	int bytes_read;
	static bool is_slip_escaped = false;

	// keep reading bytes until there is nothing to read
	do
	{
		// read RX_BUFFER_SIZE bytes from the serial port
		bytes_read = sp_nonblocking_read(m8_port, rx_buffer, RX_BUFFER_SIZE);

		if (bytes_read < 0)
		{
			// bytes_read is a libserialport error code
			libm8::Error error = sp_to_m8((sp_return)bytes_read);
			printerr("read error (code=%d), disconnecting...", error);
			disconnect();
			return error;
		}
		else if (bytes_read > 0)
		{
			zero_reads = 0;

			for (int i = 0; i < bytes_read; i++)
			{
				uint8_t byte = rx_buffer[i];

				// read and decode SLIP bytes

				if (!is_slip_escaped)
				{
					switch (byte)
					{
					case libm8::SLIP_END: // end of command, process cmd_buffer
						read_command(cmd_buffer, cmd_size);
						cmd_size = 0; // effectively reset the cmd_buffer
						memset(cmd_buffer, 0, CMD_BUFFER_SIZE * sizeof(*cmd_buffer));
						break;
					case libm8::SLIP_ESC: // escape
						is_slip_escaped = true;
						break;
					default: // add byte to cmd_buffer as-is
						cmd_buffer_append(byte);
						break;
					}
				}
				else
				{
					switch (byte)
					{
					case libm8::SLIP_ESC_END:
						cmd_buffer_append(libm8::SLIP_END);
						break;
					case libm8::SLIP_ESC_ESC:
						cmd_buffer_append(libm8::SLIP_ESC);
						break;
					default:
						return libm8::ERR_SLIP_INVALID_ESCAPED_CHAR;
					}
					is_slip_escaped = false;
				}
			}
		}
		else
		{
			zero_reads++;
			if (zero_reads >= max_zero_reads)
			{
				if (check_connected())
				{
					if (send_ping() != libm8::OK) {
						printerr("ping failed, disconnecting...");
						disconnect();
						break;
					}
					zero_reads = 0;
				}
				else {
					printerr("zero_reads = %d, disconnecting...", zero_reads);
					disconnect();
					break;
				}
			}
		}
	} while (bytes_read > 0);

	return libm8::OK;
}

libm8::Error libm8::Client::read_command(uint8_t *cmd_buffer, const uint16_t &cmd_size)
{
	switch (cmd_buffer[0])
	{
	case libm8::DRAW_RECT:
	{

		if (cmd_size != libm8::DRAW_RECT_SIZE_1 && cmd_size != libm8::DRAW_RECT_SIZE_2 && cmd_size != libm8::DRAW_RECT_SIZE_3 && cmd_size != libm8::DRAW_RECT_SIZE_4)
		{
			printerr(
				"DRAW_RECT failed: expected length %d/%d/%d/%d, got %d",
				libm8::DRAW_RECT_SIZE_1, libm8::DRAW_RECT_SIZE_2, libm8::DRAW_RECT_SIZE_3, libm8::DRAW_RECT_SIZE_4, cmd_size);
			printerr_bytes(cmd_buffer, cmd_size);
			return libm8::ERR_CMD_HANDLER_INVALID_SIZE;
		}
		// print("received draw_rectangle_command");

		static uint8_t last_r = 0;
		static uint8_t last_g = 0;
		static uint8_t last_b = 0;

		switch (cmd_size)
		{
		case libm8::DRAW_RECT_SIZE_1:
			on_draw_rect(
				libm8::decode_u16(cmd_buffer, 1),
				libm8::decode_u16(cmd_buffer, 3),
				libm8::decode_u16(cmd_buffer, 5),
				libm8::decode_u16(cmd_buffer, 7),
				cmd_buffer[9],
				cmd_buffer[10],
				cmd_buffer[11]);
			last_r = cmd_buffer[9];
			last_g = cmd_buffer[10];
			last_b = cmd_buffer[11];
			break;
		case libm8::DRAW_RECT_SIZE_2:
			on_draw_rect(
				libm8::decode_u16(cmd_buffer, 1),
				libm8::decode_u16(cmd_buffer, 3),
				libm8::decode_u16(cmd_buffer, 5),
				libm8::decode_u16(cmd_buffer, 7),
				last_r,
				last_g,
				last_b);
			break;
		case libm8::DRAW_RECT_SIZE_3:
			on_draw_rect(
				libm8::decode_u16(cmd_buffer, 1),
				libm8::decode_u16(cmd_buffer, 3),
				1,
				1,
				cmd_buffer[5],
				cmd_buffer[6],
				cmd_buffer[7]);
			last_r = cmd_buffer[5];
			last_g = cmd_buffer[6];
			last_b = cmd_buffer[7];
			break;
		case libm8::DRAW_RECT_SIZE_4:
			on_draw_rect(
				libm8::decode_u16(cmd_buffer, 1),
				libm8::decode_u16(cmd_buffer, 3),
				1,
				1,
				last_r,
				last_g,
				last_b);
			break;
		}

		break;
	}

	case libm8::DRAW_CHAR:

		if (cmd_size != libm8::DRAW_CHAR_SIZE)
		{
			printerr(
				"DRAW_CHAR failed: expected length %d, got %d",
				libm8::DRAW_CHAR_SIZE, cmd_size);

			// printerr_bytes(size, cmd_buffer);
			return libm8::ERR_CMD_HANDLER_INVALID_SIZE;
		}
		// print("received draw_character_command");
		// print("drawing character \"%c\"", cmd_buffer[1]);
		on_draw_char(
			cmd_buffer[1],
			libm8::decode_u16(cmd_buffer, 2), libm8::decode_u16(cmd_buffer, 4),
			cmd_buffer[6], cmd_buffer[7], cmd_buffer[8],
			cmd_buffer[9], cmd_buffer[10], cmd_buffer[11]);
		break;

	case libm8::DRAW_OSC:

		if (cmd_size < libm8::DRAW_OSC_SIZE_MIN ||
			cmd_size > libm8::DRAW_OSC_SIZE_MAX)
		{
			printerr(
				"DRAW_OSC failed: expected length between %d and %d, got %d",
				libm8::DRAW_OSC_SIZE_MIN,
				libm8::DRAW_OSC_SIZE_MAX, cmd_size);

			printerr_bytes(cmd_buffer, cmd_size);
			return libm8::ERR_CMD_HANDLER_INVALID_SIZE;
		}
		// print("received draw_oscilloscope_waveform_command");
		on_draw_waveform(
			0, 0,
			cmd_buffer[1], cmd_buffer[2], cmd_buffer[3],
			&cmd_buffer[4], cmd_size - 4);
		break;

	case libm8::KEY_PRESS:
	{
		if (cmd_size != libm8::KEY_PRESS_SIZE)
		{
			printerr(
				"KEY_PRESS failed: expected length %d, got %d",
				libm8::KEY_PRESS_SIZE, cmd_size);
			printerr_bytes(cmd_buffer, cmd_size);
			return libm8::ERR_CMD_HANDLER_INVALID_SIZE;
		}
		// print("received key pressed:");
		// print("	%s %s", std::bitset<8>(cmd_buffer[1]).to_string().c_str(), std::bitset<8>(cmd_buffer[2]).to_string().c_str());
		on_key_pressed(cmd_buffer[1]);
		break;
	}

	case libm8::SYSTEM_INFO:
	{
		if (cmd_size != libm8::SYSTEM_INFO_SIZE)
		{
			printerr(
				"SYSTEM_INFO failed: expected length %d, got %d",
				libm8::SYSTEM_INFO_SIZE, cmd_size);
			printerr_bytes(cmd_buffer, cmd_size);
			return libm8::ERR_CMD_HANDLER_INVALID_SIZE;
		}
		// print("received system_info_command");
		on_system_info(
			(libm8::HardwareModel)cmd_buffer[1],
			cmd_buffer[2], cmd_buffer[3], cmd_buffer[4],
			(libm8::Font)cmd_buffer[5]);
		break;
	}
	default:
		printerr("received invalid command packet:");
		printerr_bytes(cmd_buffer, cmd_size);
		return libm8::ERR_CMD_HANDLER_INVALID_CMD;
	}

	return libm8::OK;
}
