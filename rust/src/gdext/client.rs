pub mod osc;

use crate as m8;

use osc::OscBufferedTexture;
use osc::OscDisplay;

use godot::classes::BitMap;
use godot::classes::Image;
use godot::classes::ImageTexture;
use godot::prelude::Color as GodotColor;
use godot::prelude::*;

use m8::AudioHandler;
use m8::Client;
use m8::CommandIn;
use m8::DisplayHandler;
use m8::Error;
use m8::audio;
use m8::gdext::display::BufferedTexture;

/// Returns [None] if the GString is `""`, otherwise returns [Some].
fn gstring_to_option(s: GString) -> Option<String> {
    if s.is_empty() {
        None
    } else {
        Some(s.to_string())
    }
}

fn create_audio_handler(handler_name: &str) -> Result<Box<dyn AudioHandler>, Error> {
    match handler_name.to_lowercase().as_str() {
        "sdl" => {
            println!("initializing SDL3 audio backend");
            audio::SdlAudioHandler::new().and_then(|b| Ok(Box::new(b) as Box<dyn AudioHandler>))
        }
        "cpal" => {
            println!("initializing CPAL audio backend");
            audio::CpalAudioHandler::new().and_then(|b| Ok(Box::new(b) as Box<dyn AudioHandler>))
        }
        _ => Err(Error::NoBackend),
    }
}

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

    display_handler: Option<Box<dyn DisplayHandler>>,
    audio_handler: Option<Box<dyn AudioHandler>>,
    audio_handler_name: Option<String>,

    #[init(val = 1.0)]
    audio_volume: f32,

    hardware_type: Option<crate::HardwareType>,
    firmware_version: String,

    keystate: crate::KeyState,

    #[init(val = true)]
    display_enabled: bool,
    display_buffer: BufferedTexture,
    osc_buffer: OscBufferedTexture,
    #[init(val = 255)]
    bg_alpha: u8,
    bg_color: crate::Color,

    theme_colors: Vec<crate::Color>,

    font_type: crate::FontType,
    font_bitmap_array: [Option<Gd<BitMap>>; 5],
    // font_bitmap: Option<&Gd<BitMap>>,
    last_osc_size: usize,
    last_draw_color: crate::Color,
}

// display texture methods
impl GodotM8Client {
    fn display_ready(&self) -> bool {
        self.display_buffer.width() > 0 && self.display_buffer.height() > 0
        // self.display_image.get_size() != Vector2i::ZERO
    }

    fn update_display_texture(&mut self) {
        self.display_buffer.update_texture();
        // if self.display_ready() {
        //     self.display_texture.update(&self.display_buffer.image());
        //     // self.display_texture.update(&self.display_image);
        // }
    }

    fn draw_rect(
        // image: &mut Gd<Image>,
        buffer: &mut BufferedTexture,
        x: i32,
        y: i32,
        width: i32,
        height: i32,
        color: &crate::Color,
        alpha: &u8,
    ) -> () {
        if x < 0 || y < 0 || width <= 0 || height <= 0 {
            return;
        }
        buffer.set_rect(
            x as usize,
            y as usize,
            width as usize,
            height as usize,
            color,
            alpha,
        );
    }

    fn draw_pixel(
        buffer: &mut BufferedTexture,
        x: i32,
        y: i32,
        color: &crate::Color,
        alpha: &u8,
    ) -> () {
        if x < 0 || y < 0 || x >= buffer.width() as i32 || y >= buffer.height() as i32 {
            return;
        }
        buffer.set_pixel(x as usize, y as usize, color, alpha);
    }
}

