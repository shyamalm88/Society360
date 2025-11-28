# Firebase Guard App Registration - Exact Details

## 📋 Quick Reference

Use these **exact values** when registering the Guard app in Firebase Console:

---

## Android App Registration

### Step 1: Add Android App to Firebase

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your **Society360** project
3. Click **gear icon** ⚙️ → **Project settings**
4. Scroll to "Your apps" section
5. Click **"Add app"** → Select **Android** 🤖

### Step 2: Fill in Details

```
┌─────────────────────────────────────────────────────────────┐
│ Android package name (Required)                             │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ com.society360.society360_guard                         │ │
│ └─────────────────────────────────────────────────────────┘ │
│                                                             │
│ App nickname (Optional)                                     │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ Society360 Guard App                                    │ │
│ └─────────────────────────────────────────────────────────┘ │
│                                                             │
│ Debug signing certificate SHA-1 (Optional)                  │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ (Leave blank for now - add later if needed)             │ │
│ └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

**Exact Values**:
- **Android package name**: `com.society360.society360_guard`
- **App nickname**: `Society360 Guard App` (optional but recommended)
- **SHA-1**: Leave blank (optional - for Google Sign-In, not needed for FCM)

### Step 3: Download Configuration File

1. Click **"Register app"**
2. Download **`google-services.json`**
3. Place it in: `society360_guard/android/app/google-services.json`

---

## iOS App Registration

### Step 1: Add iOS App to Firebase

1. In the same Firebase **Society360** project
2. Click **"Add app"** → Select **Apple** 🍎

### Step 2: Fill in Details

```
┌─────────────────────────────────────────────────────────────┐
│ iOS bundle ID (Required)                                    │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ com.society360.society360Guard                          │ │
│ └─────────────────────────────────────────────────────────┘ │
│                                                             │
│ App nickname (Optional)                                     │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ Society360 Guard App iOS                                │ │
│ └─────────────────────────────────────────────────────────┘ │
│                                                             │
│ App Store ID (Optional)                                     │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ (Leave blank - not published yet)                       │ │
│ └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

**Exact Values**:
- **iOS bundle ID**: `com.society360.society360Guard`
- **App nickname**: `Society360 Guard App iOS` (optional but recommended)
- **App Store ID**: Leave blank (not published yet)

### Step 3: Download Configuration File

1. Click **"Register app"**
2. Download **`GoogleService-Info.plist`**
3. Place it in: `society360_guard/ios/Runner/GoogleService-Info.plist`

---

## 🔍 How These Values Were Found

### Android Package Name
**Source**: `/Volumes/Personal/Society360/society360_guard/android/app/build.gradle.kts`

```kotlin
android {
    namespace = "com.society360.society360_guard"

    defaultConfig {
        applicationId = "com.society360.society360_guard"  // ← This is it!
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
    }
}
```

### iOS Bundle ID
**Source**: `/Volumes/Personal/Society360/society360_guard/ios/Runner.xcodeproj/project.pbxproj`

```
PRODUCT_BUNDLE_IDENTIFIER = com.society360.society360Guard;  // ← This is it!
```

**Note**: iOS uses camelCase `Guard` while Android uses snake_case `guard`

---

## ⚠️ Important Notes

### 1. Package Name vs Bundle ID Format

```
Android:  com.society360.society360_guard  (snake_case with underscore)
iOS:      com.society360.society360Guard   (camelCase)
```

These are **intentionally different** - this is normal in Flutter apps!

### 2. Don't Mix Up With Resident App

Your Resident app uses:
```
Android:  com.society360.society360        (no suffix)
iOS:      com.society360.society360        (no suffix)
```

Your Guard app uses:
```
Android:  com.society360.society360_guard  (with _guard suffix)
iOS:      com.society360.society360Guard   (with Guard suffix)
```

### 3. Firebase Project Structure

After registration, your Firebase project will have:

```
Firebase Project: Society360
├── Android Apps (2):
│   ├── com.society360.society360         (Resident App)
│   └── com.society360.society360_guard   (Guard App) ← NEW
└── iOS Apps (2):
    ├── com.society360.society360         (Resident App)
    └── com.society360.society360Guard    (Guard App) ← NEW
```

