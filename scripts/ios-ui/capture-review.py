"""Run a real Debug View and capture Simulator pixels; never uses UI tests or writes user data."""
import argparse, subprocess, time
from pathlib import Path
p = argparse.ArgumentParser()
p.add_argument('route'); p.add_argument('output', type=Path)
p.add_argument('--appearance', choices=['light','dark'], default='light')
p.add_argument('--size', default='large')
p.add_argument('--bottom', action='store_true')
p.add_argument('--middle', action='store_true')
p.add_argument('--fixture', action='store_true')
a=p.parse_args()
def sim(*args): subprocess.run(['xcrun','simctl',*args], check=True, stdout=subprocess.DEVNULL)
sim('ui','booted','appearance',a.appearance)
sim('ui','booted','content_size',a.size)
sim('status_bar','booted','override','--time','9:41','--dataNetwork','wifi','--wifiMode','active','--wifiBars','3','--batteryState','charged','--batteryLevel','100')
sim('launch','--terminate-running-process','booted','com.batzz.rocom','--visual-review',a.route,*(['--visual-bottom'] if a.bottom else []),*(['--visual-middle'] if a.middle else []),*(['--visual-fixture'] if a.fixture else []))
time.sleep(3) # Allow real content validation and visible image decoding before capturing pixels.
a.output.parent.mkdir(parents=True, exist_ok=True)
sim('io','booted','screenshot',str(a.output))
print(a.output)
