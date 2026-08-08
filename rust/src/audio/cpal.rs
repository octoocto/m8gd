use std::collections::{HashSet, VecDeque};
use std::sync::{Arc, Mutex};

use crate::audio::AudioTrack;
use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
use cpal::{Device, Host, OutputCallbackInfo, StreamConfig};
use enum_map::EnumMap;
use ringbuf::traits::{Consumer, Producer, Split};
use spectrum_analyzer::scaling::scale_to_zero_to_one;
use spectrum_analyzer::windows::hann_window;
use spectrum_analyzer::{FrequencyLimit, FrequencySpectrum, samples_fft_to_spectrum};

use super::AudioSpec;
use crate::Error;

// use super::BUFFER_SIZE;
use super::LATENCY_BUFFER_SIZE;
use super::NUM_CHANNELS_MULTICHANNEL;
use super::NUM_CHANNELS_STEREO;
// use super::SAMPLE_RATE;

const BUFFER_SIZE: usize = 512;
const SAMPLE_RATE: usize = 48000;
// const SAMPLE_FORMAT: cpal::SampleFormat = cpal::SampleFormat::F32;

const OSC_BUFFER_SIZE: usize = 441;

pub struct CpalAudioBackend {
    host: Host,
    multichannel_enabled: bool,
    input_device: Option<AudioStream>,
    output_device: Option<AudioStream>,
    track_buffers: Arc<Mutex<EnumMap<AudioTrack, RingVec>>>,
    // track_buffers: Option<EnumMap<AudioTrack, ringbuf::HeapCons<f32>>>,
    volume: Arc<Mutex<f32>>,
    volume_peaks: Arc<Mutex<[f32; 2]>>,

    spectrum_analyzer_enabled: bool,
    frequency_spectrum: Arc<Mutex<FrequencySpectrum>>,
}

impl CpalAudioBackend {
    pub fn new() -> Result<Self, Error> {
        Ok(Self {
            host: cpal::default_host(),
            multichannel_enabled: false,
            input_device: None,
            output_device: None,
            track_buffers: Arc::new(Mutex::new(EnumMap::from_fn(|_| {
                RingVec::new(OSC_BUFFER_SIZE)
            }))),

            volume: Arc::new(Mutex::new(1.0)),
            volume_peaks: Arc::new(Mutex::new([0.0; 2])),

            spectrum_analyzer_enabled: true,
            frequency_spectrum: Arc::new(Mutex::new(FrequencySpectrum::default())),
        })
    }
}

impl super::AudioBackend for CpalAudioBackend {
    fn start(
        &mut self,
        input_device_name: Option<String>,
        output_device_name: Option<String>,
    ) -> Result<(), Error> {
        let num_channels = if self.multichannel_enabled {
            NUM_CHANNELS_MULTICHANNEL as u16
        } else {
            NUM_CHANNELS_STEREO as u16
        };

        let input_devices = find_input_devices(&self.host, &input_device_name, num_channels)?;
        let output_device = find_output_device(&self.host, &output_device_name)?;

        let config_out = find_output_stream_config(&output_device)?;

        // println!("  Buffer size: {:?}", config_in.buffer_size);
        // let latency_ms = 20.0;
        // let latency_frames = (latency_ms / 1000.0) * config_in.sample_rate as f32;
        // let latency_samples = latency_frames as usize * 2 as usize;
        // let ring = HeapRb::<f32>::new(latency_samples * 2);

        let buffer_size = (BUFFER_SIZE + LATENCY_BUFFER_SIZE) * 2;
        let ring = ringbuf::HeapRb::<f32>::new(buffer_size * 2);
        let (mut rb_sender, rb_receiver) = ring.split();
        for _ in 0..buffer_size {
            rb_sender.try_push(0.0).unwrap();
        }

        // println!("Using latency buffer of {} samples", latency_samples);
        println!("Using buffer size: {}", buffer_size);
        println!("Using multichannel mode: {}", self.multichannel_enabled);

        if input_devices.is_empty() {
            return Err(Error::AudioError(
                "CPAL: No valid input devices found".to_string(),
            ));
        }

        for (device, config) in input_devices {
            if AudioStream::can_open_input(&device, &config) {
                self.input_device = Some(AudioStream::open_input(
                    device,
                    config,
                    self.on_input_data_received(rb_sender, Arc::clone(&self.track_buffers)),
                )?);
                break;
            }
        }

        self.output_device = Some(AudioStream::open_output(
            output_device,
            config_out,
            self.on_output_data_requested(rb_receiver),
        )?);

        Ok(())
    }

