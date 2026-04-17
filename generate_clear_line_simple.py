import numpy as np
import wave
import os

# 创建音频目录
os.makedirs('assets/audio', exist_ok=True)

# 生成新的消除行音效
sample_rate = 44100
duration = 0.3  # 300ms
channels = 1
sampwidth = 2  # 16位

# 创建一个更柔和的音效，使用正弦波
t = np.linspace(0, duration, int(sample_rate * duration), endpoint=False)

# 主音和泛音
fundamental = 523.25  # C5
harmonic1 = 1046.50  # C6
harmonic2 = 1567.98  # G6

# 组合波形
waveform = 0.3 * np.sin(2 * np.pi * fundamental * t) + \
           0.15 * np.sin(2 * np.pi * harmonic1 * t) + \
           0.1 * np.sin(2 * np.pi * harmonic2 * t)

# 添加淡入淡出
envelope = np.ones_like(waveform)
envelope[:int(sample_rate * 0.01)] = np.linspace(0, 1, int(sample_rate * 0.01))
envelope[-int(sample_rate * 0.1):] = np.linspace(1, 0, int(sample_rate * 0.1))

waveform *= envelope

# 归一化到16位范围
waveform = np.clip(waveform, -1, 1)
waveform = (waveform * 32767).astype(np.int16)

# 保存为WAV文件
with wave.open('assets/audio/clear_line.wav', 'wb') as wf:
    wf.setnchannels(channels)
    wf.setsampwidth(sampwidth)
    wf.setframerate(sample_rate)
    wf.writeframes(waveform.tobytes())

print('Generated new clear_line.wav')