All 4 apps share the **same Firebase services** (FCM, Analytics, etc.)

---

## 📥 Where to Place Downloaded Files

### Android Configuration
```bash
# Download: google-services.json
# Place in:
society360_guard/android/app/google-services.json

# Verify with:
ls -l society360_guard/android/app/google-services.json
```

### iOS Configuration
```bash
# Download: GoogleService-Info.plist
# Place in:
society360_guard/ios/Runner/GoogleService-Info.plist

# Verify with:
ls -l society360_guard/ios/Runner/GoogleService-Info.plist
```

### ⚠️ Common Mistake

**DON'T** use the Resident app's config files!
- ❌ Resident's `google-services.json` → Won't work for Guard app
- ❌ Resident's `GoogleService-Info.plist` → Won't work for Guard app
- ✅ Download **new** files specifically for Guard app

---

## ✅ Verification Steps

### After Adding Android App

1. Check the downloaded `google-services.json` contains:
   ```json
   {
     "project_info": {
       "project_id": "society360-xxxxx"
     },
     "client": [
       {
         "client_info": {
           "mobilesdk_app_id": "1:xxxxx:android:xxxxx",
           "android_client_info": {
             "package_name": "com.society360.society360_guard"  ← Verify this!
           }
         }
       }
     ]
   }
   ```

### After Adding iOS App

1. Check the downloaded `GoogleService-Info.plist` contains:
   ```xml
   <key>BUNDLE_ID</key>
   <string>com.society360.society360Guard</string>  ← Verify this!
   ```

---

## 🚀 After Registration

### 1. Place Config Files

```bash
cd /Volumes/Personal/Society360

# For Android
cp ~/Downloads/google-services.json society360_guard/android/app/

# For iOS
cp ~/Downloads/GoogleService-Info.plist society360_guard/ios/Runner/
```

### 2. Clean and Rebuild

```bash
cd society360_guard

# Clean
flutter clean

# Get dependencies
flutter pub get

# For iOS, also run
cd ios
pod install
cd ..
```

### 3. Build and Test

```bash
# iOS
flutter build ios --debug

# Android
flutter build apk --debug
```

### 4. Verify Firebase Initialization

Run the app and check logs for:
```
✅ Firebase initialized successfully
✅ FCM token: fxxxxxxxxxxxxxxxxxxxxxxx
```

---

## 🔧 Troubleshooting

### Error: "No matching client found for package name"

**Cause**: Wrong package name or config file in wrong location

**Fix**:
1. Verify package name in Firebase Console matches `com.society360.society360_guard`
2. Verify `google-services.json` is in `android/app/` directory
3. Run `flutter clean` and rebuild

### Error: "Could not configure Firebase on iOS"

**Cause**: Wrong bundle ID or config file in wrong location

**Fix**:
1. Verify bundle ID in Firebase Console matches `com.society360.society360Guard`
2. Verify `GoogleService-Info.plist` is in `ios/Runner/` directory
3. Run `pod install` in `ios/` directory
4. Clean Xcode build: `Product` → `Clean Build Folder`

---

## 📋 Registration Checklist

- [ ] Go to Firebase Console
- [ ] Open Society360 project
- [ ] Add Android app with package: `com.society360.society360_guard`
- [ ] Download Android `google-services.json`
- [ ] Place in `society360_guard/android/app/`
- [ ] Add iOS app with bundle: `com.society360.society360Guard`
- [ ] Download iOS `GoogleService-Info.plist`
- [ ] Place in `society360_guard/ios/Runner/`
- [ ] Run `flutter clean`
- [ ] Run `flutter pub get`
- [ ] Run `cd ios && pod install && cd ..`
- [ ] Build and test the app
- [ ] Verify Firebase logs show successful initialization

---

## 🎯 Summary

**Copy-paste these exact values into Firebase Console**:

| Platform | Field | Value |
|----------|-------|-------|
| **Android** | Package name | `com.society360.society360_guard` |
| **Android** | App nickname | `Society360 Guard App` |
| **iOS** | Bundle ID | `com.society360.society360Guard` |
| **iOS** | App nickname | `Society360 Guard App iOS` |

**Remember**: These are different from your Resident app!