    fn stop(&mut self) -> Result<(), Error> {
        self.input_device = None;
        self.output_device = None;
        Ok(())
    }

    fn is_running(&self) -> bool {
        self.input_device.is_some() && self.output_device.is_some()
    }

    fn set_multichannel_mode(&mut self, enabled: bool) -> Result<(), Error> {
        self.multichannel_enabled = enabled;
        Ok(())
    }

    fn list_input_devices(&self) -> Result<Vec<String>, Error> {
        let names: Vec<String> = self
            .host
            .input_devices()
            .map_err(|e| Error::AudioError(e.to_string()))?
            .filter_map(|device| {
                device.supports_input().then_some(())?;
                let desc = device.description().ok()?;
                let config_range = device.default_input_config().ok()?;
                Some((device, desc, config_range, config_range.config()))
            })
            .filter_map(|(device, desc, config_range, config)| {
                if desc.name().contains("M8") {
                    println!("found input device: {}", desc.name());
                    println!("- supports input: {:?}", desc.supports_input());
                    println!("- supports output: {:?}", desc.supports_output());
                    println!("- device type: {:?}", desc.device_type());
                    println!("- interface type: {:?}", desc.interface_type());
                    println!("- direction: {:?}", desc.direction());
                    println!("- manufacturer: {:?}", desc.manufacturer());
                    println!("- driver: {:?}", desc.driver());
                    println!("- address: {:?}", desc.address());
                    println!("- channels: {}", config.channels);
                    println!("- sample rate: {}", config.sample_rate);
                    println!("- sample format: {:?}", config_range.sample_format());
                    println!("- buffer size range: {:?}", config_range.buffer_size());
                    println!("- buffer size: {:?}", config.buffer_size);
                    Some(device.to_string())
                } else {
                    None
                }
            })
            .collect::<HashSet<_>>()
            .into_iter()
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
        if self.is_spectrum_analyzer_enabled()? {
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
        self.spectrum_analyzer_enabled = enabled;
        Ok(())
    }

    fn is_spectrum_analyzer_enabled(&mut self) -> Result<bool, Error> {
        Ok(self.spectrum_analyzer_enabled)
    }

    fn input_spec(&self) -> Result<AudioSpec, Error> {
        if let Some(device) = self.input_device.as_ref() {
            Ok(AudioSpec {
                driver_name: self.host.id().to_string(),
                format: "F32".to_string(),
                num_channels: device.config.channels as usize,
                sample_rate: device.config.sample_rate as usize,
                buffer_size: device.stream.buffer_size()? as usize,
            })
        } else {
            Ok(AudioSpec {
                driver_name: "n/a".to_string(),
                format: "n/a".to_string(),
                num_channels: 2,
                sample_rate: 44100,
                buffer_size: BUFFER_SIZE,
            })
        }
    }

    fn track_buffer(&self, track: AudioTrack) -> Result<Vec<f32>, Error> {
        if let Ok(track_buffers) = self.track_buffers.lock() {
            Ok(track_buffers[track].to_vec())
        } else {
            Ok(Vec::new())
        }
    }
}

impl CpalAudioBackend {
    fn on_input_data_received(
        &self,
        mut rb_sender: ringbuf::HeapProd<f32>,
        track_buffers: Arc<Mutex<EnumMap<AudioTrack, RingVec>>>,
    ) -> impl FnMut(&[f32], &cpal::InputCallbackInfo) + Send + 'static {
        let multichannel_enabled = self.multichannel_enabled;
        let channels_in = if multichannel_enabled { 24u16 } else { 2u16 };

