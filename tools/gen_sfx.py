#!/usr/bin/env python3
"""生成占位音效 wav 到 assets/audio/。纯 stdlib，可重复运行。
音色简陋（合成正弦/噪声），仅作占位；后续替换为真实音效即可。
运行：python3 tools/gen_sfx.py
"""
import wave
import struct
import math
import random
import os

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")

random.seed(42)


def write_wav(name: str, samples: list[float]) -> None:
	path = os.path.join(OUT, f"{name}.wav")
	with wave.open(path, "wb") as w:
		w.setnchannels(1)
		w.setsampwidth(2)
		w.setframerate(SR)
		frames = b"".join(
			struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32767)) for s in samples
		)
		w.writeframes(frames)
	print(f"wrote {path} ({len(samples)/SR:.2f}s)")


def sine(freq: float, dur: float, amp: float = 0.5, decay: float = 6.0) -> list[float]:
	n = int(SR * dur)
	return [
		amp * math.exp(-decay * i / SR) * math.sin(2 * math.pi * freq * i / SR)
		for i in range(n)
	]


def sweep(f0: float, f1: float, dur: float, amp: float = 0.5, decay: float = 4.0) -> list[float]:
	n = int(SR * dur)
	out = []
	ph = 0.0
	for i in range(n):
		t = i / SR
		f = f0 + (f1 - f0) * (i / n)
		ph += 2 * math.pi * f / SR
		out.append(amp * math.exp(-decay * t) * math.sin(ph))
	return out


def noise(dur: float, amp: float = 0.5, decay: float = 6.0, lp: float = 0.0) -> list[float]:
	n = int(SR * dur)
	out = []
	prev = 0.0
	for i in range(n):
		t = i / SR
		r = random.uniform(-1.0, 1.0)
		if lp > 0.0:
			r = prev * lp + r * (1.0 - lp)
			prev = r
		out.append(amp * math.exp(-decay * t) * r)
	return out


def square(freq: float, dur: float, amp: float = 0.4, decay: float = 5.0) -> list[float]:
	n = int(SR * dur)
	return [
		amp * math.exp(-decay * i / SR) * (1.0 if math.sin(2 * math.pi * freq * i / SR) >= 0 else -1.0)
		for i in range(n)
	]


def mix(*arrs: list[float]) -> list[float]:
	n = max(len(a) for a in arrs)
	out = [0.0] * n
	for a in arrs:
		for i, v in enumerate(a):
			out[i] += v
	return out


def concat(*arrs: list[float]) -> list[float]:
	out = []
	for a in arrs:
		out.extend(a)
	return out


def main() -> None:
	os.makedirs(OUT, exist_ok=True)

	# 拾起：短促上行 blip
	write_wav("pick", sine(700.0, 0.06, amp=0.32, decay=11.0))
	# 放下/落地：闷响 thud
	write_wav("drop", mix(sine(150.0, 0.12, amp=0.5, decay=12.0),
						   noise(0.10, amp=0.25, decay=15.0, lp=0.6)))
	# 正确：双音 chime（纯五度）
	write_wav("correct", concat(sine(660.0, 0.09, amp=0.40, decay=6.0),
								  sine(990.0, 0.14, amp=0.40, decay=5.0)))
	# 错误：低频嗡嗡
	write_wav("wrong", mix(square(140.0, 0.20, amp=0.32, decay=4.0),
						 square(146.0, 0.20, amp=0.28, decay=4.0)))
	# 需求出现：带泛音的 ping
	write_wav("demand", mix(sine(880.0, 0.30, amp=0.30, decay=4.0),
							  sine(1760.0, 0.30, amp=0.12, decay=6.0)))
	# 吐牌：上行扫频 pop
	write_wav("spit", sweep(500.0, 950.0, 0.13, amp=0.45, decay=5.0))
	# 开包：噪声迸发
	write_wav("pack", noise(0.20, amp=0.50, decay=8.0, lp=0.3))


if __name__ == "__main__":
	main()
