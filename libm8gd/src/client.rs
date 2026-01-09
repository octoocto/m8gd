use super::Color;
use crate::display;
use godot::classes::BitMap;
use godot::classes::Image;
use godot::classes::ImageTexture;
use godot::prelude::Color as GodotColor;
use godot::prelude::*;
use libm8::Client;
use libm8::audio::AudioBackend;
use libm8::*;

fn bytes_to_bitmap(bytes: &[u8]) -> Option<Gd<BitMap>> {
    let mut font_image = Image::new_gd();
    if font_image.load_bmp_from_buffer(&PackedArray::<u8>::from(bytes)) == godot::global::Error::OK
    {
        for i in 0..font_image.get_width() {
            for j in 0..font_image.get_height() {
                if font_image.get_pixel(i as i32, j as i32) == godot::builtin::Color::BLACK {
                    font_image.set_pixel(
                        i as i32,
                        j as i32,
                        godot::builtin::Color::TRANSPARENT_BLACK,
                    );
                }
            }
        }

        let mut font_bitmap = BitMap::new_gd();
        font_bitmap.create_from_image_alpha(&font_image);

        godot_print!(
            "Loaded font bitmap size: {}x{}",
            font_bitmap.get_size().x,
            font_bitmap.get_size().y
        );

        Some(font_bitmap)
    } else {
        None
    }
}

#[derive(GodotClass)]
#[class(init, base=Node)]
pub struct GodotM8Client {
    base: Base<Node>,

    backend: Option<Box<dyn Backend>>,
    audio_backend: Option<audio::SdlAudioBackend>,

    hardware_type: Option<libm8::HardwareType>,
    firmware_version: String,

    keystate: libm8::KeyState,

    #[init(val = true)]
    display_enabled: bool,
    display_buffer: display::DisplayBuffer,
    display_texture: Gd<ImageTexture>,

    #[init(val = 255)]
    bg_alpha: u8,
    bg_color: libm8::Color,

    theme_colors: Vec<libm8::Color>,

    font: Option<libm8::FontType>,
    font_bitmap: Option<Gd<BitMap>>,
    font_bitmap_array: [Option<Gd<BitMap>>; 5],

    last_osc_size: usize,
    last_draw_color: libm8::Color,
}

#[godot_api]
impl INode for GodotM8Client {
    fn ready(&mut self) {
        let font_bitmap_array = &mut self.font_bitmap_array;
        font_bitmap_array[FontType::Model01Normal as usize] =
            bytes_to_bitmap(Font::FONT_01_SMALL.bytes);
        font_bitmap_array[FontType::Model01Big as usize] = bytes_to_bitmap(Font::FONT_01_BIG.bytes);
        font_bitmap_array[FontType::Model02Normal as usize] =
            bytes_to_bitmap(Font::FONT_02_SMALL.bytes);
        font_bitmap_array[FontType::Model02Bold as usize] =
            bytes_to_bitmap(Font::FONT_02_BOLD.bytes);
        font_bitmap_array[FontType::Model02Huge as usize] =
            bytes_to_bitmap(Font::FONT_02_HUGE.bytes);

        self.use_font(libm8::FontType::Model01Normal);
    }

    fn process(&mut self, _delta: f64) {
        if self.backend.is_none() || !self.is_connected() {
            return;
        }

        if self.display_enabled {
            match self.poll() {
                Ok(_) => self.display_update(),
                Err(e) => {
                    godot_error!("{:?}", e);
                }
            }
        }
    }
}

#[godot_api]
impl GodotM8Client {
    /// Emitted when a key is pressed or released on the connected M8 device.
    #[signal]
    fn key_pressed(key: u8, pressed: bool);

    #[signal]
    fn system_info_received(hardware_type: String, firmware_version: String);

    #[signal]
    fn theme_colors_updated(colors: PackedColorArray);

    #[signal]
    fn background_color_changed(color: GodotColor);

    #[signal]
    fn disconnected();

    #[func]
    fn set_display_enabled(&mut self, enabled: bool) {
        self.display_enabled = enabled;
    }