        move |data, _| {
            let expected = BUFFER_SIZE * channels_in as usize;
            if data.len() != expected {
                println!(
                    "CPAL: Input callback - expected {expected} samples, got {}",
                    data.len()
                );
                return;
            }

            let Ok(mut track_buffers) = track_buffers.lock() else {
                return;
            };

            let chunks = data.chunks_exact(channels_in as usize);
            if multichannel_enabled {
                for sample in chunks {
                    for (track, track_data) in track_buffers.iter_mut() {
                        let (left_idx, right_idx) = track.channels();
                        let (left, right) = (sample[left_idx], sample[right_idx]);
                        track_data.push((left + right) / 2.0);

                        if track == AudioTrack::Mix {
                            let _ = rb_sender.try_push(left).and(rb_sender.try_push(right));
                        }
                    }
                }
            } else {
                let track = AudioTrack::Mix;
                let track_data = &mut track_buffers[track];
                for sample in chunks {
                    let (left_idx, right_idx) = track.channels();
                    let (left, right) = (sample[left_idx], sample[right_idx]);
                    track_data.push((left + right) / 2.0);

                    let _ = rb_sender.try_push(left).and(rb_sender.try_push(right));
                }
            }
        }
    }

    fn on_output_data_requested(
        &self,
        mut rb_receiver: ringbuf::HeapCons<f32>,
    ) -> impl FnMut(&mut [f32], &OutputCallbackInfo) + Send + 'static {
        let volume = self.volume.clone();
        let volume_peaks = self.volume_peaks.clone();
        let frequency_spectrum = self.frequency_spectrum.clone();

