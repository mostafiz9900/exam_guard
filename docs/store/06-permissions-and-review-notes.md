# Permissions and notes for the store reviewers

## Android permissions (from AndroidManifest.xml)

| Permission | Why — paste into Play Console where asked |
|---|---|
| `BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT` (Android 12+); `BLUETOOTH`, `BLUETOOTH_ADMIN` (≤ 11) | Scan for nearby Bluetooth devices in the exam hall. Connect to the user's own Pahara sensor nodes to set them up. |
| `BLUETOOTH_ADVERTISE` | Required by the Bluetooth stack for node setup on some devices. |
| `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION` | Android requires location permission for Bluetooth and Wi-Fi scanning. Foreground only. The app never reads or stores location. |
| `NEARBY_WIFI_DEVICES`, `ACCESS_WIFI_STATE`, `CHANGE_WIFI_STATE` | Detect phone hotspots and Wi-Fi networks in the hall. |
| `ACCESS_NETWORK_STATE`, `INTERNET` | Hall link between invigilator phones and sensor nodes over the local Wi-Fi or hotspot (local sockets). There are no internet servers. |
| `CAMERA` (from plugins) | Incident photos, hidden-lens finder, hall QR code scan. |

There is no background location, foreground service, SMS, call log or
`QUERY_ALL_PACKAGES`, so **no special permission declaration forms** are
needed in Play Console.

## iOS usage strings (Info.plist)

| Key | Text shown to the user |
|---|---|
| NSBluetoothAlwaysUsageDescription | Pahara uses Bluetooth to find hidden wireless devices in the exam hall and to set up Pahara sensor nodes. |
| NSLocationWhenInUseUsageDescription | Pahara needs this to scan for nearby Bluetooth devices. Your location is never read or stored. |
| NSCameraUsageDescription | Pahara uses the camera to photograph incident evidence, find hidden camera lenses and scan hall QR codes. |
| NSLocalNetworkUsageDescription | Pahara links invigilator phones and sensor nodes in the same exam hall over the local Wi-Fi or hotspot. |
| ITSAppUsesNonExemptEncryption | NO (no encryption beyond the OS) |

---

## Google Play — App access

**"All functionality is available without special access."** There is no
login.

## Notes for the reviewer

Paste this into **Play Console → App content → App access → Instructions**
(optional) and into **App Store Connect → App Review Information → Notes**:

```
Pahara is a tool for exam invigilators to find hidden Bluetooth devices (earbuds, smartwatches, phones) in an exam hall and to log incidents. There is no login and no server; all data stays on the device.

How to try it:
1. On the first screen enter any institution, your name and a room number (e.g. "101"), then tap Start monitoring.
2. Allow Bluetooth (and Location on Android, required by the OS for Bluetooth scanning).
3. The Dashboard opens. Tap "Wireless scanner": nearby Bluetooth devices (headphones, watches, phones) are listed with an approximate distance.
4. Tap a device → Track to open the tracking radar; walk closer and the gauge rises.
5. Back on the Dashboard try the Magnetic scanner (bring a phone or magnet close), RF meter and Lens finder.
6. Tap "Log incident" to record an incident with a photo; "End exam" creates a PDF report you can share.

Optional features:
- "Hall link" connects two or more invigilator phones on the same Wi-Fi via a QR code. It needs a second device; the app is fully usable without it.
- "Sensor nodes" are optional ESP32 hardware boxes that the school builds itself. They are NOT required for any other feature, and the app is fully functional without them.

Location permission is used only because Android/iOS require it for Bluetooth scanning; the app never reads the location.
```

## App Store review contact

| Field | Value |
|---|---|
| First / last name | `{{CONTACT_NAME}}` |
| Phone | `{{CONTACT_PHONE}}` |
| Email | `{{SUPPORT_EMAIL}}` |
| Sign-in required | No |
