use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
use cpal::{Device, DeviceDescription, Host, StreamConfig};
use ringbuf::HeapRb;
use ringbuf::traits::{Consumer, Producer, Split};

use crate::Error;

impl From<cpal::DeviceIdError> for Error {
    fn from(e: cpal::DeviceIdError) -> Error {
        Error::AudioError(e.to_string())
    }
}

impl From<cpal::DefaultStreamConfigError> for Error {
    fn from(e: cpal::DefaultStreamConfigError) -> Error {
        Error::AudioError(e.to_string())
    }
}

impl From<cpal::DevicesError> for Error {
    fn from(e: cpal::DevicesError) -> Error {
        Error::AudioError(e.to_string())
    }
}

impl From<cpal::DeviceNameError> for Error {
    fn from(e: cpal::DeviceNameError) -> Error {
        Error::AudioError(e.to_string())
    }
}

impl From<cpal::SupportedStreamConfigsError> for Error {
    fn from(e: cpal::SupportedStreamConfigsError) -> Error {
        Error::AudioError(e.to_string())
    }
}

impl From<cpal::BuildStreamError> for Error {
    fn from(e: cpal::BuildStreamError) -> Error {
        Error::AudioError(e.to_string())
    }
}

impl From<cpal::PlayStreamError> for Error {
    fn from(e: cpal::PlayStreamError) -> Error {
        Error::AudioError(e.to_string())
    }
}

pub struct CpalAudioBackend {
    host: Host,
    input_stream: Option<cpal::Stream>,
    output_stream: Option<cpal::Stream>,
}

impl CpalAudioBackend {
    pub fn new() -> Result<Self, Error> {
        Ok(Self {
            host: cpal::default_host(),
            input_stream: None,
            output_stream: None,
        })
    }

    fn input_device_by_name(host: &Host, name: Option<String>) -> Option<Device> {
        let is_desc_valid = |desc: DeviceDescription| -> bool {
            match &name {
                Some(n) => desc.name().contains("M8") && desc.name() == n,
                None => desc.name().contains("M8"),
            }
        };
        host.input_devices()
            .ok()?
            .find(|device| device.description().is_ok_and(is_desc_valid))
    }
    fn output_device_by_name(host: &Host, name: Option<String>) -> Option<Device> {
        match name {
            None => host.default_output_device(),
            Some(name) => host
                .output_devices()
                .ok()?
                .find(|device| device.description().is_ok_and(|desc| name == desc.name())),
        }
    }
}

