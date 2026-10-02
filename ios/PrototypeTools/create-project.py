# Dependency-free project generator for the P0 Xcode project. Stable IDs, no package installs.
from pathlib import Path
import hashlib
root=Path('ios'); project=root/'RocoNative.xcodeproj'; project.mkdir(exist_ok=True)
def uid(s): return hashlib.sha1(s.encode()).hexdigest()[:24].upper()
objects={}
def add(key,body): objects[uid(key)]=body; return uid(key)
def arr(v): return '('+','.join(v)+(',)' if v else ')')
def q(s): return '"'+s+'"'
appfiles=sorted(p for p in (root/'RocoNative').rglob('*.swift') if 'Tests' not in p.parts and 'HostTests' not in p.parts)
testfiles=sorted(p for p in (root/'RocoNative/Tests').iterdir() if p.suffix in {'.swift','.m'})
def files(paths):
    refs=[]; builds=[]
    for p in paths:
        rel=p.relative_to(root).as_posix(); filetype='sourcecode.c.objc' if p.suffix == '.m' else 'sourcecode.swift'
        refs.append(add(rel,f'isa = PBXFileReference; lastKnownFileType = {filetype}; path = {q(rel)}; sourceTree = SOURCE_ROOT;'))
        builds.append(add(rel+'build',f'isa = PBXBuildFile; fileRef = {uid(rel)};'))
    return refs,builds
ar,ab=files(appfiles); tr,tb=files(testfiles)
hr,hb=files(sorted((root/'RocoNative/HostTests').glob('*.swift')))
res=add('resource','isa = PBXFileReference; lastKnownFileType = folder; path = RocoNative/Resources/PrototypeContent; sourceTree = SOURCE_ROOT;')
rb=add('resource-build',f'isa = PBXBuildFile; fileRef = {res};')
appProduct=add('app-product','isa = PBXFileReference; explicitFileType = wrapper.application; path = RocoNative.app; sourceTree = BUILT_PRODUCTS_DIR;')
testProduct=add('test-product','isa = PBXFileReference; explicitFileType = wrapper.cfbundle; path = RocoNativeUITests.xctest; sourceTree = BUILT_PRODUCTS_DIR;')
hostProduct=add('host-product','isa = PBXFileReference; explicitFileType = wrapper.cfbundle; path = RocoNativeHostTests.xctest; sourceTree = BUILT_PRODUCTS_DIR;')
products=add('products',f'isa = PBXGroup; children = {arr([appProduct,testProduct,hostProduct])}; name = Products; sourceTree = "<group>";')
group=add('group',f'isa = PBXGroup; children = {arr(ar+tr+hr+[res,products])}; sourceTree = "<group>";')
package=add('package','isa = XCLocalSwiftPackageReference; relativePath = Packages/RocoCore;')
product=add('domain-product',f'isa = XCSwiftPackageProductDependency; package = {package}; productName = RocoDomain;')
framework=add('domain-build',f'isa = PBXBuildFile; productRef = {product};')
configs={}
for target in ['project','app','test','host']:
    ids=[]
    for mode in ['Debug','Release']:
        settings={'IPHONEOS_DEPLOYMENT_TARGET':'27.0','SWIFT_VERSION':'6.0','SDKROOT':'iphoneos','TARGETED_DEVICE_FAMILY':q('1,2'),'SWIFT_STRICT_CONCURRENCY':'complete','SWIFT_APPROACHABLE_CONCURRENCY':'YES','ONLY_ACTIVE_ARCH':'YES' if mode=='Debug' else 'NO','CLANG_ENABLE_MODULES':'YES','CLANG_ENABLE_OBJC_ARC':'YES','SWIFT_OPTIMIZATION_LEVEL':q('-Onone' if mode=='Debug' else '-O'),'DEBUG_INFORMATION_FORMAT':q('dwarf'),'ENABLE_TESTABILITY':'YES' if mode=='Debug' else 'NO'}
        if mode=='Debug' and target=='project': settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS']=q('$(inherited) DEBUG')
        if target!='project': settings.update({'PRODUCT_NAME':q('$(TARGET_NAME)'),'PRODUCT_BUNDLE_IDENTIFIER':q('top.aoe.rocom.prototype'+('.uitests' if target=='test' else '.hosttests' if target=='host' else '')),'GENERATE_INFOPLIST_FILE':'YES','CODE_SIGN_STYLE':'Automatic','SWIFT_DEFAULT_ACTOR_ISOLATION':'MainActor' if target=='app' else 'nonisolated','INFOPLIST_KEY_UILaunchScreen_Generation':'YES'})
        if target=='app': settings.update({'INFOPLIST_KEY_CFBundleDisplayName':q('rocom'),'INFOPLIST_KEY_UIApplicationSceneManifest_Generation':'YES','INFOPLIST_KEY_UISupportedInterfaceOrientations':q('UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight')})
        if target=='test': settings.update({'TEST_TARGET_NAME':'RocoNative','SWIFT_OBJC_BRIDGING_HEADER':q('RocoNative/Tests/TouchDriver.h')})
        if target=='host': settings.update({'TEST_HOST':q('$(BUILT_PRODUCTS_DIR)/RocoNative.app/RocoNative'),'BUNDLE_LOADER':q('$(TEST_HOST)')})
        ids.append(add(target+mode,'isa = XCBuildConfiguration; buildSettings = {'+''.join(k+' = '+v+';' for k,v in settings.items())+'}; name = '+mode+';'))
    configs[target]=add(target+'configs',f'isa = XCConfigurationList; buildConfigurations = {arr(ids)}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Debug;')
