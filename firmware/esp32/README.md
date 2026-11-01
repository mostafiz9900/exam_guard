# Pahara sensor node (ESP32)

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

## 2. Connect it from the app (about a minute)

1. Turn on the hotspot the node should use — the phone that will host the
   hall is best. ESP32 is **2.4 GHz only**: on iPhone turn on
   **Personal Hotspot → Maximize Compatibility**.
2. Power the node. The first time it opens setup by itself. Later, to
   change settings, hold the **BOOT** button for **3 seconds** — the light
   double-blinks.
3. In the app: **Dashboard → Sensor nodes → Add a sensor node** (or Hall
   link → Sensor nodes → Add a sensor node). Tap **Find my node**, tap
   **Node A1B2C3** (the code is the end of its name).
4. Pick the hotspot from the list the node sees, type its password, and
   optionally a name (e.g. `Back-row`). Tap **Connect node**.
5. The node tests the Wi-Fi itself and the app shows each step: wrong
   password or a hotspot it can't see is reported right away, and you can
   fix it and try again. When it says **Node set up** the node restarts and
   appears under **Sensor nodes** with a solid light.

The node key is sent by the app — nothing to type. The hotspot and
password stay filled in for the next node, so the second node is one tap.
Settings are kept on the board through power cuts.

### Without Bluetooth (fallback)

While setup is open the node also offers a Wi-Fi setup page:

1. On **another** phone (not the one running the hotspot — joining a Wi-Fi
   can switch its hotspot off), connect to Wi-Fi **Pahara-Setup-XXXXXX**
   (password **pahara123**). A setup page opens (if not, open
   `http://192.168.4.1`).
2. Tap **Configure WiFi**: pick the hotspot, enter its password, the
   **node key** (Sensor nodes screen), optionally a node name. Tap **Save**.

### Try the app without a node

`tools/fake_node.dart` joins a hosted hall exactly like a node, so the
dashboard card, the node list, alerts and "Sensor node offline" can be
tried before buying anything:

```sh
dart run firmware/esp32/tools/fake_node.dart <host-phone-ip> <node-key>
```

### Why setup never opens by itself during an exam

Setup opens **only** on a first start or when someone holds BOOT for 3 s,
and closes after **5 minutes** (kept open while the app is connected). If the hotspot is
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
| Double blink | Setup mode (5 minutes) — ready for the app |

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
- **Hall map** (Sensor nodes → Open hall map): place each node on the seat
  map once per room; every suspicious device the nodes hear is drawn as a
  likely area with its nearest seat ("Log incident at C4"). Nodes hearing
  each other calibrate the room automatically. Three nodes in different
  corners work best; one node only gives "within X m of the node".

## Placement tips

- Put nodes where invigilators can't stand all the time: back rows, corners.
- Keep it away from metal cabinets and walls' wiring; 1 m off the floor is
  better than on the floor.
- One node covers roughly a 10–15 m radius indoors; signal-based distance
  is approximate (walls, bodies and desks change it).

## Bluetooth setup (protocol v1)

In setup mode the node advertises `Pahara-Setup-XXXXXX` with GATT
service `e9a40001-5c1d-4b6a-9e2f-3d8c7b1a0e01` — see
`lib/features/node_setup/model/node_setup_protocol.dart`:

| Characteristic | | |
|---|---|---|
| `…0002` info | read | `{"v":1,"id":"N-A1B2C3","name":…,"fw":"1.1.0","key":bool}` |
| `…0003` networks | read | `[{"s":ssid,"r":rssi,"o":1 if open}]`, strongest 12 |
| `…0004` config | write | `{"v":1,"ssid","pass","key","name","hub"}` or `{"v":1,"cmd":"scan"}` |
| `…0005` status | read, notify | `{"s":state,"d":detail}` |

Status: `joining` → `wifi_ok` → `host_ok` / `no_host` → `saved` (then it
restarts), or `no_network` / `bad_password` / `wifi_failed` /
`bad_request` (setup stays open for another try).

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
