#!/usr/bin/env python3
"""Generate original Marble Race adaptive-friendly launcher icon; Pillow only."""
from pathlib import Path
import math, random
from PIL import Image, ImageDraw, ImageFilter
OUT=Path(__file__).resolve().parents[1]/"assets/textures"
OUT.mkdir(parents=True,exist_ok=True)
S=1024
im=Image.new("RGB",(S,S),(18,20,31))
pix=im.load()
for y in range(S):
 for x in range(S):
  dx=(x-505)/710;dy=(y-490)/710
  fall=max(0,1-(dx*dx+dy*dy))
  pix[x,y]=(int(18+20*fall),int(22+20*fall),int(34+14*fall))
d=ImageDraw.Draw(im)
# Perspective miniature wooden racing lane.
d.polygon([(60,804),(540,585),(930,788),(900,990),(70,990)],fill=(99,57,35))
for i in range(7):
 a=80+i*126
 d.line([(a,996),(510+(a-430)*0.38,603)],fill=(155,99,58),width=13)
 d.line([(a+5,996),(510+(a-430)*0.38+5,603)],fill=(48,32,29),width=4)
# Gold ring halo and shadow.
shadow=Image.new("RGBA",(S,S),(0,0,0,0))
sh=ImageDraw.Draw(shadow)
sh.ellipse((179,122,850,789),fill=(0,0,0,165))
shadow=shadow.filter(ImageFilter.GaussianBlur(42))
im=Image.alpha_composite(im.convert("RGBA"),shadow)
d=ImageDraw.Draw(im)
center=(505,454);radius=329
d.ellipse((170,116,842,788),fill=(213,144,76),outline=(250,192,112),width=18)
# Glazed copper glass marble with blue agate swirls.
for y in range(center[1]-radius,center[1]+radius):
 for x in range(center[0]-radius,center[0]+radius):
  dx=(x-center[0])/radius;dy=(y-center[1])/radius
  q=dx*dx+dy*dy
  if q>=0.99:continue
  z=math.sqrt(max(0,1-q))
  swirl=math.sin(dy*17.5 + dx*7.8 + math.sin(dx*12+dy*4.3)*1.7)
  band=max(0,min(1,(swirl+0.3)/1.35))
  shade=max(.23,.44+z*.56+(-dx*.34-dy*.25))
  highlight=max(0,1-((dx+.35)**2+ (dy+.36)**2)*10.0)**5
  a=(213,109,54);b=(46,174,191)
  col=[int(max(0,min(255,(a[i]*(1-band)+b[i]*band)*shade+highlight*120))) for i in range(3)]
  im.putpixel((x,y),tuple(col)+(255,))
d=ImageDraw.Draw(im)
d.arc((218,162,788,730),195,265,fill=(255,228,184),width=19)
d.ellipse((280,203,411,285),fill=(255,238,208,178))
d.ellipse((680,578,706,602),fill=(251,236,217,172))
# Edge/track foreground emblem without small text.
d.arc((166,116,847,790),200,330,fill=(253,211,147),width=15)
im=im.convert("RGB").resize((512,512),Image.Resampling.LANCZOS)
im.save(OUT/"icon.png",optimize=True)
print("icon",OUT/"icon.png")