    #[func]
    fn is_display_enabled(&self) -> bool {
        self.display_enabled
    }

    fn set_display_size(&mut self, hardware_type: &HardwareType) {
        let (width, height) = hardware_type.screen_size();
        self.display_buffer
            .set_size(width as usize, height as usize);
        self.display_texture
            .set_image(&self.display_buffer.to_godot());
        godot_print!("Set display size to = {}x{}", width, height);
    }

    #[func]
    fn get_display_size(&self) -> Vector2i {
        let size = self.hardware_type.clone().unwrap_or_default().screen_size();
        Vector2i::new(size.0 as i32, size.1 as i32)
    }

    #[func]
    fn get_display_texture(&self) -> Gd<ImageTexture> {
        self.display_texture.clone()
    }

    #[func]
    fn set_display_bg_alpha(&mut self, alpha: f32) {
        let alpha = (alpha.clamp(0.0, 1.0) * 255.0) as u8;
        self.bg_alpha = alpha;
        godot_print!("Set display background alpha to {}", self.bg_alpha);
    }

    #[func]
    fn get_background_color(&self) -> GodotColor {
        Color(self.bg_color.clone()).to_godot()
    }

    #[func]
    fn get_hardware_name(&self) -> String {
        match &self.hardware_type {
            Some(hardware_type) => hardware_type.to_string(),
            None => String::from(""),
        }
    }

    #[func]
    fn get_firmware_version(&self) -> String {
        self.firmware_version.clone()
    }

    #[func]
    fn set_key_pressed(&mut self, key: u8, pressed: bool) {
        let mut keystate = self.keystate.clone();

        let Some(key) = libm8::Key::from_byte(key) else {
            godot_warn!("Invalid key value: {}", key);
            return;
        };

        if keystate.is_pressed(&key) != pressed {
            godot_print!("Setting key {:?} to pressed={}", key, pressed);
            keystate.set_pressed(&key, pressed);
            self.keystate = keystate.clone();

            if keystate.is_easter_egg() {
                let _ = self.reset_display();
            } else {
                let _ = self.set_keys(&keystate);
            }
        }
    }

    #[func]
    fn is_key_pressed(&self, key: u8) -> bool {
        let Some(key) = libm8::Key::from_byte(key) else {
            godot_warn!("Invalid key value: {}", key);
            return false;
        };
        self.keystate.is_pressed(&key)
    }

    /// Returns the current key state as a bitfield integer.
    #[func]
    fn get_key_state(&self) -> i32 {
        self.keystate.to_byte() as i32
    }

    #[func]
    fn get_theme_colors(&self) -> PackedArray<GodotColor> {
        if self.theme_colors.len() < libm8::NUM_THEME_COLORS {
            let mut array = PackedColorArray::new();
            array.resize(libm8::NUM_THEME_COLORS - 1);
            array.fill(GodotColor::WHITE);
            array.insert(0, Color(self.bg_color.clone()).to_godot());
            return array;
        }
        Self::color_vec_to_array(&self.theme_colors)
    }

    fn color_vec_to_array(colors: &Vec<libm8::Color>) -> PackedArray<GodotColor> {
        PackedArray::from_iter(colors.iter().cloned().map(|c| Color(c).to_godot()))
    }
}

// connection methods
#[godot_api(secondary)]
impl GodotM8Client {
    /// Creates a new GodotM8Client and connects to the M8 device via serial port.
    ///
    /// If [preferred_path] is an empty string, the first available M8 device will be used.
    /// If [check_if_valid] is true, the connection will only be made if the port is a valid M8 device.
    #[func]
    fn connect_with_serial(
        &mut self,
        #[opt(default = "")] preferred_path: GString,
        #[opt(default = true)] check_if_valid: bool,
    ) -> bool {
        let mut backend = libm8::SerialBackend::new();
        let preferred_path = if preferred_path.is_empty() {
            None
        } else {
            Some(preferred_path.to_string())
        };

        let result: Result<(), Error> = (|| {
            backend.set_preferred_path(preferred_path.as_deref(), check_if_valid)?;
            backend.connect()?;
            Ok(())
        })();

        match result {
            Ok(()) => {
                self.backend = Some(backend);
                true
            }
            Err(e) => {
                godot_error!("Error connecting to M8 device: {}", e);
                false
            }
        }
    }

