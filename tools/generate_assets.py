#!/usr/bin/env python3
"""Deterministic original oak maps and ambient/sound-score assets.
Requires numpy, Pillow, imageio-ffmpeg. Never downloads copyrighted media.
"""
from pathlib import Path
import tempfile, wave, subprocess
import numpy as np
from PIL import Image
import imageio_ffmpeg

ROOT=Path(__file__).resolve().parents[1]
TEX=ROOT/"assets/textures"
MUSIC=ROOT/"assets/audio/music"
TEX.mkdir(parents=True,exist_ok=True)
MUSIC.mkdir(parents=True,exist_ok=True)
rng=np.random.default_rng(35731)

# Repeatable longitudinal grain with irregular concentric growth rings,
# tiny pores, knots and soft fiber dispersion.
w,h=512,1024
X,Y=np.meshgrid(np.linspace(0,1,w,endpoint=False),np.linspace(0,1,h,endpoint=False))
turb=np.zeros((h,w),np.float32)
for amp, sx,sy in [(0.030,9,3),(0.015,26,5),(0.007,72,11),(0.004,175,15)]:
    ph=float(rng.uniform(-3,3))
    turb += amp*np.sin(X*sx+np.sin(Y*sy+ph)*2.1+ph)
wood_ring=X*31 + turb*20 + 0.8*np.sin(Y*2.8+X*9)
v=np.sin(wood_ring)+0.28*np.sin(wood_ring*2.35)+0.14*np.sin(wood_ring*5.4)
for cx,cy,rx,ry in [(0.29,0.21,0.065,0.12),(0.73,0.77,0.043,0.065)]:
    radial=np.sqrt(((X-cx)/rx)**2+((Y-cy)/ry)**2)
    mod=np.exp(-radial**2*0.7)
    v+=mod*np.sin(radial*8.7)*0.34
grain_noise=rng.normal(0,0.032,(h,w))
tiny_pores=np.abs(np.sin(X*1570 + np.sin(Y*12)*8))*0.022
value=np.clip(0.79 + v*0.086 + grain_noise + tiny_pores,0,1)
base=np.array([226,171,111],np.float32)
rgb=np.clip(base[None,None,:]*value[:,:,None],0,255).astype(np.uint8)
Image.fromarray(rgb,"RGB").save(TEX/"oak_albedo.png",optimize=True)
# Fine normal map: 2D gradients of real generated growth-ring height.
gy,gx=np.gradient(value)
normal=np.stack((-gx*2.4,-gy*1.25,np.ones_like(gx)),axis=2)
normal/=np.linalg.norm(normal,axis=2,keepdims=True)
normal_rgb=np.clip((normal*0.5+0.5)*255,0,255).astype(np.uint8)
Image.fromarray(normal_rgb,"RGB").save(TEX/"oak_normal.png",optimize=True)


sr=32000
beat=60/112
bars=12
duration=bars*4*beat
n=int(duration*sr)
audio=np.zeros(n,np.float32)
def note(midi):
    return 440*2**((midi-69)/12)
def add(start, duration_s, freq, volume, timbre="mallet"):
    begin=int(start*sr); count=max(1,min(int(duration_s*sr),n-begin))
    if count<=0:return
    t=np.arange(count,dtype=np.float32)/sr
    if timbre=="mallet":
        tone=(np.sin(2*np.pi*freq*t)*0.7+np.sin(2*np.pi*freq*2.01*t)*0.21
              +np.sin(2*np.pi*freq*3.999*t)*0.07)
        env=np.exp(-4.0*t/max(duration_s,0.1))*(1-np.exp(-75*t))
    elif timbre=="bass":
        tone=np.sin(2*np.pi*freq*t)+0.20*np.sin(2*np.pi*freq*2*t)
        env=np.minimum(1,t*45)*np.clip((duration_s-t)/0.07,0,1)**1.6
    else:
        tone=(np.sin(2*np.pi*freq*t)+0.33*np.sin(2*np.pi*freq*1.999*t))
        env=np.sin(np.pi*np.clip(t/duration_s,0,1))**0.65
    audio[begin:begin+count] += tone*env*volume

