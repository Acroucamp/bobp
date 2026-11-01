# Android release setup

Do these once, in this order. Replace `com.yourname.appname` with your own ID.
**The application ID is permanent once the app is on Google Play**, so choose it carefully.

## 1. Application ID and name
Easiest: `dart run change_app_package_name:main com.yourname.appname`
(or edit `namespace` and `applicationId` in `android/app/build.gradle.kts` and move `MainActivity`).

In `android/app/src/main/AndroidManifest.xml` set the visible name:
`<application android:label="Your App Name" ...>` (max 30 characters on Play).

## 2. Manifest: three things that matter in RELEASE builds
Flutter only adds the INTERNET permission to debug builds. Without it, a release
build cannot reach Supabase.

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET"/>

    <!-- Needed so url_launcher can open links and mail on Android 11+ -->
    <queries>
        <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="https"/></intent>
        <intent><action android:name="android.intent.action.SENDTO"/><data android:scheme="mailto"/></intent>
    </queries>

    <application
        android:label="Your App Name"
        android:enableOnBackInvokedCallback="true"
        ...>
```
Keep the `bobp://auth-callback` intent filter you added for password reset.

## 3. SDK levels
Google Play requires new apps to target Android 16 (API 36). In `android/app/build.gradle.kts`:
```kotlin
android {
    compileSdk = 36
    defaultConfig {
        targetSdk = 36
        // keep minSdk, versionCode, versionName as generated
    }
}
```
If the build complains about the Android Gradle Plugin or Gradle version, upgrade Flutter
(`flutter upgrade`) and re-run; the error message names the version it wants.

## 4. App icon
```
flutter pub add --dev flutter_launcher_icons
```
Add to `pubspec.yaml`:
```yaml
flutter_launcher_icons:
  android: true
  ios: false
  image_path: "assets/icon/icon.png"   # 1024x1024 PNG, no transparency
```
Run `dart run flutter_launcher_icons`. For Play you also need a separate 512x512 PNG.

## 5. Upload keystore (signing)
Generate once (keep the file and passwords somewhere safe, e.g. a password manager plus an offline copy):
```
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```
On Windows, if `keytool` is not found, use the one shipped with Android Studio, e.g.
`"C:\Program Files\Android\Android Studio\jbr\bin\keytool"` (`flutter doctor -v` shows the Java path).

Move `upload-keystore.jks` to `android/app/`. Create `android/key.properties`:
```
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=upload-keystore.jks
```
Add the signing config to `android/app/build.gradle.kts`:
```kotlin
import java.io.FileInputStream
import java.util.Properties

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
        }
    }
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}
```
(The `import` lines go at the very top of the file.) Add `gitignore_additions.txt` to `.gitignore`
BEFORE committing, so the keystore and passwords never reach GitHub.

In Play Console, enrol in **Play App Signing** when you upload the first bundle (it is the default).
Google then holds the app signing key and your keystore is only the upload key.

## 6. Version
`pubspec.yaml`: `version: 1.0.0+1` (name+build number). Every upload needs a higher build number.

## 7. Build and TEST THE RELEASE BUILD
```
cp env/prod.example.json env/prod.json     # fill in your Supabase URL and publishable key
flutter build apk --release --dart-define-from-file=env/prod.json
```
Install that APK on a real phone and run through everything: register, log in, book, reset
password, delete a throwaway account. Release builds can fail in ways debug builds don't
(missing INTERNET permission, deep links, shrinking). Then build the bundle for Play:
```
flutter build appbundle --release --dart-define-from-file=env/prod.json
```
Output: `build/app/outputs/bundle/release/app-release.aab`
