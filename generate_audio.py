import math
import struct
import wave
import random

SAMPLE_RATE = 22050

def normalize(samples, target_peak=0.92):
    max_val = max(abs(s) for s in samples) if samples else 0
    if max_val > 0.001:
        factor = target_peak / max_val
        return [s * factor for s in samples]
    return samples

def save_wav(filename, samples):
    samples = normalize(samples, 0.92)
    with wave.open(filename, 'w') as wav_file:
        wav_file.setnchannels(1)  # Mono
        wav_file.setsampwidth(2)  # 16-bit
        wav_file.setframerate(SAMPLE_RATE)
        packed = bytearray()
        for s in samples:
            val = max(-1.0, min(1.0, s))
            int_val = int(val * 32767.0)
            packed.extend(struct.pack('<h', int_val))
        wav_file.writeframes(packed)

def gen_jump():
    duration = 0.22
    total_samples = int(duration * SAMPLE_RATE)
    samples = []
    phase = 0.0
    for i in range(total_samples):
        t = i / SAMPLE_RATE
        progress = t / duration
        # Frequency sweep from 180Hz to 520Hz
        freq = 180.0 + 340.0 * (progress ** 0.8)
        phase += 2 * math.pi * freq / SAMPLE_RATE
        # Crisp square-sine mix
        wave_val = 0.6 * math.sin(phase) + 0.3 * math.sin(2 * phase) + 0.1 * math.copysign(1.0, math.sin(phase))
        env = math.exp(-t * 11.0) * min(1.0, t / 0.01)
        samples.append(wave_val * env)
    return samples

def gen_dash():
    duration = 0.32
    total_samples = int(duration * SAMPLE_RATE)
    samples = []
    phase = 0.0
    random.seed(42)
    for i in range(total_samples):
        t = i / SAMPLE_RATE
        progress = t / duration
        # Whoosh / Sonic dash
        freq = 700.0 - 520.0 * (progress ** 0.5)
        phase += 2 * math.pi * freq / SAMPLE_RATE
        sine_val = math.sin(phase)
        noise_val = (random.random() * 2.0 - 1.0)
        mixed = 0.5 * sine_val + 0.5 * noise_val
        env = (math.sin(progress * math.pi) ** 0.7) * (1.0 - progress * 0.3)
        samples.append(mixed * env)
    return samples

def gen_collect():
    # Two bright, loud bell tones (E5: 659Hz, A5: 880Hz, C#6: 1108Hz)
    duration = 0.28
    total_samples = int(duration * SAMPLE_RATE)
    samples = []
    p1, p2, p3 = 0.0, 0.0, 0.0
    for i in range(total_samples):
        t = i / SAMPLE_RATE
        if t < 0.09:
            freq = 659.25
            env = math.exp(-t * 18.0)
            p1 += 2 * math.pi * freq / SAMPLE_RATE
            val = 0.7 * math.sin(p1) + 0.3 * math.sin(2 * p1)
        elif t < 0.18:
            t2 = t - 0.09
            freq = 880.0
            env = math.exp(-t2 * 16.0)
            p2 += 2 * math.pi * freq / SAMPLE_RATE
            val = 0.7 * math.sin(p2) + 0.3 * math.sin(2 * p2)
        else:
            t3 = t - 0.18
            freq = 1108.73
            env = math.exp(-t3 * 14.0)
            p3 += 2 * math.pi * freq / SAMPLE_RATE
            val = 0.75 * math.sin(p3) + 0.25 * math.sin(2 * p3)
        samples.append(val * env)
    return samples

def gen_hit():
    duration = 0.25
    total_samples = int(duration * SAMPLE_RATE)
    samples = []
    phase = 0.0
    random.seed(123)
    for i in range(total_samples):
        t = i / SAMPLE_RATE
        progress = t / duration
        freq = max(50.0, 240.0 - 190.0 * progress)
        phase += 2 * math.pi * freq / SAMPLE_RATE
        noise = (random.random() * 2.0 - 1.0)
        wave_val = 0.6 * math.copysign(1.0, math.sin(phase)) + 0.4 * noise
        env = math.exp(-t * 14.0)
        samples.append(wave_val * env)
    return samples

def gen_game_over():
    notes = [440.0, 392.0, 349.23, 261.63]
    note_dur = 0.22
    duration = note_dur * len(notes) + 0.2
    total_samples = int(duration * SAMPLE_RATE)
    samples = [0.0] * total_samples
    
    for idx, freq in enumerate(notes):
        start_t = idx * note_dur
        p = 0.0
        n_samples = int((note_dur + 0.2) * SAMPLE_RATE)
        for i in range(n_samples):
            target_idx = int(start_t * SAMPLE_RATE) + i
            if target_idx >= total_samples:
                break
            t = i / SAMPLE_RATE
            p += 2 * math.pi * freq / SAMPLE_RATE
            val = 0.7 * math.sin(p) + 0.2 * math.sin(2 * p) + 0.1 * math.sin(3 * p)
            env = math.exp(-t * 7.0)
            samples[target_idx] += val * env
    return samples

