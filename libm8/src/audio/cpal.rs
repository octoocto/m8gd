use std::sync::{Arc, Mutex};

use crate::audio::AudioTrack;
use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
use cpal::{Device, DeviceDescription, Host, StreamConfig};
use enum_map::EnumMap;
use ringbuf::HeapRb;
use ringbuf::traits::{Consumer, Producer, Split};
use spectrum_analyzer::scaling::scale_to_zero_to_one;
use spectrum_analyzer::windows::hann_window;
use spectrum_analyzer::{FrequencyLimit, FrequencySpectrum, samples_fft_to_spectrum};

use super::AudioSpec;
use crate::Error;

use super::BUFFER_SIZE;
use super::LATENCY_BUFFER_SIZE;
use super::NUM_CHANNELS_MULTICHANNEL;
use super::NUM_CHANNELS_STEREO;
use super::SAMPLE_RATE;

pub struct CpalAudioBackend {
    host: Host,
    multichannel_enabled: bool,
    input_stream: Option<cpal::Stream>,
    output_stream: Option<cpal::Stream>,
    buffers: Arc<Mutex<EnumMap<AudioTrack, Vec<f32>>>>,

    volume: Arc<Mutex<f32>>,
    volume_peaks: Arc<Mutex<[f32; 2]>>,

    spectrum_analyzer_enabled: bool,
    frequency_spectrum: Arc<Mutex<FrequencySpectrum>>,
}

