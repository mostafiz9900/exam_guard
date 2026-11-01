# Privacy Policy — Pahara (Exam Hall Security)

This is the readable source. The copy to publish on Blogger is
[privacy-policy-blogger.html](privacy-policy-blogger.html), with the same
text in English and Bangla. When you change one, change the other.

**Effective date:** {{EFFECTIVE_DATE}}
**Developer:** {{DEVELOPER_NAME}}
**Contact:** {{SUPPORT_EMAIL}}

---

## English

### 1. Summary

Pahara is a tool for exam invigilators. It runs on the phone and **has no
servers and no user accounts**. We, the developer, do not receive, store or
sell any data from the app. Everything the app records stays on your device
unless **you** choose to share it.

### 2. Information the app handles

All of this is stored **only on your device**:

| What | Why |
|---|---|
| Exam details you type: institution, invigilator name, room, exam times, seat layout | To run the exam session and print the report |
| Incident records you create: category, severity, seat, notes, device name / ID | The incident log and the PDF report |
| Photos you take with the in-app camera for an incident | Evidence in the incident log and the report |
| Information about nearby wireless devices: Bluetooth / Wi-Fi name, hardware address or identifier, signal strength, device type | To detect devices in the exam hall. These signals are broadcast publicly by the devices themselves. |
| Sensor readings: magnetometer, camera frames for the lens finder | Measured live on the device. Camera frames are analysed in memory and **never saved**. |
| Settings: language, theme, trusted devices, room equipment lists, sensor node key, node positions on the seat map, the last hotspot name used for node setup | To remember your preferences between exams |

The app does **not**:
- collect your GPS location;
- read your contacts, messages or files;
- use advertising IDs, analytics or tracking;
- show ads.

### 3. Permissions and why they are needed

| Permission | Use |
|---|---|
| **Bluetooth / Nearby devices** | Scan for nearby Bluetooth devices, and set up Pahara sensor nodes |
| **Location** (Android, and iOS "When in use") | Android and iOS require it to scan for Bluetooth and Wi-Fi devices. The app **never reads or stores your location**. |
| **Nearby Wi-Fi devices / Wi-Fi state** (Android) | Find phone hotspots and Wi-Fi networks nearby |
| **Camera** | Incident photos, the hidden-lens finder, and scanning a hall QR code |
| **Local network** | Link invigilators' phones and sensor nodes in the same hall over the local Wi-Fi or hotspot |
| **Internet** (Android) | Used **only** for the local hall link inside your Wi-Fi or hotspot. The app does not contact any internet server. |

You can refuse any permission. Only the features that need it stop working.

### 4. When information leaves your device

Only by your own action:

- **Sharing a report.** When you tap Share, the PDF goes to the app you choose (email, messaging and so on). Those apps' privacy policies then apply.
- **Hall link.** When you host or join a hall, these are sent directly to the other invigilators' phones and sensor nodes in that hall, over your local Wi-Fi or hotspot:
  - your name as invigilator;
  - the list of devices your phone detects;
  - alerts.

  Nothing goes over the internet or to us. The link ends when the exam ends.
- **Sensor node setup.** When you add an ESP32 sensor node, the app sends the hotspot name, its password and the node key to that node over Bluetooth. They are stored on the node so it can join the hall. The app never stores the hotspot password.

We do not sell, rent or trade any information.

### 5. Third-party components

- **Google ML Kit (Android only).** Used by the QR code scanner for the hall link. Google may receive limited technical diagnostics from ML Kit: device model, OS version, app version and API performance. See Google's ML Kit data disclosure: https://developers.google.com/ml-kit/android-data-disclosure
- The phone's **operating system** (Android or iOS) handles Bluetooth, Wi-Fi, camera and sharing under its own privacy policy.

No other third-party SDK in the app collects data.

### 6. Storage, retention and deletion

- Data is kept on your device until you remove it.
- To delete everything, uninstall the app, or clear its storage:
  - Android: **Settings → Apps → Pahara → Storage → Clear data**.
  - iPhone: delete the app.
- Reports you shared stay wherever you sent them.

### 7. Security

Data is stored in the app's private storage on your device, protected by the operating system. The hall link works only inside your local network and needs a join code from the host phone. Sensor nodes need a node key. Protect your phone with a screen lock.

### 8. Children

Pahara is a professional tool for exam staff. It is **not directed at children** under 13 and does not knowingly collect any information from children. Information about devices that students carry is processed only on the invigilator's phone, for exam supervision.

### 9. Your responsibilities as the user

Use Pahara according to your institution's exam rules and the laws of your country. Detection results are approximate. Always confirm in person before taking action against anyone.

