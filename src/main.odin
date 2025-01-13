package main

import "base:builtin"
import "core:fmt"
import "core:math"
import "core:slice"
import "core:os"

import "src:basic/bytes"
import "src:basic/mem"
import ma "ext:miniaudio"

print   :: fmt.print
println :: fmt.println

main :: proc()
{
  perm_arena: mem.Arena
  mem.init_arena_static(&perm_arena)
  context.allocator = mem.allocator(&perm_arena)

  wav_write(sine_tone(), "test/out_0.wav")
  wav_file := wav_load("test/out_0.wav")
  // println(wav_file.header)
  assert(wav_file.header.type == 1)
  assert(wav_file.header.channels == 2)
  assert(wav_file.header.bits_per_sample == 16)

  sample_count := wav_file.header.data_size / u32(wav_file.header.block_align)
  samples := slice.reinterpret([]i16, wav_file.data)

  ma_result: ma.result

  audio_buffer: ma.audio_buffer
  audio_buffer_config := ma.audio_buffer_config_init(format = .s16,
                                                     channels = 2,
                                                     sizeInFrames = u64(len(samples))/2 - 1000,
                                                     pData = raw_data(samples),
                                                     pAllocationCallbacks = nil)
  ma_result = ma.audio_buffer_init(&audio_buffer_config, &audio_buffer)
  defer ma.audio_buffer_uninit(&audio_buffer)
  if ma_result != .SUCCESS
  {
    println("Failed to initialize buffer. Exiting.")
    return
  }

  device: ma.device
  device_config := ma.device_config_init(.playback)
  device_config.playback.format = .s16
  device_config.playback.channels = 2
  device_config.sampleRate = wav_file.header.samples_per_sec
  device_config.dataCallback = data_cb
  device_config.pUserData = &audio_buffer

  ma_result = ma.device_init(nil, &device_config, &device)
  defer ma.device_uninit(&device)
  if ma_result != .SUCCESS
  {
    println("Failed to initialize audio device. Exiting.")
    return
  }

  ma_result = ma.device_start(&device)
  defer ma.device_stop(&device)
  if ma_result != .SUCCESS
  {
    println("Failed to start audio device. Exiting.")
    return
  }

  terminal_input: [8]byte
  print("Press [enter] to quit...")
  os.read(os.stdin, terminal_input[:])  
}

sine_tone :: proc() -> WAV_File
{
  wav_file: WAV_File
  wav_file.header = WAV_HEADER_DEFAULT

  samples := make([]i16, WAV_HEADER_DEFAULT.samples_per_sec * 6)
  for sample_idx := 0; sample_idx < len(samples); sample_idx += 1
  {
    sample := &samples[sample_idx]
    sample^ = cast(i16) ((math.sin(f32(sample_idx) * 0.05) * (2 << 10) + 1024) * 0.5)
  }

  wav_file.data = slice.reinterpret([]byte, samples)

  return wav_file
}

data_cb :: proc "c" (device: ^ma.device, output, input: rawptr, frame_count: u32)
{
  audio_buffer := cast(^ma.audio_buffer) device.pUserData
  ma.audio_buffer_read_pcm_frames(audio_buffer, output, u64(frame_count), false)
}
