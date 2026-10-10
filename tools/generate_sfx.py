"""Generate the original V32 sound effects; no external samples are used."""

from __future__ import annotations

import math
import random
import wave
from pathlib import Path

RATE = 22050
OUT = Path(__file__).resolve().parents[1] / "assets/audio/sfx"
OUT.mkdir(parents=True, exist_ok=True)
RNG = random.Random(32032)


def layer(start: float, end: float, power: float, attack: float = 0.008,
          decay: float = 5.0, kind: str = "sine", delay: float = 0.0) -> tuple:
    return start, end, power, attack, decay, kind, delay


def render(name: str, duration: float, layers: list[tuple], gain: float = 0.6) -> None:
    count = int(RATE * duration)
    phases = [0.0] * len(layers)
    smoothed_noise = [0.0] * len(layers)
    samples = []
    for i in range(count):
        t = i / RATE
        value = 0.0
        for j, (start, end, power, attack, decay, kind, delay) in enumerate(layers):
            local = t - delay
            if local < 0:
                continue
            progress = min(1.0, local / max(0.001, duration - delay))
            freq = start + (end - start) * progress
            phases[j] += 2 * math.pi * freq / RATE
            envelope = min(1.0, local / max(0.001, attack)) * math.exp(-decay * local / max(0.001, duration - delay))
            if kind == "noise":
                smoothed_noise[j] = 0.72 * smoothed_noise[j] + 0.28 * RNG.uniform(-1.0, 1.0)
                wave_value = smoothed_noise[j]
            elif kind == "metal":
                wave_value = (math.sin(phases[j]) + 0.45 * math.sin(phases[j] * 2.71) + 0.22 * math.sin(phases[j] * 4.13)) / 1.67
            elif kind == "soft":
                wave_value = (math.sin(phases[j]) + 0.28 * math.sin(2 * phases[j])) / 1.28
            else:
                wave_value = math.sin(phases[j])
            value += power * envelope * wave_value
        samples.append(value)
    peak = max(1.0, max(abs(v) for v in samples) / gain)
    write(name, [v / peak for v in samples])


