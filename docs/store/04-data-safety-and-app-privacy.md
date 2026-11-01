# Data safety (Google Play) and App Privacy (Apple)

These answers match the code as of version 1.0.0. Re-check them before
every release that adds an SDK, a network call or a new kind of stored data.

**What the app does with data, in short:**
- No servers, accounts, analytics, ads or crash reporting.
- Everything is stored on the device (Hive).
- Data leaves the phone only when the user acts:
  - sharing a PDF report;
  - the hall link to other phones in the same local network;
  - sending a sensor node its Wi-Fi details over Bluetooth.
- One third-party SDK sends anything: **Google ML Kit** barcode scanning, Android only, used by `mobile_scanner`. It sends technical diagnostics.

---

## Google Play — Data safety form

### Data collection and security

| Question | Answer |
|---|---|
| Does your app collect or share any of the required user data types? | **Yes**, only because of Google ML Kit diagnostics (see below). If you remove ML Kit, you can answer No. |
| Is all of the user data collected by your app encrypted in transit? | **Yes**. ML Kit uses HTTPS. |
| Do you provide a way for users to request that their data is deleted? | **No account data exists.** Answer "No". In the explanation, say: data is only on the device; clear app data or uninstall. |

### Data types

Declare only this (collected by Google ML Kit):

| Category → type | Collected | Shared | Ephemeral? | Required? | Purposes |
|---|---|---|---|---|---|
| **App info and performance → Diagnostics** | Yes | No | No | Required, can't be turned off | Analytics. Google uses it to monitor and improve ML Kit. |
| **Device or other IDs** | Yes | No | No | Required | Analytics |

Declare these as **not** collected, because they never leave the device or
leave only by the user's own sharing:
- Location. The permission is only for Bluetooth/Wi-Fi scanning, and the location is never read.
- Personal info: name, entered by the user and stored locally.
- Photos: incident photos, stored locally.
- Files and docs: the PDF report, shared by the user.
- Contacts, Messages, Audio, Calendar, Health, Financial, Web browsing.

Why the hall link and report sharing are not "collected": Play counts data as
collected when it is sent off the device to you or a third party. These two
are started by the user and go directly to apps or devices the user chooses,
never to the developer. That falls under Play's "user-initiated sharing"
exemption.

> Before submitting, check Google's current ML Kit disclosure:
> https://developers.google.com/ml-kit/android-data-disclosure
> If it lists different types, follow it.

### Security practices to declare
- Data encrypted in transit: **Yes**
- Users can request deletion: **No**, with the explanation above
- Committed to Play Families Policy: **No**. The app is not for children.
- Independent security review: **No**

---

## Apple — App Privacy ("nutrition label")

On iOS the QR scanner uses Apple's own Vision framework. ML Kit is not in
the iOS build, so nothing is sent to the developer or third parties.

| Question | Answer |
|---|---|
| Do you or your third-party partners collect data from this app? | **No, we do not collect data from this app** |

Result on the App Store: **"Data Not Collected"**.

If any analytics or crash SDK is added later, this must change.

### Privacy manifest (PrivacyInfo.xcprivacy)

Apple requires reasons for some APIs. Flutter and the plugins ship their own
manifests. Before release:
1. Archive the app.
2. In Xcode, **Product → Archive → Generate Privacy Report**.
3. Check that it lists no data collection.
4. Check that each "required reason API" (e.g. UserDefaults, file timestamps) has a reason from a plugin's manifest.

If one is missing, add `ios/Runner/PrivacyInfo.xcprivacy` with that API's
reason code.
