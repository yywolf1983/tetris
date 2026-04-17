import numpy as np
import wave
import os

# 创建音频目录
os.makedirs('assets/audio', exist_ok=True)

# 生成消除行音效
sample_rate = 44100
channels = 1
sampwidth = 2  # 16位

# 音符频率（C大调）
notes = {
    'C4': 261.63,  # Do
    'E4': 329.63,  # Mi
    'G4': 392.00,  # Sol
    'C5': 523.25,  # Do (高)
    'A4': 440.00   # La
}

# 生成方波函数
def square_wave(freq, duration, sample_rate):
    t = np.linspace(0, duration, int(sample_rate * duration), endpoint=False)
    return np.sign(np.sin(2 * np.pi * freq * t))

# 1. 单行消除音效：Do → Mi → Sol → Do(高)，0.2s/音，总时长0.8s
def generate_single_clear():
    note_sequence = ['C4', 'E4', 'G4', 'C5']
    note_duration = 0.2
    total_duration = len(note_sequence) * note_duration
    
    total_samples = int(sample_rate * total_duration)
    waveform = np.zeros(total_samples, dtype=np.float32)
    
    current_sample = 0
    for note in note_sequence:
        freq = notes[note]
        note_samples = int(sample_rate * note_duration)
        
        # 生成方波
        note_wave = 0.3 * square_wave(freq, note_duration, sample_rate)
        
        # 加一点泛音
        note_wave += 0.1 * square_wave(freq * 2, note_duration, sample_rate)
        
        # 淡入淡出
        envelope = np.ones(note_samples)
        fade_samples = int(sample_rate * 0.01)
        if fade_samples < note_samples:
            envelope[:fade_samples] = np.linspace(0, 1, fade_samples)
            envelope[-fade_samples:] = np.linspace(1, 0, fade_samples)
        
        note_wave *= envelope
        
        # 添加到总波形
        waveform[current_sample:current_sample + note_samples] = note_wave
        current_sample += note_samples
    
    # 归一化到16位范围
    waveform = np.clip(waveform, -1, 1)
    waveform = (waveform * 32767).astype(np.int16)
    
    # 保存为WAV文件
    with wave.open('assets/audio/clear_line_single.wav', 'wb') as wf:
        wf.setnchannels(channels)
        wf.setsampwidth(sampwidth)
        wf.setframerate(sample_rate)
        wf.writeframes(waveform.tobytes())
    
    print('Generated clear_line_single.wav (0.8s)')

# 2. 多行连消音效：Do → Mi → Sol → La → Sol → Mi → Do，总时长1.2s
def generate_multi_clear():
    note_sequence = ['C4', 'E4', 'G4', 'A4', 'G4', 'E4', 'C4']
    total_duration = 1.2
    note_duration = total_duration / len(note_sequence)
    
    total_samples = int(sample_rate * total_duration)
    waveform = np.zeros(total_samples, dtype=np.float32)
    
    current_sample = 0
    for i, note in enumerate(note_sequence):
        freq = notes[note]
        note_samples = int(sample_rate * note_duration)
        
        # 音量递进
        volume = 0.3 + (i * 0.1)  # 0.3 → 0.4 → 0.5 → 0.6 → 0.5 → 0.4 → 0.3
        if i > 3:
            volume = 0.6 - ((i - 3) * 0.1)
        
        # 生成方波
        note_wave = volume * square_wave(freq, note_duration, sample_rate)
        
        # 加一点泛音
        note_wave += 0.1 * square_wave(freq * 2, note_duration, sample_rate)
        
        # 淡入淡出
        envelope = np.ones(note_samples)
        fade_samples = int(sample_rate * 0.01)
        if fade_samples < note_samples:
            envelope[:fade_samples] = np.linspace(0, 1, fade_samples)
            envelope[-fade_samples:] = np.linspace(1, 0, fade_samples)
        
        note_wave *= envelope
        
        # 添加到总波形
        waveform[current_sample:current_sample + note_samples] = note_wave
        current_sample += note_samples
    
    # 归一化到16位范围
    waveform = np.clip(waveform, -1, 1)
    waveform = (waveform * 32767).astype(np.int16)
    
    # 保存为WAV文件
    with wave.open('assets/audio/clear_line_multi.wav', 'wb') as wf:
        wf.setnchannels(channels)
        wf.setsampwidth(sampwidth)
        wf.setframerate(sample_rate)
        wf.writeframes(waveform.tobytes())
    
    print('Generated clear_line_multi.wav (1.2s)')

# 生成两个音效
generate_single_clear()
generate_multi_clear()