    #[func]
    fn is_connected(&mut self) -> bool {
        match self.backend() {
            Some(backend) => backend.is_connected(),
            None => false,
        }
    }

    #[func]
    fn disconnect(&mut self) -> bool {
        match self.backend.as_mut() {
            Some(backend) => match backend.disconnect() {
                Ok(_) => {
                    self.backend = None;
                    godot_print!("Sucessfully disconnected from M8 device.");
                    self.display_buffer.fill(&libm8::Color::new(0, 0, 0), 255);
                    self.display_update();
                    self.signals().disconnected().emit();
                    true
                }
                Err(e) => {
                    godot_error!("Error disconnecting from M8 device: {}", e);
                    false
                }
            },
            None => true,
        }
    }
}

// send command methods
#[godot_api(secondary)]
impl GodotM8Client {
    /// Set a theme color at index [index] with color [color]
    /// on the connected device.
    ///
    /// Returns true if the command was sent successfully.
    ///
    /// NOTE: A delay is needed if attempting to set multiple theme colors
    /// in succession with this method.
    #[func]
    fn set_theme_color(&mut self, index: u8, color: GodotColor) -> bool {
        let r = (color.r * 255.0) as u8;
        let g = (color.g * 255.0) as u8;
        let b = (color.b * 255.0) as u8;
        Client::set_theme_color(self, index, r, g, b).is_ok()
    }

    /// Directly send the EnableDisplay command to the M8.
    ///
    /// Returns true if the command was sent successfully.
    #[func]
    fn debug_enable_display(&mut self) -> bool {
        Client::enable_display(self).is_ok()
    }

    /// Directly send the ResetDisplay command to the M8.
    ///
    /// Returns true if the command was sent successfully.
    #[func]
    fn debug_reset_display(&mut self) -> bool {
        Client::reset_display(self).is_ok()
    }

    /// Directly send the DisableDisplay command to the M8.
    ///
    /// Returns true if the command was sent successfully.
    #[func]
    fn debug_disable_display(&mut self) -> bool {
        Client::send_command(self, CommandOut::DisableDisplay).is_ok()
    }

    /// Play a note on the M8 device.
    ///
    /// Returns true if the command was sent successfully.
    #[func]
    fn play_note(&mut self, note: i32, velocity: i32) -> bool {
        Client::play_note(self, note as u8, velocity as u8).is_ok()
    }

    /// Directly set the key state on the M8 device.
    ///
    /// Returns true if the command was sent successfully.
    #[func]
    fn debug_set_keys(&mut self, keybits: i32) -> bool {
        let keystate = libm8::KeyState::from(keybits as u8);
        Client::set_keys(self, &keystate).is_ok()
    }
}

fn gstring_to_option(s: GString) -> Option<String> {
    if s.is_empty() {
        None
    } else {
        Some(s.to_string())
    }
}

// audio methods
#[godot_api(secondary)]
impl GodotM8Client {
    /// Attempt to initialize the audio backend (without starting it) if
    /// it hasn't been initialized yet.
    ///
    /// If initialization fails, [self.audio_backend] will still be [None].
    fn audio_try_init(&mut self) {
        if self.audio_backend.is_none() {
            self.audio_backend = match audio::SdlAudioBackend::new() {
                Ok(audio_backend) => Some(audio_backend),
                Err(e) => {
                    godot_error!("Failed to initialize audio backend: {}", e);
                    None
                }
            };
        }
    }

