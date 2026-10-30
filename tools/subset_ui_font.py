"""Rebuild the UI font after adding text; keep the original font untouched."""
from pathlib import Path
import sys
root = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(root / 'work/font-tools'))
from fontTools import subset

characters = set(range(0x20, 0x300)) | set(range(0x2000, 0x2070))
for folder, suffix in [('lib', '*.dart'), ('assets/avatar', '*.js')]:
    for source in (root / folder).rglob(suffix):
        if 'vendor' in source.parts:
            continue
        characters.update(map(ord, source.read_text(encoding='utf-8')))
options = subset.Options()
options.recalc_timestamp = False
font = subset.load_font(str(root / 'assets/fonts/NotoSansSC.ttf'), options)
subsetter = subset.Subsetter(options=options)
subsetter.populate(unicodes=characters)
subsetter.subset(font)
output = root / 'assets/fonts/NotoSansSC-ui.ttf'
subset.save_font(font, str(output), options)
print(f'{output.name}: {output.stat().st_size} bytes')
