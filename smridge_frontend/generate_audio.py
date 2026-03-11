import wave
import struct
import math
import random

def generate_cinematic(filename, duration=5.0, sample_rate=44100):
    with wave.open(filename, 'w') as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(sample_rate)
        
        for i in range(int(duration * sample_rate)):
            t = i / sample_rate
            
            # Sub-bass massive drop (drops from 150Hz down to 30Hz)
            freq_drop = max(30, 200 * math.exp(-t * 2.5))
            sub = math.sin(2 * math.pi * freq_drop * t) * math.exp(-t * 1.5)
            
            # High-tech cinematic shimmer (FM Synth vibe)
            fm_mod = math.sin(2 * math.pi * 50 * t)
            shimmer = math.sin(2 * math.pi * (400 + 200 * fm_mod) * t) * math.exp(-t * 3.0)
            
            # Deep impact thump (very fast decay)
            thump = math.sin(2 * math.pi * 60 * t) * math.exp(-t * 20)
            
            # Reverb-like noise tail
            noise = (random.random() * 2 - 1) * math.exp(-t * 0.8)
            
            # Mix layers
            mixed = (sub * 0.7) + (shimmer * 0.15) + (thump * 0.5) + (noise * 0.05)
            
            # Fade out gracefully at the end
            envelope = min(1.0, (duration - t) * 2)
            
            val = int(mixed * envelope * 32767 * 0.95)
            val = max(-32768, min(32767, val))
            f.writeframesraw(struct.pack('<h', val))

def generate_door_open(filename, duration=0.8, sample_rate=44100):
    with wave.open(filename, 'w') as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(sample_rate)
        
        for i in range(int(duration * sample_rate)):
            t = i / sample_rate
            
            # Air suction release (white noise with fast decay)
            suction = (random.random() * 2 - 1) * math.exp(-t * 8)
            
            # Heavy magnetic latch breaking (low frequency thud)
            latch_freq = 80 * math.exp(-t * 10)
            thud = math.sin(2 * math.pi * latch_freq * t) * math.exp(-t * 15)
            
            # Sharp mechanical click
            click = math.sin(2 * math.pi * 2000 * t) * math.exp(-t * 50)
            
            mixed = (suction * 0.4) + (thud * 0.7) + (click * 0.2)
            
            val = int(mixed * 32767 * 0.8)
            val = max(-32768, min(32767, val))
            f.writeframesraw(struct.pack('<h', val))

def generate_fridge_hum(filename, duration=3.0, sample_rate=44100):
    with wave.open(filename, 'w') as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(sample_rate)
        
        for i in range(int(duration * sample_rate)):
            t = i / sample_rate
            
            # Perfect seamless 60Hz and 120Hz harmonics
            val = math.sin(2 * math.pi * 60 * t) * 0.6 + math.sin(2 * math.pi * 120 * t) * 0.3
            
            # Tiny broadband rumble
            noise = (random.random() * 2 - 1) * 0.02
            
            mixed = val + noise
            
            val = int(mixed * 32767 * 0.3)
            val = max(-32768, min(32767, val))
            f.writeframesraw(struct.pack('<h', val))

generate_cinematic('assets/audio/logo_reveal.wav')
generate_door_open('assets/audio/door_open.wav')
generate_fridge_hum('assets/audio/fridge_hum.wav')

print("High-Fidelity WAV synthesis complete.")
