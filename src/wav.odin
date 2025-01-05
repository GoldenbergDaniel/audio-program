package main

import "base:runtime"
import "core:fmt"
import "core:os"
import "core:slice"

import "src:basic/bytes"
import "src:basic/mem"

WAV_File :: struct
{
  header: WAV_Header,
  data:   []byte,
}

WAV_Header :: struct #packed
{
  riff:             [4]byte,
  file_size:        u32,
  wave:             [4]byte,
  fmt:              [4]byte,
  wav_section_size: u32,
  type:             u16,
  channels:         u16,
  samples_per_sec:  u32,
  bytes_per_sec:    u32,
  block_align:      u16,
  bits_per_sample:  u16,
  data_desc:        [4]byte,
  data_size:        u32,
}

WAV_HEADER_DEFAULT :: WAV_Header{
  riff             = {82, 73, 70, 70},
  wave             = {87, 65, 86, 69},
  fmt              = {102, 109, 116, 32},
  wav_section_size = 16,
  type             = 1,
  channels         = 2,
  samples_per_sec  = 44100,
  bytes_per_sec    = 176400,
  block_align      = 4,
  bits_per_sample  = 16,
  data_desc        = {100, 97, 116, 97},
}

wav_load :: proc
{
  wav_load_from_file,
  wav_load_from_buffer,
}

wav_load_from_file :: proc(path: string) -> WAV_File
{
  file_data, _ := os.read_entire_file(path)
  return wav_load_from_buffer(file_data)
}

wav_load_from_buffer :: proc(wav_bytes: []byte) -> WAV_File
{
  result: WAV_File
  wav_data_buffer := bytes.make_buffer(wav_bytes, .LE)

  header: WAV_Header
  {
    copy(header.riff[:], bytes.read_bytes(&wav_data_buffer, size_of(WAV_Header{}.riff)))
    header.file_size = bytes.read_u32(&wav_data_buffer)
    copy(header.wave[:], bytes.read_bytes(&wav_data_buffer, size_of(WAV_Header{}.wave)))
    copy(header.fmt[:], bytes.read_bytes(&wav_data_buffer, size_of(WAV_Header{}.fmt)))
    header.wav_section_size = bytes.read_u32(&wav_data_buffer)
    header.type = bytes.read_u16(&wav_data_buffer)
    header.channels = bytes.read_u16(&wav_data_buffer)
    header.samples_per_sec = bytes.read_u32(&wav_data_buffer)
    header.bytes_per_sec = bytes.read_u32(&wav_data_buffer)
    header.block_align = bytes.read_u16(&wav_data_buffer)
    header.bits_per_sample = bytes.read_u16(&wav_data_buffer)
    copy(header.data_desc[:], bytes.read_bytes(&wav_data_buffer, size_of(WAV_Header{}.data_desc)))
    header.data_size = bytes.read_u32(&wav_data_buffer)
  }

  data_start_idx := wav_data_buffer.r_pos
  data: []byte = slice.clone(wav_data_buffer.data[data_start_idx:])

  return {
    header = header,
    data = data,
  }
}

wav_write :: proc
{
  wav_write_to_file,
  wav_write_to_buffer,
}

wav_write_to_file :: proc(wav: WAV_File, path: string)
{
  temp := mem.scope_temp(mem.get_scratch())

  raw_bytes := make([]byte, size_of(wav.header) + len(wav.data))
  wav_write_to_buffer(wav, raw_bytes)

  os.write_entire_file(path, raw_bytes)
}

wav_write_to_buffer :: proc(wav: WAV_File, buf: []byte)
{
  wav := wav
  
  buffer := bytes.make_buffer(buf, .LE)
  bytes.write_bytes(&buffer, transmute([]byte) runtime.Raw_Slice{&wav.header, size_of(wav.header)})
  bytes.write_bytes(&buffer, wav.data)
}
