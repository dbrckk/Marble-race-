from pathlib import Path
from tempfile import TemporaryDirectory
import subprocess
import wave
import numpy as np
import imageio_ffmpeg

ROOT = Path(__file__).resolve().parents[1]
RATE = 32000
OUT = ROOT / "assets" / "audio" / "sfx"
OUT.mkdir(parents=True, exist_ok=True)
rng = np.random.default_rng(604198)

def metal_hit(index: int) -> np.ndarray:
    duration = 0.39 if index == 0 else 0.56
    t = np.arange(int(RATE * duration), dtype=np.float32) / RATE
    f = 415.0 if index == 0 else 310.0
    ratios = [1.0, 2.01, 2.58, 4.30]
    amps = [0.36, 0.24, 0.14, 0.085]
    out = np.zeros_like(t)
    for i, (ratio, amp) in enumerate(zip(ratios, amps)):
        decay = np.exp(-t * (9 + i * 5))
        out += np.sin(2.0 * np.pi * f * ratio * t) * amp * decay
    transient = rng.normal(0, 1, len(t)).astype(np.float32)
    out += transient * np.exp(-t * 95.0) * 0.18
    out *= np.minimum(t * 350.0, 1.0)
    return np.clip(out * 0.56, -0.95, 0.95)

def save_ogg(samples: np.ndarray, dest: Path) -> None:
    with TemporaryDirectory() as d:
        source = Path(d) / "hit.wav"
        with wave.open(str(source), "wb") as wf:
            wf.setnchannels(1)
            wf.setsampwidth(2)
            wf.setframerate(RATE)
            wf.writeframes((samples * 32767).astype("<i2").tobytes())
        subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(), "-hide_banner", "-loglevel", "error", "-y",
                        "-i", str(source), "-c:a", "libvorbis", "-q:a", "4", str(dest)], check=True)

for i in range(2):
    dest = OUT / ("metal_hit_%d.ogg" % (i + 1))
    save_ogg(metal_hit(i), dest)
    print(dest.relative_to(ROOT), dest.stat().st_size)
