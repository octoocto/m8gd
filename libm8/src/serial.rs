use crate::*;

use serialport;
use std::result::Result;
use std::sync::Arc;
use std::sync::atomic::AtomicBool;
use std::sync::mpsc;
use std::thread;

/// Max amount of bytes to read through the serial port in one poll.
const SERIAL_BUFFER_SIZE: usize = 1024;

/// Max amount of bytes to store in the command buffer.
const COMMAND_BUFFER_SIZE: usize = 1024;

/// Max amount of consecutive zero-byte reads before assuming the device disconnected.
// const MAX_ZERO_READS: i32 = 256;

impl From<std::io::Error> for Error {
    fn from(error: std::io::Error) -> Self {
        Error::DeviceReadError(error.to_string())
    }
}

pub fn connect_serial(
    preferred_path: Option<&str>,
    check_if_valid: bool,
) -> Result<Box<SerialBackend>, Error> {
    let mut backend = SerialBackend::new();
    backend.set_preferred_path(preferred_path, check_if_valid)?;
    backend.connect()?;
    Ok(backend)
}

/// Check if the given serial port is connected via USB and matches the M8 device's VID and PID.
pub fn is_valid_serial_port(port: &serialport::SerialPortInfo) -> bool {
    match &port.port_type {
        serialport::SerialPortType::UsbPort(info) => {
            info.vid == M8_VID && (info.pid == M8_PID_STEREO || info.pid == M8_PID_MULTICHANNEL)
        }
        _ => false,
    }
}

pub fn is_valid_serial_port_path(path: &str) -> bool {
    match get_serial_ports(true).into_iter().find(|p| p == path) {
        Some(_) => true,
        None => false,
    }
}

/// Return a list of available serial ports.
///
/// If [valid_only] is true, only return ports to M8 devices.
///
pub fn get_serial_ports(valid_only: bool) -> Vec<String> {
    let ports = serialport::available_ports()
        .unwrap_or(Vec::new())
        .iter()
        .filter(|port| {
            if valid_only {
                is_valid_serial_port(port)
            } else {
                true
            }
        })
        .map(|port| port.port_name.clone())
        .collect();
    ports
}

#[derive(Clone)]
struct ByteBuffer<const N: usize> {
    buffer: [u8; N],
    position: usize,
}

impl<const N: usize> ByteBuffer<N> {
    fn new() -> Self {
        ByteBuffer {
            buffer: [0; N],
            position: 0,
        }
    }

    fn clear(&mut self) {
        self.position = 0;
    }

    fn push(&mut self, byte: u8) -> Result<(), Error> {
        if self.position >= SERIAL_BUFFER_SIZE {
            return Err(Error::BufferOverflow);
        }
        self.buffer[self.position] = byte;
        self.position += 1;
        Ok(())
    }

    fn as_slice(&self) -> &[u8] {
        &self.buffer[..self.position]
    }
}

pub struct SerialBackend {
    /// The preferred path to the serial port.
    preferred_path: Option<String>,

    /// If connected, the path to the serial port.
    path: Option<String>,

    /// If connected, the serial port.
    port: Option<Box<dyn serialport::SerialPort>>,

    /// Handle to the read thread.
    read_thread_handle: Option<thread::JoinHandle<()>>,
    read_thread_running: Arc<AtomicBool>,

    /// Receiver for read bytes.
    read_receiver: Option<mpsc::Receiver<(Arc<[u8]>, usize)>>,
    /// Receiver for incoming errors.
    error_receiver: Option<mpsc::Receiver<Error>>,

    disconnect_callback: Option<Box<dyn FnMut()>>,

    /// If the port is connected.
    ///
    /// If true, [self.path] and [self.port] will be [Some].
    is_connected: bool,

    command_buffer: ByteBuffer<COMMAND_BUFFER_SIZE>,

    slip_escaped: bool,
    // zero_reads: i32,
}

impl SerialBackend {
    pub fn new() -> Box<SerialBackend> {
        Box::new(SerialBackend {
            preferred_path: None,

            path: None,
            port: None,

            read_thread_handle: None,
            read_thread_running: Arc::new(AtomicBool::new(false)),

            read_receiver: None,
            error_receiver: None,

            disconnect_callback: None,
            is_connected: false,
            command_buffer: ByteBuffer::new(),
            slip_escaped: false,
            // zero_reads: 0,
        })
    }