// incoming command handlers
impl GodotM8Client {
    fn on_draw_rect(&mut self, params: &crate::DrawRectParams) {
        let font_data = self.font_type.get_data();

        let (disp_w, disp_h) = self.display_buffer.size();

        let x = params.x as i32;
        let y = (params.y as i32 + font_data.draw_y_offset as i32).max(0);
        let w = params.width as i32;
        let h = params.height as i32;

        if let Some(color) = &params.color {
            self.last_draw_color = color.clone();
        };

        let color = self.last_draw_color.clone();

        // use color as background color if rect covers entire display
        if x <= 0 && y <= 0 && w >= disp_w as i32 && h >= disp_h as i32 {
            if self.bg_color != color {
                self.bg_color = color.clone();
                self.theme_colors.clear();
                godot_print!(
                    "Got new background color = rgb({}, {}, {})",
                    self.bg_color.r,
                    self.bg_color.g,
                    self.bg_color.b
                );
                let bg_color = self.bg_color.to_godot();
                self.signals().background_color_changed().emit(bg_color);
            }
        }

        // sizes of rects used on the theme screen
        // when one of these conditions pass, the user is most likely on the theme screen
        if (w == 24 && h == 7)
            || (w == 30 && h == 9)
            || (w == 36 && h == 11)
            || (w == 45 && h == 13)
        {
            if self.theme_colors.len() < crate::NUM_THEME_COLORS {
                self.theme_colors.push(color.clone());
                if self.theme_colors.len() == crate::NUM_THEME_COLORS {
                    let colors = Self::color_vec_to_array(&self.theme_colors);
                    godot_print!("Got theme colors");
                    self.signals()
                        .background_color_changed()
                        .emit(colors[0].to_godot());
                    self.signals().theme_changed().emit(colors.to_godot());
                }
            }
        }

        let alpha = if color == self.bg_color {
            &self.bg_alpha
        } else {
            &u8::MAX
        };

        Self::draw_rect(&mut self.display_buffer, x, y, w, h, &color, alpha);
    }

    fn on_draw_char(&mut self, params: &crate::DrawCharParams) {
        // bitmap only covers ASCII characters
        if params.c as u8 > 127 {
            return;
        }

        let c = params.c;
        let x = params.x as u32;
        let y = params.y as u32;
        let color_fg = &params.color_fg;
        let color_bg = &params.color_bg;

        let font_data = self.font_type.get_data();
        let mut font_bitmap = self.font_bitmap();
        let (char_width, char_height) = font_bitmap.get_size().to_tuple();
        let char_width = char_width as u8 / super::FONT_BITMAP_SIZE.0;
        let char_height = char_height as u8 / super::FONT_BITMAP_SIZE.1;

        // starting position of glyph in font bitmap
        let x0 = (c as u8 % super::FONT_BITMAP_SIZE.0) * char_width;
        let y0 = (c as u8 / super::FONT_BITMAP_SIZE.0) * char_height;

        let rect_x = x as i32;
        let rect_y =
            (y as i32) + (font_data.draw_y_offset as i32) + (font_data.char_y_offset as i32);

        let draw_bg: bool = color_bg != color_fg;

        // godot_print!("Drawing char '{}' at ({}, {})", c, rect_x, rect_y,);

        // let font_bitmap = self.font_bitmap().clone();

        for i in 0..char_width {
            let i = i as i32;
            for j in 0..char_height {
                let j = j as i32;
                if font_bitmap.get_bit(x0 as i32 + i, y0 as i32 + j) {
                    Self::draw_pixel(
                        &mut self.display_buffer,
                        rect_x + i,
                        rect_y + j,
                        &color_fg,
                        &u8::MAX,
                    );
                } else {
                    if !draw_bg {
                        continue;
                    }
                    Self::draw_pixel(
                        &mut self.display_buffer,
                        rect_x + i,
                        rect_y + j,
                        &color_bg,
                        &self.bg_alpha,
                    );
                }
                font_bitmap = self.font_bitmap();
            }
        }
    }

    fn on_draw_osc(&mut self, params: &crate::DrawOscParams) {
        let color = &params.color;
        let points = &params.waveform;
        let size = points.len();

        let display_image = &mut self.display_buffer;
        // let display_image = &mut self.display_image;
        let font_data = self.font_type.get_data();

        let osc_size = if size == 0 {
            self.last_osc_size
        } else {
            self.last_osc_size = size;
            size
        };

        let x = display_image.width() as i32 - osc_size as i32;
        // let x = display_image.get_width() - osc_size as i32;

        // clear previous osc waveform area
        Self::draw_rect(
            display_image,
            x,
            0,
            osc_size as i32,
            font_data.waveform_max as i32 + 1,
            &self.bg_color,
            &self.bg_alpha,
        );

        // draw points
        for i in 0..size as i32 {
            let mut ampl = points[i as usize] as i32;
            if ampl > font_data.waveform_max as i32 {
                ampl = font_data.waveform_max as i32;
            }
            Self::draw_pixel(display_image, x + i, ampl, &color, &u8::MAX);
        }
    }

