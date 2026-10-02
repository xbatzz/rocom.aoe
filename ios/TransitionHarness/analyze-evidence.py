"""Decode native video frames, retain their PTS, and measure transparent corner pixels.

Never interpolate or duplicate video frames. Public screen recording is the visual
evidence; display-link view properties are complementary, not a snapshot of pixels.
"""
from pathlib import Path
import argparse
import ctypes
import json
import time
import cv2
import numpy as np
from PIL import Image, ImageDraw

parser = argparse.ArgumentParser()
parser.add_argument('recording', type=Path)
parser.add_argument('--output', type=Path)
args = parser.parse_args()
out = args.output or args.recording / 'analysis'
out.mkdir(parents=True, exist_ok=True)
metadata = json.loads((args.recording / 'recording.json').read_text())
lib = ctypes.CDLL('/usr/lib/libSystem.B.dylib')
lib.mach_absolute_time.restype = ctypes.c_uint64
class Timebase(ctypes.Structure):
    _fields_ = [('numer', ctypes.c_uint32), ('denom', ctypes.c_uint32)]
tb = Timebase(); lib.mach_timebase_info(ctypes.byref(tb))
offset = time.time() - lib.mach_absolute_time() * tb.numer / tb.denom / 1e9
record_epoch = metadata.get('recordingStartedEpoch', (args.recording / 'screen.mov').stat().st_birthtime)
intervals = []
summary = {'video': str(args.recording / 'screen.mov'), 'recordingEpochApproximation': record_epoch, 'syncNote': 'Recorder acknowledgement / file creation is approximate; visual late-frame adjacency uses original PTS, independent of event offset.', 'variants': {}}
for path in sorted((args.recording / 'probes').glob('*/trace.json')):
    records = json.loads(path.read_text())
    variant = path.parent.name
    start = next((r for r in records if 'epoch' in r), None)
    if start and start['epoch'] < record_epoch - 1: continue
    epoch_offset = start['epoch'] - start['time'] if start else offset
    events = [r for r in records if r['kind'] != 'frame']
    # Grid onAppear is a beginning-of-return event in SwiftUI, not completion.
    bridge = variant.startswith('B') or variant == 'C-black-container'
    begins = [r for r in events if r['kind'] == 'will-grid'][1:] if bridge else [r for r in events if r['kind'] == 'grid-appear'][1:]
    ends = [r for r in events if r['kind'] == 'did-grid'][1:] if bridge else [r for r in events if r['kind'] == 'detail-disappear']
    info = {'displayLinkFrames': sum(r['kind'] == 'frame' for r in records), 'cycles': [], 'alphaProbes': {}}
    for png in sorted(path.parent.glob('*.png')):
        im = Image.open(png).convert('RGBA'); alpha = np.asarray(im)[:, :, 3]
        info['alphaProbes'][png.name] = {'size': list(im.size), 'cornerRGBA': list(im.getpixel((0, 0))), 'alphaMin': int(alpha.min()), 'alphaMax': int(alpha.max()), 'transparentPixels': int((alpha == 0).sum())}
    for cycle, (begin, end) in enumerate(zip(begins, ends)):
        begin_pts = begin['time'] + epoch_offset - record_epoch
        end_pts = end['time'] + epoch_offset - record_epoch
        item = {'cycle': cycle, 'beginEventPTS': begin_pts, 'endEventPTS': end_pts, 'frames': []}
        info['cycles'].append(item)
        intervals.append((begin_pts - 0.25, end_pts + 0.35, variant, item))
    summary['variants'][variant] = info