    #[func]
    fn audio_start(&mut self, input_device: GString, output_device: GString) -> bool {
        if !self.is_audio_enabled() {
            self.audio_try_init();
            let Some(audio_backend) = self.audio_backend.as_mut() else {
                return false;
            };
            godot_print!("Starting audio...");
            let input_device = gstring_to_option(input_device);
            let output_device = gstring_to_option(output_device);
            match audio_backend.start(input_device, output_device) {
                Ok(_) => {
                    godot_print!("Audio backend started successfully.");
                    return true;
                }
                Err(e) => {
                    godot_error!("Failed to start audio backend: {}", e);
                }
            };
        }
        false
    }

    #[func]
    fn audio_stop(&mut self) {
        if self.is_audio_enabled() {
            godot_print!("Stopping audio...");
            self.audio_backend = None;
        }
    }

    #[func]
    fn audio_list_input_devices(&mut self) -> Vec<GString> {
        self.audio_try_init();
        let device_names = match &self.audio_backend {
            Some(audio_backend) => audio_backend.list_input_devices().unwrap_or_default(),
            None => vec![],
        };
        device_names.iter().map(|s| GString::from(s)).collect()
    }

    #[func]
    fn is_audio_enabled(&mut self) -> bool {
        self.audio_backend.is_some() && self.audio_backend.as_ref().unwrap().is_running()
    }

    #[func]
    fn set_volume(&mut self, volume: f32) {
        if let Some(audio_backend) = self.audio_backend.as_mut() {
            let _ = audio_backend.set_volume(volume);
        }
    }

    #[func]
    fn get_volume(&mut self) -> f32 {
        if let Some(audio_backend) = self.audio_backend.as_mut() {
            return audio_backend.volume().unwrap_or(0.0);
        }
        0.0
    }

    /// Returns the peak volumes for the left and right audio channels,
    /// in linear scale.
    ///
    /// If the audio is disabled, returns `[0.0, 0.0]`.
    #[func]
    fn get_audio_peak_volume(&mut self) -> Vector2 {
        if let Some(audio_backend) = self.audio_backend.as_mut() {
            if let Ok(peaks) = audio_backend.volume_peaks() {
                return Vector2::new(peaks[0], peaks[1]);
            }
        }
        Vector2::ZERO
    }

    #[func]
    fn get_audio_spec(&mut self) -> VarDictionary {
        let mut dict = VarDictionary::new();
        dict.set("driver_name", "n/a");
        dict.set("format", "n/a");
        dict.set("sample_rate", "n/a");
        dict.set("buffer_size", "n/a");
        dict.set("latency_ms", "n/a");
        dict.set("num_channels", "n/a");

        let Some(audio_backend) = self.audio_backend.as_mut() else {
            return dict;
        };

        let Ok(spec) = audio_backend.input_spec() else {
            return dict;
        };

        dict.set("driver_name", spec.driver_name());
        dict.set("format", spec.format().to_string());
        dict.set("sample_rate", spec.sample_rate() as i32);
        dict.set("buffer_size", spec.buffer_size() as i32);
        dict.set("latency_ms", spec.latency_ms());
        dict.set("num_channels", spec.num_channels() as i32);

        dict
    }

    /// For the given frequency [freq] in Hz, returns the magnitude of the audio
    /// at that frequency, in linear scale.
    ///
    /// If the audio or spectrum analyzer is disabled, returns `0.0`.
    #[func]
    pub fn get_audio_magnitude_at_freq(&mut self, freq: f32) -> f32 {
        if let Some(audio_backend) = self.audio_backend.as_mut() {
            if let Ok(magnitude) = audio_backend.volume_at_frequency(freq) {
                return magnitude;
            }
        }
        0.0
    }

    #[func]
    pub fn is_spectrum_analyzer_enabled(&mut self) -> bool {
        if let Some(audio_backend) = self.audio_backend.as_mut() {
            return audio_backend
                .is_spectrum_analyzer_enabled()
                .unwrap_or(false);
        }
        false
    }

    #[func]
    pub fn set_spectrum_analyzer_enabled(&mut self, enabled: bool) {
        if let Some(audio_backend) = self.audio_backend.as_mut() {
            let _ = audio_backend.set_spectrum_analyzer_enabled(enabled);
        }
    }
}

