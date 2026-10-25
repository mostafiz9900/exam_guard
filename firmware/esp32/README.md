# ExamGuard sensor node (ESP32)

A small ESP32 board that sits in the exam hall (under a desk, on a wall,
at the back row) and scans for Bluetooth and Wi-Fi devices all exam long.
It reports to the invigilator phone that hosts the hall, so every phone in
the hall sees what the node hears, how strong it is, and alerts from it.

**Hardware:** any ESP32 DevKit with an ESP32-WROOM-32,
a USB cable and a USB power bank or phone charger. No wiring needed.

## 1. Flash the firmware (once per board)

Install **VS Code** with the **PlatformIO IDE** extension (or
`pip install platformio`), plug the board in by USB, then from this folder:

```sh
pio run -t upload        # build and flash
pio device monitor       # optional: watch the log (115200 baud)
```

No settings are needed in the code: everything is set from a phone.

## 2. Set it up from a phone (no computer needed)

1. In the ExamGuard app: **Dashboard → Hall link → Host this hall**.
   The **Sensor nodes** card shows the node key and these same steps.
2. Power the node. The first time it opens setup by itself. Later, to
   change settings, hold the **BOOT** button for **3 seconds** — the light
   double-blinks.
3. On **another** phone (not the one running the hotspot — joining a Wi-Fi
   can switch its hotspot off), connect to Wi-Fi **ExamGuard-Setup-XXXXXX**
   (password **examguard**). A setup page opens (if not, open
   `http://192.168.4.1`).
4. Tap **Configure WiFi**: pick the host phone's hotspot, enter its
   password, the **node key**, and optionally a node name (e.g.
   `ExamGuard-BackRow`). Tap **Save**.
5. Put that phone back on the hall hotspot. The node restarts, joins, and
   appears under **In this hall** with a solid light.

Settings are kept on the board through power cuts. Leave the key field
empty to keep the current key.

### Why setup never opens by itself during an exam

Setup opens **only** on a first start or when someone holds BOOT for 3 s,
is password-protected, and closes after **5 minutes**. If the hotspot is
switched off mid-exam, the node does NOT open a setup network — it just
keeps retrying. And if anyone tampers with a node, every phone in the hall
shows **Sensor node offline** at once.

### Optional: bake in defaults

Copy `include/node_config.example.h` to `include/node_config.h` (git-ignored)
to preset the hotspot, key, name, hub address or setup password.

## 3. LED

| LED | Meaning |
|---|---|
| Solid | Live in the hall, sending every 2 s |
| Fast blink | Wi-Fi OK, can't reach the host phone (hall not hosted yet?) |
| Slow blink | Not on Wi-Fi (hotspot off, wrong password) |
| Double blink | Setup mode (5 minutes) |

## 4. It looks after itself

- Re-joins Wi-Fi when it drops; forces a fresh re-join after 2 minutes.
- Reconnects to the host phone every 3 s when the link drops.
- Wrong node key: waits 30 s between tries (serial log says so).
- Wi-Fi fine but the host unreachable for 10 minutes: restarts cleanly.

## What the app does with a node

- Lists it under **In this hall** as a sensor node.
- Shows everything it hears under **Detected by others**, with the distance
  from the node.
- After the room baseline, raises the same **new-device alerts** as the
  phones for devices the node hears (rules: in the room, untrusted, heard
  over 3 s; random address changes are not "new").
- Shows **Sensor node offline** on every phone if it disappears.

## Placement tips

- Put nodes where invigilators can't stand all the time: back rows, corners.
- Keep it away from metal cabinets and walls' wiring; 1 m off the floor is
  better than on the floor.
- One node covers roughly a 10–15 m radius indoors; signal-based distance
  is approximate (walls, bodies and desks change it).

## What it sends (protocol v1)

JSON over a WebSocket to `ws://<host>:47800` — see
`lib/features/hall/repository/hall_protocol.dart` in the app:

- `hello` with the node key (kind `node`); a wrong key is refused and the
  node waits 30 s before retrying.
- `sightings` every 2 s: the 60 strongest devices heard in the last 15 s
  at -90 dBm or stronger, with raw clues (Bluetooth company id, first data
  byte, service UUIDs, Wi-Fi SSID). The app classifies them with the same
  rules as the phones.

Unlike an iPhone, the ESP32 sees Apple's own Bluetooth data, so a node can
recognise AirPods even when every invigilator uses an iPhone.

## Limits

- 2.4 GHz Wi-Fi and Bluetooth Low Energy only. Classic-only Bluetooth
  earpieces that don't advertise over BLE are not seen by the node (Android
  phones in the hall still find those).
- While it scans Wi-Fi (every 30 s, about 2 s), the link pauses briefly.
- The node has no clock; the host phone stamps when data arrived.
