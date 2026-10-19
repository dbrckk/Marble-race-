#!/usr/bin/env python3
"""Two compact, original peg/bumper Foley samples synthesized offline (no external IP)."""
from pathlib import Path
import subprocess, tempfile, wave
import numpy as np
import imageio_ffmpeg

ROOT=Path(__file__).resolve().parents[1]
DEST=ROOT/"assets/audio/sfx"
DEST.mkdir(parents=True,exist_ok=True)
SR=32000
RNG=np.random.default_rng(8071)

def write(name: str, intensity: float) -> None:
    dur=0.27 if intensity<0.7 else 0.43
    t=np.arange(int(SR*dur),dtype=np.float64)/SR
    # Damped silicone shell: partials move a little as the surface rebounds.
    fundamental=115.0+intensity*40.0
    phase=2.0*np.pi*(fundamental*t+29.0*np.exp(-t*29.0)*t)
    rubber=(np.sin(phase)*0.78+np.sin(phase*1.65)*0.21+np.sin(phase*2.37)*0.07)
    impact=RNG.normal(0,1,len(t))
    # Roughness limited to the first 35ms; the tail stays rounded.
    strike=impact*np.exp(-t*93.0)*0.19
    envelope=(1-np.exp(-t*340.0))*np.exp(-t*(16.0-6.0*intensity))
    wav_out=np.clip((rubber*envelope + strike)*(0.32+intensity*0.18),-0.93,0.93)
    with tempfile.TemporaryDirectory() as temp:
        source=Path(temp)/"source.wav"
        with wave.open(str(source),"wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes((wav_out*32767).astype("<i2").tobytes())
        subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(),"-hide_banner","-loglevel","error",
                        "-y","-i",str(source),"-c:a","libvorbis","-q:a","4",
                        str(DEST/name)],check=True)
    print(name,(DEST/name).stat().st_size)

if __name__=="__main__":
    write("bumper_soft.ogg",0.25)
    write("bumper_hard.ogg",1.0)
