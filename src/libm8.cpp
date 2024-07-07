#include "libm8.hpp"

libm8::Error libm8::Client::read()
{
	if (!is_connected())
		return libm8::ERR_NOT_CONNECTED;

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
			if (error == libm8::ERR_SP_INVALID_ARGS)
			{
				printerr("port invalid, disconnecting...");
				disconnect();
			}
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
		else if (bytes_read == 0)
		{
			zero_reads++;
			if (zero_reads > MAX_ZERO_READS)
			{
				print("zero_reads = %d, disconnecting...", zero_reads);
				disconnect();
			}
		}
	} while (bytes_read > 0);

	return libm8::OK;
}

libm8::Error libm8::Client::connect(godot::String target_port_name)
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

		if (libm8::is_m8_serial_port(port) && target_port_name == port_name)
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
	send_enable_display();
	send_reset_display();
	return OK;
}