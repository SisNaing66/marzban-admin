# Marzban Admin (multi-server, no reseller)

Flutter app that talks directly to Marzban panels.
Features: multi-server, users (create/search/filter/QR/delete/disable/reset), stats, core config editor,
Merge Users between servers, local Backup + Restore.

## Get the APK without installing anything (GitHub Actions)
1. Create a new GitHub repo, upload everything in this folder (keep `.github/workflows/build-apk.yml`).
2. Open the repo > Actions > "Build APK" > Run workflow (it also runs on every push to main).
3. When it finishes (~5 min) download `marzban-admin-apk` from the run page. Use `app-arm64-v8a-release.apk` on modern phones.

## Build locally
```
flutter create --platforms=android --org com.example --project-name marzban_admin .
# add INTERNET permission + android:usesCleartextTraffic="true" to android/app/src/main/AndroidManifest.xml
flutter pub get
flutter build apk --release --split-per-abi
```
