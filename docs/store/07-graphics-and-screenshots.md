# Graphics and screenshots

## Required sizes

### Google Play

| Asset | Size / rule |
|---|---|
| App icon | 512 × 512 PNG, 32-bit, ≤ 1 MB, no rounded corners (Play rounds it) |
| Feature graphic | 1024 × 500 PNG/JPG, no transparency |
| Phone screenshots | 2–8, PNG/JPG, 16:9 or 9:16, each side 320–3840 px. Recommended 1080 × 1920. |
| Tablet screenshots | Optional (7" and 10") |

### Apple App Store

| Asset | Size / rule |
|---|---|
| App icon | 1024 × 1024 PNG, **no transparency**, no rounded corners — `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png` |
| iPhone 6.9" screenshots | 1320 × 2868 (or 1290 × 2796), 3–10. **Required.** |
| iPad 13" screenshots | 2064 × 2752. **Required while iPad is supported** (TARGETED_DEVICE_FAMILY = "1,2"). Make the app iPhone-only to skip this. |

Ready-made files: [assets/play-icon-512.png](assets/play-icon-512.png),
[assets/app-icon-1024.png](assets/app-icon-1024.png), and
[assets/emblem-transparent.png](assets/emblem-transparent.png) for the
feature graphic.

---

## Icon idea

A shield with a radar/signal wave inside, in the app's blue `#4B7CFE`, with
a white mark. It must still read clearly at 48 px. If Bangla lettering is
used, keep only "প" or nothing — no full words in the icon.

## Feature graphic (Play)

Blue gradient (`#2A4DCC → #4B7CFE`):
- left side: the icon and **"Pahara"**, with **"Exam Hall Security"** under it;
- right side: a phone showing the Dashboard.

Bangla listing variant: **"পাহারা — পরীক্ষা হলের নিরাপত্তা"**.

---

## Screenshot plan (same order for both stores)

Take them on a real phone in **light mode, English**. Make a second set in
Bangla for the bn-BD Play listing. Add one short caption above each phone
frame.

| # | Screen | Caption (EN) | ক্যাপশন (BN) |
|---|---|---|---|
| 1 | Dashboard during an exam (scan running, live stats) | Guard the exam hall in real time | রিয়েল টাইমে পরীক্ষা হল পাহারা |
| 2 | Wireless scanner list with an earbud "Very close" | Find hidden earbuds, watches and phones | লুকানো ইয়ারবাড, ঘড়ি ও ফোন খুঁজুন |
| 3 | New-device alert banner / alerts sheet | Instant alert when a new device appears | নতুন ডিভাইস এলেই সাথে সাথে অ্যালার্ট |
| 4 | Tracking radar with a high closeness gauge | Walk to the device with the radar | রাডার দিয়ে ডিভাইসের কাছে যান |
| 5 | Magnetic scanner red "Magnet very close" | Detect magnets inside earpieces | ইয়ারপিসের চুম্বক শনাক্ত করুন |
| 6 | Hall map with nodes and a red device area | See where it is on the seat map | সিট ম্যাপে অবস্থান দেখুন |
| 7 | Incident form with seat + photo | Log incidents with seat and photo | সিট ও ছবিসহ ঘটনা লিখুন |
| 8 | PDF report preview | One-tap PDF report | এক ট্যাপে পিডিএফ রিপোর্ট |

**Tips:**
- Use real but harmless device names, e.g. "Galaxy Buds".
- Never show a real student's name or roll number.
- Hide the status bar clock and battery, or set them to a clean state.
