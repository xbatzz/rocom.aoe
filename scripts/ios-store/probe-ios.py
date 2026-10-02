"""Build/run a headless release Swift 6.4 probe on an already booted iOS 27 Simulator."""
import json
import platform
import subprocess
from pathlib import Path
root = Path(__file__).resolve().parents[2]
out = root/'build/ios-content/store/ios27-probe'
out.mkdir(parents=True, exist_ok=True)
def run(args): subprocess.run([str(x) for x in args], cwd=root, check=True)
sdk = subprocess.check_output(['xcrun','--sdk','iphonesimulator','--show-sdk-path'],text=True).strip()
inventory = json.loads(subprocess.check_output(['xcrun','simctl','list','devices','booted','--json']))
devices = [d for runtime, entries in inventory['devices'].items() if runtime.startswith('com.apple.CoreSimulator.SimRuntime.iOS-27-') for d in entries if d['state']=='Booted']
if not devices: raise SystemExit('Requires a booted iOS 27 Simulator; no P0 app/device changes')
flags = ['xcrun','--sdk','iphonesimulator','swiftc','-O','-parse-as-library','-swift-version','6','-strict-concurrency=complete','-warnings-as-errors','-enable-upcoming-feature','NonisolatedNonsendingByDefault','-target',platform.machine()+'-apple-ios27.0-simulator','-sdk',sdk]
for module,src in [('RocoDomain','RocoCore/Sources/RocoDomain'),('RocoContent','RocoContent/Sources/RocoContent')]:
    run(flags+['-emit-library','-emit-module','-module-name',module,'-emit-module-path',out/(module+'.swiftmodule'),'-I',out,'-L',out]+(['-lRocoDomain'] if module=='RocoContent' else [])+list(sorted((root/'ios/Packages'/src).glob('*.swift')))+['-o',out/('lib'+module+'.dylib')])
run(flags+['-I',out,'-L',out,'-lRocoDomain','-lRocoContent','-Xlinker','-rpath','-Xlinker',out,root/'ios/Packages/RocoContent/Sources/ContentProbe/Probe.swift','-o',out/'content-probe'])
run(['xcrun','simctl','spawn',devices[0]['udid'],out/'content-probe',root/'build/ios-content/store/ContentResources.bundle',root/'build/ios-content/store/ios27-report.json'])
