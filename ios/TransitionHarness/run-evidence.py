"""Record real system transitions without changing animation speed or adding sleeps."""
from pathlib import Path
import argparse
import json
import shutil
import signal
import subprocess
import time

root = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser()
parser.add_argument('--device', default='25EE507E-F0E7-4FB8-8484-0D7D216800DA')
parser.add_argument('--name', default='recording')
parser.add_argument('--only', nargs='+', help='XCTest method names')
args = parser.parse_args()
output = root / 'build/ios27-p0/transition-harness' / args.name
output.mkdir(parents=True, exist_ok=False)
base = ['xcodebuild', '-project', str(root / 'ios/TransitionHarness/TransitionHarness.xcodeproj'), '-scheme', 'TransitionHarness', '-destination', f'platform=iOS Simulator,id={args.device}', '-derivedDataPath', str(root / 'build/ios27-p0/harness'), '-parallel-testing-enabled', 'NO', '-collect-test-diagnostics', 'never', 'CODE_SIGNING_ALLOWED=NO']
with (output / 'build.log').open('w') as log:
    subprocess.run(base + ['build-for-testing'], stdout=log, stderr=subprocess.STDOUT, check=True)
capture = subprocess.Popen(['xcrun', 'simctl', 'io', args.device, 'recordVideo', '--codec=h264', '--force', str(output / 'screen.mov')], stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
metadata = {'beforeCapture': time.monotonic(), 'device': args.device, 'only': args.only}
metadata['beforeCaptureEpoch'] = time.time()
capture_lines = []
while True:
    line = capture.stderr.readline()
    capture_lines.append(line)
    if 'Recording started' in line:
        metadata['recordingStarted'] = time.monotonic()
        metadata['recordingStartedEpoch'] = time.time()
        break
    if capture.poll() is not None: raise RuntimeError('Recording failed: ' + ''.join(capture_lines))
command = base + ['-resultBundlePath', str(output / 'tests.xcresult'), 'test-without-building']
for method in args.only or []: command.append('-only-testing:TransitionHarnessUITests/ExperimentTests/' + method)
try:
    with (output / 'tests.log').open('w') as log:
        result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT)
    metadata['testExit'] = result.returncode
finally:
    capture.send_signal(signal.SIGINT)
    _, stderr = capture.communicate(timeout=30)
    (output / 'capture.log').write_text(''.join(capture_lines) + stderr)
    metadata['captureExit'] = capture.returncode
    metadata['ended'] = time.monotonic()
    (output / 'recording.json').write_text(json.dumps(metadata, indent=2))
container = subprocess.check_output(['xcrun', 'simctl', 'get_app_container', args.device, 'top.aoe.rocom.transition-harness', 'data'], text=True).strip()
methods = {'testAImage': 'A-image', 'testAEqual': 'A-equal', 'testAClear': 'A-clear-source', 'testBParity': 'B-parity', 'testBClear': 'B-clear-hero', 'testBTransparent': 'B-explicit-transparent', 'testBHeroMarker': 'B-hero-magenta', 'testBPageMarker': 'B-page-green', 'testBNoAlignment': 'B-no-alignment', 'testCContainer': 'C-black-container', 'testCBlackConfiguration': 'C-black-source-config'}
(output / 'probes').mkdir()
for method in args.only or methods:
    folder = Path(container) / 'Documents' / methods[method]
    if folder.exists(): shutil.copytree(folder, output / 'probes' / folder.name)
print(json.dumps({'output': str(output), **metadata}, indent=2), flush=True)
raise SystemExit(result.returncode)
