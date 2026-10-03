"""Materialize only audited, Web-used semantic icons. Does not touch canonical data."""
from pathlib import Path
from PIL import Image
import re, json, hashlib, shutil
root = Path(__file__).resolve().parents[2]
out = root / 'ios/RocoNative/Resources/GameIcons'
out.mkdir(parents=True, exist_ok=True)
source = root / 'src/assets/Species.png'
atlas = Image.open(source)
assert atlas.size == (512, 256)
items = re.findall(r'row: (\d+), column: (\d+), typeId: (\d+), label: "([^"]+)"', (root/'src/lib/typeIcons.ts').read_text())
assert len(items) == 18 and {int(i[2]) for i in items} == set(range(1,19))
entries = []
for row, col, type_id, label in items:
    x, y = int(col)*56+3, int(row)*58+2
    name = f'type-{type_id}.png'
    atlas.crop((x, y, x+52, y+54)).save(out/name)
    entries.append(dict(typeID=int(type_id), name=label, file=name))
for name in ['leader-crown', 'collected-check']:
    shutil.copyfile(root/f'src/assets/game-ui/{name}.png', out/f'{name}.png')
(out/'provenance.json').write_text(json.dumps(dict(atlas='src/assets/Species.png', sha256=hashlib.sha256(source.read_bytes()).hexdigest(), mapping='src/lib/typeIcons.ts', types=entries, statusSources=['src/assets/game-ui/leader-crown.png','src/assets/game-ui/collected-check.png']), ensure_ascii=False, indent=2)+'\n')
print(f'Materialized {len(entries)} type icons and 2 semantic status icons')