    /// Set the preferred path to the serial port.
    ///
    /// If [preferred_path] is [None], the first available valid device will be used.
    /// If [check_if_valid] is true, the path will only be set if it points to a valid device.
    pub fn set_preferred_path(
        &mut self,
        preferred_path: Option<&str>,
        check_if_valid: bool,
    ) -> Result<(), Error> {
        let Some(preferred_path) = preferred_path else {
            self.preferred_path = None;
            return Ok(());
        };

        // check if the preferred path exists
        let port_exists = get_serial_ports(check_if_valid)
            .iter()
            .filter(|p| p.as_str() == preferred_path)
            .count()
            > 0;

        if port_exists {
            self.preferred_path = Some(String::from(preferred_path));
            Ok(())
        } else {
            Err(Error::DeviceConnectionError(format!(
                "Serial port {} not found",
                preferred_path
            )))
        }
    }

    /// Start a thread to read from the serial port.
    ///
    /// The given Senders and a clone of the Arc pointer to [port] will be moved to the thread.
    fn start_read_thread(
        &mut self,
        mut port: Box<dyn serialport::SerialPort>,
        read_sender: mpsc::SyncSender<(Arc<[u8]>, usize)>,
        error_sender: mpsc::Sender<Error>,
        read_thread_running: Arc<AtomicBool>,
    ) -> Result<(), Error> {
        let handle = thread::spawn(move || {
            let mut read_bytes = [0; SERIAL_BUFFER_SIZE];
            loop {
                if read_thread_running.load(std::sync::atomic::Ordering::Relaxed) == false {
                    println!("Read thread stopping...");
                    break;
                }
                match port.read(read_bytes.as_mut_slice()) {
                    Ok(bytes_read) => {
                        let _ = read_sender.send((Arc::new(read_bytes), bytes_read));
                    }
                    Err(e) if e.kind() == std::io::ErrorKind::TimedOut => {
                        continue;
                    }
                    Err(e) if e.kind() == std::io::ErrorKind::Interrupted => {
                        continue;
                    }
                    Err(e) => {
                        println!("Error reading from device: {}", e);
                        error_sender.send(e.into()).unwrap();
                        break;
                    }
                }
            }
        });
        self.read_thread_handle = Some(handle);
        Ok(())
    }
}

impl Backend for SerialBackend {
    fn connect(&mut self) -> Result<(), Error> {
        if self.is_connected() {
            return Err(Error::DeviceConnectionError(
                "Already connected to a device".to_string(),
            ));
        }

        let path = match &self.preferred_path {
            Some(p) => String::from(p),
            None => {
                // use first valid port
                let ports = get_serial_ports(true);
                if ports.is_empty() {
                    return Err(Error::DeviceConnectionError(
                        "No valid serial ports found".to_string(),
                    ));
                }
                ports[0].clone()
            }
        };

        let result = serialport::new(&path, 115200)
            .data_bits(serialport::DataBits::Eight)
            .parity(serialport::Parity::None)
            .stop_bits(serialport::StopBits::One)
            .flow_control(serialport::FlowControl::None)
            .timeout(std::time::Duration::from_millis(1000))
            .open()
            .map_err(|e| Error::DeviceConnectionError(e.to_string()));

        match result {
            Ok(port) => {
                let (read_sender, read_receiver) = mpsc::sync_channel(0);
                let (error_sender, error_receiver) = mpsc::channel();

                // create a clone of the port for read thread
                let port_clone = port.try_clone().map_err(|e| {
                    Error::DeviceConnectionError(format!(
                        "Failed to clone serial port {}: {}",
                        path, e
                    ))
                })?;

                self.read_receiver = Some(read_receiver);
                self.error_receiver = Some(error_receiver);
                self.path = Some(path);
                self.port = Some(port);
                self.is_connected = true;
                self.read_thread_running = Arc::new(AtomicBool::new(true));

                // send a series of commands to the M8 to initialize the display
                self.send_command(CommandOut::DisableDisplay)?;
                std::thread::sleep(std::time::Duration::from_millis(100));
                self.send_command(CommandOut::EnableDisplay)?;
                self.send_command(CommandOut::ResetDisplay)?;

                self.start_read_thread(
                    port_clone,
                    read_sender,
                    error_sender,
                    self.read_thread_running.clone(),
                )?;

                Ok(())
            }
            Err(e) => {
                eprintln!("Failed to open serial port: {}", e);
                Err(e)
            }
        }
    }

