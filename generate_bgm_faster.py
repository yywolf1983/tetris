import numpy as np
import wave
import os

# 创建音频目录
os.makedirs('assets/audio', exist_ok=True)

# 生成新的背景音乐
sample_rate = 44100
duration = 40  # 40秒，比之前的30秒长
tempo = 120  # 欢快的速度（BPM）
channels = 1
sampwidth = 2  # 16位

# 音符频率（C大调）
notes = {
    'C4': 261.63,
    'D4': 293.66,
    'E4': 329.63,
    'F4': 349.23,
    'G4': 392.00,
    'A4': 440.00,
    'B4': 493.88,
    'C5': 523.25
}

# 更欢快的旋律（基于经典俄罗斯方块旋律，但更有活力）
melody = [
    # 主题A
    ('E4', 0.5), ('E4', 0.5), ('F4', 0.5), ('G4', 0.5),
    ('G4', 0.5), ('F4', 0.5), ('E4', 0.5), ('D4', 0.5),
    ('C4', 0.5), ('C4', 0.5), ('D4', 0.5), ('E4', 0.5),
    ('E4', 0.75), ('D4', 0.25), ('D4', 0.5),
    
    # 主题B
    ('E4', 0.5), ('E4', 0.5), ('F4', 0.5), ('G4', 0.5),
    ('G4', 0.5), ('F4', 0.5), ('E4', 0.5), ('D4', 0.5),
    ('C4', 0.5), ('C4', 0.5), ('D4', 0.5), ('E4', 0.5),
    ('D4', 0.75), ('C4', 0.25), ('C4', 0.5),
    
    # 变体
    ('D4', 0.5), ('D4', 0.5), ('E4', 0.5), ('C4', 0.5),
    ('D4', 0.5), ('E4', 0.5), ('F4', 0.5), ('E4', 0.5),
    ('C4', 0.5), ('D4', 0.5), ('E4', 0.5), ('D4', 0.5),
    ('C4', 0.75), ('C4', 0.25), ('C4', 0.5),
    
    # 高潮
    ('E4', 0.5), ('E4', 0.5), ('F4', 0.5), ('G4', 0.5),
    ('G4', 0.5), ('F4', 0.5), ('E4', 0.5), ('D4', 0.5),
    ('C4', 0.5), ('C4', 0.5), ('D4', 0.5), ('E4', 0.5),
    ('D4', 0.75), ('C4', 0.25), ('C4', 0.5),
]

# 生成波形
total_samples = int(sample_rate * duration)
waveform = np.zeros(total_samples, dtype=np.float32)

# 播放旋律
current_sample = 0
for note, duration_beat in melody:
    # 计算音符持续时间（秒）
    note_duration = (60 / tempo) * duration_beat
    note_samples = int(sample_rate * note_duration)
    
    # 生成音符波形
    t_note = np.linspace(0, note_duration, note_samples, endpoint=False)
    freq = notes[note]
    
    # 主音
    note_wave = 0.3 * np.sin(2 * np.pi * freq * t_note)
    
    # 泛音
    note_wave += 0.15 * np.sin(2 * np.pi * freq * 2 * t_note)
    note_wave += 0.1 * np.sin(2 * np.pi * freq * 3 * t_note)
    
    # 淡入淡出
    envelope = np.ones(note_samples)
    fade_samples = int(sample_rate * 0.01)
    if fade_samples < note_samples:
        envelope[:fade_samples] = np.linspace(0, 1, fade_samples)
        envelope[-fade_samples:] = np.linspace(1, 0, fade_samples)
    
    note_wave *= envelope
    
    # 添加到总波形
    if current_sample + note_samples <= total_samples:
        waveform[current_sample:current_sample + note_samples] += note_wave
        current_sample += note_samples
    else:
        break

# 归一化到16位范围
waveform = np.clip(waveform, -1, 1)
waveform = (waveform * 32767).astype(np.int16)

# 保存为WAV文件
with wave.open('assets/audio/tetris_bgm.wav', 'wb') as wf:
    wf.setnchannels(channels)
    wf.setsampwidth(sampwidth)
    wf.setframerate(sample_rate)
    wf.writeframes(waveform.tobytes())

print('Generated new tetris_bgm.wav (40s, faster tempo)')