impl super::AudioBackend for CpalAudioBackend {
    fn start(
        &mut self,
        input_device: Option<String>,
        output_device: Option<String>,
    ) -> Result<(), Error> {
        let input_device = Self::input_device_by_name(&self.host, input_device).ok_or(
            Error::AudioError("Could not find valid input device".to_string()),
        )?;
        let output_device = Self::output_device_by_name(&self.host, output_device).ok_or(
            Error::AudioError("Could not find valid output device".to_string()),
        )?;

        println!("Using input device: {}", input_device.id()?);
        println!("Using output device: {}", output_device.id()?);

        println!("Input devices: {:?}", self.list_input_devices()?);
        println!("Output devices: {:?}", self.list_output_devices()?);

        // let config = idev.default_input_config()?;
        println!("Input device spec: {}", input_device.id()?);
        println!("  Name: {}", input_device.description()?.name());
        // println!("----------------------------------");
        // for config in input_device.supported_input_configs()? {
        //     println!("  Channels: {}", config.channels());
        //     println!(
        //         "  Sample rate: {} - {}",
        //         config.min_sample_rate(),
        //         config.max_sample_rate()
        //     );
        //     println!("  Buffer size: {:?}", config.buffer_size());
        //     println!("  Format: {}", config.sample_format());
        //     println!("----------------------------------");
        // }

        let config = StreamConfig {
            channels: 24,
            sample_rate: 44100,
            buffer_size: cpal::BufferSize::Fixed(512),
        };

        let config_out = StreamConfig {
            channels: 2,
            sample_rate: 44100,
            buffer_size: cpal::BufferSize::Fixed(512),
        };

        println!("Requested spec:");
        println!("  Channels: {}", config.channels);
        println!("  Sample rate: {}", config.sample_rate);
        println!("  Buffer size: {:?}", config.buffer_size);

        let latency_ms = 20.0;
        let latency_frames = (latency_ms / 1000.0) * config.sample_rate as f32;
        let latency_samples = latency_frames as usize * config.channels as usize;

        let ring = HeapRb::<f32>::new(latency_samples * 2);
        let (mut producer, mut consumer) = ring.split();

        for _ in 0..latency_samples {
            producer.try_push(0.0).unwrap();
        }

        let input_data_fn = move |data: &[f32], _: &cpal::InputCallbackInfo| {
            let mut dropped_samples = false;
            for &sample in data {
                if producer.try_push(sample).is_err() {
                    dropped_samples = true;
                }
            }
            if dropped_samples {
                eprintln!("Input buffer overflow: dropped samples");
            }
        };

        let output_data_fn = move |data: &mut [f32], _: &cpal::OutputCallbackInfo| {
            let mut dropped_samples = false;
            let mut buf_chunk: [f32; 24] = [0.0; 24];
            for chunk in data.chunks_mut(2) {
                let removed = consumer.pop_slice(&mut buf_chunk);
                if removed < 24 {
                    dropped_samples = true;
                    chunk[0] = 0.0;
                    chunk[1] = 0.0;
                } else {
                    chunk[0] = buf_chunk[0];
                    chunk[1] = buf_chunk[1];
                };
            }
            if dropped_samples {
                eprintln!("Output buffer overflow: dropped samples");
            }
        };

        let input_stream = input_device.build_input_stream(
            &config,
            input_data_fn,
            |err| eprintln!("Input stream error: {}", err),
            None,
        )?;
        let output_stream = output_device.build_output_stream(
            &config_out,
            output_data_fn,
            |err| eprintln!("Output stream error: {}", err),
            None,
        )?;

        input_stream.play()?;
        output_stream.play()?;

        self.input_stream = Some(input_stream);
        self.output_stream = Some(output_stream);

        Ok(())
    }

    fn stop(&mut self) -> Result<(), Error> {
        self.input_stream = None;
        self.output_stream = None;
        Ok(())
    }

    fn is_running(&self) -> bool {
        self.input_stream.is_some() && self.output_stream.is_some()
    }

    fn list_input_devices(&self) -> Result<Vec<String>, Error> {
        let names: Vec<String> = self
            .host
            .input_devices()
            .map_err(|e| Error::AudioError(e.to_string()))?
            .filter_map(|dev| dev.description().ok())
            .filter_map(|desc| {
                if desc.name().contains("M8") {
                    Some(desc.name().to_string())
                } else {
                    None
                }
            })
            .collect();
        Ok(names)
    }

    fn list_output_devices(&self) -> Result<Vec<String>, Error> {
        let names: Vec<String> = self
            .host
            .output_devices()
            .map_err(|e| Error::AudioError(e.to_string()))?
            .filter_map(|dev| dev.description().ok())
            .filter_map(|desc| Some(desc.name().to_string()))
            .collect();
        Ok(names)
    }

    fn volume(&mut self) -> Result<f32, Error> {
        Ok(1.0)
    }

    fn set_volume(&mut self, volume: f32) -> Result<(), Error> {
        Ok(())
    }

    fn volume_peaks(&mut self) -> Result<[f32; 2], Error> {
        Ok([0.0, 0.0])
    }

    fn volume_at_frequency(&mut self, frequency: f32) -> Result<f32, Error> {
        Ok(0.0)
    }

    fn set_spectrum_analyzer_enabled(&mut self, enabled: bool) -> Result<(), Error> {
        Ok(())
    }

    fn is_spectrum_analyzer_enabled(&mut self) -> Result<bool, Error> {
        Ok(false)
    }

    fn input_spec(&self) -> Result<super::AudioSpec, Error> {
        todo!()
    }
}