    fn disconnect(&mut self) -> Result<(), Error> {
        if !self.is_connected {
            return Err(Error::DeviceConnectionError(
                "Not connected to any device".to_string(),
            ));
        }

        // stop read thread
        // match self.thread_stop_sender.take().unwrap().send(()) {
        //     Ok(_) => {}
        //     Err(e) => {
        //         eprintln!("Error stopping read thread: {}", e);
        //         Err(Error::DeviceConnectionError(
        //             "Failed to stop read thread".to_string(),
        //         ))?
        //     }
        // }
        self.read_thread_running
            .store(false, std::sync::atomic::Ordering::Relaxed);
        println!("Stopping read thread...");

        let _ = self.send_command(CommandOut::DisableDisplay);
        let path = self.path.as_ref().unwrap().clone();

        self.is_connected = false;
        self.port = None;
        self.path = None;
        self.read_receiver = None;
        self.error_receiver = None;
        self.command_buffer.clear();
        self.slip_escaped = false;

        match self.read_thread_handle.take().unwrap().join() {
            Ok(_) => {}
            Err(e) => {
                eprintln!("Error joining read thread: {:?}", e);
                Err(Error::DeviceConnectionError(
                    "Failed to stop read thread".to_string(),
                ))?
            }
        }

        println!("Disconnected from port {:?}", path);
        return Ok(());
    }

    fn is_connected(&self) -> bool {
        return self.is_connected && self.port.is_some();
    }

    fn send_command(&mut self, command: CommandOut) -> Result<(), Error> {
        if !self.is_connected {
            return Err(Error::DeviceNotConnected(format!(
                "Not connected to any device on port {:?}",
                self.path
            )));
        }
        self.port
            .as_mut()
            .unwrap()
            .write_all(&command.to_bytes())
            .map_err(|e| {
                let path = self.path.as_ref();
                Error::DeviceConnectionError(format!(
                    "Failed to send command on port {:?}: {}",
                    path, e
                ))
            })?;
        Ok(())
    }

    fn poll(&mut self) -> Result<Vec<CommandIn>, Error> {
        if !self.is_connected {
            return Err(Error::DeviceNotConnected(format!(
                "Not connected to any device on port {:?}",
                self.path
            )));
        }

        let read_receiver = self.read_receiver.as_mut().unwrap();
        let error_receiver = self.error_receiver.as_mut().unwrap();

        // check for any errors in the read thread

        if let Ok(error) = error_receiver.try_recv() {
            let _ = self.disconnect();
            return Err(error);
        }

        let mut commands = vec![];

        // try receiving bytes

        let (bytes, bytes_read) = match read_receiver.try_recv() {
            Ok((bytes, bytes_read)) => (bytes, bytes_read),
            Err(mpsc::TryRecvError::Disconnected) => {
                let _ = self.disconnect();
                return Err(Error::DeviceNotConnected(format!(
                    "Device disconnected on port {:?}",
                    self.path
                )));
            }
            Err(mpsc::TryRecvError::Empty) => return Ok(commands),
        };

        // parse commands (received as SLIP packets)

        for i in 0..bytes_read {
            let byte = bytes[i];

            if !self.slip_escaped {
                match SlipByte::from(byte) {
                    SlipByte::End => {
                        // reached end of command, parse it
                        let buf = self.command_buffer.as_slice();
                        if buf.is_empty() {
                            continue;
                        }
                        match CommandIn::from_bytes(buf) {
                            Some(command) => commands.push(command),
                            None => eprintln!("Error parsing command from bytes {:02X?}", buf),
                        };
                        self.command_buffer.clear();
                    }
                    SlipByte::Esc => {
                        // escape
                        self.slip_escaped = true;
                    }
                    _ => {
                        // add byte to command buffer
                        self.command_buffer.push(byte)?;
                    }
                }
            } else {
                match SlipByte::from(byte) {
                    SlipByte::EscEnd => {
                        self.command_buffer.push((&SlipByte::End).into())?;
                        self.slip_escaped = false;
                    }
                    SlipByte::EscEsc => {
                        self.command_buffer.push((&SlipByte::Esc).into())?;
                        self.slip_escaped = false;
                    }
                    _ => {
                        let estring = format!("Invalid SLIP escaped character: {}", byte);
                        eprintln!("{}", estring);
                        return Err(Error::CommandParseError(estring));
                    }
                }
            }
        }

        Ok(commands)
    }
}
