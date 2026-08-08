use crate::Color;
use crate::HardwareType;
use godot::{
    classes::{
        Image, ImageTexture, class_macros::private::virtuals::Os::PackedByteArray, image::Format,
    },
    global::godot_warn,
    meta::GodotConvert,
    obj::Gd,
};

const IMAGE_FORMAT: Format = godot::classes::image::Format::RGBA8;

const BUFFER_SIZE_MAX: usize =
    HardwareType::SCREEN_SIZE_MAX.0 as usize * HardwareType::SCREEN_SIZE_MAX.1 as usize * 4;

/// A display buffer in RGBA8 format.
// #[derive(Default)]
pub struct BufferedTexture {
    width: usize,
    height: usize,
    image: Gd<Image>,
    texture: Gd<ImageTexture>,
    data: Box<[u8; BUFFER_SIZE_MAX]>,
    // data: [u8; BUFFER_SIZE_MAX],
    data_len: usize,
}

impl Default for BufferedTexture {
    fn default() -> Self {
        BufferedTexture {
            width: usize::default(),
            height: usize::default(),
            image: Gd::<Image>::default(),
            texture: Gd::<ImageTexture>::default(),
            // data: vec![0; width * height * 4],
            data: Box::new([0; BUFFER_SIZE_MAX]),
            data_len: usize::default(),
        }
    }
}

impl BufferedTexture {
    pub fn new(width: usize, height: usize) -> Self {
        let mut s = Self::default();
        s.set_size(width, height);
        s
    }

    /// Returns true if the texture is currently being used by another node.
    pub fn is_referenced(&self) -> bool {
        self.texture.get_reference_count() > 1
    }
}

impl BufferedTexture {
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

    pub fn set_pixel(&mut self, x: usize, y: usize, color: &Color, a: &u8) {
        if x >= self.width || y >= self.height {
            return;
        }

        let index = (x + y * self.width) * 4;
        self.data[index] = color.r;
        self.data[index + 1] = color.g;
        self.data[index + 2] = color.b;
        self.data[index + 3] = *a;
    }

    pub fn set_rect(&mut self, x: usize, y: usize, w: usize, h: usize, color: &Color, a: &u8) {
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

    pub fn fill(&mut self, color: &Color, a: &u8) {
        for y in 0..self.height {
            for x in 0..self.width {
                self.set_pixel(x, y, color, a);
            }
        }
    }

    pub fn set_size(&mut self, width: usize, height: usize) {
        if self.width == width && self.height == height {
            return;
        }
        self.width = width;
        self.height = height;
        self.image =
            Image::create_empty(width as i32, height as i32, false, Format::RGBA8).unwrap();
        // self.data = vec![0; width * height * 4];
        self.data_len = width * height * 4;
        self.data[..self.data_len].fill(0);
        self.texture.set_image(&self.image);
    }

    /// Updates the texture with the current image data. Call this after modifying the pixel data.
    pub fn update_texture(&mut self) {
        self.image.set_data(
            self.width as i32,
            self.height as i32,
            false,
            IMAGE_FORMAT,
            &PackedByteArray::from(&self.data[..self.data_len]),
        );
        // if self.texture.get_size().cast_int().to_tuple() != (self.width as i32, self.height as i32)
        // {
        //     self.texture.set_image(&self.image);
        // } else {
        self.texture.update(&self.image);
        // }
    }

    pub fn texture(&self) -> Gd<ImageTexture> {
        // self.texture.set_image(&self.image());
        self.texture.clone()
    }
}

impl GodotConvert for BufferedTexture {
    type Via = Gd<Image>;

    fn godot_shape() -> godot::meta::shape::GodotShape {
        Gd::<Image>::godot_shape()
    }
}
