#!/usr/bin/env python3
"""Procedural race audio, wholly original and reproducible with seed."""
from pathlib import Path
import numpy as np
import wave, tempfile, subprocess, imageio_ffmpeg
root=Path(__file__).resolve().parents[1]
out=root/"assets/audio"
sr=32000
rng=np.random.default_rng(20261019)
ff=imageio_ffmpeg.get_ffmpeg_exe()
def save(audio,path):
    audio=np.nan_to_num(audio)
    audio=np.clip(audio,-.95,.95)
    with tempfile.TemporaryDirectory() as d:
        source=Path(d)/"audio.wav"
        with wave.open(str(source),"wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(sr)
            w.writeframes((audio*32767).astype("<i2").tobytes())
        subprocess.run([ff,"-loglevel","error","-y","-i",str(source),"-c:a","libvorbis","-q:a","4",str(path)],check=True)
def fade_loop(a,seconds=.10):
    n=int(sr*seconds)
    a[:n]=a[:n]*np.linspace(0,1,n)+a[-n:]*np.linspace(1,0,n)
    return a
# 5.6s stereo-esque mono filtered wood/wind movement loop.
T=np.arange(int(sr*5.6))/sr
noise=rng.normal(0,1,len(T))
kernel=np.ones(13)/13
smooth=np.convolve(noise,kernel,"same")
high=noise-np.convolve(noise,np.ones(4)/4,"same")
amb=(smooth*.095+high*.009)*(0.78+0.22*np.sin(2*np.pi*0.4*T))
amb+=np.sin(2*np.pi*(85*T + 15*np.sin(T*0.9)))*.014
save(fade_loop(amb),out/"sfx/airrush.ogg")
# Bright toy glockenspiel fanfare, a sound for the finish line.
duration=2.1;T=np.arange(int(sr*duration))/sr
fanfare=np.zeros(len(T))
for i,(pitch,time) in enumerate([(659.25,0),(783.99,.19),(987.77,.38),(1318.5,.64),(1567.98,.95)]):
    st=int(time*sr);length=len(T)-st
    t=np.arange(length)/sr
    env=(1-np.exp(-t*95))*np.exp(-t*2.8)
    fanfare[st:]+=env*(np.sin(2*np.pi*pitch*t)+.22*np.sin(2*np.pi*pitch*2.01*t))*.105
save(fanfare,out/"sfx/fanfare.ogg")
# rhythmic percussion for music dynamic stem, exact 12 bars @112 BPM
beat=60/112
seconds=12*4*beat
arr=np.zeros(int(sr*seconds))
for k in range(12*8):
    start=k*beat*.5
    i=int(start*sr)
    m=min(int(sr*.12),len(arr)-i)
    if m<=0:continue
    t=np.arange(m)/sr
    noise=rng.normal(0,1,m)
    pulse=noise*.021*(np.exp(-t*(66 if k%2 else 28)))
    if k%2==0: pulse+=np.sin(2*np.pi*(70-45*t)*t)*np.exp(-t*27)*.078
    if k%4==2: pulse+=np.sin(2*np.pi*330*t)*np.exp(-t*34)*.025
    arr[i:i+m]+=pulse
save(fade_loop(arr),out/"music/pace_percussion.ogg")
print("Original adaptive audio created",[(p.name,p.stat().st_size) for p in [out/"sfx/airrush.ogg",out/"sfx/fanfare.ogg",out/"music/pace_percussion.ogg"]])

# Clockwork toy spinner: brushed gear whirr and soft regularly spaced pawl clicks.
t = np.arange(int(sr*2.0),dtype=np.float32)/sr
gear = (np.sin(2*np.pi*77*t)*.038 +
        np.sin(2*np.pi*154*t + np.sin(2*np.pi*7*t)*.2)*.024 +
        np.sin(2*np.pi*310*t)*.008)
gear *= 0.65 + 0.25 * np.sin(2*np.pi*4*t)**2
for k in range(8):
    at=int(sr*k*0.25)
    n=min(int(sr*.045), len(gear)-at)
    at_t=np.arange(n)/sr
    click=rng.normal(0,1,n)*np.exp(-at_t*97)*.017
    gear[at:at+n] += click
save(fade_loop(gear),out/"sfx/mechanism_loop.ogg")