impl Client for GodotM8Client {
    fn backend(&mut self) -> Option<&mut dyn Backend> {
        match &mut self.backend {
            Some(backend) => Some(backend.as_mut()),
            None => None,
        }
    }

    fn handle_command(&mut self, command: libm8::CommandIn) -> Result<(), libm8::Error> {
        match command {
            libm8::CommandIn::DrawRect { params } => self.on_draw_rect(params),
            libm8::CommandIn::DrawChar { params } => self.on_draw_char(params),
            libm8::CommandIn::DrawOsc { params } => self.on_draw_osc(params),
            libm8::CommandIn::GetKeyState { keystate } => self.on_key_pressed(keystate),
            libm8::CommandIn::GetSystemInfo { info } => self.on_get_system_info(info),
        }
        Ok(())
    }
}

impl GodotM8Client {
    fn display_ready(&self) -> bool {
        self.display_buffer.width() > 0 && self.display_buffer.height() > 0
    }

    fn display_update(&mut self) {
        if self.display_ready() {
            self.display_texture.update(&self.display_buffer.to_godot());
        }
    }

    fn use_font(&mut self, font_type: libm8::FontType) -> () {
        if self.font.as_ref().is_none_or(|ft| *ft != font_type) {
            let index = font_type.clone() as usize;
            let font_bitmap = &self.font_bitmap_array[index];
            self.font = Some(font_type);
            self.font_bitmap = font_bitmap.clone();
            godot_print!("Using font: {:?}", self.font);
        }
    }

    fn draw_rect(
        buffer: &mut display::DisplayBuffer,
        x: i32,
        y: i32,
        width: i32,
        height: i32,
        color: &libm8::Color,
        alpha: u8,
    ) -> () {
        // let rect = Rect2i::from_components(x, y, width, height);
        // image.fill_rect(rect, color.to_godot_color_with_alpha(alpha));
        // godot_print!("Drawing rect at ({}, {}) size {}x{}", x, y, width, height);
        // println!("Drawing rect at ({}, {}) size {}x{}", x, y, width, height);
        assert!(x >= 0 && y >= 0);
        assert!(width >= 0 && height >= 0);
        buffer.set_rect(
            x as usize,
            y as usize,
            width as usize,
            height as usize,
            color,
            alpha,
        );
    }
    fn draw_pixel(buffer: &mut display::DisplayBuffer, x: i32, y: i32, color: &libm8::Color) -> () {
        // if x < 0 || y < 0 || x >= image.get_width() || y >= image.get_height() {
        // godot_error!("Attempted to set pixel out of bounds: ({}, {})", x, y);
        // return;
        // }
        // image.set_pixel(x, y, color.to_godot_color());
        // godot_print!("Drawing pixel at ({}, {})", x, y);
        buffer.set_pixel(x as usize, y as usize, color, u8::MAX);
    }

    fn on_draw_rect(&mut self, params: libm8::DrawRectParams) {
        let font_data = self.font.as_ref().unwrap().get_data();

        let disp_w = self.display_buffer.width() as i32;
        let disp_h = self.display_buffer.height() as i32;

        let x = params.x as i32;
        let y = (params.y as i32 + font_data.draw_y_offset as i32).max(0);
        let w = params.width as i32;
        let h = params.height as i32;

        let color = match params.color {
            Some(c) => {
                self.last_draw_color = c.clone();
                c
            }
            None => self.last_draw_color.clone(),
        };

        // use color as background color if rect covers entire display
        if x <= 0 && y <= 0 && w >= disp_w && h >= disp_h {
            self.bg_color = color.clone();
            godot_print!(
                "Set background color to rgb({}, {}, {})",
                self.bg_color.r,
                self.bg_color.g,
                self.bg_color.b
            );
            let bg_color = Color(self.bg_color.clone()).to_godot();
            self.signals().background_color_changed().emit(bg_color);
        }

        // sizes of rects used on the theme screen
        // when one of these conditions pass, the user is most likely on the theme screen
        if (w == 24 && h == 7)
            || (w == 30 && h == 9)
            || (w == 36 && h == 11)
            || (w == 45 && h == 13)
        {
            if self.theme_colors.len() == libm8::NUM_THEME_COLORS {
                self.theme_colors.clear();
            }
            self.theme_colors.push(color.clone());
            if self.theme_colors.len() == libm8::NUM_THEME_COLORS {
                let colors = Self::color_vec_to_array(&self.theme_colors);
                self.signals()
                    .theme_colors_updated()
                    .emit(colors.to_godot());
            }
        }

        let alpha = if color == self.bg_color {
            self.bg_alpha
        } else {
            u8::MAX
        };

        Self::draw_rect(&mut self.display_buffer, x, y, w, h, &color, alpha);
    }

