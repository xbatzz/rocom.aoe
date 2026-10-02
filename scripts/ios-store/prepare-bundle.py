"""Stage the frozen packages into an isolated resource Bundle; never regenerate content."""
import json
import shutil
import plistlib
from pathlib import Path
root = Path(__file__).resolve().parents[2]
bundle = root / 'build/ios-content/store/ContentResources.bundle'
if bundle.exists(): shutil.rmtree(bundle)
bundle.mkdir(parents=True)
(bundle/'Info.plist').write_bytes(plistlib.dumps({'CFBundleIdentifier':'top.aoe.rocom.content-verification','CFBundleName':'ContentResources','CFBundlePackageType':'BNDL'}))
for src,dst in [('v2/current','canonical'),('assets/current','assets')]:
    shutil.copytree(root/'build/ios-content'/src, bundle/'Content'/dst)
print(bundle)
