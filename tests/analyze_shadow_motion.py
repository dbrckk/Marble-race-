"""Measure acceleration of the image-space shadow signal on matched paths."""
from pathlib import Path
from PIL import Image
from statistics import median
import json
import numpy as np
import sys

root = Path(sys.argv[1])
rows = [json.loads(line) for line in (root / "shadow-motion.jsonl").read_text().splitlines()]
keys = sorted({(row["layout"], row["section"]) for row in rows})
values = []

def luminance(layout, section, mode):
    samples = []
    for png in sorted(root.glob(f"l{layout}-s{section}-{mode}-*.png")):
        im = Image.open(png).convert("RGB")
        x, y = im.size
        crop = im.crop((round(x*.18), round(y*.27), round(x*.82), round(y*.83)))
        rgb = np.asarray(crop, dtype=np.float32)
        samples.append(rgb @ [0.2126,0.7152,0.0722])
    return np.asarray(samples)

for layout, section in keys:
    reference = luminance(layout, section, "unshadowed")
    if len(reference) < 12:
        continue
    levels = {}
    for mode in ("double", "single"):
        shade = reference - luminance(layout, section, mode)
        accel = np.abs(np.diff(shade,n=2,axis=0))
        calls = next(r["draw_calls"] for r in rows if (r["layout"],r["section"],r["mode"])==(layout,section,mode))
        levels[mode] = {
            "temporal_mean": float(np.mean(accel)),
            "strong_delta_fraction": float(np.mean(accel>12.0)),
            "median_draws": median(calls),
            "mean_darkening": float(np.mean(np.maximum(shade,0.0))),
        }
    values.append({"layout":layout,"section":section,**levels})
    print(layout,section,*(f"{mode}: {result['temporal_mean']:.3f} / {result['strong_delta_fraction']:.2%} / {result['median_draws']}" for mode,result in levels.items()))

if len(values)==9:
    for mode in ("double","single"):
        print(mode, "median variation", median(v[mode]["temporal_mean"] for v in values))
    if len(sys.argv)>2:
        Path(sys.argv[2]).write_text(json.dumps(values,indent=2)+"\n")
