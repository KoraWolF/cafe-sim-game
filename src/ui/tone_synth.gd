class_name ToneSynth
extends RefCounted
## Placeholder sounds made in code, so every audio hook makes a noise before
## real files exist. A sound is a list of segments:
## {"f": start Hz, "to": end Hz (optional sweep), "d": seconds, "w": "sine" |
## "square" | "tri" | "noise", "v": volume 0..1}.

const RATE: int = 22050


static func render(segments: Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	for segment: Dictionary in segments:
		data.append_array(_segment(segment))
	return _stream(data, false)


## A soft looping pad: each chord is a list of Hz, held for `seconds`.
static func pad(chords: Array, seconds: float, volume: float, wave := "sine", pulse := 0.0) -> AudioStreamWAV:
	var data := PackedByteArray()
	var rate := RATE / 2
	var samples := int(seconds * rate)
	data.resize(chords.size() * samples * 2)
	var offset := 0
	for chord: Array in chords:
		for i: int in samples:
			var t := float(i) / rate
			# Slow swell in and out per chord; optional rhythmic pulse.
			var envelope := sin(PI * float(i) / samples)
			if pulse > 0.0:
				envelope *= 0.55 + 0.45 * absf(sin(PI * t * pulse))
			var value := 0.0
			for frequency: float in chord:
				value += _wave(wave, frequency * t)
			value *= volume * envelope / maxf(chord.size(), 1)
			data.encode_s16(offset, int(clampf(value, -1.0, 1.0) * 32767.0))
			offset += 2
	var stream := _stream(data, true, rate)
	return stream


static func _segment(segment: Dictionary) -> PackedByteArray:
	var seconds: float = segment.get("d", 0.1)
	var start: float = segment.get("f", 440.0)
	var end: float = segment.get("to", start)
	var wave: String = segment.get("w", "sine")
	var volume: float = segment.get("v", 0.4)
	var samples := int(seconds * RATE)
	var bytes := PackedByteArray()
	bytes.resize(samples * 2)
	var phase := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i: int in samples:
		var progress := float(i) / samples
		phase += lerpf(start, end, progress) / RATE
		var value := rng.randf_range(-1.0, 1.0) if wave == "noise" else _wave(wave, phase)
		# Quick attack, smooth release: no clicks.
		var envelope := minf(1.0, progress * 40.0) * pow(1.0 - progress, 1.5)
		bytes.encode_s16(i * 2, int(clampf(value * volume * envelope, -1.0, 1.0) * 32767.0))
	return bytes


## One cycle-normalised oscillator at phase (in cycles).
static func _wave(wave: String, phase: float) -> float:
	var cycle := phase - floorf(phase)
	match wave:
		"square":
			return 0.6 if cycle < 0.5 else -0.6
		"tri":
			return 4.0 * absf(cycle - 0.5) - 1.0
	return sin(TAU * cycle)


static func _stream(data: PackedByteArray, loop: bool, rate := RATE) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = data.size() / 2
	return stream
