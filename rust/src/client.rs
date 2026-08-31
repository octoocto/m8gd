use crate::*;

pub trait Client {
    // Required methods

    /// Get the backend used to communicate with the M8 device.
    fn display(&mut self) -> Option<&mut dyn DisplayHandler>;

    /// Process an incoming command from the M8 device.
    fn handle_command(&mut self, command: &CommandIn) -> Result<(), Error>;

    // Provided methods
    fn is_connected(&mut self) -> bool {
        match self.display() {
            Some(display) => display.is_connected(),
            None => false,
        }
    }

    /// Poll incoming commands from the connected device and handles them using
    /// [`Client::handle_command`].
    fn poll(&mut self) -> Result<(), Error> {
        let commands = self.display().ok_or(Error::NoBackend)?.poll()?;
        for command in commands {
            self.handle_command(&command)?;
        }
        Ok(())
    }

    /// Send a command to the M8 device.
    fn send_command(&mut self, command: CommandOut) -> Result<(), Error> {
        self.display()
            .ok_or(Error::NoBackend)?
            .send_command(command)
    }

    fn set_keys(&mut self, keystate: &KeyState) -> Result<(), Error> {
        self.send_command(CommandOut::ControlKeys {
            keybits: keystate.to_byte(),
        })
    }

    fn play_note(&mut self, note: u8, velocity: u8) -> Result<(), Error> {
        self.send_command(CommandOut::KeyJazz { note, velocity })
    }

    fn enable_display(&mut self) -> Result<(), Error> {
        self.send_command(CommandOut::EnableDisplay)
    }

    fn reset_display(&mut self) -> Result<(), Error> {
        self.send_command(CommandOut::ResetDisplay)
    }

    fn set_theme_color(&mut self, index: u8, r: u8, g: u8, b: u8) -> Result<(), Error> {
        self.send_command(CommandOut::ThemeColor { index, r, g, b })
    }

    fn ping(&mut self) -> Result<(), Error> {
        self.send_command(CommandOut::Ping)
    }
}

// Represents a method of connecting to the display of an M8 device.
//
pub trait DisplayHandler {
    fn connect(&mut self) -> Result<(), Error>;
    fn disconnect(&mut self) -> Result<(), Error>;
    fn is_connected(&self) -> bool;

    /// Returns whether the connected device is in multichannel audio mode.
    ///
    /// If no device is connected, or if multichannel mode cannot be determined,
    /// returns [`None`].
    fn is_multichannel_audio(&self) -> Option<bool>;

    /// Poll incoming commands from the device, returning a vector of
    /// commands that were received.
    ///
    /// # Errors
    ///
    /// If the device has disconnected while running this method, [`Error::DeviceNotConnected`] is returned.
    /// If the backend can no longer read data from the device, [`Error::DeviceReadError`]
    /// is returned.
    ///
    /// If any error is returned, the connection is no longer valid and the client that owns
    /// this backend should call [`ClientBackend::disconnect`].
    fn poll(&mut self) -> Result<Vec<CommandIn>, Error>;

    /// Send a command to the device.
    fn send_command(&mut self, command: CommandOut) -> Result<(), Error>;
}