### 10. Changes to this policy

If this policy changes, we will update this page and its effective date. Big changes will also be mentioned in the app's release notes.

### 11. Contact

Questions or requests: **{{SUPPORT_EMAIL}}**
{{DEVELOPER_NAME}}, {{DEVELOPER_ADDRESS}}

---

## বাংলা

### ১. সংক্ষেপে

পাহারা পরীক্ষার পরিদর্শকদের একটি টুল। এটি ফোনেই চলে।
- **কোনো সার্ভার বা ইউজার অ্যাকাউন্ট নেই।**
- আমরা (ডেভেলপার) অ্যাপ থেকে কোনো তথ্য পাই না, রাখি না বা বিক্রি করি না।
- **আপনি** নিজে শেয়ার না করলে অ্যাপের সব তথ্য আপনার ফোনেই থাকে।

### ২. অ্যাপ যে তথ্য ব্যবহার করে

এসব তথ্য **শুধু আপনার ফোনে** থাকে:

| তথ্য | কেন |
|---|---|
| আপনার দেওয়া পরীক্ষার তথ্য: প্রতিষ্ঠান, পরিদর্শকের নাম, রুম, সময়, সিট লেআউট | পরীক্ষার সেশন চালানো ও রিপোর্ট তৈরি |
| আপনার লেখা ঘটনা: ধরন, গুরুত্ব, সিট, নোট, ডিভাইসের নাম/আইডি | ঘটনা লগ ও পিডিএফ রিপোর্ট |
| ঘটনার জন্য অ্যাপের ক্যামেরায় তোলা ছবি | প্রমাণ হিসেবে |
| আশেপাশের ওয়্যারলেস ডিভাইসের তথ্য: ব্লুটুথ/ওয়াই-ফাই নাম, হার্ডওয়্যার ঠিকানা বা আইডি, সিগন্যালের শক্তি, ধরন | হলে ডিভাইস শনাক্ত করা। এসব সিগন্যাল ডিভাইস নিজেই প্রকাশ্যে পাঠায়। |
| সেন্সর রিডিং: ম্যাগনেটোমিটার; লেন্স ফাইন্ডারের ক্যামেরা ফ্রেম | ফোনেই সরাসরি মাপা হয়। ক্যামেরা ফ্রেম মেমরিতে বিশ্লেষণ করা হয়, **কখনো সেভ হয় না**। |
| সেটিংস: ভাষা, থিম, বিশ্বস্ত ডিভাইস, রুমের যন্ত্রপাতি, সেন্সর নোড কি, সিট ম্যাপে নোডের অবস্থান, শেষ ব্যবহৃত হটস্পটের নাম | পরের পরীক্ষার জন্য পছন্দ মনে রাখা |

অ্যাপ যা **করে না**:
- আপনার জিপিএস লোকেশন নেয় না;
- কন্টাক্ট, মেসেজ বা ফাইল পড়ে না;
- বিজ্ঞাপন আইডি, অ্যানালিটিক্স বা ট্র্যাকিং ব্যবহার করে না;
- বিজ্ঞাপন দেখায় না।

### ৩. পারমিশন ও কারণ

| পারমিশন | ব্যবহার |
|---|---|
| **ব্লুটুথ / কাছের ডিভাইস** | আশেপাশের ব্লুটুথ ডিভাইস স্ক্যান ও সেন্সর নোড সেটআপ |
| **লোকেশন** | ব্লুটুথ/ওয়াই-ফাই স্ক্যানের জন্য অ্যান্ড্রয়েড ও আইওএস এটি বাধ্যতামূলক করে। অ্যাপ **কখনো আপনার লোকেশন পড়ে না বা রাখে না**। |
| **কাছের ওয়াই-ফাই / ওয়াই-ফাই অবস্থা** (অ্যান্ড্রয়েড) | ফোনের হটস্পট ও ওয়াই-ফাই খোঁজা |
| **ক্যামেরা** | ঘটনার ছবি, লেন্স ফাইন্ডার ও হলের কিউআর কোড স্ক্যান |
| **লোকাল নেটওয়ার্ক** | একই হলের পরিদর্শকদের ফোন ও সেন্সর নোড যুক্ত করা |
| **ইন্টারনেট** (অ্যান্ড্রয়েড) | **শুধু** আপনার ওয়াই-ফাই/হটস্পটের ভেতরে হল লিংকের জন্য। অ্যাপ কোনো ইন্টারনেট সার্ভারে যোগাযোগ করে না। |

যেকোনো পারমিশন না দিতে পারেন। তখন শুধু সেই পারমিশনের ওপর নির্ভরশীল ফিচারগুলো কাজ করবে না।

