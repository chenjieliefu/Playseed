"""Build a locally branded app without modifying the installed Godot application."""
from pathlib import Path
import argparse
import os
import plistlib
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--runtime', type=Path, default=Path.home()/'Desktop/Godot游戏引擎/Godot.app/Contents/MacOS/Godot')
args = parser.parse_args()
for helper in ['playseed_base.gd', 'playseed_feedback.gd', 'playseed_audio.gd']:
    shutil.copy2(ROOT/'runtime'/helper, ROOT/'app'/helper)
app = ROOT/'Playseed.app'
macos = app/'Contents/MacOS'
resources = app/'Contents/Resources'
macos.mkdir(parents=True, exist_ok=True)
resources.mkdir(parents=True, exist_ok=True)
runtime = macos/'PlayseedRuntime'
if not runtime.exists():
    shutil.copy2(args.runtime, runtime)
    runtime.chmod(0o755)
subprocess.run(['clang', '-Os', str(ROOT/'scripts/playseed_launcher.c'), '-o', str(macos/'Playseed')], check=True)
subprocess.run(['swiftc', '-O', '-target', os.uname().machine + '-apple-macosx13.0', str(ROOT/'scripts/remove_background.swift'), '-o', str(macos/'PlayseedCutout')], check=True)
icon = ROOT/'assets/brand/playseed-app-icon-v2.png'
subprocess.run(['swift', str(ROOT/'scripts/package_icon.swift'), str(ROOT/'assets/brand/playseed-app-icon-v2-source.png'), str(icon)], check=True)
shutil.copy2(icon, ROOT/'app/assets/playseed-icon.png')
iconset = ROOT/'.playseed/build/Playseed.iconset'
iconset.mkdir(parents=True, exist_ok=True)
for points in [16, 32, 128, 256, 512]:
    for scale in [1, 2]:
        name = f'icon_{points}x{points}' + ('@2x' if scale == 2 else '') + '.png'
        subprocess.run(['sips', '-z', str(points*scale), str(points*scale), str(icon), '--out', str(iconset/name)], check=True, stdout=subprocess.DEVNULL)
subprocess.run(['iconutil', '-c', 'icns', str(iconset), '-o', str(resources/'Playseed.icns')], check=True)
shutil.copy2(resources/'Playseed.icns', ROOT/'assets/brand/Playseed.icns')
shutil.copy2(resources/'Playseed.icns', ROOT/'app/assets/Playseed.icns')
info = {
    'CFBundleName': 'Playseed', 'CFBundleDisplayName': 'Playseed',
    'CFBundleIdentifier': 'local.playseed.studio', 'CFBundleExecutable': 'Playseed',
    'CFBundleIconFile': 'Playseed.icns', 'CFBundlePackageType': 'APPL',
    'CFBundleShortVersionString': '0.8.39', 'CFBundleVersion': '56',
    'CFBundleDevelopmentRegion': 'zh_CN',
    'CFBundleLocalizations': ['zh-Hans', 'zh_CN'],
    'CFBundleAllowMixedLocalizations': True,
    'NSHighResolutionCapable': True, 'NSPrincipalClass': 'NSApplication',
    'NSHumanReadableCopyright': 'Playseed. Includes Godot Engine, © Juan Linietsky, Ariel Manzur & Godot contributors.',
    'LSMinimumSystemVersion': '13.0', 'LSApplicationCategoryType': 'public.app-category.developer-tools',
}
with (app/'Contents/Info.plist').open('wb') as f:
    plistlib.dump(info, f)
for locale in ['zh-Hans', 'zh_CN']:
    localized = resources / (locale + '.lproj')
    localized.mkdir(parents=True, exist_ok=True)
    (localized/'InfoPlist.strings').write_text('"CFBundleDisplayName" = "Playseed";\n"CFBundleName" = "Playseed";\n', encoding='utf-8')
    (localized/'Localizable.strings').write_text('"Cancel" = "取消";\n"Open" = "打开";\n"New Folder" = "新建文件夹";\n"Search" = "搜索";\n', encoding='utf-8')
(resources/'Runtime-Notice.txt').write_text('Playseed uses a local bundled copy of Godot Engine as its runtime.\nGodot Engine: https://godotengine.org/\nSource and license: https://github.com/godotengine/godot\nCopyright Juan Linietsky, Ariel Manzur and Godot Engine contributors.\n')
subprocess.run(['codesign', '--force', '--deep', '--sign', '-', str(app)], check=True)
subprocess.run([str(runtime), '--headless', '--path', str(ROOT/'app'), '--import'], check=True)
print(app)