def gen_victory():
    notes = [(523.25, 0.15), (659.25, 0.15), (783.99, 0.15), (1046.50, 0.5)]
    total_time = sum(dur for _, dur in notes) + 0.25
    total_samples = int(total_time * SAMPLE_RATE)
    samples = [0.0] * total_samples
    
    start_t = 0.0
    for freq, dur in notes:
        n_samples = int((dur + 0.3) * SAMPLE_RATE)
        p = 0.0
        for i in range(n_samples):
            target_idx = int(start_t * SAMPLE_RATE) + i
            if target_idx >= total_samples:
                break
            t = i / SAMPLE_RATE
            p += 2 * math.pi * freq / SAMPLE_RATE
            val = 0.7 * math.sin(p) + 0.2 * math.sin(2 * p) + 0.1 * math.sin(3 * p)
            env = math.exp(-t * (5.0 if dur > 0.3 else 10.0))
            samples[target_idx] += val * env
        start_t += dur
    return samples

def gen_checkpoint():
    notes = [587.33, 880.0, 1174.66]
    duration = 0.35
    total_samples = int(duration * SAMPLE_RATE)
    samples = []
    p1, p2, p3 = 0.0, 0.0, 0.0
    for i in range(total_samples):
        t = i / SAMPLE_RATE
        p1 += 2 * math.pi * notes[0] / SAMPLE_RATE
        p2 += 2 * math.pi * notes[1] / SAMPLE_RATE
        p3 += 2 * math.pi * notes[2] / SAMPLE_RATE
        val = 0.4 * math.sin(p1) + 0.4 * math.sin(p2) + 0.2 * math.sin(p3)
        env = math.exp(-t * 9.0)
        samples.append(val * env)
    return samples

def gen_bgm():
    # Loopable upbeat chiptune background music
    # Tempo: 132 BPM
    bpm = 132.0
    beat_dur = 60.0 / bpm
    total_beats = 16
    duration = total_beats * beat_dur
    total_samples = int(duration * SAMPLE_RATE)
    samples = [0.0] * total_samples

    # Upbeat melody notes: (freq, beat_start, beat_length)
    melody = [
        # Bar 1: C - E - G - high C
        (523.25, 0.0, 0.5),
        (659.25, 0.5, 0.5),
        (783.99, 1.0, 0.75),
        (1046.50, 2.0, 0.5),
        (880.00, 2.5, 0.5),
        (783.99, 3.0, 0.75),
        
        # Bar 2: A minor feel
        (659.25, 4.0, 0.5),
        (783.99, 4.5, 0.5),
        (880.00, 5.0, 1.0),
        (1046.50, 6.0, 0.5),
        (880.00, 6.5, 0.5),
        (783.99, 7.0, 0.75),

        # Bar 3: F - G energetic jump
        (659.25, 8.0, 0.5),
        (783.99, 8.5, 0.5),
        (880.00, 9.0, 0.75),
        (987.77, 10.0, 0.5),
        (1046.50, 10.5, 0.5),
        (1174.66, 11.0, 0.75),

        # Bar 4: Resolution to C
        (1046.50, 12.0, 0.5),
        (880.00, 12.5, 0.5),
        (783.99, 13.0, 0.75),
        (659.25, 14.0, 0.5),
        (587.33, 14.5, 0.5),
        (523.25, 15.0, 0.8),
    ]

    # Bassline with punchy 1st and 2nd harmonics (audible on small phone speakers!)
    bass = [
        # C chord
        (130.81, 0.0, 1.6),
        (130.81, 2.0, 1.6),
        # Am chord
        (110.00, 4.0, 1.6),
        (110.00, 6.0, 1.6),
        # F chord
        (174.61, 8.0, 1.6),
        (174.61, 10.0, 1.6),
        # G chord
        (196.00, 12.0, 1.6),
        (196.00, 14.0, 1.6),
    ]

    # Chords accompaniment (arpeggiated stabs on off-beats)
    chords = [
        # C (C4, E4, G4)
        ([261.63, 329.63, 392.00], 0.5, 0.4),
        ([261.63, 329.63, 392.00], 1.5, 0.4),
        ([261.63, 329.63, 392.00], 2.5, 0.4),
        ([261.63, 329.63, 392.00], 3.5, 0.4),
        # Am (A3, C4, E4)
        ([220.00, 261.63, 329.63], 4.5, 0.4),
        ([220.00, 261.63, 329.63], 5.5, 0.4),
        ([220.00, 261.63, 329.63], 6.5, 0.4),
        ([220.00, 261.63, 329.63], 7.5, 0.4),
        # F (F3, A3, C4)
        ([174.61, 220.00, 261.63], 8.5, 0.4),
        ([174.61, 220.00, 261.63], 9.5, 0.4),
        ([174.61, 220.00, 261.63], 10.5, 0.4),
        ([174.61, 220.00, 261.63], 11.5, 0.4),
        # G (G3, B3, D4)
        ([196.00, 246.94, 293.66], 12.5, 0.4),
        ([196.00, 246.94, 293.66], 13.5, 0.4),
        ([196.00, 246.94, 293.66], 14.5, 0.4),
        ([196.00, 246.94, 293.66], 15.5, 0.4),
    ]

    # Synthesize Bass
    for freq, beat_start, beat_len in bass:
        start_sample = int(beat_start * beat_dur * SAMPLE_RATE)
        n_samples = int(beat_len * beat_dur * SAMPLE_RATE)
        p = 0.0
        for i in range(n_samples):
            idx = (start_sample + i) % total_samples
            t = i / SAMPLE_RATE
            p += 2 * math.pi * freq / SAMPLE_RATE
            # Sine + 2nd harmonic + square hint for rich bass
            val = 0.5 * math.sin(p) + 0.35 * math.sin(2 * p) + 0.15 * math.sin(3 * p)
            env = math.exp(-t * 2.2) * 0.45
            samples[idx] += val * env

    # Synthesize Chords
    for chord_freqs, beat_start, beat_len in chords:
        start_sample = int(beat_start * beat_dur * SAMPLE_RATE)
        n_samples = int(beat_len * beat_dur * SAMPLE_RATE)
        for f in chord_freqs:
            p = 0.0
            for i in range(n_samples):
                idx = (start_sample + i) % total_samples
                t = i / SAMPLE_RATE
                p += 2 * math.pi * f / SAMPLE_RATE
                val = 0.6 * math.sin(p) + 0.4 * math.sin(2 * p)
                env = math.exp(-t * 8.0) * 0.2
                samples[idx] += val * env

    # Synthesize Melody (Lead synth)
    for freq, beat_start, beat_len in melody:
        start_sample = int(beat_start * beat_dur * SAMPLE_RATE)
        n_samples = int(beat_len * beat_dur * SAMPLE_RATE)
        p = 0.0
        for i in range(n_samples):
            idx = (start_sample + i) % total_samples
            t = i / SAMPLE_RATE
            p += 2 * math.pi * freq / SAMPLE_RATE
            # Classic 8-bit pulse / square-sine wave
            square = math.copysign(1.0, math.sin(p))
            val = 0.55 * math.sin(p) + 0.3 * square + 0.15 * math.sin(2 * p)
            env = min(1.0, t / 0.015) * math.exp(-t * (2.2 / beat_len)) * 0.55
            samples[idx] += val * env

    # Hi-hat / snare drum beat
    random.seed(777)
    for b in range(total_beats * 2):
        beat_time = b * (beat_dur / 2.0)
        start_sample = int(beat_time * SAMPLE_RATE)
        is_snare = (b % 4 == 2)
        dur = 0.12 if is_snare else 0.04
        n_samples = int(dur * SAMPLE_RATE)
        for i in range(n_samples):
            idx = (start_sample + i) % total_samples
            t = i / SAMPLE_RATE
            noise = (random.random() * 2.0 - 1.0)
            if is_snare:
                tone = math.sin(2 * math.pi * 180 * t)
                env = math.exp(-t * 35.0) * 0.35
                samples[idx] += (0.6 * noise + 0.4 * tone) * env
            else:
                env = math.exp(-t * 85.0) * 0.18
                samples[idx] += noise * env

    return samples