app=uid('app'); test=uid('test'); host=uid('host'); proj=uid('project')
proxy=add('proxy',f'isa = PBXContainerItemProxy; containerPortal = {proj}; proxyType = 1; remoteGlobalIDString = {app}; remoteInfo = RocoNative;')
dep=add('dep',f'isa = PBXTargetDependency; target = {app}; targetProxy = {proxy};')
for name,builds,productref in [('app',ab,appProduct),('test',tb,testProduct),('host',hb,hostProduct)]:
    src=add(name+'sources',f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = {arr(builds)}; runOnlyForDeploymentPostprocessing = 0;')
    fw=add(name+'frameworks',f'isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = {arr([framework] if name=="app" else [])}; runOnlyForDeploymentPostprocessing = 0;')
    resources=add(name+'resources',f'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = {arr([rb] if name=="app" else [])}; runOnlyForDeploymentPostprocessing = 0;')
    add(name,f'isa = PBXNativeTarget; buildConfigurationList = {configs[name]}; buildPhases = {arr([src,fw,resources])}; buildRules = (); dependencies = {arr([dep]) if name!="app" else "()"}; name = {"RocoNative" if name=="app" else "RocoNativeUITests" if name=="test" else "RocoNativeHostTests"}; packageProductDependencies = {arr([product]) if name=="app" else "()"}; productReference = {productref}; productType = {q("com.apple.product-type.application" if name=="app" else "com.apple.product-type.bundle.ui-testing" if name=="test" else "com.apple.product-type.bundle.unit-test")};')
add('project',f'isa = PBXProject; attributes = {{ LastUpgradeCheck = 2700; TargetAttributes = {{{test} = {{TestTargetID = {app};}};}}; }}; buildConfigurationList = {configs["project"]}; compatibilityVersion = "Xcode 14.0"; developmentRegion = zh_CN; knownRegions = (zh_CN,en,Base); mainGroup = {group}; packageReferences = {arr([package])}; productRefGroup = {products}; projectDirPath = ""; projectRoot = ""; targets = {arr([app,test,host])};')
(project/'project.pbxproj').write_text('// !$*UTF8*$!\n{archiveVersion = 1; classes = {}; objectVersion = 60; objects = {\n'+''.join(k+' = {'+v+'};\n' for k,v in sorted(objects.items()))+'}; rootObject = '+proj+';}\n')
schemes=project/'xcshareddata/xcschemes'; schemes.mkdir(parents=True,exist_ok=True)
def ref(id,name,path):return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{id}" BuildableName="{name}" BlueprintName="{path}" ReferencedContainer="container:RocoNative.xcodeproj"/>'
a=ref(app,'RocoNative.app','RocoNative'); t=ref(test,'RocoNativeUITests.xctest','RocoNativeUITests'); h=ref(host,'RocoNativeHostTests.xctest','RocoNativeHostTests')
(schemes/'RocoNative.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2700" version="1.3"><BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{a}</BuildActionEntry></BuildActionEntries></BuildAction><TestAction buildConfiguration="Debug" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">{t}</TestableReference><TestableReference skipped="NO">{h}</TestableReference></Testables></TestAction><LaunchAction buildConfiguration="Debug" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{a}</BuildableProductRunnable></LaunchAction><ProfileAction buildConfiguration="Release"><BuildableProductRunnable runnableDebuggingMode="0">{a}</BuildableProductRunnable></ProfileAction><AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/></Scheme>''')