impl CpalAudioBackend {
    pub fn new(volume: f32) -> Result<Self, Error> {
        Ok(Self {
            host: cpal::default_host(),
            multichannel_enabled: false,
            input_stream: None,
            output_stream: None,
            buffers: Arc::new(Mutex::new(EnumMap::from_fn(|_| vec![0.0; BUFFER_SIZE * 4]))),

            volume: Arc::new(Mutex::new(volume)),
            volume_peaks: Arc::new(Mutex::new([0.0; 2])),

            spectrum_analyzer_enabled: true,
            frequency_spectrum: Arc::new(Mutex::new(FrequencySpectrum::default())),
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

        let channels_in = if self.multichannel_enabled {
            NUM_CHANNELS_MULTICHANNEL
        } else {
            NUM_CHANNELS_STEREO
        };

        let config_in = StreamConfig {
            channels: channels_in as u16,
            sample_rate: SAMPLE_RATE as u32,
            buffer_size: cpal::BufferSize::Fixed(BUFFER_SIZE as u32),
        };

        let config_out = StreamConfig {
            channels: 2,
            sample_rate: SAMPLE_RATE as u32,
            buffer_size: cpal::BufferSize::Fixed(BUFFER_SIZE as u32),
        };

        println!("Requested spec:");
        println!("  Channels: {}", config_in.channels);
        println!("  Sample rate: {}", config_in.sample_rate);
        println!("  Buffer size: {:?}", config_in.buffer_size);

        // let latency_ms = 20.0;
        // let latency_frames = (latency_ms / 1000.0) * config_in.sample_rate as f32;
        // let latency_samples = latency_frames as usize * 2 as usize;
        // let ring = HeapRb::<f32>::new(latency_samples * 2);

        let buffer_size = (BUFFER_SIZE + LATENCY_BUFFER_SIZE) * 2;
        let ring = HeapRb::<f32>::new(buffer_size * 2);
        let (mut producer, mut consumer) = ring.split();

        // println!("Using latency buffer of {} samples", latency_samples);
        println!("Using buffer size: {}", buffer_size);
        println!("Using multichannel mode: {}", self.multichannel_enabled);

        for _ in 0..buffer_size {
            producer.try_push(0.0).unwrap();
        }

        let buffers_clone = self.buffers.clone();
        let multichannel_enabled = self.multichannel_enabled;

        let input_data_fn = {
            move |data: &[f32], _: &cpal::InputCallbackInfo| {
                // println!("Input callback with {} samples", data.len());
                let expected = BUFFER_SIZE * channels_in as usize;
                if data.len() < expected {
                    eprintln!(
                        "Input buffer overflow: expected {}, received {}",
                        expected,
                        data.len()
                    );
                    return;
                }

                let chunks = data.chunks_exact(channels_in as usize);
                if multichannel_enabled {
                    // println!("Processing {} chunks", chunks.len());
                    for (i, chunk) in chunks.enumerate() {
                        // println!("Processing chunk {}", i);
                        for (key, value) in buffers_clone.lock().unwrap().iter_mut() {
                            let channels = key.channels();
                            let (left, right) = (chunk[channels.0], chunk[channels.1]);
                            value[i] = (left + right) / 2.0;
                            if key == AudioTrack::Mix {
                                let _ = producer.try_push(left).and(producer.try_push(right));
                            }
                        }
                    }
                } else {
                    let value = &mut buffers_clone.lock().unwrap()[AudioTrack::Mix];
                    for (i, chunk) in chunks.enumerate() {
                        let channels = (0, 1);
                        let (left, right) = (chunk[channels.0], chunk[channels.1]);
                        value[i] = (left + right) / 2.0;
                        let _ = producer.try_push(left).and(producer.try_push(right));
                    }
                }
            }
        };

        let output_data_fn = {
            let volume = self.volume.clone();
            let volume_peaks = self.volume_peaks.clone();
            let frequency_spectrum = self.frequency_spectrum.clone();

            move |data: &mut [f32], _: &cpal::OutputCallbackInfo| {
                let mut dropped_samples = false;
                let volume = **volume.lock().as_ref().unwrap();
                let volume_peaks = &mut *volume_peaks.lock().unwrap();
                volume_peaks[0] = 0.0;
                volume_peaks[1] = 0.0;

                // println!("Output callback with {} samples", data.len());

                for (i, sample) in data.iter_mut().enumerate() {
                    *sample = match consumer.try_pop() {
                        Some(s) => {
                            if s.abs() > volume_peaks[i % 2] {
                                volume_peaks[i % 2] = s.abs();
                            }
                            s * volume
                        }
                        None => {
                            dropped_samples = true;
                            0.0
                        }
                    };
                }

                let mut fs = frequency_spectrum.lock().unwrap();
                match samples_fft_to_spectrum(
                    hann_window(data).as_slice(),
                    44100,
                    FrequencyLimit::All,
                    Some(&scale_to_zero_to_one),
                ) {
                    Ok(spectrum) => {
                        *fs = spectrum;
                    }
                    Err(e) => {
                        eprintln!("FFT error: {}", e);
                    }
                }

                if dropped_samples {
                    eprintln!("Output buffer overflow: dropped samples");
                }
            }
        };

        let input_stream = input_device.build_input_stream(
            &config_in,
            input_data_fn,
            |err| eprintln!("Input audio stream error: {}", err),
            None,
        )?;
        let output_stream = output_device.build_output_stream(
            &config_out,
            output_data_fn,
            |err| eprintln!("Output audio stream error: {}", err),
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
        Ok(*self.volume.lock().as_deref().unwrap())
    }

    fn set_volume(&mut self, new_volume: f32) -> Result<(), Error> {
        *self.volume.lock().as_deref_mut().unwrap() = new_volume;
        Ok(())
    }

    fn volume_peaks(&mut self) -> Result<[f32; 2], Error> {
        match self.volume_peaks.lock().as_deref() {
            Ok(peaks) => Ok(*peaks),
            Err(_) => Ok([0.0, 0.0]),
        }
    }

    fn volume_at_frequency(&mut self, frequency: f32) -> Result<f32, Error> {
        if self
            .is_spectrum_analyzer_enabled()
            .is_ok_and(|enabled| enabled)
        {
            match self.frequency_spectrum.lock() {
                Ok(fs) => {
                    if fs.samples_len() > 0 {
                        Ok(fs.freq_val_exact(frequency).val())
                    } else {
                        Ok(0.0)
                    }
                }
                Err(_) => Ok(0.0),
            }
        } else {
            Ok(0.0)
        }
    }

    fn set_spectrum_analyzer_enabled(&mut self, enabled: bool) -> Result<(), Error> {
        Ok(self.spectrum_analyzer_enabled = enabled)
    }

    fn is_spectrum_analyzer_enabled(&mut self) -> Result<bool, Error> {
        Ok(self.spectrum_analyzer_enabled)
    }

    fn input_spec(&self) -> Result<AudioSpec, Error> {
        Ok(AudioSpec {
            driver_name: "n/a".to_string(),
            format: "n/a".to_string(),
            num_channels: 2,
            sample_rate: 44100,
            buffer_size: BUFFER_SIZE,
        })
    }

    fn track_buffer(&mut self, track: AudioTrack) -> Result<Vec<f32>, Error> {
        let Ok(buffers) = self.buffers.lock() else {
            return Err(Error::AudioError(
                "Failed to retrieve track buffer lock".to_string(),
            ));
        };
        Ok(buffers[track].clone())
    }

    fn set_multichannel_mode(&mut self, enabled: bool) -> Result<(), Error> {
        self.multichannel_enabled = enabled;
        Ok(())
    }
}

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