cap = cv2.VideoCapture(str(args.recording / 'screen.mov'))
frame_index = 0
kept = {}
while True:
    ok, frame = cap.read()
    if not ok: break
    pts = cap.get(cv2.CAP_PROP_POS_MSEC) / 1000
    matches = [i for i in intervals if i[0] <= pts <= i[1]]
    if matches:
        rgb = cv2.cvtColor(cv2.resize(frame, (402, 874), interpolation=cv2.INTER_AREA), cv2.COLOR_BGR2RGB)
        for _, _, variant, item in matches:
            # A fixed clear-alpha corner in the final image square, inside the grey cell.
            corner = rgb[255:261, 50:56].mean(axis=(0, 1)).round(2).tolist()
            cell_edge = rgb[270:276, 35:40].mean(axis=(0, 1)).round(2).tolist()
            # Sprite-colored components, excluding pure page-marker green.
            mask = ((rgb[:, :, 1].astype(float) > rgb[:, :, 0] * 1.12) & (rgb[:, :, 1].astype(float) > rgb[:, :, 2] * 1.12) & (rgb[:, :, 0] > 20) & (rgb[:, :, 1] > 55)).astype('uint8')
            mask[:70] = 0; mask[500:] = 0
            n, labels, stats, centers = cv2.connectedComponentsWithStats(mask)
            blobs = [list(map(int, s[:5])) for s in stats[1:] if s[4] > 100]
            measurement = {'index': frame_index, 'pts': pts, 'transparentCornerRGB': corner, 'cellEdgeRGB': cell_edge, 'greenComponents': blobs}
            item['frames'].append(measurement)
            if item['cycle'] == 0:
                key = variant, frame_index
                kept[key] = rgb
                folder = out / variant / 'frames'
                folder.mkdir(parents=True, exist_ok=True)
                Image.fromarray(rgb).save(folder / f'{frame_index:06d}.png')
    frame_index += 1
cap.release()
summary['decodedFrames'] = frame_index
for variant, info in summary['variants'].items():
    for cycle in info['cycles']:
        frames = cycle['frames']
        black = [f for f in frames if max(f['transparentCornerRGB']) < 12]
        gray = [f for f in frames if min(f['transparentCornerRGB']) > 35 and max(f['transparentCornerRGB']) < 58]
        jumps = [(a, b) for a, b in zip(frames, frames[1:]) if max(a['transparentCornerRGB']) < 12 and min(b['transparentCornerRGB']) > 35 and max(b['transparentCornerRGB']) < 58]
        cycle['blackFramesAtCorner'] = len(black)
        cycle['grayFramesAtCorner'] = len(gray)
        cycle['blackToGrayAdjacentFrames'] = [{'before': a, 'after': b, 'deltaSeconds': b['pts'] - a['pts']} for a, b in jumps]
        if cycle['cycle'] != 0 or not frames: continue
        indices = list(range(0, len(frames), 3))
        # Include EVERY recorded late frame around the colour discontinuity.
        if jumps:
            j = frames.index(jumps[-1][0]); indices += list(range(max(0, j - 5), min(len(frames), j + 5)))
        indices = sorted(set(indices))
        tiles = []
        for index in indices:
            f = frames[index]; rgb = kept[variant, f['index']]
            tile = Image.new('RGB', (201, 210), '#171717')
            tile.paste(Image.fromarray(rgb).crop((0, 90, 402, 450)).resize((201, 180)), (0, 25))
            ImageDraw.Draw(tile).text((4, 4), f"#{f['index']}  {f['pts']:.3f}s", fill='white')
            tiles.append(tile)
        sheet = Image.new('RGB', (201 * 6, 210 * ((len(tiles) + 5) // 6)), '#171717')
        for index, tile in enumerate(tiles): sheet.paste(tile, ((index % 6) * 201, (index // 6) * 210))
        sheet.save(out / f'{variant}-return.jpg', quality=94)
(out / 'measurements.json').write_text(json.dumps(summary, indent=2))
print(json.dumps({v: [{'cycle': c['cycle'], 'frames': len(c['frames']), 'jumps': [(j['before']['index'], j['after']['index'], j['deltaSeconds']) for j in c['blackToGrayAdjacentFrames']]} for c in d['cycles']] for v, d in summary['variants'].items()}, indent=2))
