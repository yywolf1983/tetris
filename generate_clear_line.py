import numpy as np
import soundfile as sf
import os

# 创建音频目录
os.makedirs('assets/audio', exist_ok=True)

# 生成新的消除行音效
sample_rate = 44100
duration = 0.3  # 300ms

# 创建一个更柔和的音效，使用正弦波和三角波的组合
t = np.linspace(0, duration, int(sample_rate * duration))

# 主音
fundamental = 523.25  # C5
wave1 = 0.3 * np.sin(2 * np.pi * fundamental * t)

# 泛音
wave2 = 0.15 * np.sin(2 * np.pi * fundamental * 2 * t)
wave3 = 0.1 * np.sin(2 * np.pi * fundamental * 3 * t)

# 三角波
wave4 = 0.1 * np.sign(np.sin(2 * np.pi * fundamental * 1.5 * t))

# 组合波形
total_wave = wave1 + wave2 + wave3 + wave4

# 添加快速的淡入淡出
envelope = np.ones_like(total_wave)
envelope[:int(sample_rate * 0.01)] = np.linspace(0, 1, int(sample_rate * 0.01))
envelope[-int(sample_rate * 0.1):] = np.linspace(1, 0, int(sample_rate * 0.1))

total_wave *= envelope

# 归一化
total_wave /= np.max(np.abs(total_wave))

# 转换为16位整数
total_wave = np.int16(total_wave * 32767)

# 保存文件
sf.write('assets/audio/clear_line.wav', total_wave, sample_rate)
print('Generated new clear_line.wav')