    fn on_key_pressed(&mut self, keystate: &crate::KeyState) {
        if keystate != &self.keystate {
            // println!("on_key_pressed: {keystate}");
            let old_keystate = self.keystate.clone();
            self.keystate = keystate.clone();
            for key in crate::Key::ALL_KEYS {
                let pressed = self.keystate.is_pressed(key);
                // println!("is_key_pressed({key:?}) = {pressed}");
                if pressed != old_keystate.is_pressed(key) {
                    // println!(
                    //     "on_key_pressed: emitting signal {{ key={key:?}, pressed={pressed} }}"
                    // );
                    self.signals().key_pressed().emit(key.to_byte(), pressed);
                }
            }
        }
    }

    fn on_get_system_info(&mut self, params: &crate::SystemInfo) {
        let hardware_type = &params.model;
        let firmware = &params.firmware;
        let font_type = &params.font;

        if self.hardware_type != Some(hardware_type.clone()) {
            self.set_display_size(&hardware_type);
            self.hardware_type = Some(hardware_type.clone());
            self.firmware_version = firmware.clone();

            let hardware_name = self.get_hardware_name();
            let firmware_version = self.get_firmware_version();

            self.signals()
                .system_info_received()
                .emit(hardware_name, firmware_version);
        }

        if &self.font_type != font_type {
            self.use_font(font_type);
        }
    }
}

#[godot_api]
impl INode for GodotM8Client {
    fn ready(&mut self) {
        self.reset_font_bitmap(crate::FontType::Model01Normal);
        self.reset_font_bitmap(crate::FontType::Model01Big);
        self.reset_font_bitmap(crate::FontType::Model02Normal);
        self.reset_font_bitmap(crate::FontType::Model02Bold);
        self.reset_font_bitmap(crate::FontType::Model02Huge);
    }

    fn process(&mut self, _delta: f64) {
        if self.display().is_none() {
            return;
        };

        if let Err(e) = self.poll() {
            godot_error!("{:?}", e);
            self.disconnect();
            return;
        }

        if !self.is_connected() || !self.is_display_enabled() {
            return;
        }

        self.update_display_texture();
        // OscDisplay::update_texture(self);
    }

    fn physics_process(&mut self, _delta: f64) {}
}

#[godot_api]
impl GodotM8Client {
    /// Emitted when a key is pressed or released on the connected M8 device.
    #[signal]
    fn key_pressed(key: u8, pressed: bool);

    #[signal]
    fn system_info_received(hardware_type: String, firmware_version: String);

    #[signal]
    fn theme_changed(colors: PackedColorArray);

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

    fn set_display_size(&mut self, hardware_type: &m8::HardwareType) {
        let (width, height) = hardware_type.screen_size();
        self.display_buffer
            .set_size(width as usize, height as usize);
        OscDisplay::update_size(self);
        // self.display_image = Image::create_empty(
        //     width as i32,
        //     height as i32,
        //     false,
        //     godot::classes::image::Format::RGBA8,
        // )
        // .unwrap();
        // self.display_texture.set_image(&self.display_image);
        godot_print!("Set display size to = {}x{}", width, height);
    }

    #[func]
    fn get_display_size(&self) -> Vector2i {
        let size = self.hardware_type.clone().unwrap_or_default().screen_size();
        Vector2i::new(size.0 as i32, size.1 as i32)
    }

    #[func]
    fn get_display_texture(&self) -> Gd<ImageTexture> {
        self.display_buffer.texture()
    }

    #[func]
    fn get_osc_texture(&mut self) -> Gd<ImageTexture> {
        OscDisplay::texture(self)
    }

    #[func]
    fn set_display_bg_alpha(&mut self, alpha: f32) {
        let alpha = (alpha.clamp(0.0, 1.0) * 255.0) as u8;
        self.bg_alpha = alpha;
        godot_print!("Set display background alpha to {}", self.bg_alpha);
    }

    #[func]
    fn get_background_color(&self) -> GodotColor {
        self.bg_color.to_godot()
    }

    #[func]
    fn get_hardware_name(&self) -> String {
        match &self.hardware_type {
            Some(hardware_type) => hardware_type.name(),
            None => String::from(""),
        }
    }

