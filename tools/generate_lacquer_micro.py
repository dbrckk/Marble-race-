#!/usr/bin/env python3
"""Generate a repeatable 256px painted polymer microstructure texture.
Pack fine pigment grain / sparse mineral flecks / roughness noise in RGB."""
from pathlib import Path
import numpy as np
from PIL import Image

DEST = Path(__file__).resolve().parents[1] / "assets/textures/lacquer_micro.png"
DEST.parent.mkdir(parents=True,exist_ok=True)
rng=np.random.default_rng(20061019)
size=256
y,x=np.mgrid[:size,:size]
fiber = (np.sin(x*2.1+np.sin(y*.035)*.8)*0.16+
         np.sin(x*.22+y*.025)*0.08)
noise=rng.normal(0,0.11,(size,size))
granular=np.clip(.50+fiber+noise,0,1)
flecks=np.where(rng.random((size,size))>.987,1.0,.40+rng.normal(0,.08,(size,size)))
roughness=np.clip(.52+rng.normal(0,.16,(size,size))+np.sin(x*.11+y*.08)*.055,.0,1)
pixel=np.stack([granular,flecks,roughness],axis=2)
Image.fromarray(np.clip(pixel*255,0,255).astype('uint8'),'RGB').save(DEST,optimize=True)
print(DEST,DEST.stat().st_size)