### ৪. কখন তথ্য ফোনের বাইরে যায়

শুধু আপনার নিজের কাজে:

- **রিপোর্ট শেয়ার।** শেয়ার চাপলে পিডিএফ আপনার বাছাই করা অ্যাপে যায়। তখন সেই অ্যাপের নীতি প্রযোজ্য।
- **হল লিংক।** হল হোস্ট বা জয়েন করলে, ওই হলের অন্য পরিদর্শকের ফোন ও সেন্সর নোডে আপনার লোকাল ওয়াই-ফাই/হটস্পট দিয়ে সরাসরি যায়:
  - পরিদর্শক হিসেবে আপনার নাম;
  - আপনার ফোনে ধরা পড়া ডিভাইসের তালিকা;
  - অ্যালার্ট।

  ইন্টারনেটে বা আমাদের কাছে কিছু যায় না। পরীক্ষা শেষে লিংক বন্ধ হয়।
- **সেন্সর নোড সেটআপ।** নোড যোগ করলে অ্যাপ ব্লুটুথে নোডকে হটস্পটের নাম, পাসওয়ার্ড ও নোড কি পাঠায়। হলে যুক্ত হওয়ার জন্য নোডে সেগুলো থাকে। অ্যাপ হটস্পটের পাসওয়ার্ড কখনো সেভ করে না।

আমরা কোনো তথ্য বিক্রি, ভাড়া বা বিনিময় করি না।

### ৫. তৃতীয় পক্ষের উপাদান

- **Google ML Kit (শুধু অ্যান্ড্রয়েড):** হল লিংকের কিউআর স্ক্যানারে ব্যবহৃত। গুগল এ থেকে সীমিত কারিগরি তথ্য পেতে পারে: ডিভাইস মডেল, ওএস ও অ্যাপের ভার্সন, পারফরম্যান্স। বিস্তারিত: https://developers.google.com/ml-kit/android-data-disclosure
- ব্লুটুথ, ওয়াই-ফাই, ক্যামেরা ও শেয়ার ফোনের **অপারেটিং সিস্টেম** তার নিজস্ব নীতিতে পরিচালনা করে।

অ্যাপের অন্য কোনো তৃতীয় পক্ষের উপাদান তথ্য সংগ্রহ করে না।

### ৬. সংরক্ষণ ও মুছে ফেলা

- আপনি না মোছা পর্যন্ত তথ্য ফোনে থাকে।
- সব মুছতে অ্যাপ আনইনস্টল করুন, অথবা:
  - অ্যান্ড্রয়েড: **Settings → Apps → Pahara → Storage → Clear data**।
  - আইফোন: অ্যাপটি ডিলিট করুন।
- শেয়ার করা রিপোর্ট যেখানে পাঠিয়েছেন সেখানেই থাকবে।

### ৭. নিরাপত্তা

- তথ্য অ্যাপের নিজস্ব সুরক্ষিত স্টোরেজে থাকে।
- হল লিংক শুধু লোকাল নেটওয়ার্কে চলে এবং হোস্টের জয়েন কোড লাগে।
- সেন্সর নোডের জন্য নোড কি লাগে।
- ফোনে স্ক্রিন লক ব্যবহার করুন।

### ৮. শিশু

পাহারা পরীক্ষা পরিচালনাকারীদের পেশাদার টুল।
- এটি ১৩ বছরের কম বয়সী শিশুদের জন্য **নয়**।
- এটি জেনেশুনে শিশুদের কোনো তথ্য সংগ্রহ করে না।
- শিক্ষার্থীদের ডিভাইসের তথ্য শুধু পরিদর্শকের ফোনে, পরীক্ষা তত্ত্বাবধানের জন্য প্রক্রিয়া করা হয়।

### ৯. ব্যবহারকারীর দায়িত্ব

- প্রতিষ্ঠানের পরীক্ষার নিয়ম ও দেশের আইন মেনে ব্যবহার করুন।
- শনাক্তকরণ আনুমানিক।
- কারো বিরুদ্ধে ব্যবস্থা নেওয়ার আগে নিজে গিয়ে নিশ্চিত হোন।

### ১০. নীতির পরিবর্তন

নীতি বদলালে এই পাতা ও কার্যকর তারিখ হালনাগাদ হবে। বড় পরিবর্তন অ্যাপের রিলিজ নোটেও জানানো হবে।

### ১১. যোগাযোগ

**{{SUPPORT_EMAIL}}**
{{DEVELOPER_NAME}}, {{DEVELOPER_ADDRESS}}
