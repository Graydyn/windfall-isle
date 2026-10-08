"""Flag near-empty outputs: prints each game/art PNG with its opaque coverage."""
import glob
from PIL import Image
for p in sorted(glob.glob("game/art/**/*.png", recursive=True)):
    im = Image.open(p).convert("RGBA")
    a = im.getchannel("A")
    cov = sum(a.histogram()[1:]) / (im.width * im.height)
    flag = "  <-- NEAR EMPTY" if cov < 0.05 else ""
    print(f"{cov:6.1%}  {im.width}x{im.height}  {p}{flag}")