# Quiet evolving toy-shop marimba + Rhodes-esque harmonies.
chords=[[57,60,64,67],[53,57,60,64],[55,59,62,67],[52,55,60,64]]
for bar in range(bars):
    chord=chords[bar%4]
    sec=bar*4*beat
    root=chord[0]-24
    add(sec,3.9*beat,note(root),0.095,"bass")
    add(sec+2*beat,1.7*beat,note(root+7),0.05,"bass")
    for degree in range(4):
        add(sec,3.15*beat,note(chord[degree]),0.024,"pad")
    for ix in range(8):
        step=[0,1,2,3,2,1,3,1][(ix+bar)%8]
        add(sec+ix*.5*beat,0.39*beat,note(chord[step]+12),0.044 if ix%2==0 else 0.028)
# Glimmering percussion, noise filtered by smoothed differences.
for k in range(int(duration/beat)):
    when=k*beat
    p=int(when*sr)
    length=int(.09*sr)
    time=np.arange(length)/sr
    kick=(np.sin(2*np.pi*(64-36*time)*time)*np.exp(-time*34)*0.12)
    audio[p:p+length]+=kick
    if k%2:
        l=int(.055*sr)
        noise=rng.normal(0,1,l)
        sm=np.diff(noise,prepend=0)
        audio[p:p+l] += np.clip(sm,-3,3)*np.exp(-np.arange(l)/sr*57)*0.017

# Gentle tape-style echo and circular crossfade for seamless looping.
delay=int(.29*sr)
audio[delay:]+=audio[:-delay]*0.105
fade=int(.5*sr)
audio[:fade]=audio[:fade]*np.linspace(0,1,fade)+audio[-fade:]*np.linspace(1,0,fade)*0.65
audio*=0.80/max(float(np.max(np.abs(audio))),1e-6)
def ogg(arr, path, quality=5):
    arr=np.clip(arr,-1,1)
    with tempfile.TemporaryDirectory() as tmp:
        source=Path(tmp)/"audio.wav"
        with wave.open(str(source),"wb") as f:
            f.setnchannels(1);f.setsampwidth(2);f.setframerate(sr)
            f.writeframes((arr*32767).astype("<i2").tobytes())
        subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(),'-hide_banner','-loglevel','error','-y',
                        '-i',str(source),'-c:a','libvorbis','-q:a',str(quality),str(path)],check=True)

ogg(audio,MUSIC/"marble_workshop.ogg")
# Loop under the rolling billiards; granular texture smoothed for unobtrusive movement.
seconds=3.0
T=np.arange(int(sr*seconds),dtype=np.float32)/sr
white=rng.normal(0,1,T.size).astype(np.float32)
smooth=np.convolve(white,np.ones(43)/43,mode="same")
rolling=(smooth*0.16 + (white-np.convolve(white,np.ones(5)/5,mode="same"))*0.006)
rolling*=0.65
cross=int(sr*.2)
rolling[:cross]=rolling[:cross]*np.linspace(0,1,cross)+rolling[-cross:]*np.linspace(1,0,cross)
ogg(rolling,ROOT/"assets/audio/sfx/wood_roll.ogg",quality=3)
for name, pitch, duration_s in [("start",660,.27),("checkpoint",1000,.42),("finish",880,1.8),
                                ("boost",230,.45),("count",440,.17)]:
    t=np.arange(int(sr*duration_s))/sr
    phase=2*np.pi*(pitch*t+(70 if name=="boost" else 0)*t**2)
    tone=np.sin(phase)*0.72+np.sin(phase*1.502)*0.18
    if name=="finish":tone+=np.sin(phase*.75)*.35
    env=np.exp(-t/(duration_s*.35))*np.minimum(t*95,1)
    ogg((tone*env*.38).astype(np.float32), ROOT/("assets/audio/sfx/"+name+".ogg"),4)
print("Generated original procedural PBR-albedo and six original audio assets")