    fn on_draw_char(&mut self, params: libm8::DrawCharParams) {
        // bitmap only covers ASCII characters
        if self.font_bitmap.is_none() || params.c as u8 > 127 {
            return;
        }

        let c = params.c;
        let x = params.x as u32;
        let y = params.y as u32;
        let color_fg = params.color_fg;
        let color_bg = params.color_bg;

        let font_data = self.font.as_ref().unwrap().get_data();
        let font_bitmap = self.font_bitmap.as_ref().unwrap();
        let display_image = &mut self.display_buffer;

        // starting position of glyph in font bitmap
        let x0 = (c as u8 % super::FONT_BITMAP_SIZE.0) * font_data.char_width;
        let y0 = (c as u8 / super::FONT_BITMAP_SIZE.0) * font_data.char_height;

        let rect_x = x as i32;
        let rect_y =
            (y as i32) + (font_data.draw_y_offset as i32) + (font_data.char_y_offset as i32);

        let draw_bg: bool = color_bg != color_fg;

        for i in 0..font_data.char_width {
            let i = i as i32;
            for j in 0..font_data.char_height {
                let j = j as i32;
                if font_bitmap.get_bit(x0 as i32 + i, y0 as i32 + j) {
                    // foreground pixel
                    Self::draw_pixel(display_image, rect_x + i, rect_y + j, &color_fg);
                } else if draw_bg {
                    // background pixel
                    Self::draw_pixel(display_image, rect_x + i, rect_y + j, &color_bg);
                }
            }
        }
    }

    fn on_draw_osc(&mut self, params: libm8::DrawOscParams) {
        let color = params.color;
        let points = params.waveform;
        let size = points.len();

        let display_image = &mut self.display_buffer;
        let font_data = self.font.as_ref().unwrap().get_data();

        let osc_size = if size == 0 {
            self.last_osc_size
        } else {
            self.last_osc_size = size;
            size
        };

        let x = display_image.width() as i32 - osc_size as i32;

        // clear previous osc waveform area
        Self::draw_rect(
            display_image,
            x,
            0,
            osc_size as i32,
            font_data.waveform_max as i32 + 1,
            &self.bg_color,
            u8::MAX,
        );

        // draw points
        for i in 0..size as i32 {
            let mut ampl = points[i as usize] as i32;
            if ampl > font_data.waveform_max as i32 {
                ampl = font_data.waveform_max as i32;
            }
            Self::draw_pixel(display_image, x + i, ampl, &color);
        }
    }

    fn on_key_pressed(&mut self, keystate: libm8::KeyState) {
        if keystate != self.keystate {
            for key in libm8::Key::ALL_KEYS {
                let pressed = keystate.is_pressed(key);
                if pressed != self.keystate.is_pressed(key) {
                    self.signals().key_pressed().emit(key.to_byte(), pressed);
                }
            }
            self.keystate = keystate;
        }
    }

    fn on_get_system_info(&mut self, params: libm8::SystemInfo) {
        let hardware_type = params.model;
        let firmware = params.firmware;
        let font_type = params.font;

        self.use_font(font_type.clone());

        self.signals()
            .system_info_received()
            .emit(hardware_type.name(), firmware.clone());
        self.set_display_size(&hardware_type);

        self.hardware_type = Some(hardware_type);
        self.firmware_version = firmware;
    }
}
