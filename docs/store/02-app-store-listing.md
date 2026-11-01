# Apple App Store — App Store Connect listing

App: **Pahara** · Subtitle: **Exam Hall Security**
Fill the `{{…}}` placeholders listed in [README](README.md) first.

---

## App information

| Field | Value |
|---|---|
| Name (≤ 30) | `Pahara` |
| Subtitle (≤ 30) | `Exam Hall Security` |
| Primary language | English (U.S.) |
| Localizations | Bangla is not an App Store storefront language. Add Arabic. Bangla text lives inside the app. |
| Bundle ID | `com.it24617.pahara.app` |
| SKU | `pahara-ios-001` |
| Primary category | **Utilities** |
| Secondary category | Education |
| Content rights | Does not contain third-party content |
| Age rating | 4+ (see [05-content-rating.md](05-content-rating.md)) |
| Price | Free |
| Privacy Policy URL | `{{PRIVACY_URL}}` |
| Support URL | `{{SUPPORT_URL}}`, e.g. a Blogger "Support" page |
| Marketing URL (optional) | `{{WEBSITE_URL}}` |
| Copyright | `© 2026 {{DEVELOPER_NAME}}` |

---

## English (U.S.)

### Promotional text (≤ 170, can change any time)

```
Find hidden earbuds, smartwatches and phones in the exam hall. Log incidents with evidence and share a PDF report. Offline, no account.
```

### Description (≤ 4000)

> iOS does not let apps scan classic Bluetooth or Wi-Fi networks, and it hides the details of Apple devices. This description says so on purpose: Apple rejects claims the iPhone version can't keep.

```
Pahara helps exam invigilators find hidden electronic devices in the exam hall – earbuds, smartwatches, phones and spy earpieces – and record incidents with evidence.

Everything runs on the iPhone, offline. No account, no sign-in, no ads.

WIRELESS SCANNER
• Lists nearby Bluetooth Low Energy devices with an easy distance in metres.
• Recognises earbuds, smartwatches, phones and spy earpieces from their signals and names.
• Take a room baseline at the start: anything new that appears later raises an alert.
• Mark the invigilators' own devices as trusted so they never alert.

FIND THE DEVICE
• Tracking radar: walk around and watch the closeness gauge rise as you get nearer.
• Walk finder: vibrates when you pass near any chosen device.
• Seat sweep: measures the signal seat by seat and points to the most likely seat.

MORE DETECTORS
• Magnetic scanner – finds the magnets inside earpieces, phones and speakers using the compass sensor.
• RF activity meter – shows how busy the Bluetooth air is around you.
• Hidden camera lens finder – uses the flashlight and camera to spot the glint of a lens.

INCIDENT LOG AND REPORT
• Log an incident in seconds: category, severity, seat on the seat map, notes and a photo.
• At the end of the exam, a PDF report with a timeline and evidence charts, ready to share.

ONE HALL, MANY INVIGILATORS
• Hall link: invigilators' phones join one hall by scanning a QR code on the same Wi-Fi or hotspot.
• Everyone sees the shared device list and alerts. Data stays inside the hall's local network.

OPTIONAL SENSOR NODES (ESP32)
• Small ESP32 boxes at the back rows scan all exam long and report to the host phone.
• Set them up from the app over Bluetooth. A hall map shows the likely area of each suspicious device.

English, Bangla and Arabic.

HONEST LIMITS
Pahara finds devices that are switched on and transmitting. On iPhone, Apple devices show little detail and classic Bluetooth and Wi-Fi scanning are not available. A device that is fully off cannot be detected by any app. Distance and position are approximate. Always confirm in person before acting.

PRIVACY
No servers and no accounts. Exam data stays on your iPhone unless you share a report yourself.
```

### Keywords (≤ 100 characters, comma-separated, no spaces after commas)

```
exam,invigilator,proctor,cheating,bluetooth,scanner,earpiece,detector,hidden,device,smartwatch,hall
```

### What's New – version 1.0.0

```
First release: wireless scanner with alerts, tracking radar, magnetic scanner, RF meter, lens finder, incident log with PDF report, hall link and optional ESP32 sensor nodes with a hall map.
```

---

## Arabic

| Field | Text |
|---|---|
| Name | `Pahara` |
| Subtitle | `أمن قاعة الامتحان` |
| Promotional text | `اكتشف السماعات والساعات والهواتف المخفية في قاعة الامتحان. سجّل الحوادث مع الأدلة وشارك تقرير PDF. دون إنترنت ودون حساب.` |
| Keywords | `امتحان,مراقب,غش,بلوتوث,ماسح,سماعة,كاشف,مخفي,جهاز,ساعة,قاعة` |

For the description, use the Arabic full description in [01-play-store-listing.md](01-play-store-listing.md#العربية-ar) as is.