def gen_countdown_tick():
    duration = 0.14
    total_samples = int(duration * SAMPLE_RATE)
    samples = []
    freq = 740.0
    phase = 0.0
    for i in range(total_samples):
        t = i / SAMPLE_RATE
        phase += 2 * math.pi * freq / SAMPLE_RATE
        val = 0.8 * math.sin(phase) + 0.2 * math.sin(2 * phase)
        env = min(1.0, t / 0.005) * math.exp(-t * 22.0)
        samples.append(val * env)
    return samples

def gen_countdown_go():
    duration = 0.42
    total_samples = int(duration * SAMPLE_RATE)
    samples = []
    f1 = 1174.66  # D6
    f2 = 1480.0   # F#6
    p1 = 0.0
    p2 = 0.0
    for i in range(total_samples):
        t = i / SAMPLE_RATE
        p1 += 2 * math.pi * f1 / SAMPLE_RATE
        p2 += 2 * math.pi * f2 / SAMPLE_RATE
        val = 0.6 * math.sin(p1) + 0.4 * math.sin(p2)
        env = min(1.0, t / 0.008) * math.exp(-t * 7.5)
        samples.append(val * env)
    return samples

if __name__ == '__main__':
    save_wav('assets/audio/jump.wav', gen_jump())
    save_wav('assets/audio/dash.wav', gen_dash())
    save_wav('assets/audio/collect.wav', gen_collect())
    save_wav('assets/audio/hit.wav', gen_hit())
    save_wav('assets/audio/game_over.wav', gen_game_over())
    save_wav('assets/audio/victory.wav', gen_victory())
    save_wav('assets/audio/checkpoint.wav', gen_checkpoint())
    save_wav('assets/audio/countdown_tick.wav', gen_countdown_tick())
    save_wav('assets/audio/countdown_go.wav', gen_countdown_go())
    save_wav('assets/audio/bgm.wav', gen_bgm())
    print("All audio files generated and normalized successfully!")
