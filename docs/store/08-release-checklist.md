# Release checklist — Pahara 1.0.0

## Already done in the code (2026-11-01)

- [x] App name **Pahara** everywhere:
  - [x] Android label and iOS display/bundle name;
  - [x] in-app texts in en/bn/ar;
  - [x] PDF report, report file name `pahara_room_…pdf`;
  - [x] hall QR scheme `pahara://`;
  - [x] web, Windows and Linux titles.
- [x] ID **`com.it24617.pahara.app`**: Android applicationId and namespace (Kotlin moved to `com/it24617/pahara/app`), iOS and macOS bundle IDs, Linux APPLICATION_ID.
- [x] ESP32 firmware names `Pahara-Node-…` / `Pahara-Setup-…`; setup Wi-Fi password `pahara123`. Old `ExamGuard-…` nodes and `examguard://` codes are still accepted.
- [x] iOS permission texts rewritten. `ITSAppUsesNonExemptEncryption = NO` added.
- [x] Builds verified: Android debug APK and iOS (no codesign).
- [x] All tests pass; analyzer clean.
- Not renamed on purpose: the Dart package `exam_guard` (only used in code imports, never visible to users) and internal platform channel names.

## Blockers — must do before submitting

- [x] **App icon** (2026-11-01): the radar emblem, cut out of its baked-in checkerboard, on navy `#0B1628`.
  - Android: legacy, round and adaptive icons. iOS: every size. Store files are in `docs/store/assets/`.
  - The source was only 512 px, so the 1024 px App Store icon is upscaled. A sharper 1024+ px original (with real transparency) would be better.
- [x] **Splash + onboarding** (2026-11-01): native splash on Android (12+ too) and iOS, an animated brand intro, and a 5-page first-run introduction.
- [ ] **Android release signing.** Create an upload keystore and `android/key.properties` (never commit it), and point `buildTypes.release.signingConfig` at it. Today release builds use the debug key, and Play rejects that.
- [ ] **flutter_blue_plus license.** `lib/core/services/bluetooth/*_impl.dart` uses `License.nonprofit`. If Pahara is sold or used commercially, buy the commercial license from the package author and switch to `License.commercial`.
- [ ] **Publish the privacy policy** on Blogger ([09-blogger-setup.md](09-blogger-setup.md)) and put its URL in both consoles.
- [ ] **Fill every `{{…}}` placeholder** in these docs (list in [README](README.md)).
- [ ] **Apple Developer account** ($99/year) and **Google Play developer account** ($25 once).
  - New personal Play accounts must run a **closed test with 12+ testers for 14 days** before production.

## Strongly recommended

- [ ] Decide on iPad:
  - keep it, and make iPad screenshots and test on an iPad; or
  - set `TARGETED_DEVICE_FAMILY = 1` (iPhone only).
- [ ] Test on real devices:
  - Android 10, 12 and 14 (permission flows differ);
  - an iPhone with iOS 17 or later.
- [ ] Version: `pubspec.yaml` → `version: 1.0.0+1`. Raise the build number (`+2`, …) on every upload.
- [ ] Android `targetSdk` must meet Play's current requirement (Flutter's default usually does). Check the Play Console warning on the first upload.
- [ ] Generate the Xcode privacy report and confirm no data collection ([04](04-data-safety-and-app-privacy.md)).
- [ ] Add a **"Delete this exam"** action in History. The privacy policy now says the only way to delete is clearing app data. Update the policy if this is added.
- [ ] Optional: drop ML Kit on Android (QR via camera + a pure-Dart decoder). Play Data safety then becomes "No data collected".

## Build commands

```sh
# Android App Bundle for Play
fvm flutter build appbundle --release
# → build/app/outputs/bundle/release/app-release.aab

# iOS — then upload with Xcode Organizer or Transporter
fvm flutter build ipa --release
# → build/ios/ipa/*.ipa
```

## Submission order

1. Publish the privacy policy and support pages on Blogger.
2. Play Console:
   1. Create the app (package `com.it24617.pahara.app`).
   2. Fill the store listing and App content (Data safety, rating, target audience, ads = no).
   3. Upload the AAB to Internal testing, then Closed testing, then Production.
3. App Store Connect:
   1. Create the app (bundle `com.it24617.pahara.app`).
   2. Fill the listing, App Privacy and age rating.
   3. Upload the build, add reviewer notes, and submit for review.
