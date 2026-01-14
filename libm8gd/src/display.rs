use godot::{
    classes::{
        Image,
        class_macros::private::virtuals::Os::{PackedArray, PackedByteArray},
        image::Format,
    },
    global::godot_warn,
    meta::{ByValue, GodotConvert, ToGodot},
    obj::Gd,
};

use libm8::Color;

const IMAGE_FORMAT: Format = godot::classes::image::Format::RGBA8;

/// A display buffer in RGBA8 format.
#[derive(Default)]
pub struct ImageBuffer {
    width: usize,
    height: usize,
    image: Gd<Image>,
    data: Vec<u8>,
}

impl ImageBuffer {
    pub fn create_image(width: usize, height: usize) -> Gd<Image> {
        let image = Image::create_empty(width as i32, height as i32, false, Format::RGBA8).unwrap();
        image
    }

    pub fn width(&self) -> usize {
        self.width
    }

    pub fn height(&self) -> usize {
        self.height
    }

    pub fn size(&self) -> (usize, usize) {
        (self.width, self.height)
    }

    // pub fn clear(&mut self, color: &Color, a: u8) {
    //     self.set_rect(0, 0, self.width, self.height, color, a);
    // }

    pub fn set_pixel(&mut self, x: usize, y: usize, color: &Color, a: u8) {
        if x >= self.width || y >= self.height {
            return;
        }

        let index = (x + y * self.width) * 4;
        self.data[index] = color.r;
        self.data[index + 1] = color.g;
        self.data[index + 2] = color.b;
        self.data[index + 3] = a;
    }

    pub fn set_rect(&mut self, x: usize, y: usize, w: usize, h: usize, color: &Color, a: u8) {
        for dy in 0..h {
            for dx in 0..w {
                let x = match x.checked_add(dx) {
                    Some(v) => v,
                    None => {
                        godot_warn!("set_pixel: x overflowed (x={}, dx={})", x, dx);
                        self.width
                    }
                };
                let y = match y.checked_add(dy) {
                    Some(v) => v,
                    None => {
                        godot_warn!("set_pixel: y overflowed (y={}, dy={})", y, dy);
                        self.height
                    }
                };
                self.set_pixel(x, y, color, a);
            }
        }
    }

    pub fn fill(&mut self, color: &Color, a: u8) {
        for y in 0..self.height {
            for x in 0..self.width {
                self.set_pixel(x, y, color, a);
            }
        }
    }

    pub fn set_size(&mut self, width: usize, height: usize) {
        self.width = width;
        self.height = height;
        self.image = Self::create_image(width, height);
        self.data = vec![0; width * height * 4];
    }

    pub fn to_image(&mut self) -> Gd<Image> {
        self.image.set_data(
            self.width as i32,
            self.height as i32,
            false,
            IMAGE_FORMAT,
            &PackedByteArray::from(self.data.clone()),
        );
        self.image.clone()
    }
}

impl GodotConvert for ImageBuffer {
    type Via = Gd<Image>;
}