def write(name: str, samples: list[float]) -> None:
    path = OUT / f"{name}.wav"
    with wave.open(str(path), "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(RATE)
        data = bytearray()
        for sample in samples:
            value = int(max(-1.0, min(1.0, sample)) * 32767)
            data.extend(value.to_bytes(2, "little", signed=True))
        wav.writeframes(data)


def wind() -> None:
    count = 4 * RATE
    noise = [RNG.uniform(-1.0, 1.0) for _ in range(count)]
    # Circular filtering makes the first and last samples join naturally.
    for _ in range(3):
        noise = [(noise[(i - 1) % count] + 2 * noise[i] + noise[(i + 1) % count]) * 0.25 for i in range(count)]
    samples = []
    for i, value in enumerate(noise):
        cycle = 2 * math.pi * i / count
        gust = 0.54 + 0.18 * math.sin(cycle) + 0.09 * math.sin(3 * cycle + 0.6)
        samples.append(value * gust * 0.16)
    write("wind", samples)


def main() -> None:
    presets = {
        "hover": (0.075, [layer(620, 800, .13, .003, 5, "soft")]),
        "click": (0.11, [layer(390, 260, .24, .002, 5, "metal"), layer(130, 90, .12, .002, 8)]),
        "confirm": (0.25, [layer(440, 660, .24, .006, 3, "metal"), layer(660, 880, .15, .006, 4, "soft", .07)]),
        "invalid": (0.19, [layer(270, 165, .27, .003, 3, "metal"), layer(180, 115, .12, .003, 4)]),
        "hero_select": (0.25, [layer(310, 470, .23, .007, 3, "metal"), layer(465, 700, .13, .008, 4, "soft", .07)]),
        "route": (0.36, [layer(280, 390, .22, .008, 3, "metal"), layer(420, 560, .19, .008, 3, "metal", .10)]),
        "attribute": (0.30, [layer(480, 720, .18, .007, 3, "soft"), layer(720, 930, .12, .007, 3, "metal", .09)]),
        "unlock": (0.68, [layer(392, 392, .19, .014, 2, "metal"), layer(494, 494, .18, .014, 2, "metal", .08), layer(784, 784, .14, .014, 2, "metal", .17)]),
        "sword": (0.22, [layer(1300, 320, .23, .003, 3, "noise"), layer(780, 270, .20, .003, 4, "metal")]),
        "bow": (0.26, [layer(240, 120, .24, .004, 4, "metal"), layer(710, 340, .12, .003, 6)]),
        "arrow": (0.25, [layer(1250, 410, .20, .003, 3, "noise"), layer(600, 300, .12, .003, 5, "soft")]),
        "physical_hit": (0.20, [layer(155, 70, .35, .002, 5), layer(650, 170, .20, .001, 7, "noise")]),
        "critical_hit": (0.34, [layer(120, 52, .40, .002, 4), layer(800, 150, .29, .002, 6, "noise"), layer(290, 110, .20, .002, 5, "metal")]),
        "shield": (0.28, [layer(410, 285, .25, .003, 4, "metal"), layer(620, 440, .17, .003, 5, "metal")]),
        "arcane_cast": (0.34, [layer(350, 880, .19, .015, 2, "soft"), layer(510, 1250, .13, .012, 3, "metal")]),
        "magic_projectile": (0.25, [layer(960, 390, .20, .008, 3, "soft"), layer(1250, 540, .10, .005, 4)]),
        "magic_hit": (0.31, [layer(460, 140, .28, .003, 4, "metal"), layer(850, 200, .15, .002, 5, "noise")]),
        "fire_cast": (0.37, [layer(180, 470, .19, .018, 2, "noise"), layer(390, 620, .13, .014, 4, "soft")]),
        "fire_burst": (0.48, [layer(225, 65, .32, .002, 3, "noise"), layer(125, 50, .25, .002, 3), layer(690, 190, .13, .002, 5, "noise")]),
        "curse": (0.52, [layer(510, 165, .21, .022, 2, "metal"), layer(330, 90, .19, .018, 3, "soft")]),
        "heal": (0.57, [layer(520, 680, .19, .025, 2, "soft"), layer(780, 960, .13, .025, 2, "metal", .08)]),
        "holy": (0.52, [layer(392, 392, .16, .019, 2, "soft"), layer(588, 588, .16, .019, 2, "soft"), layer(784, 784, .10, .019, 2, "metal")]),
        "revive": (0.83, [layer(260, 520, .19, .022, 2, "soft"), layer(392, 784, .14, .022, 2, "soft", .12), layer(520, 1040, .10, .018, 2, "metal", .24)]),
        "level_up": (0.72, [layer(392, 392, .18, .01, 2, "metal"), layer(523, 523, .18, .01, 2, "metal", .12), layer(784, 784, .16, .01, 2, "metal", .24)]),
        "card": (0.42, [layer(440, 550, .18, .008, 3, "metal"), layer(660, 880, .15, .009, 3, "soft", .10)]),
        "relic": (0.69, [layer(294, 294, .17, .01, 2, "metal"), layer(440, 440, .17, .01, 2, "metal", .13), layer(740, 740, .14, .01, 2, "metal", .24)]),
        "floor_clear": (0.65, [layer(330, 330, .17, .01, 2, "metal"), layer(440, 440, .17, .01, 2, "metal", .14), layer(660, 660, .14, .01, 2, "metal", .28)]),
        "expedition_start": (0.76, [layer(262, 262, .17, .008, 2, "metal"), layer(392, 392, .17, .008, 2, "metal", .14), layer(523, 523, .16, .008, 2, "metal", .28), layer(784, 784, .10, .008, 2, "soft", .39)]),
        "defeat": (0.95, [layer(392, 330, .16, .018, 2, "metal"), layer(311, 247, .16, .018, 2, "soft", .23), layer(220, 164, .15, .018, 2, "soft", .45)]),
        "final_victory": (1.12, [layer(392, 392, .17, .01, 1.5, "metal"), layer(523, 523, .17, .01, 1.5, "metal", .18), layer(659, 659, .17, .01, 1.5, "metal", .36), layer(784, 784, .16, .01, 1.5, "metal", .54), layer(1047, 1047, .10, .01, 1.7, "soft", .66)]),
    }
    for name, (duration, layers) in presets.items():
        render(name, duration, layers)
    wind()
    print(f"Generated {len(presets) + 1} original WAV files in {OUT}")


if __name__ == "__main__":
    main()
