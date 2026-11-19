"""Patches the freshly generated android/ project for the plugins we use. Fails loudly if a pattern is missing."""
import pathlib, re, sys

root = pathlib.Path('android')

# --- manifest: permissions + cleartext (http panels) ---
m = root / 'app/src/main/AndroidManifest.xml'
s = m.read_text()
perms = ['INTERNET', 'POST_NOTIFICATIONS', 'USE_BIOMETRIC']
add = ''.join(f'    <uses-permission android:name="android.permission.{p}"/>\n'
              for p in perms if f'android.permission.{p}' not in s)
assert '<application' in s, 'no <application> in manifest'
s = s.replace('<application', add + '    <application', 1)
if 'usesCleartextTraffic' not in s:
    s = s.replace('<application', '<application android:usesCleartextTraffic="true"', 1)
m.write_text(s)
print('manifest ok')

# --- app gradle: core library desugaring (flutter_local_notifications) + appcompat (local_auth theme) ---
kts = root / 'app/build.gradle.kts'
groovy = root / 'app/build.gradle'
if kts.exists():
    g, is_kts = kts, True
elif groovy.exists():
    g, is_kts = groovy, False
else:
    sys.exit('no app/build.gradle(.kts)')
s = g.read_text()
flag = 'isCoreLibraryDesugaringEnabled = true' if is_kts else 'coreLibraryDesugaringEnabled true'
s, n = re.subn(r'compileOptions\s*\{', lambda mo: mo.group(0) + '\n        ' + flag, s, count=1)
assert n == 1, 'compileOptions block not found'
if is_kts:
    s += '\n\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n    implementation("androidx.appcompat:appcompat:1.7.0")\n}\n'
else:
    s += "\n\ndependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'\n    implementation 'androidx.appcompat:appcompat:1.7.0'\n}\n"
g.write_text(s)
print('gradle ok', g)

# --- MainActivity must be a FragmentActivity for the biometric prompt ---
acts = list((root / 'app/src/main').rglob('MainActivity.*'))
assert acts, 'MainActivity not found'
for a in acts:
    t = a.read_text()
    t2 = re.sub(r'\bFlutterActivity\b', 'FlutterFragmentActivity', t)
    assert t2 != t, f'FlutterActivity not found in {a}'
    a.write_text(t2)
    print('activity ok', a)

# --- themes must inherit from AppCompat (biometric prompt) ---
for f, old, new in [
    ('values/styles.xml', '@android:style/Theme.Light.NoTitleBar', 'Theme.AppCompat.Light.NoActionBar'),
    ('values-night/styles.xml', '@android:style/Theme.Black.NoTitleBar', 'Theme.AppCompat.NoActionBar'),
]:
    p = root / 'app/src/main/res' / f
    if p.exists():
        t = p.read_text()
        p.write_text(t.replace(old, new))
        print('theme', f, 'patched' if old in t else 'unchanged')