        move |data, _| {
            let mut dropped_samples = false;
            let volume = **volume.lock().as_ref().unwrap();
            let volume_peaks = &mut *volume_peaks.lock().unwrap();
            volume_peaks[0] = 0.0;
            volume_peaks[1] = 0.0;

            // let Some(data) = data.as_slice_mut() else {
            //     println!("CPAL: Received no output data");
            //     return;
            // };

            // println!("Output callback with {} samples", data.len());

            for (i, sample) in data.iter_mut().enumerate() {
                *sample = match rb_receiver.try_pop() {
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
    }
}

impl From<cpal::Error> for Error {
    fn from(e: cpal::Error) -> Error {
        Error::AudioError(e.to_string())
    }
}

struct RingVec {
    deque: VecDeque<f32>,
    capacity: usize,
    // vec: Vec<f32>,
    // marker: usize,
}

impl RingVec {
    fn new(capacity: usize) -> Self {
        let mut deque = VecDeque::with_capacity(capacity);
        deque.make_contiguous().fill(0.0);
        Self { deque, capacity }
        // let vec = vec![0.0; capacity];
        // Self { vec, marker: 0 }
    }

    fn push(&mut self, value: f32) {
        if self.deque.len() == self.capacity {
            self.deque.pop_front();
        }
        self.deque.push_back(value);
        // self.vec[self.marker] = value;
        // self.marker = (self.marker + 1) % self.vec.capacity();
    }

    fn to_vec(&self) -> Vec<f32> {
        self.deque.clone().into()
        // self.vec.clone()
    }
}

fn find_input_devices(
    host: &Host,
    name: &Option<String>,
    channels: u16,
) -> Result<Vec<(cpal::Device, cpal::StreamConfig)>, Error> {
    println!("CPAL: Finding input devices with name: {name:?}");
    let devices = host
        .input_devices()?
        // filter to only devices with a valid name and description
        .filter_map(|device| {
            let desc = device.description().ok()?;
            if (match &name {
                Some(n) => desc.name().contains("M8") && n == &device.to_string(),
                None => desc.name().contains("M8"),
            }) && desc
                .driver()
                .is_some_and(|driver| !driver.to_lowercase().contains("sink"))
                && device.supports_input()
            {
                Some(device)
            } else {
                None
            }
        })
        // find a suitable config for each device
        .filter_map(|device| {
            let config = find_input_stream_config(&device, channels).ok()?;
            Some((device, config))
        })
        .collect::<Vec<(cpal::Device, cpal::StreamConfig)>>();

    println!("CPAL: Found {} valid input devices", devices.len());
    Ok(devices)
}

fn find_output_device(host: &Host, name: &Option<String>) -> Result<Device, Error> {
    println!("CPAL: Finding output device with name: {name:?}");
    let device = match name {
        None => host.default_output_device(),
        Some(name) => host
            .output_devices()?
            .find(|device| device.description().is_ok_and(|desc| name == desc.name())),
    };
    if let Some(device) = device {
        println!(
            "CPAL: Found output device: {}",
            device.description()?.name()
        );
        Ok(device)
    } else {
        Err(Error::AudioError(
            "CPAL: No output device found".to_string(),
        ))
    }
}

fn find_input_stream_config(device: &Device, channels: u16) -> Result<StreamConfig, Error> {
    let sample_format = cpal::SampleFormat::F32;
    let sample_rate = SAMPLE_RATE as u32;
    let buffer_size = BUFFER_SIZE as u32;
    // let buffer_size = 1024u32;

    println!(
        "Finding input stream config for device: {}, driver: {:?}, channels: {}",
        device.to_string(),
        device.description()?.driver(),
        channels
    );

    let supported_config = device
        .supported_input_configs()?
        .filter_map(|config_range| {
            println!("- config range: {:?}", config_range);
            config_range.try_with_sample_rate(sample_rate)
        })
        .find(|config| {
            println!(
                "- config: {{ channels: {}, sample_format: {:?}, buffer_size: {:?} }}",
                config.channels(),
                config.sample_format(),
                config.buffer_size()
            );
            config.channels() == channels
                && config.sample_format() == sample_format
                && match config.buffer_size() {
                    cpal::SupportedBufferSize::Unknown => false,
                    cpal::SupportedBufferSize::Range { min, max } => {
                        &buffer_size >= min && &buffer_size <= max
                    }
                }
        })
        .ok_or(Error::AudioError(
            "Unable to find a valid input config".to_string(),
        ))?;

    let mut config = supported_config.config();
    config.buffer_size = cpal::BufferSize::Fixed(buffer_size);
    Ok(config)
}

fn find_output_stream_config(device: &Device) -> Result<StreamConfig, Error> {
    let sample_format = cpal::SampleFormat::F32;
    let sample_rate = SAMPLE_RATE as u32;
    let buffer_size = BUFFER_SIZE as u32;
    // let buffer_size = 1024u32;
    let channels = 2u16;

    device
        .supported_output_configs()?
        .find(|config| {
            config.channels() == channels
                && config.contains_rate(sample_rate)
                && config.sample_format() == sample_format
                && match config.buffer_size() {
                    cpal::SupportedBufferSize::Unknown => false,
                    cpal::SupportedBufferSize::Range { min, max } => {
                        &buffer_size >= min && &buffer_size <= max
                    }
                }
        })
        .ok_or(Error::AudioError(
            "Unable to find a valid output config".to_string(),
        ))?;

    Ok(StreamConfig {
        sample_rate,
        buffer_size: cpal::BufferSize::Fixed(buffer_size),
        channels,
    })
}

struct AudioStream {
    // pub device: cpal::Device,
    pub config: cpal::StreamConfig,
    pub stream: cpal::Stream,
}

impl AudioStream {
    fn open_input(
        device: cpal::Device,
        config: cpal::StreamConfig,
        callback: impl FnMut(&[f32], &cpal::InputCallbackInfo) + Send + 'static,
    ) -> Result<Self, Error> {
        let name = device.to_string();
        let desc = device.description()?;
        let id = device.id()?;
        let driver = desc.driver();
        println!(
            "CPAL: Opening input stream for device: {name} \n\
             -     id: {id:?} \n\
             - driver: {driver:?} \n\
             - config: {config:?}",
        );
        let stream = device.build_input_stream(
            config,
            callback,
            |err| eprintln!("Input stream error: {}", err),
            None,
        )?;
        stream.play()?;
        Ok(Self {
            // device,
            config,
            stream,
        })
    }

    fn open_output(
        device: cpal::Device,
        config: cpal::StreamConfig,
        callback: impl FnMut(&mut [f32], &cpal::OutputCallbackInfo) + Send + 'static,
    ) -> Result<Self, Error> {
        let name = device.to_string();
        let desc = device.description()?;
        let id = device.id()?;
        let driver = desc.driver();
        println!(
            "CPAL: Opening output stream for device: {name} \n\
             -     id: {id:?} \n\
             - driver: {driver:?} \n\
             - config: {config:?}",
        );
        let stream = device.build_output_stream(
            config,
            callback,
            |err| eprintln!("Output stream error: {}", err),
            None,
        )?;
        stream.play()?;
        Ok(Self {
            // device,
            config,
            stream,
        })
    }

    fn can_open_input(device: &cpal::Device, config: &cpal::StreamConfig) -> bool {
        device
            .build_input_stream(
                config.clone(),
                |_: &[f32], _| return,
                |err| eprintln!("Input stream error: {}", err),
                None,
            )
            .is_ok()
    }
}
