"""Bundle Chinese UI and IPA glyph coverage; no browser font CDN dependency."""
from pathlib import Path
import os
import sys
root = Path(__file__).resolve().parent.parent
tools_root = Path(os.environ.get('SNOW_FLUTTER_TOOLS') or Path(root.anchor) / 'sdk' / 'snow-speaks')
sys.path.insert(0, str(tools_root / 'font-tools'))
from fontTools import subset
from fontTools.ttLib import TTFont

characters = set(range(32, 256))
for folder, pattern in [('scene-preview/lib', '*.dart'), ('../server/data/legacy-course-assets/courses', '*.json'), ('../server/data/curriculum', '*.json')]:
    for source in (root / folder).rglob(pattern):
        characters.update(map(ord, source.read_text(encoding='utf-8-sig')))
font = subset.load_font(str(root / 'assets/fonts/NotoSansSC.ttf'), subset.Options())
subsetter = subset.Subsetter()
subsetter.populate(unicodes=characters)
subsetter.subset(font)
font.save(str(root / 'scene-preview/assets/fonts/NotoSansSC-ui.ttf'))
ipa_font = TTFont(tools_root / 'NotoSans-full.ttf')
ipa_subset = subset.Subsetter()
ipa_subset.populate(unicodes=set(range(32, 0x400)) | set(range(0x1D00, 0x1D80)) | set(range(0x2000, 0x2070)))
ipa_subset.subset(ipa_font)
ipa_font.save(str(root / 'scene-preview/assets/fonts/NotoSans-IPA.ttf'))
ipa = ipa_font.getBestCmap()
missing = [c for c in 'æəˈːɪʊʌɔɡθŋɑɒɜɹɚ' if ord(c) not in ipa]
assert not missing, f'Missing IPA codepoints: {[ord(c) for c in missing]}'
print('Scene Chinese font rebuilt; IPA coverage passed.')
