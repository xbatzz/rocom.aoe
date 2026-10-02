"""Independent P0 experiment. Never regenerates or edits RocoNative."""
from pathlib import Path
import hashlib

root = Path(__file__).resolve().parent
project = root / 'TransitionHarness.xcodeproj'
project.mkdir(exist_ok=True)
objects = {}
def uid(key): return hashlib.sha1(key.encode()).hexdigest()[:24].upper()
def add(key, value):
    objects[uid(key)] = value
    return uid(key)
def arr(items): return '(' + ','.join(items) + (',)' if items else ')')
def quote(value): return '"' + value + '"'

refs = []; sources = {}
for target, directory in [('app', 'App'), ('test', 'Tests')]:
    sources[target] = []
    for path in sorted((root / directory).glob('*.swift')):
        name = path.relative_to(root).as_posix()
        ref = add(name, f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {quote(name)}; sourceTree = SOURCE_ROOT;')
        refs.append(ref)
        sources[target].append(add(name + 'build', f'isa = PBXBuildFile; fileRef = {ref};'))
asset = add('asset', 'isa = PBXFileReference; lastKnownFileType = image.png; path = "../RocoNative/Resources/PrototypeContent/JL_miaomiao.png"; sourceTree = SOURCE_ROOT;')
asset_build = add('asset-build', f'isa = PBXBuildFile; fileRef = {asset};')
products = {}
for target, name in [('app', 'TransitionHarness.app'), ('test', 'TransitionHarnessUITests.xctest')]:
    products[target] = add(target + '-product', f'isa = PBXFileReference; explicitFileType = {"wrapper.application" if target == "app" else "wrapper.cfbundle"}; path = {name}; sourceTree = BUILT_PRODUCTS_DIR;')
product_group = add('products', f'isa = PBXGroup; children = {arr(list(products.values()))}; name = Products; sourceTree = "<group>";')
group = add('group', f'isa = PBXGroup; children = {arr(refs + [asset, product_group])}; sourceTree = "<group>";')
configs = {}
for target in ['project', 'app', 'test']:
    ids = []
    for mode in ['Debug', 'Release']:
        settings = {'IPHONEOS_DEPLOYMENT_TARGET': '27.0', 'SWIFT_VERSION': '6.0', 'SDKROOT': 'iphoneos', 'TARGETED_DEVICE_FAMILY': quote('1,2'), 'SWIFT_STRICT_CONCURRENCY': 'complete', 'SWIFT_APPROACHABLE_CONCURRENCY': 'YES', 'CLANG_ENABLE_MODULES': 'YES', 'CLANG_ENABLE_OBJC_ARC': 'YES', 'SWIFT_OPTIMIZATION_LEVEL': quote('-Onone' if mode == 'Debug' else '-O'), 'ENABLE_TESTABILITY': 'YES'}
        if target != 'project':
            settings.update({'PRODUCT_NAME': quote('$(TARGET_NAME)'), 'PRODUCT_BUNDLE_IDENTIFIER': quote('top.aoe.rocom.transition-harness' + ('.uitests' if target == 'test' else '')), 'GENERATE_INFOPLIST_FILE': 'YES', 'CODE_SIGN_STYLE': 'Automatic', 'SWIFT_DEFAULT_ACTOR_ISOLATION': 'MainActor' if target == 'app' else 'nonisolated'})
        if target == 'app':
            settings.update({'INFOPLIST_KEY_CFBundleDisplayName': quote('P0 Zoom Lab'), 'INFOPLIST_KEY_UILaunchScreen_Generation': 'YES', 'INFOPLIST_KEY_UIApplicationSceneManifest_Generation': 'YES', 'INFOPLIST_KEY_UISupportedInterfaceOrientations': quote('UIInterfaceOrientationPortrait')})
        if target == 'test': settings['TEST_TARGET_NAME'] = 'TransitionHarness'
        ids.append(add(target + mode, 'isa = XCBuildConfiguration; buildSettings = {' + ''.join(k + ' = ' + v + ';' for k, v in settings.items()) + '}; name = ' + mode + ';'))
    configs[target] = add(target + 'configs', f'isa = XCConfigurationList; buildConfigurations = {arr(ids)}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Debug;')
proxy = add('proxy', f'isa = PBXContainerItemProxy; containerPortal = {uid("project")}; proxyType = 1; remoteGlobalIDString = {uid("app")}; remoteInfo = TransitionHarness;')
dep = add('dep', f'isa = PBXTargetDependency; target = {uid("app")}; targetProxy = {proxy};')
for target in ['app', 'test']:
    phases = []
    for phase, kind, files in [('sources', 'PBXSourcesBuildPhase', sources[target]), ('frameworks', 'PBXFrameworksBuildPhase', []), ('resources', 'PBXResourcesBuildPhase', [asset_build] if target == 'app' else [])]:
        phases.append(add(target + phase, f'isa = {kind}; buildActionMask = 2147483647; files = {arr(files)}; runOnlyForDeploymentPostprocessing = 0;'))
    name = 'TransitionHarness' + ('UITests' if target == 'test' else '')
    add(target, f'isa = PBXNativeTarget; buildConfigurationList = {configs[target]}; buildPhases = {arr(phases)}; buildRules = (); dependencies = {arr([dep] if target == "test" else [])}; name = {name}; productReference = {products[target]}; productType = {quote("com.apple.product-type.application" if target == "app" else "com.apple.product-type.bundle.ui-testing")};')
add('project', f'isa = PBXProject; attributes = {{LastUpgradeCheck = 2700; TargetAttributes = {{{uid("test")} = {{TestTargetID = {uid("app")};}};}};}}; buildConfigurationList = {configs["project"]}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; knownRegions = (en, Base); mainGroup = {group}; productRefGroup = {product_group}; projectDirPath = ""; projectRoot = ""; targets = {arr([uid("app"), uid("test")])};')
(project / 'project.pbxproj').write_text('// !$*UTF8*$!\n{archiveVersion = 1; classes = {}; objectVersion = 60; objects = {\n' + ''.join(k + ' = {' + v + '};\n' for k, v in sorted(objects.items())) + '}; rootObject = ' + uid('project') + ';}\n')
schemes = project / 'xcshareddata/xcschemes'
schemes.mkdir(parents=True, exist_ok=True)
def ref(target, name): return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid(target)}" BuildableName="{name}" BlueprintName="{name.split(".")[0]}" ReferencedContainer="container:TransitionHarness.xcodeproj"/>'
app = ref('app', 'TransitionHarness.app'); test = ref('test', 'TransitionHarnessUITests.xctest')
(schemes / 'TransitionHarness.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2700" version="1.3"><BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{app}</BuildActionEntry></BuildActionEntries></BuildAction><TestAction buildConfiguration="Debug" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">{test}</TestableReference></Testables></TestAction><LaunchAction buildConfiguration="Debug" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{app}</BuildableProductRunnable></LaunchAction><ProfileAction buildConfiguration="Release"><BuildableProductRunnable runnableDebuggingMode="0">{app}</BuildableProductRunnable></ProfileAction><AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/></Scheme>''')
