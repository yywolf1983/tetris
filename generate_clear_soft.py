import numpy as np
import wave
import os

os.makedirs('assets/audio', exist_ok=True)

sample_rate = 44100
channels = 1
sampwidth = 2

notes = {
    'C4': 261.63,
    'E4': 329.63,
    'G4': 392.00,
    'C5': 523.25,
    'A4': 440.00
}

def generate_tone(freq, duration, sample_rate, volume=0.3):
    t = np.linspace(0, duration, int(sample_rate * duration), endpoint=False)
    wave = volume * np.sin(2 * np.pi * freq * t)
    wave += volume * 0.3 * np.sin(2 * np.pi * freq * 2 * t)
    wave += volume * 0.15 * np.sin(2 * np.pi * freq * 3 * t)
    return wave

def apply_envelope(waveform, sample_rate, attack=0.01, release=0.05):
    total_samples = len(waveform)
    envelope = np.ones_like(waveform)
    
    attack_samples = int(sample_rate * attack)
    release_samples = int(sample_rate * release)
    
    if attack_samples < total_samples:
        envelope[:attack_samples] = np.linspace(0, 1, attack_samples)
    if release_samples < total_samples:
        envelope[-release_samples:] = np.linspace(1, 0, release_samples)
    
    return waveform * envelope

def save_wav(filename, waveform, sample_rate, channels, sampwidth):
    waveform = np.clip(waveform, -1, 1)
    waveform = (waveform * 32767 * 0.8).astype(np.int16)
    with wave.open(filename, 'wb') as wf:
        wf.setnchannels(channels)
        wf.setsampwidth(sampwidth)
        wf.setframerate(sample_rate)
        wf.writeframes(waveform.tobytes())

def generate_single_clear():
    note_seq = ['C4', 'E4', 'G4', 'C5']
    note_duration = 0.2
    pause = 0.05
    
    total_duration = len(note_seq) * (note_duration + pause)
    waveform = np.zeros(int(sample_rate * total_duration), dtype=np.float64)
    
    current = 0
    for note in note_seq:
        tone = generate_tone(notes[note], note_duration, sample_rate, volume=0.2)
        tone = apply_envelope(tone, sample_rate, attack=0.008, release=0.03)
        
        tone_samples = int(sample_rate * note_duration)
        waveform[current:current + tone_samples] = tone
        current += int(sample_rate * (note_duration + pause))
    
    save_wav('assets/audio/clear_line_single.wav', waveform, sample_rate, channels, sampwidth)
    print('Generated clear_line_single.wav')

def generate_multi_clear():
    note_seq = ['C4', 'E4', 'G4', 'A4', 'G4', 'E4', 'C4']
    note_duration = 0.17
    pause = 0.02
    
    total_duration = len(note_seq) * (note_duration + pause)
    waveform = np.zeros(int(sample_rate * total_duration), dtype=np.float64)
    
    current = 0
    for i, note in enumerate(note_seq):
        volume = 0.15 + (i * 0.03) if i <= 3 else 0.25 - ((i - 3) * 0.03)
        tone = generate_tone(notes[note], note_duration, sample_rate, volume=volume)
        tone = apply_envelope(tone, sample_rate, attack=0.008, release=0.03)
        
        tone_samples = int(sample_rate * note_duration)
        waveform[current:current + tone_samples] = tone
        current += int(sample_rate * (note_duration + pause))
    
    save_wav('assets/audio/clear_line_multi.wav', waveform, sample_rate, channels, sampwidth)
    print('Generated clear_line_multi.wav')

generate_single_clear()
generate_multi_clear()