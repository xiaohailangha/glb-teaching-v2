from PIL import Image
from pathlib import Path
root=Path(__file__).resolve().parent.parent
src=root/'source-models/snow-source/Snow/textures'
out=root/'work/textures'
out.mkdir(parents=True,exist_ok=True)
atlas=Image.new('RGB',(3072,1024))
for i in range(3):
    im=Image.open(src/f'skin_diffuse.{1001+i}.png').convert('RGB').resize((1024,1024),Image.Resampling.LANCZOS)
    atlas.paste(im,(1024*i,0))
atlas.save(out/'skin_atlas.jpg',quality=90)
for name in ['hair_diffuse','eyes_diffuse','shirt_diffuse','pants_diffuse','shoes_diffuse']:
    im=Image.open(src/f'{name}.png').convert('RGB')
    im.thumbnail((1024,1024),Image.Resampling.LANCZOS)
    im.save(out/f'{name}.jpg',quality=90)
print(out)