    #[func]
    fn get_firmware_version(&self) -> String {
        (&self.firmware_version).clone()
    }

    #[func]
    fn is_multichannel_audio(&mut self) -> bool {
        if let Some(backend) = self.display_handler.as_mut() {
            return backend.is_multichannel_audio().unwrap_or(false);
        }
        false
    }

    #[func]
    fn set_key_pressed(&mut self, key: u8, pressed: bool) {
        let mut keystate = self.keystate.clone();

        let Some(key) = crate::Key::from_byte(key) else {
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
        let Some(key) = crate::Key::from_byte(key) else {
            godot_warn!("Invalid key value: {}", key);
            return false;
        };
        let pressed = self.keystate.is_pressed(&key);
        pressed
    }

    /// Returns the current key state as a bitfield integer.
    #[func]
    fn get_key_state(&self) -> i32 {
        self.keystate.to_byte() as i32
    }

    #[func]
    fn get_theme_colors(&self) -> PackedArray<GodotColor> {
        if self.theme_colors.len() < crate::NUM_THEME_COLORS {
            let mut array = PackedColorArray::new();
            array.resize(crate::NUM_THEME_COLORS - 1);
            array.fill(GodotColor::WHITE);
            array.insert(0, self.bg_color.to_godot());
            return array;
        }
        Self::color_vec_to_array(&self.theme_colors)
    }

    fn color_vec_to_array(colors: &Vec<crate::Color>) -> PackedArray<GodotColor> {
        PackedArray::from_iter(colors.iter().cloned().map(|c| c.to_godot()))
    }
}

// connection methods
#[godot_api(secondary)]
impl GodotM8Client {
    /// Connects to an M8 device via the serial port at path `preferred_path`.
    ///
    /// If `preferred_path` is an empty string, the first available M8 device will be used.
    /// If `check_if_valid` is true, the connection will only be made if the port is a valid M8 device.
    #[func]
    fn connect_with_serial(
        &mut self,
        #[opt(default = "")] preferred_path: GString,
        #[opt(default = true)] check_if_valid: bool,
    ) -> bool {
        let mut client_backend = crate::SerialDisplayHandler::new();
        let preferred_path = gstring_to_option(preferred_path);

        let result: Result<(), Error> = (|| {
            client_backend.set_preferred_path(preferred_path.as_deref(), check_if_valid)?;
            client_backend.connect()?;
            Ok(())
        })();

        match result {
            Ok(()) => {
                self.display_handler = Some(client_backend);
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
        self.display().is_some_and(|backend| backend.is_connected())
    }

    #[func]
    fn disconnect(&mut self) -> bool {
        if !self.is_connected() {
            return false;
        }
        self.display_handler = None;
        self.audio_handler = None;
        self.display_buffer
            .fill(&crate::Color::new(0, 0, 0), &u8::MAX);
        // self.display_image.fill(GodotColor::BLACK);
        self.update_display_texture();
        self.signals().disconnected().emit();
        godot_print!("Sucessfully disconnected from M8 device.");
        true
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
        Client::send_command(self, m8::CommandOut::DisableDisplay).is_ok()
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
        let keystate = crate::KeyState::from(keybits as u8);
        Client::set_keys(self, &keystate).is_ok()
    }
}
// audio methods
#[godot_api(secondary)]
impl GodotM8Client {
    /// Attempt to initialize the audio backend (without starting it) if
    /// it hasn't been initialized yet.
    ///
    /// If initialization fails, [struct@audio_backend] will still be [None].
    fn audio_try_init(&mut self) {
        let Some(backend_name) = &self.audio_handler_name else {
            godot_warn!("libm8: failed to initialize audio - backend has not been set");
            return;
        };
        godot_print!("libm8: initializing audio with backend {backend_name}...");
        if self.audio_handler.is_none() {
            self.audio_handler = match create_audio_handler(backend_name) {
                Ok(audio_backend) => {
                    godot_print!("libm8: initialized");
                    Some(audio_backend)
                }
                Err(e) => {
                    godot_error!("libm8: failed to initialize: {}", e);
                    None
                }
            };
        }
    }

    #[func]
    fn audio_set_backend(&mut self, backend_name: GString) {
        if self
            .audio_handler_name
            .as_ref()
            .is_some_and(|name| name == &backend_name.to_string())
        {
            return;
        }
        self.audio_stop();
        self.audio_handler_name = if backend_name.is_empty() {
            godot_print!("libm8: backend set to none");
            None
        } else {
            godot_print!("libm8: backend set to '{}'", backend_name);
            Some(backend_name.to_string())
        };
    }

    #[func]
    fn audio_start(&mut self, input_device: GString, output_device: GString) -> bool {
        if !self.is_audio_enabled() {
            self.audio_try_init();
            let is_multichannel = self.is_multichannel_audio();
            let Some(audio_backend) = self.audio_handler.as_mut() else {
                return false;
            };
            godot_print!("Starting audio...");
            let _ = audio_backend.set_volume(self.audio_volume);
            let _ = audio_backend.set_multichannel_mode(is_multichannel);
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
            godot_print!("audio: stopping...");
        }
        self.audio_handler = None;
    }

    #[func]
    fn audio_list_input_devices(&mut self) -> Vec<GString> {
        self.audio_try_init();
        godot_print!(
            "audio: listing input devices for backend: {:?}",
            &self.audio_handler_name
        );
        let device_names = match &self.audio_handler {
            Some(audio_backend) => audio_backend.list_input_devices().unwrap_or_default(),
            None => {
                godot_print!("audio: backend not running, returning empty list");
                vec![]
            }
        };
        device_names.iter().map(|s| GString::from(s)).collect()
    }

    #[func]
    fn is_audio_enabled(&mut self) -> bool {
        match self.audio_handler.as_ref() {
            Some(backend) => backend.is_running(),
            None => false,
        }
    }

    #[func]
    fn set_volume(&mut self, volume: f32) {
        self.audio_volume = volume.clamp(0.0, 1.0);
        if let Some(audio_backend) = self.audio_handler.as_mut() {
            let _ = audio_backend.set_volume(self.audio_volume);
        }
    }

    #[func]
    fn get_volume(&mut self) -> f32 {
        if let Some(audio_backend) = self.audio_handler.as_mut() {
            return audio_backend.volume().unwrap_or(0.0);
        }
        0.0
    }

    /// Returns the peak volumes for the left and right audio channels,
    /// in linear scale.
    ///
    /// If the audio is disabled, returns `[0.0, 0.0]`.
    #[func]
    fn get_audio_peaks_linear(&mut self) -> PackedFloat32Array {
        if let Some(audio_backend) = self.audio_handler.as_mut() {
            if let Ok(peaks) = audio_backend.peaks_linear() {
                return PackedFloat32Array::from(&peaks);
            }
        }
        PackedFloat32Array::from(&[0.0, 0.0])
    }

    /// Returns the peak volumes for the left and right audio channels,
    /// in linear scale.
    ///
    /// If the audio is disabled, returns `[0.0, 0.0]`.
    #[func]
    fn get_audio_peaks_db(&mut self) -> PackedFloat32Array {
        if let Some(audio_backend) = self.audio_handler.as_mut() {
            if let Ok(peaks) = audio_backend.peaks_db() {
                return PackedFloat32Array::from(&peaks);
            }
        }
        PackedFloat32Array::from(&[f32::NEG_INFINITY, f32::NEG_INFINITY])
    }

    #[func]
    fn get_audio_spec(&mut self) -> VarDictionary {
        let mut dict = VarDictionary::new();
        dict.set("driver_name", "n/a");
        dict.set("format", "n/a");
        dict.set("sample_rate", 0_i32);
        dict.set("buffer_size", 0_i32);
        dict.set("latency_ms", 0.0_f32);
        dict.set("num_channels", 0_i32);

        let Some(audio_backend) = self.audio_handler.as_mut() else {
            return dict;
        };

        let Ok(spec) = audio_backend.input_spec() else {
            return dict;
        };

        dict.set("driver_name", spec.host());
        dict.set("format", spec.format().to_string());
        dict.set("sample_rate", spec.sample_rate() as i32);
        dict.set("buffer_size", spec.buffer_size() as i32);
        dict.set("latency_ms", spec.latency_ms());
        dict.set("num_channels", spec.num_channels() as i32);

        dict
    }

    /// For the given frequency `freq` in Hz, returns the magnitude of the audio
    /// at that frequency, in linear scale.
    ///
    /// If the audio or spectrum analyzer is disabled, returns `0.0`.
    #[func]
    pub fn get_audio_magnitude_at_freq(&mut self, freq: f32) -> f32 {
        if let Some(audio_backend) = self.audio_handler.as_mut() {
            if let Ok(magnitude) = audio_backend.value_at_frequency(freq) {
                return magnitude;
            }
        }
        0.0
    }

    #[func]
    pub fn is_spectrum_analyzer_enabled(&mut self) -> bool {
        if let Some(audio_backend) = self.audio_handler.as_mut() {
            return audio_backend
                .is_spectrum_analyzer_enabled()
                .unwrap_or(false);
        }
        false
    }

    #[func]
    pub fn set_spectrum_analyzer_enabled(&mut self, enabled: bool) {
        if let Some(audio_backend) = self.audio_handler.as_mut() {
            let _ = audio_backend.set_spectrum_analyzer_enabled(enabled);
        }
    }

    #[func]
    pub fn get_audio_track_buffer(&mut self, index: i32) -> Vec<f32> {
        let track = m8::Track::from_index(index as usize);
        if let Some(audio_backend) = self.audio_handler.as_mut() {
            if let Ok(buffer) = audio_backend.track_buffer(track) {
                return buffer;
            }
        }
        vec![]
    }
}

// font methods
#[godot_api(secondary)]
impl GodotM8Client {
    fn font_bitmap(&self) -> &Gd<BitMap> {
        let index = self.font_type.to_index();
        self.font_bitmap_array
            .get(index)
            .expect("Font bitmap should be set")
            .as_ref()
            .expect("Font bitmap should not be None")
    }

    fn use_font(&mut self, font_type: &crate::FontType) {
        if &self.font_type != font_type {
            self.font_type = font_type.clone();
            godot_print!("Using font: {:?}", self.font_type);
        }
    }

    /// Sets a custom font bitmap for the given font type index.
    ///
    /// Refer to the `FONT_` constants in [crate::crate] for valid values for `font`.
    #[func]
    fn set_font_bitmap(&mut self, font: u8, bitmap: Gd<BitMap>) -> bool {
        let Some(font) = crate::FontType::from_index(font as usize) else {
            godot_error!("Invalid font type index: {}", font);
            return false;
        };
        let (w, h) = bitmap.get_size().to_tuple();
        let (cols, rows) = super::FONT_BITMAP_SIZE;
        if w % cols as i32 != 0 || h % rows as i32 != 0 {
            godot_error!(
                "Invalid font bitmap size: {}x{}. Must be multiple of {}x{}.",
                w,
                h,
                cols,
                rows
            );
            return false;
        }
        self.font_bitmap_array[font.to_index()] = Some(bitmap);
        let _ = self.reset_display();
        godot_print!("Set custom font bitmap for font {:?}", font);
        true
    }

    fn reset_font_bitmap(&mut self, font: crate::FontType) {
        self.font_bitmap_array[font.to_index()] = bytes_to_bitmap(font.get_data().bytes);
    }

    /// Resets the font bitmap for the given font type index to the default.
    #[func(rename = reset_font_bitmap)]
    fn gd_reset_font_bitmap(&mut self, font: u8) -> bool {
        let Some(font) = crate::FontType::from_index(font as usize) else {
            godot_error!("Invalid font type index: {}", font);
            return false;
        };
        self.reset_font_bitmap(font);
        true
    }
}
impl Client for GodotM8Client {
    fn display(&mut self) -> Option<&mut dyn DisplayHandler> {
        match &mut self.display_handler {
            Some(client_backend) => Some(client_backend.as_mut()),
            None => None,
        }
    }

    fn handle_command(&mut self, command: &CommandIn) -> Result<(), crate::Error> {
        match command {
            CommandIn::DrawRect { params } => self.on_draw_rect(params),
            CommandIn::DrawChar { params } => self.on_draw_char(params),
            CommandIn::DrawOsc { params } => self.on_draw_osc(params),
            CommandIn::GetKeyState { keystate } => self.on_key_pressed(keystate),
            CommandIn::GetSystemInfo { info } => self.on_get_system_info(info),
        }
        Ok(())
    }
}
