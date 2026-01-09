mod client;
mod display;

use godot::meta::ByValue;
use godot::prelude::Color as GodotColor;
use godot::prelude::*;

const FONT_BITMAP_SIZE: (u8, u8) = (16, 8);

struct LibM8Godot;

#[gdextension]
unsafe impl ExtensionLibrary for LibM8Godot {}

struct Color(libm8::Color);

impl GodotConvert for Color {
    type Via = GodotColor;
}

impl ToGodot for Color {
    type Pass = ByValue;

    fn to_godot(&self) -> Self::Via {
        GodotColor::from_rgba8(self.0.r, self.0.g, self.0.b, 255)
    }
}

#[derive(GodotClass)]
#[class(no_init)]
struct LibM8;

#[godot_api]
impl LibM8 {
    #[constant]
    const KEY_UP: u8 = libm8::Key::UP;
    #[constant]
    const KEY_DOWN: u8 = libm8::Key::DOWN;
    #[constant]
    const KEY_LEFT: u8 = libm8::Key::LEFT;
    #[constant]
    const KEY_RIGHT: u8 = libm8::Key::RIGHT;
    #[constant]
    const KEY_OPTION: u8 = libm8::Key::OPTION;
    #[constant]
    const KEY_SHIFT: u8 = libm8::Key::SHIFT;
    #[constant]
    const KEY_EDIT: u8 = libm8::Key::EDIT;
    #[constant]
    const KEY_PLAY: u8 = libm8::Key::PLAY;
}

#[godot_api(secondary)]
impl LibM8 {
    /// Returns a list of available serial ports.
    #[func]
    fn list_serial_ports(#[opt(default = true)] show_valid_only: bool) -> Array<GString> {
        let vec = libm8::get_serial_ports(show_valid_only);
        vec.into_iter()
            .map(|s| GString::from(&s))
            .collect::<Array<GString>>()
    }

    #[func]
    fn is_valid_serial_port(path: GString) -> bool {
        libm8::serial::is_valid_serial_port_path(path.to_string().as_str())
    }

    #[func]
    fn list_audio_input_devices() -> Array<GString> {
        let vec = libm8::audio::input_device_names().unwrap_or_else(|e| {
            godot_error!("Failed to get audio input device names: {}", e.to_string());
            vec![]
        });
        vec.iter()
            .map(|s| GString::from(s))
            .collect::<Array<GString>>()
    }
}
